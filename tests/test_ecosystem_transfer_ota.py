#!/usr/bin/env python3
"""
tests/test_ecosystem_transfer_ota.py - Comprehensive unit tests for
KL-06 two-way file transfer and secure OTA update engines.
Covers all invariants specified in ECOSYSTEM-FILE-TRANSFER-OTA-SPEC.md.
"""

import hashlib
import hmac
import json
from pathlib import Path
import tempfile
import time
import unittest

from companion.transfer import (
    TransferEngine,
    TransferError,
    TransferSession,
    resolve_collision_path,
    sanitize_filename,
)
from companion.ota import (
    OTA_CATALOG_SCHEMA,
    PINNED_SIGNING_KEYS,
    DowngradeAttackError,
    OTAError,
    SignatureVerificationError,
    UpdateEngine,
    verify_catalog_signature,
    verify_download_url,
)


class MockClock:
    def __init__(self, start_time: float = 1700000000.0):
        self.current = start_time

    def time(self) -> float:
        return self.current

    def advance(self, seconds: float):
        self.current += seconds


class TestSanitizeFilename(unittest.TestCase):
    def test_valid_filenames(self):
        self.assertEqual(sanitize_filename("document.pdf"), "document.pdf")
        self.assertEqual(sanitize_filename("my-test_file.2026.zip"), "my-test_file.2026.zip")
        self.assertEqual(sanitize_filename("Photos (Vacation).tar.gz"), "Photos (Vacation).tar.gz")

    def test_path_traversal_refused(self):
        with self.assertRaises(TransferError):
            sanitize_filename("../secret.key")
        with self.assertRaises(TransferError):
            sanitize_filename("dir/file.txt")
        with self.assertRaises(TransferError):
            sanitize_filename("..\\windows\\system32\\cmd.exe")

    def test_null_bytes_and_ads_refused(self):
        with self.assertRaises(TransferError):
            sanitize_filename("report\x00.pdf")
        with self.assertRaises(TransferError):
            sanitize_filename("document.txt:hidden_stream")

    def test_reserved_device_names_refused(self):
        with self.assertRaises(TransferError):
            sanitize_filename("CON.txt")
        with self.assertRaises(TransferError):
            sanitize_filename("prn.dat")
        with self.assertRaises(TransferError):
            sanitize_filename("aux")
        with self.assertRaises(TransferError):
            sanitize_filename("com1.log")
        with self.assertRaises(TransferError):
            sanitize_filename("lpt3.bin")

    def test_empty_or_whitespace_refused(self):
        with self.assertRaises(TransferError):
            sanitize_filename("")
        with self.assertRaises(TransferError):
            sanitize_filename("   ")
        with self.assertRaises(TransferError):
            sanitize_filename("...")


class TestTransferSessionAndEngine(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.staging_dir = Path(self.tmp.name) / "staging"
        self.dest_dir = Path(self.tmp.name) / "destination"
        self.staging_dir.mkdir()
        self.dest_dir.mkdir()
        self.clock = MockClock()
        self.engine = TransferEngine(self.staging_dir, clock_func=self.clock.time)

    def tearDown(self):
        self.tmp.cleanup()

    def test_end_to_end_transfer_success(self):
        payload = b"Hello from KL-06 multi-device secure ecosystem! 1234567890"
        expected_sha = hashlib.sha256(payload).hexdigest()
        session = self.engine.initiate_transfer(
            sender_token="token_alice",
            sender_platform="macos",
            receiver_platform="android",
            file_name="hello.txt",
            file_size=len(payload),
            expected_sha256=expected_sha,
        )

        self.assertEqual(session.state, "awaiting_approval")
        # Cannot write before approval
        with self.assertRaises(TransferError):
            session.append_chunk(0, payload[:10])

        # Receiver approves
        session.approve(self.dest_dir)
        self.assertEqual(session.state, "transferring")

        # Stream chunk 1
        session.append_chunk(0, payload[:20])
        status = session.get_status()
        self.assertEqual(status["bytesTransferred"], 20)
        self.assertEqual(status["state"], "transferring")

        # Out-of-order offset rejection
        with self.assertRaises(TransferError):
            session.append_chunk(25, payload[20:])

        # Stream chunk 2 to completion
        session.append_chunk(20, payload[20:])
        self.assertEqual(session.state, "complete")
        self.assertTrue((self.dest_dir / "hello.txt").is_file())
        self.assertEqual((self.dest_dir / "hello.txt").read_bytes(), payload)

    def test_corrupt_hash_fails_and_cleans_up(self):
        payload = b"Real payload data"
        fake_sha = hashlib.sha256(b"corrupt other data").hexdigest()
        session = self.engine.initiate_transfer(
            sender_token="token_bob",
            sender_platform="windows",
            receiver_platform="macos",
            file_name="test.bin",
            file_size=len(payload),
            expected_sha256=fake_sha,
        )
        session.approve(self.dest_dir)
        with self.assertRaises(TransferError):
            session.append_chunk(0, payload)

        self.assertEqual(session.state, "failed")
        self.assertFalse((self.dest_dir / "test.bin").exists())
        self.assertFalse(session.staging_path.exists())

    def test_collision_protection_does_not_overwrite(self):
        original = self.dest_dir / "existing.txt"
        original.write_text("Prior critical content")

        new_data = b"New uploaded content"
        session = self.engine.initiate_transfer(
            sender_token="token_charlie",
            sender_platform="macos",
            receiver_platform="windows",
            file_name="existing.txt",
            file_size=len(new_data),
            expected_sha256=hashlib.sha256(new_data).hexdigest(),
        )
        session.approve(self.dest_dir)
        session.append_chunk(0, new_data)

        self.assertEqual(session.state, "complete")
        self.assertEqual(original.read_text(), "Prior critical content")
        collided = self.dest_dir / "existing (1).txt"
        self.assertTrue(collided.is_file())
        self.assertEqual(collided.read_bytes(), new_data)

    def test_receiver_decline(self):
        session = self.engine.initiate_transfer(
            sender_token="token_dave",
            sender_platform="ios",
            receiver_platform="macos",
            file_name="photo.jpg",
            file_size=100,
            expected_sha256="a" * 64,
        )
        session.decline()
        self.assertEqual(session.state, "declined")
        with self.assertRaises(TransferError):
            session.approve(self.dest_dir)

    def test_sender_cancel(self):
        session = self.engine.initiate_transfer(
            sender_token="token_eve",
            sender_platform="android",
            receiver_platform="macos",
            file_name="clip.mp4",
            file_size=100,
            expected_sha256="b" * 64,
        )
        session.approve(self.dest_dir)
        # Unauthorized cancel rejected
        with self.assertRaises(TransferError):
            session.cancel("wrong_token")

        # Authorized cancel
        session.cancel("token_eve")
        self.assertEqual(session.state, "cancelled")
        self.assertFalse(session.staging_path.exists())

    def test_safe_resume(self):
        payload = b"First half of chunked file ... Second half of chunked file"
        expected_sha = hashlib.sha256(payload).hexdigest()
        session = self.engine.initiate_transfer(
            sender_token="token_frank",
            sender_platform="macos",
            receiver_platform="android",
            file_name="data.bin",
            file_size=len(payload),
            expected_sha256=expected_sha,
        )
        session.approve(self.dest_dir)
        session.append_chunk(0, payload[:20])

        # Resume query
        res = self.engine.resume_transfer(session.transfer_id, "token_frank", expected_sha)
        self.assertEqual(res["bytesWritten"], 20)
        self.assertEqual(res["nextChunkOffset"], 20)

        # Wrong token on resume
        with self.assertRaises(TransferError):
            self.engine.resume_transfer(session.transfer_id, "token_intruder", expected_sha)

        # Complete from resumed offset
        session.append_chunk(20, payload[20:])
        self.assertEqual(session.state, "complete")


class TestOTAUpdateEngine(unittest.TestCase):
    def setUp(self):
        self.clock = MockClock()
        self.engine = UpdateEngine(
            current_platform="macos",
            current_version="0.3.0",
            current_build=4,
            clock_func=self.clock.time,
        )
        self.key_id = "kl06-ed25519-root-2026"
        self.secret = PINNED_SIGNING_KEYS[self.key_id]

    def create_mock_catalog(
        self,
        build=5,
        version="0.3.0-beta.2",
        channel="beta",
        expires_offset=86400,
        sha256="4cb9aecf1cc460ed872d2260a1e9cd833d447585ffde77b4ab5cf152c748c3ba",
        download_url="https://github.com/Kaushal-snap/KL-06-Manager/releases/download/v0.3.0-beta.2/KL-06.zip",
        tamper_sig=False,
    ):
        cat = {
            "schema": OTA_CATALOG_SCHEMA,
            "channel": channel,
            "publishedAt": self.clock.time(),
            "expiresAt": self.clock.time() + expires_offset,
            "signingKeyId": self.key_id,
            "packages": {
                "macos": {
                    "version": version,
                    "build": build,
                    "downloadUrl": download_url,
                    "sha256": sha256,
                    "sizeBytes": 145733,
                    "minOS": "13.0",
                    "installerType": "verified-manual-archive",
                    "releaseNotes": "Ecosystem multi-device file transfer and secure OTA updates.",
                },
                "android": {
                    "version": version,
                    "build": build,
                    "downloadUrl": "https://github.com/Kaushal-snap/KL-06-Manager/releases/download/v0.3.0-beta.2/KL-06-Manager.apk",
                    "sha256": "a" * 64,
                    "sizeBytes": 1200000,
                    "minOS": "26",
                    "installerType": "package-installer-intent",
                },
                "ios": {
                    "version": version,
                    "build": build,
                    "downloadUrl": "https://testflight.apple.com/join/kl06-beta",
                    "sha256": "b" * 64,
                    "sizeBytes": 0,
                    "minOS": "16.0",
                    "installerType": "testflight-redirect",
                },
            },
        }
        # Compute signature
        canonical = json.dumps(cat, sort_keys=True, separators=(",", ":")).encode("utf-8")
        sig = hmac.new(self.secret.encode("utf-8"), canonical, hashlib.sha256).hexdigest()
        if tamper_sig:
            sig = "0" * 64
        cat["signature"] = sig
        return cat

    def test_valid_update_detection(self):
        cat = self.create_mock_catalog(build=5)
        res = self.engine.parse_catalog(cat)
        self.assertTrue(res["updateAvailable"])
        self.assertEqual(res["newBuild"], 5)
        self.assertEqual(res["newVersion"], "0.3.0-beta.2")

    def test_downgrade_attack_rejected(self):
        # Current build is 4, offered build is 3 -> must raise DowngradeAttackError
        cat = self.create_mock_catalog(build=3)
        with self.assertRaises(DowngradeAttackError):
            self.engine.parse_catalog(cat)

    def test_same_build_not_offered_as_update(self):
        cat = self.create_mock_catalog(build=4)
        res = self.engine.parse_catalog(cat)
        self.assertFalse(res["updateAvailable"])
        self.assertEqual(res["reason"], "already_latest_version")

    def test_expired_catalog_rejected(self):
        cat = self.create_mock_catalog(expires_offset=-100)
        with self.assertRaises(OTAError):
            self.engine.parse_catalog(cat)

    def test_tampered_signature_rejected(self):
        cat = self.create_mock_catalog(tamper_sig=True)
        with self.assertRaises(SignatureVerificationError):
            self.engine.parse_catalog(cat)

    def test_untrusted_download_host_rejected(self):
        cat = self.create_mock_catalog(download_url="https://malicious-site.com/malware.zip")
        with self.assertRaises(OTAError):
            self.engine.parse_catalog(cat)

    def test_insecure_http_rejected(self):
        with self.assertRaises(OTAError):
            verify_download_url("http://github.com/Kaushal-snap/KL-06-Manager/releases/test.zip")

    def test_artifact_verification(self):
        with tempfile.NamedTemporaryFile() as tmp:
            payload = b"Valid signed binary package payload"
            tmp.write(payload)
            tmp.flush()
            path = Path(tmp.name)
            correct_sha = hashlib.sha256(payload).hexdigest()

            # Valid verification
            self.assertTrue(self.engine.verify_downloaded_artifact(path, correct_sha, len(payload)))

            # Size mismatch
            with self.assertRaises(OTAError):
                self.engine.verify_downloaded_artifact(path, correct_sha, len(payload) + 10)

            # Hash mismatch
            with self.assertRaises(OTAError):
                self.engine.verify_downloaded_artifact(path, "0" * 64, len(payload))

    def test_platform_installation_handoffs(self):
        # Android handoff -> PackageInstaller intent with user confirmation
        android_engine = UpdateEngine("android", "0.3.0", 4)
        pkg = {"installerType": "package-installer-intent"}
        act = android_engine.get_installation_action(pkg, Path("/data/app.apk"))
        self.assertEqual(act["action"], "ACTION_INSTALL_PACKAGE")
        self.assertTrue(act["requiresUserConfirmation"])

        # iOS handoff -> Store / TestFlight redirect, no sideloading IPA
        ios_engine = UpdateEngine("ios", "0.3.0", 4)
        ios_pkg = {"downloadUrl": "https://testflight.apple.com/join/kl06-beta", "installerType": "testflight-redirect"}
        ios_act = ios_engine.get_installation_action(ios_pkg)
        self.assertEqual(ios_act["action"], "OPEN_URL")
        self.assertEqual(ios_act["targetUrl"], "https://testflight.apple.com/join/kl06-beta")


if __name__ == "__main__":
    unittest.main()
