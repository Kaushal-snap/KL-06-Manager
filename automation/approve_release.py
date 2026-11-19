#!/usr/bin/env python3
"""Owner runs locally AFTER native physical-device testing. Never uploads anything.
Private SSH key stays outside the repository and CI. No password is read/stored here.
"""
from __future__ import annotations
import argparse
import datetime as dt
import os
from pathlib import Path
import subprocess
import sys
from drive_release import (APPROVAL_NAME, DESKTOP_TESTS, PHONE_TESTS, PLATFORMS, SCHEMA, TESTS,
                          Refused, audit_zip, canonical, decode, require, sha256, validate_approval)


def fields(platform):
    keys = set(TESTS) | set(PHONE_TESTS if platform in ("android", "ios") else DESKTOP_TESTS)
    if platform == "macos":
        keys |= {"f13RunningOnly", "workingGraphicsFnAudioUSBPreserved", "hdrRemainsOff"}
    return keys


def private_write(path, data):
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, "wb") as stream:
        stream.write(data)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    template = commands.add_parser("template", help="Create false/unfilled owner test results; NOT an approval.")
    template.add_argument("--zip", type=Path, required=True)
    template.add_argument("--platform", action="append", choices=sorted(PLATFORMS), required=True)
    template.add_argument("--output", type=Path, required=True)
    approve = commands.add_parser("approve", help="Sign exact tested ZIP approval locally, after reviewing completed test results.")
    for flag in ("zip", "results", "key", "output-dir"):
        approve.add_argument("--" + flag, type=Path, required=True)
    for flag in ("version", "repository", "source-commit", "drive-file-id"):
        approve.add_argument("--" + flag, required=True)
    approve.add_argument("--valid-hours", type=int, default=48, choices=range(1, 169), metavar="1..168")
    args = parser.parse_args()
    try:
        require(args.zip.is_file() and not args.zip.is_symlink(), "Choose the exact tested regular ZIP.")
        if args.command == "template":
            platforms = sorted(set(args.platform))
            audit_zip(args.zip, platforms)
            results = {platform: {**{key: False for key in sorted(fields(platform))}, "osMajor": None, "testedAt": None} for platform in platforms}
            private_write(args.output, canonical({"schema": "KL06_OWNER_RESULTS_V1", "artifactSha256": sha256(args.zip), "platformTests": results,
                                                  "notice": "UNTESTED template. Only the owner changes fields after actual native physical-device checks. Never treat a source/cross-build/mock test as a device pass."}))
            print("False/unfilled test template created locally. No approval, signature or upload was made.")
            return
        require(not hasattr(os, "geteuid") or os.geteuid() != 0, "Run locally as a normal user, never root/sudo.")
        source_root = Path(__file__).resolve().parent.parent
        key = args.key.expanduser().resolve()
        require(key.is_file() and source_root not in key.parents, "Keep the private signing key outside this source/repository. It is never uploaded to CI.")
        require(args.results.is_file() and args.results.stat().st_size <= 32768, "Bounded local test results required.")
        results = decode(args.results.read_bytes())
        require(isinstance(results, dict) and set(results) == {"schema", "artifactSha256", "platformTests", "notice"} and results["schema"] == "KL06_OWNER_RESULTS_V1", "Invalid owner test results file.")
        digest = sha256(args.zip)
        require(results["artifactSha256"] == digest, "This ZIP changed since its test template. Re-test the exact artifact.")
        now = dt.datetime.now(dt.timezone.utc).replace(microsecond=0)
        utc = lambda value: value.strftime("%Y-%m-%dT%H:%M:%SZ")
        approval = {"schema": SCHEMA, "artifactKind": "owner-tested-app-zip", "repository": args.repository,
                    "version": args.version, "sourceCommit": args.source_commit, "driveFileId": args.drive_file_id,
                    "fileName": args.zip.name, "size": args.zip.stat().st_size, "sha256": digest,
                    "approvedAt": utc(now), "expiresAt": utc(now + dt.timedelta(hours=args.valid_hours)), "platformTests": results["platformTests"]}
        validate_approval(approval)
        audit_zip(args.zip, approval["platformTests"])
        print("This declaration approves ONE exact app ZIP as a PRIVATE beta, for only the physical-device platforms you recorded.")
        print("It does not certify untested OSes, activate firmware controls, alter EFI/Windows boot, or approve a stable/public release.")
        print("ZIP SHA-256:", digest)
        require(sys.stdin.isatty(), "Interactive local owner confirmation required; no unattended auto-approval flag exists.")
        require(input("Type TESTED followed by a space and the full SHA-256 to sign: ") == "TESTED " + digest, "No approval signed.")
        args.output_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
        require(not args.output_dir.is_symlink(), "Approval output directory cannot be a link.")
        path = args.output_dir / APPROVAL_NAME
        require(not path.exists() and not path.with_name(path.name + ".sig").exists(), "Existing approval/signature will not be overwritten. Use a fresh private directory.")
        private_write(path, canonical(approval))
        result = subprocess.run(["ssh-keygen", "-Y", "sign", "-n", "kl06-drive-release", "-f", str(key), str(path)], check=False)
        require(result.returncode == 0, "Local signing failed. Unsigned JSON cannot pass automation.")
        path.with_name(path.name + ".sig").chmod(0o600)
        print("Signed locally. Place the JSON and .sig beside the exact tested ZIP directly in your private Drive App folder.")
        print("No file was uploaded by this tool. The private key and raw local test results must never be put in Drive/repo/releases.")
    except (Refused, OSError, ValueError) as error:
        parser.exit(1, "No automatic release approval: " + (str(error) if isinstance(error, Refused) else "Local file/tool operation failed; inspect privately.") + "\n")


if __name__ == "__main__":
    main()
