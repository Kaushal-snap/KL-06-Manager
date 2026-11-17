#!/usr/bin/env python3
"""
Unit tests for KL-06 release validation and staging automation.
"""

import io
import os
import plistlib
import tempfile
import unittest
import zipfile

from scripts.validate_and_stage_release import (
    EXPECTED_BUNDLE_ID,
    ValidationError,
    compute_sha256,
    inspect_and_validate_zip,
    stage_draft_release,
)


def create_mock_app_zip(
    zip_path,
    bundle_id=EXPECTED_BUNDLE_ID,
    version="0.2.1",
    build="3",
    exec_name="KL-06",
    include_exec=True,
    traversal_path=None,
    omit_plist=False,
):
    with zipfile.ZipFile(zip_path, "w") as zf:
        if not omit_plist:
            plist_data = {
                "CFBundleIdentifier": bundle_id,
                "CFBundleShortVersionString": version,
                "CFBundleVersion": build,
                "CFBundleExecutable": exec_name,
                "CFBundleName": "KL-06",
            }
            zf.writestr("KL-06.app/Contents/Info.plist", plistlib.dumps(plist_data))

        if include_exec:
            zf.writestr(f"KL-06.app/Contents/MacOS/{exec_name}", b"mock_executable_bytes")

        if traversal_path:
            zf.writestr(traversal_path, b"malicious_bytes")


class TestReleaseAutomation(unittest.TestCase):
    def setUp(self):
        self.tmp_dir = tempfile.TemporaryDirectory()

    def tearDown(self):
        self.tmp_dir.cleanup()

    def test_valid_app_zip(self):
        zip_path = os.path.join(self.tmp_dir.name, "KL-06-valid.zip")
        create_mock_app_zip(zip_path, version="0.9.9", build="99")

        expected_hash = compute_sha256(zip_path)
        info = inspect_and_validate_zip(zip_path, expected_sha256=expected_hash)

        self.assertEqual(info["bundle_id"], EXPECTED_BUNDLE_ID)
        self.assertEqual(info["version"], "0.9.9")
        self.assertEqual(info["build"], "99")
        self.assertEqual(info["executable"], "KL-06")
        self.assertEqual(info["sha256"], expected_hash)

        # Stage dry run
        stage_res = stage_draft_release(info, dry_run=True)
        self.assertEqual(stage_res["status"], "dry_run_success")
        self.assertEqual(stage_res["tag"], "v0.9.9-beta.99")

    def test_wrong_bundle_id_rejected(self):
        zip_path = os.path.join(self.tmp_dir.name, "wrong-id.zip")
        create_mock_app_zip(zip_path, bundle_id="com.fake.app")

        with self.assertRaises(ValidationError) as ctx:
            inspect_and_validate_zip(zip_path)
        self.assertIn("Invalid CFBundleIdentifier", str(ctx.exception))

    def test_missing_executable_rejected(self):
        zip_path = os.path.join(self.tmp_dir.name, "no-exec.zip")
        create_mock_app_zip(zip_path, include_exec=False)

        with self.assertRaises(ValidationError) as ctx:
            inspect_and_validate_zip(zip_path)
        self.assertIn("Missing bundle executable", str(ctx.exception))

    def test_checksum_mismatch_rejected(self):
        zip_path = os.path.join(self.tmp_dir.name, "bad-hash.zip")
        create_mock_app_zip(zip_path)

        with self.assertRaises(ValidationError) as ctx:
            inspect_and_validate_zip(zip_path, expected_sha256="deadbeef" * 8)
        self.assertIn("Checksum mismatch", str(ctx.exception))

    def test_traversal_attack_rejected(self):
        zip_path = os.path.join(self.tmp_dir.name, "traversal.zip")
        create_mock_app_zip(zip_path, traversal_path="../evil.sh")

        with self.assertRaises(ValidationError) as ctx:
            inspect_and_validate_zip(zip_path)
        self.assertIn("directory traversal", str(ctx.exception))

    def test_missing_info_plist_rejected(self):
        zip_path = os.path.join(self.tmp_dir.name, "no-plist.zip")
        create_mock_app_zip(zip_path, omit_plist=True)

        with self.assertRaises(ValidationError) as ctx:
            inspect_and_validate_zip(zip_path)
        self.assertIn("No Contents/Info.plist", str(ctx.exception))


if __name__ == "__main__":
    unittest.main()
