#!/usr/bin/env python3
"""End-to-end tests of the companion broker over real TLS/HTTP on loopback.

The earlier unit tests called Broker.handle() directly and so never exercised the HTTP size limit:
a phone sending 64 KiB chunks (about 87 KB of base64 JSON) was refused with 403 request-size, which
made every file larger than ~12 KB fail. These tests send real chunks through the real server.
"""
import base64
import hashlib
import http.client
import json
import os
from pathlib import Path
import shutil
import ssl
import subprocess
import tempfile
import threading
import time
import unittest

from companion import server as S


class Harness:
    def __init__(self):
        self.root = Path(tempfile.mkdtemp(prefix="kl06-http-"))
        os.chmod(self.root, 0o700)
        subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-sha256", "-nodes", "-days", "1", "-subj", "/CN=t",
                        "-keyout", str(self.root / "key.pem"), "-out", str(self.root / "cert.pem")], check=True, capture_output=True)
        for name in ("key.pem", "cert.pem"):
            os.chmod(self.root / name, 0o600)
        self.broker = S.Broker(self.root)
        self.downloads = self.root / "downloads"
        self.downloads.mkdir(mode=0o700, exist_ok=True)
        self.broker.downloads_dir = self.downloads
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(self.root / "cert.pem", self.root / "key.pem")
        self.server = S.Server(("127.0.0.1", 0), self.broker, context, test_loopback=True)
        self.server.timeout = 0.1
        self.port = self.server.server_address[1]
        self.stop = threading.Event()
        self.thread = threading.Thread(target=self._loop, daemon=True)
        self.thread.start()

    def _loop(self):
        while not self.stop.is_set():
            self.server.handle_request()

    def close(self):
        self.stop.set()
        self.thread.join(2)
        self.server.server_close()
        shutil.rmtree(self.root, ignore_errors=True)

    def post(self, path, body, token=None):
        connection = http.client.HTTPSConnection("127.0.0.1", self.port, context=ssl._create_unverified_context(), timeout=10)
        headers = {"Content-Type": "application/json"}
        if token:
            headers["Authorization"] = "Bearer " + token
        connection.request("POST", path, json.dumps(body).encode(), headers)
        response = connection.getresponse()
        data = json.loads(response.read())
        connection.close()
        return response.status, data

    def pair(self):
        status, reply = self.post("/v1/pair", {"code": self.broker.pair_code, "platform": "android"})
        assert status == 202, reply
        ticket = reply["ticket"]
        (self.root / "requests" / f"{ticket}.result.json").write_text(json.dumps({"approved": True}))
        status, reply = self.post("/v1/pair/finish", {"ticket": ticket, "code": self.broker.pair_code})
        assert status == 200, reply
        return reply["token"]

    def decide(self, transfer_id, approved):
        (self.root / "requests" / f"{transfer_id}.result.json").write_text(json.dumps({"ok": True, "approved": approved}))


class HttpTransferTests(unittest.TestCase):
    def setUp(self):
        self.h = Harness()
        self.token = self.h.pair()

    def tearDown(self):
        self.h.close()

    def test_large_file_with_64k_chunks_transfers_after_laptop_approval(self):
        data = os.urandom(300_000)
        sha = hashlib.sha256(data).hexdigest()
        status, init = self.h.post("/v1/transfer/init", {"fileName": "big.bin", "fileSize": len(data), "expectedSha256": sha, "senderPlatform": "android"}, self.token)
        self.assertEqual(status, 202)
        self.assertEqual(init["status"], "awaiting-laptop-confirmation")
        tid = init["transferId"]
        request = json.loads((self.h.root / "requests" / f"{tid}.json").read_text())
        self.assertEqual((request["kind"], request["fileName"], request["fileSize"], request["platform"]), ("transfer", "big.bin", len(data), "android"))
        # Nothing may be written, and chunks must wait, until the laptop owner accepts.
        status, reply = self.h.post("/v1/transfer/chunk", {"transferId": tid, "chunkOffset": 0, "chunkBase64": base64.b64encode(data[:65536]).decode()}, self.token)
        self.assertEqual((status, reply["status"]), (202, "awaiting-laptop-confirmation"))
        self.assertEqual(list(self.h.downloads.iterdir()), [])
        self.h.decide(tid, True)
        offset = 0
        while offset < len(data):
            chunk = data[offset:offset + 65536]
            status, reply = self.h.post("/v1/transfer/chunk", {"transferId": tid, "chunkOffset": offset, "chunkBase64": base64.b64encode(chunk).decode()}, self.token)
            self.assertEqual(status, 200, reply)
            offset += len(chunk)
        self.assertEqual(reply["state"], "complete")
        self.assertEqual((self.h.downloads / "big.bin").read_bytes(), data)

    def test_one_mebibyte_chunk_is_accepted(self):
        data = os.urandom(1024 * 1024)
        sha = hashlib.sha256(data).hexdigest()
        _, init = self.h.post("/v1/transfer/init", {"fileName": "m.bin", "fileSize": len(data), "expectedSha256": sha, "senderPlatform": "ios"}, self.token)
        self.h.decide(init["transferId"], True)
        status, reply = self.h.post("/v1/transfer/chunk", {"transferId": init["transferId"], "chunkOffset": 0, "chunkBase64": base64.b64encode(data).decode()}, self.token)
        self.assertEqual((status, reply["state"]), (200, "complete"))

    def test_decline_discards_everything(self):
        data = b"x" * 1000
        _, init = self.h.post("/v1/transfer/init", {"fileName": "no.txt", "fileSize": 1000, "expectedSha256": hashlib.sha256(data).hexdigest(), "senderPlatform": "android"}, self.token)
        self.h.decide(init["transferId"], False)
        status, reply = self.h.post("/v1/transfer/status", {"transferId": init["transferId"]}, self.token)
        self.assertEqual(status, 403)
        self.assertEqual(reply["reason"], "transfer-denied-by-laptop")
        self.assertEqual(list(self.h.downloads.iterdir()), [])
        self.assertEqual([p for p in (self.h.root / "transfers").iterdir()], [])

    def test_wrong_hash_is_rejected_and_nothing_is_kept(self):
        data = b"hello world" * 100
        _, init = self.h.post("/v1/transfer/init", {"fileName": "bad.txt", "fileSize": len(data), "expectedSha256": "0" * 64, "senderPlatform": "android"}, self.token)
        self.h.decide(init["transferId"], True)
        status, reply = self.h.post("/v1/transfer/chunk", {"transferId": init["transferId"], "chunkOffset": 0, "chunkBase64": base64.b64encode(data).decode()}, self.token)
        self.assertEqual(status, 403)
        self.assertEqual(list(self.h.downloads.iterdir()), [])

    def test_other_endpoints_still_have_the_small_body_limit(self):
        status, reply = self.h.post("/v1/command", {"operation": "setVolume", "params": {"value": 5}, "pad": "x" * 20000}, self.token)
        self.assertEqual((status, reply["reason"]), (403, "request-size"))

    def test_sustained_chunk_upload_is_not_rate_limited_at_100_requests(self):
        data = b"a" * 64
        sha = hashlib.sha256(data * 150).hexdigest()
        _, init = self.h.post("/v1/transfer/init", {"fileName": "r.bin", "fileSize": 64 * 150, "expectedSha256": sha, "senderPlatform": "android"}, self.token)
        self.h.decide(init["transferId"], True)
        for index in range(150):
            status, reply = self.h.post("/v1/transfer/chunk", {"transferId": init["transferId"], "chunkOffset": index * 64, "chunkBase64": base64.b64encode(data).decode()}, self.token)
            self.assertEqual(status, 200, (index, reply))
        self.assertEqual(reply["state"], "complete")


class HttpOutboxTests(unittest.TestCase):
    def setUp(self):
        self.h = Harness()
        self.token = self.h.pair()
        self.source = self.h.root / "to-phone.bin"
        self.payload = os.urandom(600_000)
        self.source.write_bytes(self.payload)
        self.outbox_id = "ab" * 16
        (self.h.root / "outbox" / f"{self.outbox_id}.json").write_text(json.dumps(
            {"schema": "KL06_OUTBOX_V1", "id": self.outbox_id, "path": str(self.source), "createdAt": time.time(), "expiresAt": time.time() + 600}))

    def tearDown(self):
        self.h.close()

    def wait_ready(self):
        for _ in range(100):
            _, reply = self.h.post("/v1/outbox/list", {}, self.token)
            if reply["items"] and reply["items"][0]["state"] == "ready":
                return reply["items"][0]
            time.sleep(0.05)
        self.fail("outbox item never became ready")

    def test_phone_can_download_the_laptop_file_with_matching_hash(self):
        item = self.wait_ready()
        self.assertEqual((item["fileName"], item["fileSize"], item["sha256"]), ("to-phone.bin", len(self.payload), hashlib.sha256(self.payload).hexdigest()))
        received, offset = b"", 0
        while True:
            status, reply = self.h.post("/v1/outbox/chunk", {"id": self.outbox_id, "offset": offset, "length": 262144}, self.token)
            self.assertEqual(status, 200, reply)
            piece = base64.b64decode(reply["chunkBase64"])
            received += piece
            offset += len(piece)
            if reply["done"]:
                break
        self.assertEqual(received, self.payload)
        status, reply = self.h.post("/v1/outbox/ack", {"id": self.outbox_id, "status": "received"}, self.token)
        self.assertEqual((status, reply["status"]), (200, "received"))
        _, listing = self.h.post("/v1/outbox/list", {}, self.token)
        self.assertEqual(listing["items"], [])
        peers = json.loads((self.h.root / "peers.json").read_text())
        self.assertEqual(peers["peers"][0]["platform"], "android")
        self.assertNotIn("token", json.dumps(peers))

    def test_unpaired_client_cannot_list_or_read(self):
        self.wait_ready()
        status, _ = self.h.post("/v1/outbox/list", {})
        self.assertEqual(status, 403)
        status, _ = self.h.post("/v1/outbox/chunk", {"id": self.outbox_id, "offset": 0, "length": 10})
        self.assertEqual(status, 403)

    def test_symlink_and_missing_files_are_refused(self):
        link = self.h.root / "link.bin"
        link.symlink_to(self.source)
        other = "cd" * 16
        (self.h.root / "outbox" / f"{other}.json").write_text(json.dumps(
            {"schema": "KL06_OUTBOX_V1", "id": other, "path": str(link), "createdAt": time.time(), "expiresAt": time.time() + 600}))
        missing = "ef" * 16
        (self.h.root / "outbox" / f"{missing}.json").write_text(json.dumps(
            {"schema": "KL06_OUTBOX_V1", "id": missing, "path": str(self.h.root / "nope.bin"), "createdAt": time.time(), "expiresAt": time.time() + 600}))
        item = self.wait_ready()
        _, reply = self.h.post("/v1/outbox/list", {}, self.token)
        self.assertEqual([i["id"] for i in reply["items"]], [self.outbox_id])

    def test_file_changed_after_hashing_is_refused(self):
        self.wait_ready()
        self.source.write_bytes(self.payload + b"tampered")
        status, reply = self.h.post("/v1/outbox/chunk", {"id": self.outbox_id, "offset": 0, "length": 1000}, self.token)
        self.assertEqual((status, reply["reason"]), (403, "outbox-file-changed"))

    def test_oversized_chunk_request_is_refused(self):
        self.wait_ready()
        status, reply = self.h.post("/v1/outbox/chunk", {"id": self.outbox_id, "offset": 0, "length": 5_000_000}, self.token)
        self.assertEqual((status, reply["reason"]), (403, "outbox-chunk-range"))


if __name__ == "__main__":
    unittest.main()
