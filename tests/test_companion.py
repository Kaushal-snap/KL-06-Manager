"""Synthetic broker/privacy tests + loopback TLS protocol tests; no device controls."""
import base64
import hashlib
import http.client
import importlib.util
import json
import os
from pathlib import Path
import shutil
import ssl
import subprocess
import sys
import tempfile
import threading
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('kl06broker', ROOT/'companion/server.py')
S = importlib.util.module_from_spec(spec); spec.loader.exec_module(S)

class Clock:
    def __init__(self): self.wall=1700000000.;self.mono=1000.
    def step(self,n):self.wall+=n;self.mono+=n

class BrokerTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(prefix='kl06-broker-test-');self.root=Path(self.temp.name);self.clock=Clock();self.b=S.Broker(self.root,clock=lambda:self.clock.wall,monotonic=lambda:self.clock.mono)
    def tearDown(self):self.temp.cleanup()
    def pair(self,platform='android'):
        _,p=self.b.handle('/v1/pair',{'code':self.b.pair_code,'platform':platform});ticket=p['ticket']
        S.atomic_json(self.root/'requests'/f'{ticket}.result.json',{'approved':True})
        _,r=self.b.handle('/v1/pair/finish',{'ticket':ticket,'code':self.b.pair_code});return 'Bearer '+r['token']
    def test_private_addresses_only(self):
        for good in ['10.0.0.1','172.16.1.2','172.31.255.254','192.168.0.1']:self.assertTrue(S.private_ipv4(good))
        for bad in ['0.0.0.0','127.0.0.1','169.254.1.2','172.32.0.1','8.8.8.8','localhost','10.0.0.1\n','010.1.1.1','::1',None]:self.assertFalse(S.private_ipv4(bad),bad)
    def test_authentication_required(self):
        for path in ['/v1/state','/v1/command','/v1/result','/v1/disconnect']:
            with self.assertRaises(S.Rejected):self.b.handle(path,{})
    def test_pair_needs_laptop_approval(self):
        _,p=self.b.handle('/v1/pair',{'code':self.b.pair_code,'platform':'ios'});ticket=p['ticket']
        status,r=self.b.handle('/v1/pair/finish',{'ticket':ticket,'code':self.b.pair_code});self.assertEqual(status,202);self.assertNotIn('token',r)
        S.atomic_json(self.root/'requests'/f'{ticket}.result.json',{'approved':1})
        with self.assertRaises(S.Rejected):self.b.handle('/v1/pair/finish',{'ticket':ticket,'code':self.b.pair_code})
        S.atomic_json(self.root/'requests'/f'{ticket}.result.json',{'approved':True});_,r=self.b.handle('/v1/pair/finish',{'ticket':ticket,'code':self.b.pair_code});self.assertEqual(len(r['token']),64)
    def test_pair_code_and_platform_schema(self):
        for body in [{'code':'a'*32,'platform':'android'},{'code':self.b.pair_code,'platform':'shell'},{'code':self.b.pair_code,'platform':'android','extra':True}]:
            with self.assertRaises(S.Rejected):self.b.handle('/v1/pair',body)
    def test_pair_code_expires_monotonically(self):
        self.clock.mono+=301;self.clock.wall-=10000
        with self.assertRaises(S.Rejected):self.b.handle('/v1/pair',{'code':self.b.pair_code,'platform':'android'})
    def test_pair_finish_cannot_extend_expired_code(self):
        self.clock.step(290);_,p=self.b.handle('/v1/pair',{'code':self.b.pair_code,'platform':'android'})
        S.atomic_json(self.root/'requests'/(p['ticket']+'.result.json'),{'approved':True});self.clock.step(11)
        with self.assertRaises(S.Rejected):self.b.handle('/v1/pair/finish',{'ticket':p['ticket'],'code':self.b.pair_code})
    def test_session_cannot_extend_after_clock_rollback(self):
        self.clock.wall-=10000;self.clock.mono+=1801
        with self.assertRaises(S.Rejected):self.b.handle('/v1/pair',{'code':self.b.pair_code,'platform':'android'})
    def test_expired_pending_pair_removed(self):
        _,p=self.b.handle('/v1/pair',{'code':self.b.pair_code,'platform':'android'});self.clock.step(91)
        with self.assertRaises(S.Rejected):self.b.handle('/v1/pair/finish',{'ticket':p['ticket'],'code':self.b.pair_code})
        self.assertFalse((self.root/'requests'/(p['ticket']+'.json')).exists())
    def test_two_phone_limit(self):
        self.pair();self.pair('ios')
        with self.assertRaises(S.Rejected):self.pair()
    def test_action_allowlist_and_exact_parameters(self):
        for body in [{'operation':'shell','params':{}},{'operation':'setFan','params':{'value':2000}},{'operation':'setVolume','params':{'value':True}},{'operation':'setVolume','params':{'value':101}},{'operation':'setVolume','params':{'value':float('nan')}},{'operation':'setVolume','params':{'value':50,'cmd':'bad'}},{'operation':'applyTweak','params':{'id':['bad']}},{'operation':'applyTweak','params':{'id':'../boot'}},{'operation':'keepAwake','params':{},'extra':1}]:
            with self.assertRaises(S.Rejected,msg=str(body)):S.command(body)
        self.assertEqual(S.command({'operation':'setVolume','params':{'value':50.5}})['params']['value'],50.5)
    def test_command_is_only_file_request_not_execution(self):
        auth=self.pair();status,r=self.b.handle('/v1/command',{'operation':'setVolume','params':{'value':37}},auth);self.assertEqual(status,202)
        path=self.root/'requests'/(r['id']+'.json');data=S.read_json(path);self.assertEqual(data['params'],{'value':37});self.assertEqual(data['kind'],'command')
        status,r=self.b.handle('/v1/result',{'id':data['id']},auth);self.assertEqual(status,202)
    def test_result_ownership(self):
        a,b=self.pair(),self.pair('ios');_,r=self.b.handle('/v1/command',{'operation':'keepAwake','params':{}},a)
        with self.assertRaises(S.Rejected):self.b.handle('/v1/result',{'id':r['id']},b)
    def test_command_queue_bounded_and_pruned(self):
        a=self.pair()
        for _ in range(8):self.b.handle('/v1/command',{'operation':'keepAwake','params':{}},a)
        with self.assertRaises(S.Rejected):self.b.handle('/v1/command',{'operation':'keepAwake','params':{}},a)
        self.clock.step(91);self.b.handle('/v1/command',{'operation':'keepAwake','params':{}},a);self.assertEqual(len(self.b.owners),1)
    def test_request_deadline_survives_wall_clock_rollback(self):
        a=self.pair();_,r=self.b.handle('/v1/command',{'operation':'keepAwake','params':{}},a)
        self.clock.wall-=3600;self.clock.mono+=91
        with self.assertRaises(S.Rejected):self.b.handle('/v1/result',{'id':r['id']},a)
        self.assertFalse((self.root/'requests'/(r['id']+'.json')).exists())
    def test_disconnect_revokes_token_and_unapproved_requests(self):
        a=self.pair();_,r=self.b.handle('/v1/command',{'operation':'keepAwake','params':{}},a);path=self.root/'requests'/(r['id']+'.json');self.assertTrue(path.exists())
        self.b.handle('/v1/disconnect',{},a);self.assertFalse(path.exists());self.assertEqual(len(self.b.tokens),0)
        with self.assertRaises(S.Rejected):self.b.handle('/v1/state',{},a)
    def test_authenticated_transfer_completes_only_after_sha256_verification(self):
        auth=self.pair('ios')
        payload=(b'KL06-transfer-fixture-'*600)
        expected=hashlib.sha256(payload).hexdigest()
        status,created=self.b.handle('/v1/transfer/init',{'fileName':'ios-fixture.bin','fileSize':len(payload),'expectedSha256':expected,'senderPlatform':'ios'},auth)
        self.assertEqual(status,200)
        self.assertEqual(created['status'],'approved')
        transfer_id=created['transferId']
        offset=0
        for start in range(0,len(payload),8192):
            chunk=payload[start:start+8192]
            body={'transferId':transfer_id,'chunkOffset':offset,'chunkBase64':base64.b64encode(chunk).decode('ascii')}
            self.assertLess(len(json.dumps(body,separators=(',',':')).encode()),16384)
            status,progress=self.b.handle('/v1/transfer/chunk',body,auth)
            self.assertEqual(status,200)
            offset+=len(chunk)
        status,final=self.b.handle('/v1/transfer/status',{'transferId':transfer_id},auth)
        self.assertEqual(status,200)
        self.assertEqual(final['state'],'complete')
        self.assertEqual(final['bytesTransferred'],len(payload))
        self.assertEqual(hashlib.sha256(Path(final['finalPath']).read_bytes()).hexdigest(),expected)

    def test_no_snapshot_does_not_invent_readings(self):
        _,r=self.b.handle('/v1/state',{},self.pair());self.assertEqual(r['status'],'not-sampled');self.assertIsNone(r['state'])
    def fixture(self):return {'schema':'KL06_DESKTOP_SNAPSHOT_V1','writtenAt':self.clock.wall,'state':{'platform':'macos','version':'0.3.0-beta.2','volume':42,'serial':'SYNTHETIC-PRIVATE-CANARY','rawReport':'SYNTHETIC-PRIVATE-CANARY','battery':{'chargePercent':60,'SerialNumber':'SYNTHETIC-PRIVATE-CANARY'},'fan':{'status':'ok','ageSeconds':2,'source':'AppleSMC / existing provider','fans':[{'index':0,'status':'ok','rpm':3366,'private':'SYNTHETIC-PRIVATE-CANARY'}]},'tweaks':[{'id':'dock-autohide','saved':True,'original':'SYNTHETIC-PRIVATE-CANARY'}]}}
    def test_projection_minimizes_private_fields(self):
        r=S.project_state(self.fixture(),self.clock.wall);self.assertNotIn('CANARY',json.dumps(r));self.assertFalse(r['state']['fan']['manualControl']);self.assertEqual(r['state']['fan']['fans'][0]['rpm'],3366)
    def test_snapshot_stale_no_history_or_zero_fallback(self):
        f=self.fixture();f['writtenAt']-=13;r=S.project_state(f,self.clock.wall);self.assertEqual(r['status'],'stale');self.assertIsNone(r['state'])
    def test_fan_age_includes_snapshot_delay(self):
        f=self.fixture();f['state']['fan']['ageSeconds']=11;f['writtenAt']-=2;r=S.project_state(f,self.clock.wall);self.assertIsNone(r['state']['fan']['fans'][0]['rpm']);self.assertEqual(r['state']['fan']['ageSeconds'],13)
    def test_invalid_fan_is_never_zero(self):
        for rpm in [float('nan'),-1,30001,True,'1800']:
            f=self.fixture();f['state']['fan']['fans'][0]['rpm']=rpm;r=S.project_state(f,self.clock.wall);self.assertIsNone(r['state']['fan']['fans'][0]['rpm'])
    def test_duplicate_json_rejected(self):
        with self.assertRaises(S.Rejected):S.decode_json('{"value":50,"value":100}')
    def test_nonfinite_json_rejected(self):
        with self.assertRaises(S.Rejected):S.decode_json('{"value":NaN}')
    def test_symlink_and_hardlink_records_refused(self):
        target=self.root/'data.json';S.atomic_json(target,{'x':1});link=self.root/'link.json';link.symlink_to(target)
        with self.assertRaises(S.Rejected):S.read_json(link)
        link.unlink();os.link(target,link)
        with self.assertRaises(S.Rejected):S.read_json(target)
    def test_unsafe_directory_refused(self):
        target=self.root/'directory';target.mkdir(mode=0o700);link=self.root/'linked';link.symlink_to(target,target_is_directory=True)
        with self.assertRaises(S.Rejected):S.Broker(link)
    def test_endpoint_and_result_path_traversal_refused(self):
        a=self.pair()
        with self.assertRaises(S.Rejected):self.b.handle('/v1/result',{'id':'../../key'},a)
        with self.assertRaises(S.Rejected):self.b.handle('/v1/shell',{},a)
    def test_rate_limit(self):
        a=self.pair()
        for _ in range(100):self.b.handle('/v1/state',{},a)
        with self.assertRaises(S.Rejected):self.b.handle('/v1/state',{},a)

@unittest.skipUnless(shutil.which('openssl'),'OpenSSL is needed for the local TLS fixture')
class TLSTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp=tempfile.TemporaryDirectory(prefix='kl06-loopback-tls-test-');cls.root=Path(cls.temp.name)
        cls.cert=cls.root/'cert.pem';cls.key=cls.root/'key.pem'
        subprocess.run(['openssl','req','-x509','-newkey','rsa:2048','-sha256','-nodes','-days','1','-subj','/CN=localhost','-keyout',str(cls.key),'-out',str(cls.cert)],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        cls.b=S.Broker(cls.root);context=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);context.minimum_version=ssl.TLSVersion.TLSv1_2;context.load_cert_chain(cls.cert,cls.key)
        cls.server=S.Server(('127.0.0.1',0),cls.b,context,test_loopback=True);cls.port=cls.server.server_address[1]
        cls.thread=threading.Thread(target=cls.server.serve_forever,daemon=True);cls.thread.start()
    @classmethod
    def tearDownClass(cls):cls.server.shutdown();cls.server.server_close();cls.thread.join(2);cls.temp.cleanup()
    def request(self,body,headers=None,method='POST'):
        context=ssl.create_default_context(cafile=str(self.cert));context.check_hostname=False
        c=http.client.HTTPSConnection('127.0.0.1',self.port,context=context,timeout=5)
        try:
            c.request(method,'/v1/pair',body,{'Content-Type':'application/json',**(headers or {})});r=c.getresponse();return r.status,json.loads(r.read())
        finally:c.close()
    def test_tls_valid_pair_requires_local_approval(self):
        status,r=self.request(json.dumps({'code':self.b.pair_code,'platform':'android'}));self.assertEqual(status,202);self.assertIn('ticket',r);self.assertNotIn('token',r)
    def test_browser_origin_even_empty_refused(self):
        self.assertEqual(self.request('{}',{'Origin':''})[0],403)
        self.assertEqual(self.request('{}',{'Origin':'https://example.invalid'})[0],403)
    def test_duplicate_json_over_tls_refused(self):self.assertEqual(self.request('{"code":"a","code":"b","platform":"android"}')[0],403)
    def test_no_browser_get_endpoint(self):self.assertEqual(self.request(None,method='GET')[0],405)
    def test_wrong_host_header_refused(self):self.assertEqual(self.request('{}',{'Host':'public.example:8766'})[0],403)
    def test_oversized_body_refused(self):self.assertEqual(self.request('x'*17000)[0],403)
    def test_pin_fixture_mismatch_detected(self):
        context=ssl.create_default_context(cafile=str(self.cert));context.check_hostname=False
        c=http.client.HTTPSConnection('127.0.0.1',self.port,context=context,timeout=5);c.connect()
        try:
            actual=hashlib.sha256(c.sock.getpeercert(binary_form=True)).hexdigest();expected=hashlib.sha256(ssl.PEM_cert_to_DER_cert(self.cert.read_text())).hexdigest();self.assertEqual(actual,expected);self.assertNotEqual(actual,'0'*64)
        finally:c.close()

if __name__=='__main__':unittest.main()
