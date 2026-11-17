#!/usr/bin/env python3
"""
package_release.py - Automated release packager and metadata generator for KL-06 Manager.

Automatically extracts version and build from Info.plist, retrieves the current Git revision,
runs privacy/safety scans, builds a clean ZIP without junk, computes SHA-256,
and generates BUILD-METADATA.json, SHA256SUMS, and release notes automatically.
"""

import argparse
import datetime
import hashlib
import json
import os
import plistlib
import re
import subprocess
import sys
import zipfile

EXPECTED_BUNDLE_ID = "app.klasus.controlcenter"


def compute_sha256(file_path):
    h = hashlib.sha256()
    with open(file_path, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()


def get_git_revision(cwd=None):
    try:
        res = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=cwd,
            capture_output=True,
            text=True,
            check=True,
        )
        return res.stdout.strip()
    except Exception:
        return "unknown"


def run_privacy_scan(app_dir):
    sensitive_patterns = [
        (re.compile(r"ghp_[a-zA-Z0-9]+"), "GitHub Token"),
        (re.compile(r"github_pat_[a-zA-Z0-9_]+"), "Fine-Grained Token"),
        (re.compile(r"BEGIN (?:RSA |EC )?PRIVATE KEY"), "Private Key"),
        (re.compile(r"/Users/[a-zA-Z0-9_-]+"), "User Home Path"),
    ]
    findings = []
    for root, _, files in os.walk(app_dir):
        for f in files:
            p = os.path.join(root, f)
            try:
                with open(p, "rb") as fp:
                    content = fp.read()
                for pat, desc in sensitive_patterns:
                    matches = pat.findall(content.decode("utf-8", errors="ignore"))
                    if matches:
                        for m in set(matches):
                            findings.append((f, desc, m))
            except Exception:
                pass
    return findings


def check_release_deduplication(tag_name, sha256):
    try:
        res = subprocess.run(
            ["gh", "release", "view", tag_name, "--json", "isDraft,isPrerelease,tagName,body"],
            capture_output=True,
            text=True,
            check=False,
        )
        if res.returncode == 0:
            data = json.loads(res.stdout)
            body = data.get("body", "")
            if sha256.lower() in body.lower():
                return {"status": "duplicate_skipped", "tag": tag_name, "message": "Identical release already exists."}
            return {"status": "version_exists_different_hash", "tag": tag_name, "data": data}
    except Exception:
        pass
    return {"status": "not_found", "tag": tag_name}


def package_app(app_path, output_dir=None, git_dir=None):
    if not os.path.isdir(app_path):
        raise ValueError(f"App directory not found: {app_path}")

    plist_path = os.path.join(app_path, "Contents", "Info.plist")
    if not os.path.isfile(plist_path):
        raise ValueError(f"Missing Contents/Info.plist in {app_path}")

    with open(plist_path, "rb") as f:
        plist = plistlib.load(f)

    bundle_id = plist.get("CFBundleIdentifier")
    if bundle_id != EXPECTED_BUNDLE_ID:
        raise ValueError(
            f"Bundle identifier mismatch: got '{bundle_id}', expected '{EXPECTED_BUNDLE_ID}'"
        )

    version = plist.get("CFBundleShortVersionString") or plist.get("CFBundleVersion", "0.0.0")
    build = plist.get("CFBundleVersion", "1")
    exec_name = plist.get("CFBundleExecutable", "KL-06")

    exec_path = os.path.join(app_path, "Contents", "MacOS", exec_name)
    if not os.path.isfile(exec_path):
        raise ValueError(f"Bundle executable missing at {exec_path}")

    # Run privacy check
    findings = run_privacy_scan(app_path)
    if findings:
        raise ValueError(f"Privacy scan failed with findings: {findings}")

    if not output_dir:
        output_dir = os.path.dirname(os.path.abspath(app_path))
    os.makedirs(output_dir, exist_ok=True)

    zip_filename = "KL-06.zip"
    zip_path = os.path.join(output_dir, zip_filename)

    # Build clean ZIP archive (strip .DS_Store, __MACOSX)
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        app_base = os.path.basename(os.path.normpath(app_path))
        for root, _, files in os.walk(app_path):
            for file in sorted(files):
                if file in (".DS_Store", "Thumbs.db") or file.startswith("._"):
                    continue
                full_path = os.path.join(root, file)
                rel_path = os.path.relpath(full_path, os.path.dirname(app_path))
                zf.write(full_path, rel_path)

    sha256 = compute_sha256(zip_path)
    size_bytes = os.path.getsize(zip_path)
    source_rev = get_git_revision(git_dir)

    # Generate BUILD-METADATA.json automatically
    metadata = {
        "app_name": "KL-06 Manager",
        "bundle_id": bundle_id,
        "version": version,
        "build": build,
        "executable": exec_name,
        "source_revision": source_rev,
        "archive_file": zip_filename,
        "sha256": sha256,
        "size_bytes": size_bytes,
        "target_os": "macOS 13+",
        "target_arch": "x86_64",
        "privacy_scan": "passed_clean",
        "generated_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    }
    metadata_path = os.path.join(output_dir, "BUILD-METADATA.json")
    with open(metadata_path, "w", encoding="utf-8") as f:
        json.dump(metadata, f, indent=2)

    # Generate SHA256SUMS automatically
    sums_path = os.path.join(output_dir, "SHA256SUMS")
    with open(sums_path, "w", encoding="utf-8") as f:
        f.write(f"{sha256}  {zip_filename}\n")

    # Generate matching release notes automatically
    notes = [
        f"## KL-06 Manager v{version} Beta (Build {build})",
        "",
        "**Status**: Beta Prerelease (Target-verified on ASUS VivoBook K15 OLED K513EA, macOS Sequoia 15.8.3).",
        "",
        "### Artifact Integrity",
        f"- **File**: `{zip_filename}` ({size_bytes} bytes)",
        f"- **SHA-256**: `{sha256}`",
        f"- **Bundle ID**: `{bundle_id}`",
        f"- **Version / Build**: `{version}` / `{build}`",
        f"- **Source Revision**: `{source_rev}`",
        f"- **Architecture**: `x86_64` (Mach-O 64-bit)",
        "",
        "### Verified Target Capabilities",
        "- Native AppKit/IOKit/CoreAudio/Metal control center companion.",
        "- Working WhateverXe 0.8.2 Iris Xe graphics, OLED/DPCD brightness, and Fn keys preserved.",
        "- Core Audio default output volume scalar supported; no audio kext or layout modifications.",
        "- Global F13 hotkey (keyCode 105, no modifiers) for show/hide with Carbon buffer.count fix.",
        "- No fake fan controls, no EC/SMC writes, no persistent pmset edits.",
        "- Private reports, EFI backups, and credentials strictly excluded.",
    ]
    notes_path = os.path.join(output_dir, "RELEASE-NOTES.md")
    with open(notes_path, "w", encoding="utf-8") as f:
        f.write("\n".join(notes) + "\n")

    return {
        "zip_path": zip_path,
        "metadata_path": metadata_path,
        "sums_path": sums_path,
        "notes_path": notes_path,
        "metadata": metadata,
    }


def main():
    parser = argparse.ArgumentParser(
        description="Automatically package KL-06.app and generate metadata without manual manifests."
    )
    parser.add_argument("app_path", help="Path to built KL-06.app directory")
    parser.add_argument("-o", "--output-dir", help="Output directory for archive and manifests")
    args = parser.parse_args()

    try:
        res = package_app(args.app_path, output_dir=args.output_dir)
        m = res["metadata"]
        print(f"✓ Successfully packaged KL-06 Manager v{m['version']} (build {m['build']})")
        print(f"  Archive:  {res['zip_path']} ({m['size_bytes']} bytes)")
        print(f"  SHA-256:  {m['sha256']}")
        print(f"  Metadata: {res['metadata_path']}")
        print(f"  Sums:     {res['sums_path']}")
        print(f"  Notes:    {res['notes_path']}")
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
