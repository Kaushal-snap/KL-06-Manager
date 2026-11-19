#!/usr/bin/env python3
"""Opt-in, bounded TLS LAN broker. No OS command execution, credentials or driver writes.
Only native desktop UI can approve pairing and carry out allowlisted user actions.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import hmac
import http.server
import ipaddress
import json
import math
import os
from pathlib import Path
import re
import secrets
import signal
import socketserver
import ssl
import stat
import sys
import threading
import time
import uuid

try:
    from companion.transfer import TransferEngine, TransferError, sanitize_filename
except ImportError:
    from transfer import TransferEngine, TransferError, sanitize_filename

PROTOCOL = "KL06_COMPANION_V1"
NETWORKS = tuple(ipaddress.ip_network(n) for n in ("10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"))
TWEAKS = frozenset((
    "dock-autohide", "dock-reveal", "dock-scale", "dock-launch", "finder-path", "finder-status",
    "finder-hidden", "file-extensions", "scrollbars", "dock-recents", "finder-folders-first",
    "natural-scroll", "win-extensions", "win-hidden", "win-theme-dark",
))
ID = re.compile(r"[a-f0-9]{32}")


class Rejected(Exception):
    pass


def _mac_uptime_clock(api):
    """Fixed public read-only clock API; no Python-version-dependent time-zero."""
    import ctypes
    class Timebase(ctypes.Structure):
        _fields_ = [("numer", ctypes.c_uint32), ("denom", ctypes.c_uint32)]
    api.mach_timebase_info.argtypes = [ctypes.POINTER(Timebase)]
    api.mach_timebase_info.restype = ctypes.c_int
    api.mach_absolute_time.argtypes = []
    api.mach_absolute_time.restype = ctypes.c_uint64
    base = Timebase()
    if api.mach_timebase_info(ctypes.byref(base)) != 0 or not base.numer or not base.denom:
        raise Rejected("native-clock-unavailable")
    scale = base.numer / base.denom / 1e9
    return lambda: api.mach_absolute_time() * scale


def _windows_uptime_clock(api):
    import ctypes
    for name in ("QueryPerformanceFrequency", "QueryPerformanceCounter"):
        function = getattr(api, name)
        function.argtypes = [ctypes.POINTER(ctypes.c_int64)]
        function.restype = ctypes.c_int
    frequency = ctypes.c_int64()
    if not api.QueryPerformanceFrequency(ctypes.byref(frequency)) or frequency.value <= 0:
        raise Rejected("native-clock-unavailable")
    def clock():
        value = ctypes.c_int64()
        if not api.QueryPerformanceCounter(ctypes.byref(value)) or value.value < 0:
            raise Rejected("native-clock-unavailable")
        return value.value / frequency.value
    return clock


def native_uptime_clock():
    # Python 3.9 macOS monotonic has a process-local epoch; older Windows versions
    # use GetTickCount64 instead of QPC. Never compare either to a native QPC/mach
    # deadline. Load only the fixed OS clock functions, never an arbitrary library.
    import ctypes
    if sys.platform == "darwin":
        return _mac_uptime_clock(ctypes.CDLL("/usr/lib/libSystem.B.dylib"))
    if sys.platform == "win32":
        return _windows_uptime_clock(ctypes.WinDLL("kernel32.dll", use_last_error=True))
    return time.monotonic  # Linux portable/loopback tests, not a supported app host.


def private_ipv4(value, test_loopback=False):
    try:
        address = ipaddress.IPv4Address(value)
    except (ValueError, TypeError):
        return False
    return any(address in network for network in NETWORKS) or (test_loopback and address.is_loopback)


def unique_object(pairs):
    out = {}
    for key, value in pairs:
        if key in out:
            raise Rejected("duplicate-json-key")
        out[key] = value
    return out


def decode_json(raw):
    return json.loads(raw, object_pairs_hook=unique_object,
                      parse_constant=lambda _: (_ for _ in ()).throw(Rejected("nonfinite-json")))


def regular(info, limit):
    if (not stat.S_ISREG(info.st_mode) or info.st_nlink != 1 or info.st_size > limit
            or getattr(info, "st_file_attributes", 0) & getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0)):
        raise Rejected("unsafe-file")
    if hasattr(os, "geteuid") and info.st_uid != os.geteuid():
        raise Rejected("file-owner")


def read_json(path: Path, limit=262144):
    regular(path.lstat(), limit)
    descriptor = os.open(path, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
    with os.fdopen(descriptor, "rb") as stream:
        regular(os.fstat(stream.fileno()), limit)
        raw = stream.read(limit + 1)
    if len(raw) > limit:
        raise Rejected("oversize-file")
    return decode_json(raw.decode("utf-8"))


def atomic_json(path: Path, value):
    raw = json.dumps(value, allow_nan=False, separators=(",", ":")).encode()
    temporary = path.with_name("." + secrets.token_hex(12) + ".tmp")
    descriptor = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(raw)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        try:
            temporary.unlink()
        except FileNotFoundError:
            pass


def command(body):
    if not isinstance(body, dict) or set(body) != {"operation", "params"}:
        raise Rejected("command-schema")
    method, params = body["operation"], body["params"]
    if not isinstance(method, str) or not isinstance(params, dict):
        raise Rejected("command-params")
    if method == "setVolume" and set(params) == {"value"}:
        v = params["value"]
        if type(v) not in (int, float) or not math.isfinite(v) or not 0 <= v <= 100:
            raise Rejected("volume-range")
    elif method in ("applyTweak", "restoreTweak") and set(params) == {"id"}:
        if not isinstance(params["id"], str) or params["id"] not in TWEAKS:
            raise Rejected("unknown-tweak")
    elif method in ("restoreAll", "keepAwake") and not params:
        pass
    else:
        raise Rejected("operation-unavailable")
    return {"operation": method, "params": params}


def finite(value, low, high):
    return type(value) in (int, float) and math.isfinite(value) and low <= value <= high


def project_state(value, now):
    if not isinstance(value, dict) or value.get("schema") != "KL06_DESKTOP_SNAPSHOT_V1":
        raise Rejected("snapshot-schema")
    stamp = value.get("writtenAt")
    if not finite(stamp, 0, 1e12) or not -2 <= now - stamp <= 12:
        return {"protocol": PROTOCOL, "status": "stale", "state": None,
                "message": "No fresh desktop snapshot. No history is substituted."}
    source = value.get("state")
    if not isinstance(source, dict) or source.get("platform") not in ("macos", "windows"):
        raise Rejected("snapshot-platform")
    age = max(0, now - stamp)
    out = {"platform": source["platform"]}

    def text(key, length=80):
        v = source.get(key)
        if isinstance(v, str) and len(v) <= length and not any(ord(c) < 32 for c in v):
            out[key] = v

    for key in ("version", "sampledAt"):
        text(key)
    for key, limits in (("build", (0, 1000000)), ("volume", (0, 100)),
                        ("sampledAtUnix", (0, 1e12)), ("sampledUptimeSeconds", (0, 1e12))):
        if finite(source.get(key), *limits):
            out[key] = source[key]
    out["awake"] = source.get("awake") is True

    def fields(name, numbers, texts=(), booleans=()):
        s = source.get(name)
        if not isinstance(s, dict):
            return
        result = {key: s[key] for key, limits in numbers.items() if finite(s.get(key), *limits)}
        for key in texts:
            v = s.get(key)
            if isinstance(v, str) and len(v) <= 140 and not any(ord(c) < 32 for c in v):
                result[key] = v
        for key in booleans:
            if type(s.get(key)) is bool:
                result[key] = s[key]
        out[name] = result

    fields("cpu", {"loadPercent": (0, 100), "logicalCores": (1, 4096), "intervalSeconds": (0, 3600)}, ("name", "source"))
    fields("memory", {"totalGB": (0, 1e6), "usedGB": (0, 1e6), "compressedGB": (0, 1e6), "swapMB": (0, 1e12)}, ("source",))
    fields("storage", {"totalGB": (0, 1e12), "freeGB": (0, 1e12)})
    fields("battery", {"chargePercent": (0, 100), "healthPercent": (0, 200), "CycleCount": (0, 1e6)}, booleans=("onAC", "charging"))
    f = source.get("fan")
    if isinstance(f, dict):
        out["fan"] = {"status": "unavailable-or-stale", "manualControl": False, "fans": [], "ageSeconds": None}
        for key, limit in (("source", 160), ("quality", 160), ("reportedAt", 64)):
            if isinstance(f.get(key), str) and len(f[key]) <= limit:
                out["fan"][key] = f[key]
        fan_age = f.get("ageSeconds")
        fresh = finite(fan_age, 0, 12) and fan_age + age <= 12 and f.get("status") in ("ok", "partial-or-sensor-unavailable")
        if finite(fan_age, 0, 1e12):
            out["fan"]["ageSeconds"] = fan_age + age
        rows = f.get("fans") if isinstance(f.get("fans"), list) else []
        for r in rows[:2]:
            if not isinstance(r, dict) or type(r.get("index")) is not int or r["index"] not in (0, 1):
                continue
            valid = fresh and r.get("status") == "ok" and finite(r.get("rpm"), 0, 30000)
            out["fan"]["fans"].append({"index": r["index"], "status": "ok" if valid else "unavailable-or-stale", "rpm": r["rpm"] if valid else None})
        if fresh:
            out["fan"]["status"] = f["status"]
        elif f.get("status") in ("unsupported", "denied", "invalid", "stale", "reading", "not-sampled"):
            out["fan"]["status"] = f["status"]
    rows = source.get("tweaks") if isinstance(source.get("tweaks"), list) else []
    out["tweaks"] = [{"id": r["id"], **{k: r.get(k) is True for k in ("saved", "conflict", "blocked", "managed")}}
                     for r in rows[:32] if isinstance(r, dict) and isinstance(r.get("id"), str) and r["id"] in TWEAKS]
    # No original preferences, imported history, raw reports, network/account/path/serial identifiers.
    return {"protocol": PROTOCOL, "status": "fresh", "state": out, "snapshotAgeSeconds": age,
            "validForSeconds": max(0, 12 - age)}


class Broker:
    def __init__(self, root: Path, *, clock=time.time, monotonic=None, lifetime=1800):
        if not 0 < lifetime <= 1800:
            raise Rejected("session-lifetime")
        if monotonic is None:
            monotonic = native_uptime_clock()
        self.root, self.clock, self.monotonic = root, clock, monotonic
        self.started, self.started_mono = clock(), monotonic()
        self.expires, self.deadline = self.started + lifetime, self.started_mono + lifetime
        self.pair_code = secrets.token_hex(16)
        self.tokens, self.pending, self.owners, self.rates = {}, {}, {}, {}
        self.lock = threading.RLock()
        root.mkdir(mode=0o700, exist_ok=True)
        self._directory(root)
        (root / "requests").mkdir(mode=0o700, exist_ok=True)
        self._directory(root / "requests")
        staging_dir = root / "transfers"
        staging_dir.mkdir(mode=0o700, exist_ok=True)
        self._directory(staging_dir)
        self.transfer_engine = TransferEngine(staging_dir, clock_func=self.clock)
        self.downloads_dir = Path.home() / "Downloads"
        if not self.downloads_dir.exists():
            self.downloads_dir = root / "downloads"
            self.downloads_dir.mkdir(mode=0o700, exist_ok=True)

    @staticmethod
    def _directory(path):
        info = path.lstat()
        if not stat.S_ISDIR(info.st_mode) or path.is_symlink() or getattr(info, "st_file_attributes", 0) & getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0):
            raise Rejected("unsafe-directory")
        if hasattr(os, "geteuid") and (info.st_uid != os.geteuid() or info.st_mode & 0o077):
            raise Rejected("directory-owner-or-permissions")

    def alive(self):
        if self.clock() >= self.expires or self.monotonic() >= self.deadline:
            raise Rejected("session-expired")

    def _unlink(self, identifier):
        for suffix in (".json", ".result.json"):
            try:
                (self.root / "requests" / (identifier + suffix)).unlink()
            except FileNotFoundError:
                pass

    def prune(self):
        now = self.clock()
        for identifier, item in list(self.pending.items()):
            if now >= item["expiresAt"] or self.monotonic() >= item["expiresMonotonic"]:
                self._unlink(identifier)
                del self.pending[identifier]
        for identifier, (expiry, _, deadline) in list(self.owners.items()):
            if now >= expiry or self.monotonic() >= deadline:
                self._unlink(identifier)
                del self.owners[identifier]

    def rate(self, key, cap):
        now = self.monotonic()
        start, count = self.rates.get(key, (now, 0))
        if now - start >= 60:
            start, count = now, 0
        if count >= cap:
            raise Rejected("rate-limit")
        self.rates[key] = (start, count + 1)

    def auth(self, authorization):
        if not isinstance(authorization, str) or not authorization.startswith("Bearer "):
            raise Rejected("not-paired")
        candidate = authorization[7:]
        if not re.fullmatch(r"[a-f0-9]{64}", candidate):
            raise Rejected("not-paired")
        for token, expiry in self.tokens.items():
            if hmac.compare_digest(token, candidate) and self.clock() < expiry:
                return token
        raise Rejected("not-paired")

    def pair(self, body):
        self.rate("pair", 8)
        if set(body) != {"code", "platform"} or body["platform"] not in ("android", "ios", "macos", "windows"):
            raise Rejected("pair-schema")
        if (self.clock() - self.started >= 300 or self.monotonic() - self.started_mono >= 300
                or not isinstance(body["code"], str) or not hmac.compare_digest(body["code"], self.pair_code)):
            raise Rejected("pair-code-invalid-or-expired")
        if len(self.pending) >= 4 or len(self.tokens) >= 2:
            raise Rejected("pair-limit")
        ticket = uuid.uuid4().hex
        expiry = min(self.expires, self.clock() + 90)
        deadline = min(self.deadline, self.monotonic() + 90)
        self.pending[ticket] = {"platform": body["platform"], "expiresAt": expiry, "expiresMonotonic": deadline}
        atomic_json(self.root / "requests" / f"{ticket}.json", {"schema": PROTOCOL, "id": ticket, "kind": "pair", "platform": body["platform"], "createdAt": self.clock(), "expiresAt": expiry, "createdMonotonic": self.monotonic(), "expiresMonotonic": deadline})
        return 202, {"ticket": ticket, "status": "awaiting-laptop-confirmation"}

    def finish(self, body):
        self.rate("finish", 30)
        if self.clock() - self.started >= 300 or self.monotonic() - self.started_mono >= 300:
            raise Rejected("pair-code-expired")
        if set(body) != {"ticket", "code"} or not isinstance(body.get("code"), str) or not hmac.compare_digest(body["code"], self.pair_code):
            raise Rejected("pair-schema")
        ticket = body["ticket"]
        item = self.pending.get(ticket) if isinstance(ticket, str) else None
        if not item or self.clock() >= item["expiresAt"] or self.monotonic() >= item["expiresMonotonic"]:
            raise Rejected("pair-expired")
        try:
            result = read_json(self.root / "requests" / f"{ticket}.result.json", 4096)
        except FileNotFoundError:
            return 202, {"status": "awaiting-laptop-confirmation"}
        if not isinstance(result, dict) or result.get("approved") is not True:
            raise Rejected("pair-denied")
        if "token" not in item:
            if len(self.tokens) >= 2:
                raise Rejected("pair-limit")
            item["token"] = secrets.token_hex(32)
            self.tokens[item["token"]] = self.expires
        return 200, {"status": "paired", "token": item["token"], "expiresAt": self.expires, "protocol": PROTOCOL}

    def handle(self, path, body, authorization=None):
        with self.lock:
            self.alive()
            if not isinstance(body, dict):
                raise Rejected("object-required")
            self.prune()
            if path == "/v1/discover":
                if body:
                    raise Rejected("discover-schema")
                import socket
                return 200, {
                    "protocol": PROTOCOL,
                    "service": "KL-06 Companion",
                    "version": "0.4.2-beta",
                    "build": 9,
                    "hostname": socket.gethostname(),
                    "platform": sys.platform
                }
            if path == "/v1/pair":
                return self.pair(body)
            if path == "/v1/pair/finish":
                return self.finish(body)
            token = self.auth(authorization)
            self.rate(token, 100)
            if path == "/v1/disconnect":
                if body:
                    raise Rejected("disconnect-schema")
                del self.tokens[token]
                self.rates.pop(token, None)
                for identifier, (_, owner, _) in list(self.owners.items()):
                    if hmac.compare_digest(owner, token):
                        self._unlink(identifier)
                        del self.owners[identifier]
                for identifier, item in list(self.pending.items()):
                    if item.get("token") == token:
                        self._unlink(identifier)
                        del self.pending[identifier]
                return 200, {"status": "disconnected-and-revoked"}
            if path == "/v1/transfer/init":
                if set(body.keys()) != {"fileName", "fileSize", "expectedSha256", "senderPlatform"}:
                    raise Rejected("transfer-init-schema")
                if not isinstance(body["fileName"], str) or not isinstance(body["fileSize"], int) or not isinstance(body["expectedSha256"], str) or not isinstance(body["senderPlatform"], str):
                    raise Rejected("transfer-init-types")
                try:
                    session = self.transfer_engine.initiate_transfer(
                        sender_token=token,
                        sender_platform=body["senderPlatform"],
                        receiver_platform=sys.platform,
                        file_name=body["fileName"],
                        file_size=body["fileSize"],
                        expected_sha256=body["expectedSha256"]
                    )
                    session.approve(self.downloads_dir)
                    return 200, {
                        "status": "approved",
                        "transferId": session.transfer_id,
                        "fileName": session.file_name,
                        "maxChunkSize": 1024 * 1024
                    }
                except TransferError as e:
                    raise Rejected(str(e))
            if path == "/v1/transfer/chunk":
                if set(body.keys()) != {"transferId", "chunkOffset", "chunkBase64"}:
                    raise Rejected("transfer-chunk-schema")
                try:
                    session = self.transfer_engine.get_transfer(body["transferId"])
                    if not hmac.compare_digest(session.sender_token, token):
                        raise Rejected("transfer-unauthorized")
                    chunk_data = base64.b64decode(body["chunkBase64"])
                    session.append_chunk(body["chunkOffset"], chunk_data)
                    return 200, session.get_status()
                except (TransferError, ValueError) as e:
                    raise Rejected(str(e))
            if path == "/v1/transfer/status":
                if set(body.keys()) != {"transferId"}:
                    raise Rejected("transfer-status-schema")
                try:
                    session = self.transfer_engine.get_transfer(body["transferId"])
                    if not hmac.compare_digest(session.sender_token, token):
                        raise Rejected("transfer-unauthorized")
                    return 200, session.get_status()
                except TransferError as e:
                    raise Rejected(str(e))
            if path == "/v1/transfer/cancel":
                if set(body.keys()) != {"transferId"}:
                    raise Rejected("transfer-cancel-schema")
                try:
                    session = self.transfer_engine.get_transfer(body["transferId"])
                    session.cancel(token)
                    return 200, {"status": "cancelled", "transferId": body["transferId"]}
                except TransferError as e:
                    raise Rejected(str(e))
            if path == "/v1/state":
                if body:
                    raise Rejected("state-schema")
                try:
                    return 200, project_state(read_json(self.root / "snapshot.json"), self.clock())
                except FileNotFoundError:
                    return 200, {"protocol": PROTOCOL, "status": "not-sampled", "state": None}
            if path == "/v1/command":
                operation = command(body)
                if len(self.owners) >= 8:
                    raise Rejected("queue-full")
                identifier = uuid.uuid4().hex
                expiry = min(self.expires, self.clock() + 90)
                deadline = min(self.deadline, self.monotonic() + 90)
                self.owners[identifier] = (expiry, token, deadline)
                atomic_json(self.root / "requests" / f"{identifier}.json", {"schema": PROTOCOL, "id": identifier, "kind": "command", "createdAt": self.clock(), "expiresAt": expiry, "createdMonotonic": self.monotonic(), "expiresMonotonic": deadline, **operation})
                return 202, {"id": identifier, "status": "awaiting-laptop-confirmation"}
            if path == "/v1/result":
                identifier = body.get("id")
                if set(body) != {"id"} or not isinstance(identifier, str) or not ID.fullmatch(identifier):
                    raise Rejected("result-schema")
                record = self.owners.get(identifier)
                if not record or not hmac.compare_digest(record[1], token):
                    raise Rejected("unknown-or-expired-request")
                try:
                    reply = read_json(self.root / "requests" / f"{identifier}.result.json", 4096)
                except FileNotFoundError:
                    return 202, {"status": "awaiting-laptop-confirmation"}
                if not isinstance(reply, dict):
                    raise Rejected("result-schema")
                return 200, {"status": "approved-and-completed" if reply.get("ok") is True else "denied-or-failed", "message": str(reply.get("message", ""))[:512]}
            raise Rejected("endpoint-unavailable")


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version, server_version, sys_version = "HTTP/1.1", "KL06", ""

    def setup(self):
        self.request.settimeout(5)
        if isinstance(self.request, ssl.SSLSocket):
            self.request.do_handshake()
        super().setup()

    def log_message(self, *_):
        pass

    def send_json(self, status, body):
        data = json.dumps(body, allow_nan=False, separators=(",", ":")).encode()
        self.send_response(status)
        for key, value in (("Content-Type", "application/json"), ("Content-Length", str(len(data))), ("Cache-Control", "no-store"), ("Connection", "close")):
            self.send_header(key, value)
        self.end_headers()
        self.wfile.write(data)
        self.close_connection = True

    def do_POST(self):
        try:
            if self.headers.get_all("Transfer-Encoding") or self.headers.get_all("Origin"):
                raise Rejected("browser-origin-or-transfer-encoding-not-allowed")
            lengths, types = self.headers.get_all("Content-Length", []), self.headers.get_all("Content-Type", [])
            hosts, authorizations = self.headers.get_all("Host", []), self.headers.get_all("Authorization", [])
            if len(lengths) != 1 or len(types) != 1 or len(hosts) != 1 or len(authorizations) > 1:
                raise Rejected("ambiguous-headers")
            if types[0].split(";")[0] != "application/json" or hosts[0] != self.server.expected_host:
                raise Rejected("native-json-host-required")
            if not re.fullmatch(r"0|[1-9][0-9]{0,4}", lengths[0]):
                raise Rejected("request-size")
            length = int(lengths[0])
            if length > 16384:
                raise Rejected("request-size")
            data = self.rfile.read(length)
            if len(data) != length:
                raise Rejected("short-body")
            body = decode_json(data.decode("utf-8"))
            status, result = self.server.broker.handle(self.path, body, authorizations[0] if authorizations else None)
            self.send_json(status, result)
        except Rejected as error:
            self.send_json(403, {"status": "refused", "reason": str(error)})
        except (ValueError, UnicodeError, TypeError, KeyError, RecursionError):
            self.send_json(400, {"status": "invalid-request"})
        except Exception:
            self.send_json(503, {"status": "unavailable"})

    def do_GET(self):
        self.send_json(405, {"status": "POST-only-native-client"})

    def do_OPTIONS(self):
        self.send_json(403, {"status": "no-browser-cors"})


class Server(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads, allow_reuse_address = True, False

    def __init__(self, address, broker, context, *, test_loopback=False):
        self.broker, self.context, self.test_loopback = broker, context, test_loopback
        self.slots = threading.BoundedSemaphore(8)
        super().__init__(address, Handler)
        self.expected_host = f"{self.server_address[0]}:{self.server_address[1]}"

    def verify_request(self, request, address):
        return private_ipv4(address[0], self.test_loopback)

    def get_request(self):
        sock, address = super().get_request()
        sock.settimeout(5)
        try:
            return self.context.wrap_socket(sock, server_side=True, do_handshake_on_connect=False), address
        except Exception:
            sock.close()
            raise

    def process_request(self, request, address):
        if not self.slots.acquire(False):
            self.shutdown_request(request)
            return
        try:
            super().process_request(request, address)
        except Exception:
            self.slots.release()
            raise

    def process_request_thread(self, request, address):
        try:
            super().process_request_thread(request, address)
        finally:
            self.slots.release()

    def handle_error(self, *_):
        pass


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--directory", type=Path, required=True)
    parser.add_argument("--bind", required=True)
    args = parser.parse_args()
    if hasattr(os, "geteuid") and os.geteuid() == 0:
        raise SystemExit("Run without root/sudo.")
    if not private_ipv4(args.bind):
        raise SystemExit("Choose a literal RFC1918 LAN IPv4 address. No public/wildcard bind.")
    broker = Broker(args.directory)
    cert, key = args.directory / "cert.pem", args.directory / "key.pem"
    regular(cert.lstat(), 16384)
    regular(key.lstat(), 16384)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    context.load_cert_chain(cert, key)
    fingerprint = hashlib.sha256(ssl.PEM_cert_to_DER_cert(cert.read_text())).hexdigest()
    stopping = threading.Event()
    signal.signal(signal.SIGTERM, lambda *_: stopping.set())

    import socket

    def udp_responder():
        try:
            udp_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            udp_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            try:
                udp_sock.bind(("", 8766))
            except Exception:
                try:
                    udp_sock.bind((args.bind, 8766))
                except Exception:
                    return
            udp_sock.settimeout(0.5)
            while not stopping.is_set():
                try:
                    data, addr = udp_sock.recvfrom(2048)
                    if b"KL06_DISCOVER" in data:
                        reply = json.dumps({
                            "service": "KL-06 Companion",
                            "protocol": PROTOCOL,
                            "version": "0.4.2-beta",
                            "build": 9,
                            "platform": sys.platform,
                            "hostname": socket.gethostname(),
                            "port": 8766,
                            "pin": fingerprint
                        }).encode("utf-8")
                        udp_sock.sendto(reply, addr)
                except socket.timeout:
                    continue
                except Exception:
                    break
            udp_sock.close()
        except Exception:
            pass

    udp_thread = threading.Thread(target=udp_responder, daemon=True)
    udp_thread.start()

    try:
        with Server((args.bind, 8766), broker, context) as server:
            server.timeout = 0.5
            atomic_json(args.directory / "session.json", {"schema": PROTOCOL, "url": f"https://{args.bind}:8766", "certificateSha256": fingerprint, "pairCode": broker.pair_code, "expiresAt": broker.expires, "pairCodeExpiresAt": broker.started + 300, "pairCodeExpiresMonotonic": broker.started_mono + 300})
            while not stopping.is_set():
                try:
                    broker.alive()
                except Rejected:
                    break
                server.handle_request()
    finally:
        with broker.lock:
            broker.tokens.clear()
            for identifier in list(broker.pending) + list(broker.owners):
                broker._unlink(identifier)
        for name in ("session.json", "snapshot.json", "key.pem", "cert.pem"):
            try:
                (args.directory / name).unlink()
            except FileNotFoundError:
                pass


if __name__ == "__main__":
    main()
