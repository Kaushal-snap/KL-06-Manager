#!/usr/bin/env python3
"""Reproducible source-only manifest; never treats a hash as native/device approval."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
EXCLUDE={'SOURCE-MANIFEST.json','SHA256SUMS'}
GENERATED={'.git','.gradle','.idea','node_modules','bin','obj','build','Local-build','Local-approvals','__pycache__','test-results','playwright-report','.arena'}
PRIVATE_PARTS={'efi','opencore','uploads','reports','raw-reports','private-backups','.ssh','__macosx'}
PRIVATE_NAMES={'.env','id_rsa','id_ed25519','owner-ed25519','session.json','restore-v1.json','restore-v1.plist','kl06-release-approval.json','kl06-release-approval.json.sig','kl06-owner-results.json','upload-receipt.json'}
BINARY_OR_PRIVATE={'.apk','.ipa','.exe','.dll','.pdb','.so','.dylib','.a','.o','.class','.jks','.keystore','.p12','.pfx','.mobileprovision','.csv','.log','.zip','.pyc','.key','.pem','.efi','.aml','.dmp'}
WRAPPER='android/gradle/wrapper/gradle-wrapper.jar'
WRAPPER_SHA256='81a82aaea5abcc8ff68b3dfcb58b3c3c429378efd98e7433460610fecd7ae45f'

def digest(path):
    h=hashlib.sha256()
    with path.open('rb') as stream:
        while block:=stream.read(1024*1024):h.update(block)
    return h.hexdigest()

def source_files():
    paths=[]
    for p in ROOT.rglob('*'):
        parts=p.relative_to(ROOT).parts
        if set(parts)&GENERATED or p.name in EXCLUDE or p.name=='.DS_Store' or p.suffix=='.pyc':continue
        relative=p.relative_to(ROOT).as_posix()
        if p.is_symlink():raise ValueError('Source link refused: '+relative)
        if set(x.casefold() for x in parts)&PRIVATE_PARTS:raise ValueError('Private/EFI path refused: '+relative)
        if p.is_file():
            if p.name.casefold() in PRIVATE_NAMES or p.name.casefold().startswith(('.env.','credentials','service-account')):raise ValueError('Private runtime/approval input refused: '+relative)
            if p.suffix.lower() in BINARY_OR_PRIVATE:raise ValueError('Compiled/private input refused: '+relative)
            if p.suffix.lower()=='.jar' and (relative!=WRAPPER or digest(p)!=WRAPPER_SHA256):raise ValueError('Unreviewed JAR refused: '+relative)
            paths.append(p)
    return sorted(paths,key=lambda p:p.relative_to(ROOT).as_posix())

def manifest():
    v=json.loads((ROOT/'VERSION.json').read_text())
    files=[{'path':p.relative_to(ROOT).as_posix(),'bytes':p.stat().st_size,'sha256':digest(p),'executable':bool(p.stat().st_mode&0o111)} for p in source_files()]
    return {'schema':'KL06_SOURCE_MANIFEST_V1','version':v['version'],'build':v['build'],'scope':'source-only-not-native-build-or-owner-approval','files':files}

def main():
    p=argparse.ArgumentParser();p.add_argument('--write',action='store_true',help='Intentionally regenerate after reviewed source changes; never device approval.');args=p.parse_args();current=manifest()
    if args.write:
        (ROOT/'SOURCE-MANIFEST.json').write_text(json.dumps(current,indent=2,sort_keys=True)+'\n')
        (ROOT/'SHA256SUMS').write_text(''.join(x['sha256']+'  '+x['path']+'\n' for x in current['files']))
        print('Source manifests written for',len(current['files']),'files. Native/device/release status was NOT changed.');return
    expected=json.loads((ROOT/'SOURCE-MANIFEST.json').read_text())
    # ZIP extraction may not retain execute bits; contents/paths/sizes are the cross-platform contract.
    strip=lambda d:{**d,'files':[{k:v for k,v in f.items() if k!='executable'} for f in d['files']]}
    if strip(current)!=strip(expected):raise SystemExit('Source integrity differs. Preserve originals; review intentional changes before deliberately regenerating. No build/release approval implied.')
    checks=''.join(x['sha256']+'  '+x['path']+'\n' for x in current['files'])
    if (ROOT/'SHA256SUMS').read_text()!=checks:raise SystemExit('SHA256SUMS differs from source manifest.')
    print('Source content integrity passed:',len(current['files']),'files; no native/device approval implied.')

if __name__=='__main__':main()
