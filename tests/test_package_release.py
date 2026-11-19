#!/usr/bin/env python3
"""
Unit tests for packaging/package_release.py.
Enforces non-negotiable safety and privacy invariants.
"""

import json
import os
import plistlib
import tempfile
import unittest
import zipfile

from packaging.package_release import (
    EXPECTED_BUNDLE_ID,
    PrivacyViolationHoldError,
    compute_sha256,
    package_app,
)


def create_mock_app(
    base_dir,
    bundle_id=EXPECTED_BUNDLE_ID,
    version="0.2.1",
    build="3",
    exec_name="KL-06",
    leak_secret=False,
    binary_payload=b"mock_signed_macho_binary_bytes_12345",
):
    app_dir = os.path.join(base_dir, "KL-06.app")
    contents = os.path.join(app_dir, "Contents")
    macos = os.path.join(contents, "MacOS")
    resources = os.path.join(contents, "Resources")
    os.makedirs(macos, exist_ok=True)
    os.makedirs(resources, exist_ok=True)

    plist = {
        "CFBundleIdentifier": bundle_id,
        "CFBundleShortVersionString": version,
        "CFBundleVersion": build,
        "CFBundleExecutable": exec_name,
        "CFBundleName": "KL-06",
    }
    with open(os.path.join(contents, "Info.plist"), "wb") as f:
        plistlib.dump(plist, f)

    exec_file = os.path.join(macos, exec_name)
    with open(exec_file, "wb") as f:
        f.write(binary_payload)

    # Add resource
    with open(os.path.join(resources, "test.txt"), "w") as f:
        if leak_secret:
            f.write("ghp_fakeTokenSecret1234567890abcdef")
        else:
            f.write("safe clean content")

    # Add junk file to verify it gets stripped
    with open(os.path.join(contents, ".DS_Store"), "w") as f:
        f.write("junk")

    return app_dir, exec_file, binary_payload


class TestPackageRelease(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()

    def tearDown(self):
        self.tmp.cleanup()

    def test_automatic_packaging_and_metadata(self):
        app_dir, _, _ = create_mock_app(self.tmp.name)
        out_dir = os.path.join(self.tmp.name, "output")

        res = package_app(app_dir, output_dir=out_dir)

        self.assertTrue(os.path.isfile(res["zip_path"]))
        self.assertTrue(os.path.isfile(res["metadata_path"]))
        self.assertTrue(os.path.isfile(res["sums_path"]))
        self.assertTrue(os.path.isfile(res["notes_path"]))

        # Verify metadata content
        with open(res["metadata_path"], "r") as f:
            meta = json.load(f)

        self.assertEqual(meta["bundle_id"], EXPECTED_BUNDLE_ID)
        self.assertEqual(meta["version"], "0.2.1")
        self.assertEqual(meta["build"], "3")
        self.assertEqual(meta["privacy_scan"], "passed_clean")
        self.assertEqual(meta["sha256"], compute_sha256(res["zip_path"]))

        # Verify junk was stripped from ZIP
        with zipfile.ZipFile(res["zip_path"]) as zf:
            names = zf.namelist()
            self.assertFalse(any(".DS_Store" in n for n in names))
            self.assertTrue(any("Contents/Info.plist" in n for n in names))

    def test_hold_publication_and_require_clean_rebuild_without_modifying_binary(self):
        """
        INVARIANT: Do not blindly modify a signed app binary to redact strings;
        hold publication and require a clean rebuild if private data is embedded in a build.
        """
        app_dir, exec_path, original_bytes = create_mock_app(self.tmp.name, leak_secret=True)
        out_dir = os.path.join(self.tmp.name, "output")

        with self.assertRaises(PrivacyViolationHoldError) as ctx:
            package_app(app_dir, output_dir=out_dir)

        err_msg = str(ctx.exception)
        self.assertIn("Publication held", err_msg)
        self.assertIn("Do not blindly patch or redact a signed binary", err_msg)
        self.assertIn("A clean rebuild without private strings is required", err_msg)

        # Verify the binary was NOT modified or redacted in-place
        with open(exec_path, "rb") as f:
            current_bytes = f.read()
        self.assertEqual(current_bytes, original_bytes, "Signed binary must never be modified in-place")

    def test_record_owner_reported_testing_honestly_without_inventing_granular_results(self):
        """
        INVARIANT: Record owner-reported testing honestly without inventing granular test results.
        """
        app_dir, _, _ = create_mock_app(self.tmp.name)
        out_dir = os.path.join(self.tmp.name, "output")

        res = package_app(app_dir, output_dir=out_dir)
        with open(res["notes_path"], "r") as f:
            notes = f.read()

        # Must record verified target facts honestly
        self.assertIn("ASUS VivoBook K15 OLED K513EA", notes)
        self.assertIn("macOS Sequoia 15.8.3", notes)
        self.assertIn("No fake fan controls, no EC/SMC writes", notes)

        # Must NOT claim invented granular benchmarks or controls
        self.assertNotIn("Geekbench", notes)
        self.assertNotIn("Cinebench", notes)
        self.assertNotIn("100% fan speed verified", notes)
        self.assertNotIn("undervolting confirmed", notes)

    def test_wrong_bundle_id_rejected(self):
        app_dir, _, _ = create_mock_app(self.tmp.name, bundle_id="com.unauthorized.id")
        out_dir = os.path.join(self.tmp.name, "output")

        with self.assertRaises(ValueError) as ctx:
            package_app(app_dir, output_dir=out_dir)
        self.assertIn("Bundle identifier mismatch", str(ctx.exception))


if __name__ == "__main__":
    unittest.main()
