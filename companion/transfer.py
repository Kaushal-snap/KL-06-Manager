#!/usr/bin/env python3
"""
companion/transfer.py - Secure, chunked, two-way file transfer engine for KL-06 ecosystem.
Enforces explicit receiver approval, path sanitization, streaming SHA-256 verification,
collision protection, safe resume, and cancellation cleanup.
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import os
from pathlib import Path
import re
import threading
import time
import uuid

# Safety limits
MAX_FILE_SIZE = 2 * 1024 * 1024 * 1024  # 2 GB
MAX_CHUNK_SIZE = 1024 * 1024             # 1 MB
MAX_ACTIVE_TRANSFERS = 8
TRANSFER_EXPIRY_SECONDS = 3600           # 1 hour
RESERVED_NAMES = frozenset((
    "CON", "PRN", "AUX", "NUL",
    "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
    "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"
))

# Route Matrix declaration
SUPPORTED_ROUTES = {
    ("macos", "windows"): {"type": "direct_lan", "relay": False, "notes": "Direct authenticated TLS LAN streaming."},
    ("windows", "macos"): {"type": "direct_lan", "relay": False, "notes": "Direct authenticated TLS LAN streaming."},
    ("macos", "android"): {"type": "saf_stream", "relay": False, "notes": "Storage Access Framework URI + native streamed IO."},
    ("android", "macos"): {"type": "saf_stream", "relay": False, "notes": "Storage Access Framework URI + native streamed IO."},
    ("macos", "ios"): {"type": "security_scoped", "relay": False, "notes": "Security-scoped document access + foreground lifecycle."},
    ("ios", "macos"): {"type": "security_scoped", "relay": False, "notes": "Security-scoped document access + foreground lifecycle."},
    ("windows", "android"): {"type": "saf_stream", "relay": False, "notes": "Windows filesystem to Android SAF content URI."},
    ("android", "windows"): {"type": "saf_stream", "relay": False, "notes": "Android SAF content URI to Windows filesystem."},
    ("windows", "ios"): {"type": "security_scoped", "relay": False, "notes": "Windows filesystem to iOS security-scoped document container."},
    ("ios", "windows"): {"type": "security_scoped", "relay": False, "notes": "iOS security-scoped document container to Windows filesystem."},
    ("android", "ios"): {"type": "direct_lan", "relay": False, "notes": "Direct authenticated TLS LAN Quick Share / AirDrop streaming."},
    ("ios", "android"): {"type": "direct_lan", "relay": False, "notes": "Direct authenticated TLS LAN AirDrop / Quick Share streaming."}
}


class TransferError(ValueError):
    """Raised when transfer validation, authentication, or streaming fails."""
    pass


def sanitize_filename(filename: str) -> str:
    """
    Sanitizes candidate filename against traversal, ADS, NUL bytes, and reserved device names.
    Returns cleaned basename or raises TransferError.
    """
    if not filename or not isinstance(filename, str):
        raise TransferError("filename_required")
    if "\x00" in filename:
        raise TransferError("null_byte_in_filename")
    if "/" in filename or "\\" in filename:
        raise TransferError("path_separators_forbidden")
    if ".." in filename:
        raise TransferError("traversal_sequence_forbidden")
    if ":" in filename:
        raise TransferError("alternate_data_stream_forbidden")

    cleaned = filename.strip(". ")
    if not cleaned:
        raise TransferError("empty_or_whitespace_filename")

    base = cleaned.split(".")[0].upper()
    if base in RESERVED_NAMES:
        raise TransferError("reserved_device_filename")

    return cleaned


def resolve_collision_path(target_path: Path) -> Path:
    """
    Generates a non-colliding target path by appending ' (1)', ' (2)' etc.
    Never silently overwrites an existing file.
    """
    if not target_path.exists():
        return target_path

    directory = target_path.parent
    stem = target_path.stem
    suffix = target_path.suffix
    counter = 1
    while True:
        candidate = directory / f"{stem} ({counter}){suffix}"
        if not candidate.exists():
            return candidate
        counter += 1


class TransferSession:
    """Represents an active or completed file transfer session."""

    def __init__(
        self,
        transfer_id: str,
        sender_token: str,
        sender_platform: str,
        receiver_platform: str,
        file_name: str,
        file_size: int,
        expected_sha256: str,
        staging_dir: Path,
        clock_func=None,
    ):
        self.transfer_id = transfer_id
        self.sender_token = sender_token
        self.sender_platform = sender_platform
        self.receiver_platform = receiver_platform
        self.file_name = sanitize_filename(file_name)
        self.file_size = int(file_size)
        self.expected_sha256 = expected_sha256.lower()
        self.staging_dir = staging_dir
        self.clock = clock_func or time.time

        if self.file_size < 0 or self.file_size > MAX_FILE_SIZE:
            raise TransferError("file_size_out_of_bounds")
        if not re.fullmatch(r"[a-f0-9]{64}", self.expected_sha256):
            raise TransferError("invalid_sha256_format")

        self.created_at = self.clock()
        self.expires_at = self.created_at + TRANSFER_EXPIRY_SECONDS
        self.state = "awaiting_approval"
        self.destination_path: Path | None = None
        self.staging_path = staging_dir / f".transfer_{self.transfer_id}.part"

        self.bytes_written = 0
        self.hasher = hashlib.sha256()
        self.file_handle = None
        self.lock = threading.Lock()

    def approve(self, destination_dir: Path, custom_filename: str | None = None):
        """Receiver approves the transfer and assigns destination directory."""
        with self.lock:
            if self.state != "awaiting_approval":
                raise TransferError(f"cannot_approve_in_state_{self.state}")
            if not destination_dir.is_dir():
                raise TransferError("destination_directory_not_found")

            target_name = sanitize_filename(custom_filename) if custom_filename else self.file_name
            self.destination_path = resolve_collision_path(destination_dir / target_name)
            self.staging_dir.mkdir(parents=True, exist_ok=True)
            self.file_handle = open(self.staging_path, "wb")
            self.state = "transferring"

    def decline(self, reason: str = "declined_by_receiver"):
        """Receiver declines the transfer."""
        with self.lock:
            if self.state not in ("awaiting_approval", "transferring"):
                raise TransferError(f"cannot_decline_in_state_{self.state}")
            self.state = "declined"
            self.expires_at = self.clock() + 60
            self._close_and_clean()

    def cancel(self, requester_token: str):
        """Sender or receiver cancels the transfer."""
        with self.lock:
            if not hmac.compare_digest(self.sender_token, requester_token):
                raise TransferError("unauthorized_cancel")
            if self.state in ("complete", "failed", "cancelled", "declined"):
                return
            self.state = "cancelled"
            self.expires_at = self.clock() + 60
            self._close_and_clean()

    def append_chunk(self, chunk_offset: int, data: bytes):
        """Appends a received chunk with offset validation and hash accumulation."""
        with self.lock:
            if self.state != "transferring":
                raise TransferError(f"cannot_write_chunk_in_state_{self.state}")
            if self.clock() > self.expires_at:
                self.state = "failed"
                self.expires_at = self.clock() + 60
                self._close_and_clean()
                raise TransferError("transfer_expired")

            if chunk_offset != self.bytes_written:
                raise TransferError(f"chunk_offset_mismatch_expected_{self.bytes_written}_got_{chunk_offset}")

            chunk_len = len(data)
            if chunk_len > MAX_CHUNK_SIZE:
                raise TransferError("chunk_size_exceeds_maximum")
            if self.bytes_written + chunk_len > self.file_size:
                raise TransferError("total_bytes_exceeds_announced_size")

            self.file_handle.write(data)
            self.file_handle.flush()
            self.hasher.update(data)
            self.bytes_written += chunk_len

            if self.bytes_written == self.file_size:
                self._finalize()

    def _finalize(self):
        """Verifies final SHA-256 and atomically renames staging to destination."""
        if self.file_handle:
            self.file_handle.close()
            self.file_handle = None

        digest = self.hasher.hexdigest().lower()
        if digest != self.expected_sha256:
            self.state = "failed"
            self.expires_at = self.clock() + 60
            self._close_and_clean()
            raise TransferError(f"sha256_verification_failed_expected_{self.expected_sha256}_computed_{digest}")

        # Atomic rename to final destination
        try:
            os.replace(self.staging_path, self.destination_path)
            self.state = "complete"
            self.expires_at = self.clock() + 60
        except Exception as e:
            self.state = "failed"
            self.expires_at = self.clock() + 60
            self._close_and_clean()
            raise TransferError(f"finalization_rename_failed: {e}")

    def _close_and_clean(self):
        if self.file_handle:
            try:
                self.file_handle.close()
            except Exception:
                pass
            self.file_handle = None
        if self.staging_path.exists():
            try:
                self.staging_path.unlink()
            except Exception:
                pass

    def get_status(self) -> dict:
        """Returns structured status dictionary."""
        with self.lock:
            pct = 100.0 if self.file_size == 0 else round((self.bytes_written / self.file_size) * 100, 1)
            route = SUPPORTED_ROUTES.get((self.sender_platform, self.receiver_platform), {"type": "unknown", "relay": False})
            return {
                "transferId": self.transfer_id,
                "fileName": self.file_name,
                "fileSize": self.file_size,
                "bytesTransferred": self.bytes_written,
                "percentComplete": pct,
                "state": self.state,
                "senderPlatform": self.sender_platform,
                "receiverPlatform": self.receiver_platform,
                "routeType": route["type"],
                "desktopHubRelay": route["relay"],
                "finalPath": str(self.destination_path) if self.state == "complete" else None,
                "expiresAt": self.expires_at,
            }


class TransferEngine:
    """Manages active transfers, session validation, and quota enforcement."""

    def __init__(self, staging_root: Path, clock_func=None):
        self.staging_root = staging_root
        self.clock = clock_func or time.time
        self.transfers: dict[str, TransferSession] = {}
        self.lock = threading.Lock()

    def initiate_transfer(
        self,
        sender_token: str,
        sender_platform: str,
        receiver_platform: str,
        file_name: str,
        file_size: int,
        expected_sha256: str,
    ) -> TransferSession:
        with self.lock:
            self._prune_expired()
            if len(self.transfers) >= MAX_ACTIVE_TRANSFERS:
                raise TransferError("max_active_transfers_reached")

            transfer_id = uuid.uuid4().hex
            session = TransferSession(
                transfer_id=transfer_id,
                sender_token=sender_token,
                sender_platform=sender_platform,
                receiver_platform=receiver_platform,
                file_name=file_name,
                file_size=file_size,
                expected_sha256=expected_sha256,
                staging_dir=self.staging_root,
                clock_func=self.clock,
            )
            self.transfers[transfer_id] = session
            return session

    def get_transfer(self, transfer_id: str) -> TransferSession:
        with self.lock:
            self._prune_expired()
            session = self.transfers.get(transfer_id)
            if not session:
                raise TransferError("transfer_not_found")
            return session

    def resume_transfer(self, transfer_id: str, sender_token: str, expected_sha256: str) -> dict:
        """Supports safe resume of an interrupted transfer."""
        session = self.get_transfer(transfer_id)
        with session.lock:
            if not hmac.compare_digest(session.sender_token, sender_token):
                raise TransferError("unauthorized_resume_peer")
            if session.expected_sha256 != expected_sha256.lower():
                raise TransferError("resume_hash_mismatch")
            if session.state not in ("transferring", "awaiting_approval"):
                raise TransferError(f"cannot_resume_in_state_{session.state}")

            return {
                "transferId": session.transfer_id,
                "state": session.state,
                "bytesWritten": session.bytes_written,
                "expectedSize": session.file_size,
                "nextChunkOffset": session.bytes_written,
            }

    def _prune_expired(self):
        now = self.clock()
        # Keep terminal status available briefly so senders can confirm completion/failure.
        expired = [tid for tid, s in self.transfers.items() if now > s.expires_at]
        for tid in expired:
            session = self.transfers.pop(tid)
            session._close_and_clean()
