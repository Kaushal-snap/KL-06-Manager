"""Portable source/export contracts, not a macOS compiler or hardware test."""
import pathlib, plistlib, re, unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
class Contracts(unittest.TestCase):
 def text(self,p): return (ROOT/p).read_text()
 def test_version_identity(self):
  p=plistlib.loads((ROOT/'Info.plist').read_bytes());self.assertEqual(p['CFBundleIdentifier'],'app.klasus.controlcenter');self.assertIn(p['CFBundleVersion'],('5','6','7','8','9','10'));self.assertIn(p['CFBundleShortVersionString'],('0.3.0','0.4.0','0.4.1','0.4.2','0.4.3'))
 def test_assets_present_and_local(self):
  s=self.text('Resources/index.html');self.assertIn("connect-src 'none'",s)
  for item in re.findall(r'(?:src|href)="([^\"]+)"',s):self.assertTrue((ROOT/'Resources'/item).is_file(),item);self.assertNotIn('://',item)
 def test_build_has_bridge_and_fan_code(self):
  s=self.text('BUILD-MAC.command')
  for item in ['SMCReader.c','SMCReader.h','FanMonitor.swift','history.js','-import-objc-header','codesign --verify','open -R']:self.assertIn(item,s)
 def test_mac_tests_are_isolated(self):
  s=self.text('TEST-MAC.command');self.assertIn('tests/mac/main.swift',s);self.assertIn('KL06_SMC_TEST',s);self.assertNotIn('fan-reader/main.c',s)
 def test_root_os_guards(self):
  for p in ['BUILD-MAC.command','TEST-MAC.command','COLLECT-MAC-FANS.command']:
   s=self.text(p);self.assertIn('Darwin',s);self.assertIn('x86_64',s);self.assertIn('-ge 27',s);self.assertIn('-eq 0',s)
 def test_collector_minimal(self):
  s=self.text('COLLECT-MAC-FANS.command');self.assertIn('umask 077',s);self.assertIn('mktemp -d',s);self.assertNotRegex(s,r'\bsudo\s+/');self.assertNotRegex(s,r'\b(?:curl|wget|diskutil|nvram)\s+')
 def test_whitelist_reader(self):
  s=self.text('Sources/SMCReader.c');self.assertIn('"FNum"',s);self.assertIn('"F0Ac"',s);self.assertIn('"F1Ac"',s);self.assertNotRegex(s,r'"F[0-9](?:Tg|Md|Mn|Mx)"');self.assertNotIn('IOConnectCallScalarMethod',s)
 def test_no_root_helper_installer(self):
  s=self.text('Sources/main.swift');self.assertIn('getuid() != 0',s);self.assertNotIn('SMJobBless',s);self.assertNotIn('AuthorizationExecuteWithPrivileges',s);self.assertNotIn('case "shell"',s)
 def test_restore_identity(self):
  s=self.text('Sources/Core.swift');self.assertIn('"KL-Asus"',s);self.assertIn('"Restore-v1.plist"',s);self.assertIn('journalURL',s)
 def test_f13_preserved(self):
  s=self.text('Sources/HotKey.swift');self.assertRegex(s,r'keyCode[^\n]*105');self.assertIn('RegisterEventHotKey',s);self.assertNotIn('UInt32(buffer.count)',s)
 def test_no_foreign_binaries_or_diagnostics(self):
  forbidden={'.aml','.efi','.kext','.exe','.dll','.csv','.log','.dmp','.mobileconfig'}
  for p in ROOT.rglob('*'):
   if any(v in {'Local-build','node_modules','.git','__pycache__','test-results','playwright-report'} for v in p.relative_to(ROOT).parts):continue
   if p.is_file():self.assertNotIn(p.suffix.lower(),forbidden,str(p));self.assertNotEqual(p.name,'config.plist')
 def test_documented_native_limit(self):
  s=self.text('README.md');self.assertIn('No precompiled',s);self.assertIn('not independently calibrated',s);self.assertIn('No privileged helper',s)
if __name__=='__main__':unittest.main()
