"""Offline synthetic release fixtures. NEVER uses real Drive/GitHub credentials."""
import copy
import contextlib
import io
import os
import datetime as dt
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
from urllib.parse import urlsplit,parse_qs
import zipfile
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'automation'))
import drive_release as R
NOW=1700000000.
def timestamp(n):return dt.datetime.fromtimestamp(n,dt.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
def declaration():
    keys=set(R.TESTS)|set(R.DESKTOP_TESTS)
    return {'schema':R.SCHEMA,'artifactKind':'owner-tested-app-zip','repository':'synthetic-owner/KL-06-Manager','version':'v0.3.0-beta.2','sourceCommit':'b'*40,'driveFileId':'syntheticFile_012345','fileName':'KL-06-0.3.0-beta.2-windows-tested.zip','size':100,'sha256':'a'*64,'approvedAt':timestamp(NOW-60),'expiresAt':timestamp(NOW+3600),'platformTests':{'windows':{**{k:True for k in keys},'testedAt':timestamp(NOW-120),'osMajor':11}}}

def make_zip(path,entries=None):
    with zipfile.ZipFile(path,'w',compression=zipfile.ZIP_DEFLATED) as z:
        for name,data in entries or [('KL-06/KL-06 Manager.exe',b'MZsynthetic-unit-test-not-a-working-app')]:z.writestr(name,data)

class ApprovalTests(unittest.TestCase):
    def test_valid_synthetic_declaration(self):self.assertEqual(R.validate_approval(declaration(),now=NOW)['version'],'v0.3.0-beta.2')
    def test_every_required_test_must_be_true(self):
        for key in R.TESTS+R.DESKTOP_TESTS:
            d=declaration();d['platformTests']['windows'][key]=False
            with self.assertRaises(R.Refused,msg=key):R.validate_approval(d,now=NOW)
    def test_truthy_string_or_int_is_not_pass(self):
        for value in [1,'true',None,{},[]]:
            d=declaration();d['platformTests']['windows']['nativeBuild']=value
            with self.assertRaises(R.Refused):R.validate_approval(d,now=NOW)
    def test_source_not_owner_app(self):
        d=declaration();d['artifactKind']='source-zip'
        with self.assertRaises(R.Refused):R.validate_approval(d,now=NOW)
    def test_only_beta_versions(self):
        for value in ['v0.3.0','v0.3.0-stable','latest','v0.3.0-beta.2\n','v00.3.0-beta.2','../../tag']:
            d=declaration();d['version']=value
            with self.assertRaises(R.Refused):R.validate_approval(d,now=NOW)
    def test_expiry_and_future_dates(self):
        for approved,expiry in [(NOW-100,NOW-1),(NOW+200,NOW+400),(NOW-60,NOW+8*86400)]:
            d=declaration();d['approvedAt']=timestamp(approved);d['expiresAt']=timestamp(expiry)
            with self.assertRaises(R.Refused):R.validate_approval(d,now=NOW)
    def test_unknown_extra_or_duplicate_schema(self):
        d=declaration();d['autoApprove']=True
        with self.assertRaises(R.Refused):R.validate_approval(d,now=NOW)
        with self.assertRaises(R.Refused):R.decode('{"x":1,"x":2}')
    def test_exact_repo_protects_unrelated(self):
        d=declaration();d['repository']='synthetic-owner/EFI'
        with self.assertRaises(R.Refused):R.validate_approval(d,now=NOW)
    def test_phone_tests_not_substituted_by_desktop(self):
        d=declaration();d['platformTests']['android']=d['platformTests'].pop('windows')
        with self.assertRaises(R.Refused):R.validate_approval(d,now=NOW)
    def test_mac27_blocked_even_with_all_true(self):
        d=declaration();keys=set(R.TESTS)|set(R.DESKTOP_TESTS)|{'f13RunningOnly','workingGraphicsFnAudioUSBPreserved','hdrRemainsOff'};d['platformTests']={'macos':{**{k:True for k in keys},'testedAt':timestamp(NOW-120),'osMajor':27}}
        with self.assertRaises(R.Refused):R.validate_approval(d,now=NOW)

class ArchiveTests(unittest.TestCase):
    def setUp(self):self.temp=tempfile.TemporaryDirectory(prefix='kl06-zip-audit-test-');self.path=Path(self.temp.name)/'fixture.zip'
    def tearDown(self):self.temp.cleanup()
    def test_structural_windows_fixture_only(self):make_zip(self.path);self.assertEqual(R.audit_zip(self.path,['windows'])['platforms'],['windows'])
    def test_source_only_not_release_app(self):
        make_zip(self.path,[('Sources/main.swift',b'// source only')])
        with self.assertRaises(R.Refused):R.audit_zip(self.path,['macos'])
    def test_untested_platform_not_inferred(self):
        make_zip(self.path)
        with self.assertRaises(R.Refused):R.audit_zip(self.path,['windows','ios'])
    def test_private_and_unsafe_paths_refused(self):
        for path in ['../app.exe','/app.exe','C:/app.exe','x\\app.exe','EFI/BOOT/BOOTx64.efi','reports/private.txt','app/raw.csv','.env','id_ed25519','key.pem','app/UPLOAD-RECEIPT.json','__MACOSX/._x']:
            make_zip(self.path,[(path,b'MZsynthetic')])
            with self.assertRaises(R.Refused,msg=path):R.audit_zip(self.path,['windows'])
    def test_symlink_and_case_collision_refused(self):
        with zipfile.ZipFile(self.path,'w') as z:
            i=zipfile.ZipInfo('linked.exe');i.create_system=3;i.external_attr=(stat.S_IFLNK|0o777)<<16;z.writestr(i,'elsewhere')
        with self.assertRaises(R.Refused):R.audit_zip(self.path,['windows'])
        make_zip(self.path,[('app.exe',b'MZx'),('APP.exe',b'MZx')])
        with self.assertRaises(R.Refused):R.audit_zip(self.path,['windows'])
    def test_expansion_bomb_refused(self):
        make_zip(self.path,[('app.exe',b'MZ'+b'0'*2000000)])
        with self.assertRaises(R.Refused):R.audit_zip(self.path,['windows'])
    def test_invalid_zip_refused(self):
        self.path.write_bytes(b'not zip')
        with self.assertRaises(R.Refused):R.audit_zip(self.path,['windows'])

class FakeAPI:
    """In-memory ONLY; records hypothetical GitHub writes, never calls a network."""
    def __init__(self,raw,sig,artifact,folder='syntheticFolder_012345'):
        self.folder=folder;self.raw=raw;self.sig=sig;self.artifact=artifact;self.writes=[];self.private=True;self.repo_name='synthetic-owner/KL-06-Manager';self.existing=None;self.tag_assets=[];self.change=False;self.reads={};self.bad_digest=False;self.ref=None;self.tag_objects={};self.move_tag_on_upload=False;self.make_public_on_upload=False
        self.files={R.APPROVAL_NAME:('syntheticApproval_012345',raw),R.SIGNATURE_NAME:('syntheticSignature_012345',sig),'KL-06-0.3.0-beta.2-windows-tested.zip':('syntheticFile_012345',artifact)}
    def meta(self,identifier):
        if identifier==self.folder:return {'id':identifier,'name':'App','mimeType':'application/vnd.google-apps.folder','trashed':False,'version':'1'}
        name,(i,raw)=next((n,v) for n,v in self.files.items() if v[0]==identifier)
        self.reads[identifier]=self.reads.get(identifier,0)+1
        return {'id':i,'name':name,'mimeType':'application/zip' if name.endswith('.zip') else 'application/octet-stream','parents':[self.folder],'trashed':False,'size':str(len(raw)),'md5Checksum':hashlib.md5(raw).hexdigest(),'version':'2' if self.change and self.reads[identifier]>1 else '1'}
    def json(self,method,url,body=None,allow404=False,file=None):
        p=urlsplit(url);q=parse_qs(p.query)
        if p.hostname=='www.googleapis.com':
            if p.path.endswith('/files'):
                query=q['q'][0];name=next(name for name in self.files if f"name = '{name}'" in query);return {'files':[{'id':self.files[name][0]}]}
            return self.meta(p.path.rsplit('/',1)[1])
        if method=='GET' and p.path.endswith('/KL-06-Manager'):return {'full_name':self.repo_name,'private':self.private,'visibility':'private' if self.private else 'public','default_branch':'main','archived':False,'fork':False}
        if '/compare/' in p.path:return {'status':'ahead'}
        if '/git/ref/tags/' in p.path:return copy.deepcopy(self.ref)
        if '/git/tags/' in p.path:return copy.deepcopy(self.tag_objects[p.path.rsplit('/',1)[1]])
        if '/releases/tags/' in p.path:return copy.deepcopy(self.existing)
        self.writes.append((method,p.hostname,p.path,body))
        if p.hostname=='uploads.github.com':
            raw=Path(file).read_bytes();asset={'name':Path(file).name,'size':len(raw),'digest':'sha256:'+('0'*64 if self.bad_digest else hashlib.sha256(raw).hexdigest())}
            if self.existing is not None:self.existing['assets'].append(asset)
            if self.move_tag_on_upload:self.ref['object']['sha']='c'*40
            if self.make_public_on_upload:self.private=False
            return asset
        if method=='POST' and p.path.endswith('/git/refs'):
            self.ref={'ref':body['ref'],'object':{'type':'commit','sha':body['sha']}};return copy.deepcopy(self.ref)
        if method=='POST':
            self.existing={**body,'id':12345,'draft':True,'prerelease':True,'assets':[]};return copy.deepcopy(self.existing)
        self.existing.update(body);return copy.deepcopy(self.existing)
    def download(self,url,destination,limit):
        identifier=urlsplit(url).path.rsplit('/',1)[1];raw=next(v[1] for v in self.files.values() if v[0]==identifier);R.require(len(raw)<=limit,'synthetic bound');destination.write_bytes(raw);return len(raw)

@unittest.skipUnless(shutil.which('ssh-keygen'),'OpenSSH -Y required for synthetic signature tests')
class TransferTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp=tempfile.TemporaryDirectory(prefix='kl06-owner-signature-test-');cls.root=Path(cls.temp.name);cls.key=cls.root/'test-only-key'
        subprocess.run(['ssh-keygen','-q','-t','ed25519','-N','','-C','synthetic-test-only','-f',str(cls.key)],check=True)
        cls.signers=cls.root/'signers';cls.signers.write_text('kl06-owner '+cls.key.with_suffix('.pub').read_text())
        z=cls.root/'payload.zip';make_zip(z);cls.artifact=z.read_bytes();cls.approval=declaration();cls.approval['size']=len(cls.artifact);cls.approval['sha256']=hashlib.sha256(cls.artifact).hexdigest();cls.raw=R.canonical(cls.approval);f=cls.root/'approval.json';f.write_bytes(cls.raw)
        subprocess.run(['ssh-keygen','-Y','sign','-n','kl06-drive-release','-f',str(cls.key),str(f)],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL);cls.sig=Path(str(f)+'.sig').read_bytes()
    @classmethod
    def tearDownClass(cls):cls.temp.cleanup()
    def setUp(self):self.work=tempfile.TemporaryDirectory(prefix='kl06-transfer-mock-');self.api=FakeAPI(self.raw,self.sig,self.artifact)
    def tearDown(self):self.work.cleanup()
    def run_transfer(self,dry=True):return R.run(self.api,'synthetic-owner/KL-06-Manager',self.api.folder,self.signers,Path(self.work.name),now=NOW,dry_run=dry)
    def test_owner_signature_authenticates_exact_bytes(self):R.verify_signature(self.raw,self.sig,self.signers)
    def test_changed_manifest_signature_refused(self):
        with self.assertRaises(R.Refused):R.verify_signature(self.raw.replace(b'windows',b'android'),self.sig,self.signers)
    def test_missing_or_example_key_blocks(self):
        with self.assertRaises(R.Refused):R.verify_signature(self.raw,self.sig,self.root/'missing')
        with self.assertRaises(R.Refused):R.verify_signature(self.raw,self.sig,ROOT/'automation/owner-release-signers.example')
    def test_complete_dry_run_never_writes_release(self):self.assertIn('dry-run-passed',self.run_transfer());self.assertEqual(self.api.writes,[])
    def test_mock_publishes_exact_zip_no_rebuild(self):
        self.assertIn('published-private',self.run_transfer(False));self.assertEqual([x[0] for x in self.api.writes],['POST','POST','POST','POST','POST','PATCH'])
        receipt=json.loads((Path(self.work.name)/'RELEASE-VERIFICATION.json').read_bytes());self.assertFalse(receipt['rebuilt']);self.assertFalse(receipt['executed']);self.assertNotIn('driveFileId',receipt);self.assertNotIn('syntheticFolder',json.dumps(receipt))
    def test_public_repo_refused_before_drive(self):
        self.api.private=False
        with self.assertRaises(R.Refused):self.run_transfer(False)
        self.assertEqual(self.api.reads,{});self.assertEqual(self.api.writes,[])
    def test_corrupt_signature_refused_before_artifact(self):
        identifier,raw=self.api.files[R.SIGNATURE_NAME];self.api.files[R.SIGNATURE_NAME]=(identifier,raw[:-10]+b'bad')
        with self.assertRaises(R.Refused):self.run_transfer(False)
        self.assertNotIn('syntheticFile_012345',self.api.reads);self.assertEqual(self.api.writes,[])
    def test_zip_checksum_mismatch_refused(self):
        i,raw=self.api.files[self.approval['fileName']];self.api.files[self.approval['fileName']]=(i,raw[:-1]+bytes([raw[-1]^1]))
        with self.assertRaises(R.Refused):self.run_transfer(False)
        self.assertEqual(self.api.writes,[])
    def test_changed_drive_metadata_refused(self):
        self.api.change=True
        with self.assertRaises(R.Refused):self.run_transfer(False)
        self.assertEqual(self.api.writes,[])
    def test_wrong_existing_release_never_replaced(self):
        self.api.existing={'id':99,'body':'other release','prerelease':False,'assets':[]}
        with self.assertRaises(R.Refused):self.run_transfer(False)
        self.assertEqual(self.api.writes,[])
    def test_asset_digest_failure_leaves_draft_not_published(self):
        self.api.bad_digest=True
        with self.assertRaises(R.Refused):self.run_transfer(False)
        self.assertNotIn('PATCH',[x[0] for x in self.api.writes])
    def test_wrong_existing_tag_never_moved_or_released(self):
        self.api.ref={'ref':'refs/tags/'+self.approval['version'],'object':{'type':'commit','sha':'c'*40}}
        with self.assertRaises(R.Refused):self.run_transfer(False)
        self.assertEqual(self.api.writes,[])
    def test_annotated_tag_is_resolved_without_writes_in_dry_run(self):
        self.api.ref={'ref':'refs/tags/'+self.approval['version'],'object':{'type':'tag','sha':'d'*40}}
        self.api.tag_objects['d'*40]={'object':{'type':'commit','sha':self.approval['sourceCommit']}}
        self.assertIn('dry-run-passed',self.run_transfer());self.assertEqual(self.api.writes,[])
    def test_annotated_tag_cycle_refused(self):
        self.api.ref={'ref':'refs/tags/'+self.approval['version'],'object':{'type':'tag','sha':'d'*40}}
        self.api.tag_objects['d'*40]={'object':{'type':'tag','sha':'d'*40}}
        with self.assertRaises(R.Refused):self.run_transfer(False)
        self.assertEqual(self.api.writes,[])
    def test_tag_moved_during_upload_leaves_draft(self):
        self.api.move_tag_on_upload=True
        with self.assertRaises(R.Refused):self.run_transfer(False)
        self.assertNotIn('PATCH',[x[0] for x in self.api.writes]);self.assertTrue(self.api.existing['draft'])
    def test_repo_made_public_during_upload_blocks_publication(self):
        self.api.make_public_on_upload=True
        with self.assertRaises(R.Refused):self.run_transfer(False)
        self.assertNotIn('PATCH',[x[0] for x in self.api.writes])
    def test_expiry_rechecked_after_upload_before_publication(self):
        path=Path(self.work.name)/self.approval['fileName'];path.write_bytes(self.artifact)
        with patch.object(R.time,'time',side_effect=[NOW,NOW+7200]):
            with self.assertRaises(R.Refused):R.release_assets(self.api,self.approval['repository'],self.approval,[path],False)
        self.assertNotIn('PATCH',[x[0] for x in self.api.writes])
    def test_exact_already_published_is_idempotent(self):
        self.assertIn('published-private',self.run_transfer(False));writes=len(self.api.writes)
        self.work.cleanup();self.work=tempfile.TemporaryDirectory(prefix='kl06-transfer-repeat-')
        self.assertEqual(self.run_transfer(False),'already-published-exact-artifact');self.assertEqual(len(self.api.writes),writes)
    def test_manual_dry_run_works_before_publish_activation(self):
        with patch.dict(os.environ,{'KL06_ENABLE_DRIVE_RELEASES':'false'},clear=True), patch.object(sys,'argv',['drive_release.py','--dry-run']), patch.object(R,'run',return_value='dry-run-passed-no-release-created') as run, contextlib.redirect_stdout(io.StringIO()):
            R.main();self.assertTrue(run.call_args.kwargs['dry_run'])
    def test_publish_main_refuses_disabled_activation(self):
        with patch.dict(os.environ,{'KL06_ENABLE_DRIVE_RELEASES':'false'},clear=True), patch.object(sys,'argv',['drive_release.py']), patch.object(R,'run') as run, contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit) as error:R.main()
            self.assertEqual(error.exception.code,1);run.assert_not_called()
    def test_no_arbitrary_network_host_or_plain_http(self):
        api=R.API('synthetic-never-a-real-token')
        for url in ['http://api.github.com/repos/x','https://example.invalid/','https://api.github.com.evil.invalid/','https://name@api.github.com/repos/x']:
            with self.assertRaises(R.Refused):api._open('GET',url)

if __name__=='__main__':unittest.main()
