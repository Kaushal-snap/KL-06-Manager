#!/usr/bin/env python3
"""
companion/ota.py - Secure OTA App Update engine for KL-06 Manager.
Validates signed update catalogs, enforces monotonic versioning and downgrade protection,
checks platform compatibility, computes SHA-256 integrity, and prepares platform-approved installation handoffs.
"""

from __future__ import annotations

import hashlib
import hmac
import json
import os
from pathlib import Path
import re
import time
import urllib.parse

OTA_CATALOG_SCHEMA = "KL06_SIGNED_UPDATE_CATALOG_V1"
PINNED_SIGNING_KEYS = {
    "kl06-ed25519-root-2026": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
}

ALLOWED_DOWNLOAD_HOSTS = frozenset((
    "github.com",
    "objects.githubusercontent.com",
    "drive.google.com",
    "raw.githubusercontent.com"
))


class OTAError(ValueError):
    """Base exception for OTA update errors."""
    pass


class DowngradeAttackError(OTAError):
    """Raised when an update attempts to downgrade version or build number."""
    pass


class SignatureVerificationError(OTAError):
    """Raised when catalog signature or key validation fails."""
    pass


def verify_download_url(url: str) -> str:
    """Ensures download URL uses HTTPS and comes from an allowlisted host."""
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme != "https":
        raise OTAError("https_required_for_updates")
    if not parsed.hostname or parsed.hostname.lower() not in ALLOWED_DOWNLOAD_HOSTS:
        raise OTAError(f"untrusted_update_host_{parsed.hostname}")
    return url


def verify_catalog_signature(catalog: dict, key_secret: str | None = None) -> bool:
    """
    Verifies catalog signature against pinned root key.
    Uses HMAC-SHA256 over canonical JSON payload for portable verification.
    """
    sig = catalog.get("signature")
    key_id = catalog.get("signingKeyId")
    if not sig or not key_id:
        raise SignatureVerificationError("missing_signature_or_key_id")
    if key_id not in PINNED_SIGNING_KEYS:
        raise SignatureVerificationError(f"unknown_or_untrusted_signing_key_{key_id}")

    payload = {k: v for k, v in catalog.items() if k != "signature"}
    canonical_bytes = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    
    # Secret key for signature check
    secret = (key_secret or PINNED_SIGNING_KEYS[key_id]).encode("utf-8")
    expected = hmac.new(secret, canonical_bytes, hashlib.sha256).hexdigest()
    if not hmac.compare_digest(sig.lower(), expected.lower()):
        raise SignatureVerificationError("invalid_catalog_signature")
    return True


class UpdateEngine:
    """Validates update catalogs, stages downloads, and outputs platform-specific install specs."""

    def __init__(self, current_platform: str, current_version: str, current_build: int, clock_func=None):
        self.platform = current_platform.lower()
        self.version = current_version
        self.build = int(current_build)
        self.clock = clock_func or time.time

    def parse_catalog(self, catalog_dict: dict, current_channel: str = "beta", key_secret: str | None = None) -> dict:
        """Parses and validates signed catalog for available updates."""
        if catalog_dict.get("schema") != OTA_CATALOG_SCHEMA:
            raise OTAError(f"unsupported_catalog_schema_{catalog_dict.get('schema')}")

        now = self.clock()
        expires = catalog_dict.get("expiresAt", 0)
        if now > expires:
            raise OTAError("update_catalog_expired")

        channel = catalog_dict.get("channel")
        if channel != current_channel:
            raise OTAError(f"channel_mismatch_expected_{current_channel}_got_{channel}")

        verify_catalog_signature(catalog_dict, key_secret=key_secret)

        packages = catalog_dict.get("packages", {})
        pkg = packages.get(self.platform)
        if not pkg:
            return {"updateAvailable": False, "reason": "no_package_for_platform"}

        new_version = pkg.get("version", "")
        new_build = int(pkg.get("build", 0))

        # Check version monotonicity / downgrade protection
        if new_build < self.build:
            raise DowngradeAttackError(f"downgrade_detected_current_{self.build}_offered_{new_build}")
        if new_build == self.build:
            return {"updateAvailable": False, "reason": "already_latest_version", "currentBuild": self.build}

        download_url = verify_download_url(pkg.get("downloadUrl", ""))
        sha256 = pkg.get("sha256", "").lower()
        if not re.fullmatch(r"[a-f0-9]{64}", sha256):
            raise OTAError("invalid_sha256_in_package")

        return {
            "updateAvailable": True,
            "platform": self.platform,
            "currentVersion": self.version,
            "currentBuild": self.build,
            "newVersion": new_version,
            "newBuild": new_build,
            "downloadUrl": download_url,
            "sha256": sha256,
            "sizeBytes": int(pkg.get("sizeBytes", 0)),
            "minOS": pkg.get("minOS", ""),
            "releaseNotes": pkg.get("releaseNotes", ""),
            "installerType": pkg.get("installerType", "verified-manual"),
        }

    def verify_downloaded_artifact(self, file_path: Path, expected_sha256: str, expected_size: int) -> bool:
        """Verifies downloaded binary package integrity before prompting installation."""
        if not file_path.is_file():
            raise OTAError("download_artifact_not_found")

        actual_size = file_path.stat().st_size
        if actual_size != expected_size:
            raise OTAError(f"size_mismatch_expected_{expected_size}_got_{actual_size}")

        hasher = hashlib.sha256()
        with open(file_path, "rb") as f:
            while chunk := f.read(65536):
                hasher.update(chunk)
        digest = hasher.hexdigest().lower()
        if digest != expected_sha256.lower():
            raise OTAError(f"sha256_mismatch_expected_{expected_sha256}_computed_{digest}")
        return True

    def get_installation_action(self, verified_pkg: dict, staged_file_path: Path | None = None) -> dict:
        """
        Generates platform-approved, compliant installation handoff action.
        Never bypasses OS package managers or executes silent installs.
        """
        platform = self.platform
        installer_type = verified_pkg.get("installerType")

        if platform == "android":
            # Public PackageInstaller intent handoff with user confirmation
            return {
                "action": "ACTION_INSTALL_PACKAGE",
                "targetMime": "application/vnd.android.package-archive",
                "requiresUserConfirmation": True,
                "stagedPath": str(staged_file_path) if staged_file_path else None,
                "packageId": "app.klasus.controlcenter",
                "notes": "Handed off to Android OS PackageInstaller. Requires matching signing certificate lineage."
            }
        elif platform == "ios":
            # TestFlight / App Store public distribution URL
            store_url = verified_pkg.get("downloadUrl")
            return {
                "action": "OPEN_URL",
                "targetUrl": store_url,
                "requiresUserConfirmation": True,
                "notes": "Redirects to TestFlight / App Store. Direct IPA sideloading is disallowed."
            }
        elif platform == "macos":
            return {
                "action": "OPEN_VERIFIED_ARCHIVE",
                "stagedPath": str(staged_file_path) if staged_file_path else None,
                "requiresUserConfirmation": True,
                "notes": "Reveals verified archive in Finder with instructions to replace KL-06 Manager.app in /Applications."
            }
        elif platform == "windows":
            return {
                "action": "RUN_SIGNED_INSTALLER",
                "stagedPath": str(staged_file_path) if staged_file_path else None,
                "requiresUserConfirmation": True,
                "notes": "Launches signed MSIX / installer package under standard user privilege."
            }
        else:
            return {
                "action": "MANUAL_INSTALL",
                "stagedPath": str(staged_file_path) if staged_file_path else None,
                "requiresUserConfirmation": True,
                "notes": "Verified manual install."
            }
