"""Synthetic ZIP/source-export regressions only. Fake MZ bytes are never an app test."""
import contextlib
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

ROOT=Path(__file__).resolve().parents[1]
AUTOMATION=ROOT/'automation'
spec=importlib.util.spec_from_file_location('kl06_source_manifest_test',AUTOMATION/'source_manifest.py')
M=importlib.util.module_from_spec(spec);spec.loader.exec_module(M)

class AppPackageTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(prefix='kl06-fake-package-');self.root=Path(self.temp.name)
        self.app=self.root/'SyntheticWin';self.app.mkdir();(self.app/'KL-06 Manager.exe').write_bytes(b'MZ'+b'FAKE-NOT-EXECUTABLE')
    def tearDown(self):self.temp.cleanup()
    def run_package(self,output,platform='windows',app=None):
        return subprocess.run([sys.executable,str(AUTOMATION/'package_test_app.py'),'--platform',platform,'--app',str(app or self.app),'--output',str(output)],capture_output=True,text=True,timeout=20,cwd=self.root)
    def test_synthetic_zip_is_reproducible_and_unapproved(self):
        a,b=self.root/'a.zip',self.root/'b.zip';one=self.run_package(a);two=self.run_package(b)
        self.assertEqual(one.returncode,0,one.stderr);self.assertEqual(two.returncode,0,two.stderr);self.assertEqual(a.read_bytes(),b.read_bytes());self.assertIn('UNTESTED',one.stdout)
        with zipfile.ZipFile(a) as z:self.assertEqual(z.namelist(),['KL-06-Manager-windows/KL-06 Manager.exe','KL06-PACKAGE-STATUS.txt']);self.assertIn(b'CREATED UNTESTED',z.read('KL06-PACKAGE-STATUS.txt'));self.assertIsNone(z.testzip())
    def test_debug_metadata_is_excluded_not_original_deleted(self):
        (self.app/'app.pdb').write_text('SYNTHETIC-NOT-A-PRIVATE-PATH');(self.app/'.DS_Store').write_text('fake')
        output=self.root/'out.zip';result=self.run_package(output);self.assertEqual(result.returncode,0,result.stderr)
        with zipfile.ZipFile(output) as z:self.assertFalse(any(n.endswith(('.pdb','.DS_Store')) for n in z.namelist()))
        self.assertTrue((self.app/'app.pdb').exists());self.assertTrue((self.app/'.DS_Store').exists())
    def test_existing_output_never_replaced(self):
        output=self.root/'existing.zip';output.write_bytes(b'KEEP');self.assertNotEqual(self.run_package(output).returncode,0);self.assertEqual(output.read_bytes(),b'KEEP')
    def test_output_inside_input_refused(self):
        output=self.app/'new.zip';self.assertNotEqual(self.run_package(output).returncode,0);self.assertFalse(output.exists())
    def test_efi_or_raw_history_refused_without_output(self):
        for name in ['EFI/BOOT/BOOTx64.efi','owner.csv']:
            with self.subTest(name=name):
                file=self.app/name;file.parent.mkdir(parents=True,exist_ok=True);file.write_text('fake')
                output=self.root/('out-'+str(len(name))+'.zip');self.assertNotEqual(self.run_package(output).returncode,0);self.assertFalse(output.exists());file.unlink()
                if name.startswith('EFI/'):file.parent.rmdir();(self.app/'EFI').rmdir()
    def test_wrong_payload_platform_refused(self):
        self.assertNotEqual(self.run_package(self.root/'out.zip',platform='macos').returncode,0)
    @unittest.skipUnless(hasattr(os,'symlink'),'Symlinks not available')
    def test_links_are_not_followed(self):
        outside=self.root/'outside.txt';outside.write_text('SYNTHETIC');link=self.app/'link.txt'
        try:link.symlink_to(outside)
        except OSError:self.skipTest('Normal-user symlinks unavailable on this platform')
        output=self.root/'out.zip';self.assertNotEqual(self.run_package(output).returncode,0);self.assertFalse(output.exists());self.assertEqual(outside.read_text(),'SYNTHETIC')

class SourceManifestTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(prefix='kl06-manifest-test-');self.root=Path(self.temp.name)
        (self.root/'VERSION.json').write_text(json.dumps({'version':'0.3.0-beta.2','build':5}))
        self.patcher=patch.object(M,'ROOT',self.root);self.patcher.start()
    def tearDown(self):self.patcher.stop();self.temp.cleanup()
    def test_sorted_content_hashes_without_absolute_paths(self):
        (self.root/'z.txt').write_text('synthetic');(self.root/'a.txt').write_text('a');value=M.manifest()
        self.assertEqual([f['path'] for f in value['files']],['VERSION.json','a.txt','z.txt']);self.assertNotIn(str(self.root),json.dumps(value))
        self.assertEqual(value['files'][-1]['sha256'],hashlib.sha256(b'synthetic').hexdigest())
    def test_generated_native_outputs_excluded(self):
        for relative in ['windows/bin/a.exe','android/app/build/outputs/a.apk','tests/__pycache__/x.pyc']:
            p=self.root/relative;p.parent.mkdir(parents=True,exist_ok=True);p.write_text('fake')
        self.assertEqual([p.name for p in M.source_files()],['VERSION.json'])
    def test_private_names_or_files_refused(self):
        for name in ['owner.csv','app.exe','app.pdb','.env','Restore-v1.plist','id_ed25519','session.json','credentials-test.json','KL06-RELEASE-APPROVAL.json']:
            p=self.root/name;p.write_text('synthetic')
            with self.assertRaises(ValueError,msg=name):M.source_files()
            p.unlink()
    def test_private_directory_refused(self):
        p=self.root/'EFI'/'config.plist';p.parent.mkdir();p.write_text('synthetic')
        with self.assertRaises(ValueError):M.source_files()
    def test_unverified_jar_refused(self):
        p=self.root/'arbitrary.jar';p.write_bytes(b'PK-FAKE')
        with self.assertRaises(ValueError):M.source_files()
    def test_manifests_exclude_themselves(self):
        (self.root/'SOURCE-MANIFEST.json').write_text('{}');(self.root/'SHA256SUMS').write_text('')
        self.assertEqual([p.name for p in M.source_files()],['VERSION.json'])

if __name__=='__main__':unittest.main()
