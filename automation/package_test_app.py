#!/usr/bin/env python3
"""Create a clean UNTESTED package from an already built app. Never install/test/approve/upload it.
The owner must test the exact extracted ZIP before signing a checksum-bound approval.
"""
from __future__ import annotations
import argparse
import os
from pathlib import Path
import shutil
import stat
import tempfile
import zipfile
from drive_release import MAX_UNCOMPRESSED, MAX_ZIP, PLATFORMS, Refused, audit_zip, require, sha256

SKIP = {'.DS_Store', 'Microsoft.Web.WebView2.Core.xml', 'Microsoft.Web.WebView2.WinForms.xml'}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--platform',choices=sorted(PLATFORMS),required=True)
    parser.add_argument('--app',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    made_output=False
    try:
        require(not args.app.is_symlink(), 'Input cannot be a symbolic link.')
        require(not args.output.is_symlink(), 'Output cannot be a symbolic link.')
        source=args.app.expanduser().resolve(strict=True);output=args.output.expanduser().resolve()
        require(output.suffix.lower()=='.zip' and not output.exists(), 'Choose a new .zip output; existing files are never replaced.')
        require(output.parent.is_dir() and source not in output.parents, 'Output must be outside the app and inside an existing chosen directory.')
        if args.platform=='macos':
            require(source.is_dir() and source.name=='KL-06 Manager.app', 'Select the built KL-06 Manager.app, not source/EFI/a general directory.')
            prefix='KL-06 Manager.app'
        elif args.platform=='windows':
            require(source.is_dir() and (source/'KL-06 Manager.exe').is_file(), 'Select the complete published KL-06 Windows app directory.')
            prefix='KL-06-Manager-windows'
        else:
            require(source.is_file() and source.suffix.lower()==('.apk' if args.platform=='android' else '.ipa'), 'Select one already built APK/IPA.')
            prefix='KL-06-Manager'+source.suffix.lower()
        paths=sorted(source.rglob('*')) if source.is_dir() else [source]
        require(0<len(paths)<=15000,'Input member limit.')
        skipped=0;total=0
        with tempfile.TemporaryDirectory(prefix='kl06-package-') as directory:
            temporary=Path(directory)/'candidate.zip'
            with zipfile.ZipFile(temporary,'x',compression=zipfile.ZIP_DEFLATED,compresslevel=6,allowZip64=False) as archive:
                for path in paths:
                    info=path.lstat()
                    require(not path.is_symlink() and (stat.S_ISDIR(info.st_mode) or stat.S_ISREG(info.st_mode)), 'Links/special files require a separate reviewed packager; no link is followed.')
                    if path.is_dir():continue
                    if path.name in SKIP or path.suffix.lower()=='.pdb':skipped+=1;continue
                    total+=info.st_size
                    require(info.st_size<=MAX_ZIP and total<=MAX_UNCOMPRESSED, 'App input exceeds bounded release archive size; no automatic splitting or upload.')
                    relative=(prefix+'/'+path.relative_to(source).as_posix()) if source.is_dir() else prefix
                    item=zipfile.ZipInfo(relative,date_time=(1980,1,1,0,0,0));item.create_system=3
                    mode=0o755 if info.st_mode&0o111 else 0o644;item.external_attr=(stat.S_IFREG|mode)<<16;item.compress_type=zipfile.ZIP_DEFLATED
                    with path.open('rb') as read,archive.open(item,'w') as write:shutil.copyfileobj(read,write,1024*1024)
                status=zipfile.ZipInfo('KL06-PACKAGE-STATUS.txt',date_time=(1980,1,1,0,0,0));status.create_system=3;status.external_attr=(stat.S_IFREG|0o644)<<16;status.compress_type=zipfile.ZIP_DEFLATED
                archive.writestr(status,('KL-06 '+args.platform+' APP PACKAGE — CREATED UNTESTED\n\nThis source packager did NOT execute, install, physically test, approve, release-sign or upload the app. A filename/checksum/build/debug signature is NOT owner approval.\n\nReview required runtime prerequisites and licenses. Keep originals; never disable OS protections or modify EFI/partitions/drivers to force a test. Android debug signing is not Play Store signing. Windows cross-publish is not Windows execution.\n\nIf an owner later tests this EXACT extracted ZIP, their separate recent checksum-bound signed approval must establish that fact; this packager cannot do so. Do not rebuild/recompress a ZIP behind an existing approval. Source-only archives cannot pass the release gate.\n').encode('utf-8'))
            audit_zip(temporary,[args.platform])
            with output.open('xb') as write,temporary.open('rb') as read:
                made_output=True;shutil.copyfileobj(read,write,1024*1024);write.flush();os.fsync(write.fileno())
            require(sha256(output)==sha256(temporary),'Package copy checksum mismatch.')
        print('UNTESTED app package created. No app was executed, changed, installed, approved, signed for release or uploaded.')
        print('SHA-256:',sha256(output));print('Known metadata/debug documentation files excluded:',skipped)
        print('Test this exact extracted ZIP on the physical target before creating owner results. Keep originals and review all files/licenses.')
    except (Refused,OSError,ValueError,zipfile.BadZipFile) as error:
        if made_output:
            try:output.unlink()
            except OSError:pass
        parser.exit(1,'No approved app package: '+(str(error) if isinstance(error,Refused) else 'Local file/ZIP operation failed; inspect privately.')+'\n')


if __name__=='__main__':main()
