#!/usr/bin/env python3
"""
Rebuilds KL-06 Android APK by updating web assets, ensuring resources.arsc is 4-byte aligned and uncompressed,
and signing with the Android APK Signature Scheme v2 (0x7109871a) using an RSA debug key.
"""

import os
import sys
import struct
import hashlib
import zipfile
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BASE_APK = Path("/tmp/orig_apk/KL-06-Manager.apk")
WEB_DIR = ROOT / "shared" / "web"
OUTPUT_APK = Path("/tmp/rebuilt_apk/KL-06-Manager.apk")
KEY_PATH = Path("/tmp/android_debug_key.pem")
CERT_PATH = Path("/tmp/android_debug_cert.der")


def ensure_debug_keys():
    if not KEY_PATH.exists() or not CERT_PATH.exists():
        crt_pem = Path("/tmp/android_debug_cert.pem")
        subprocess.run([
            "openssl", "req", "-x509", "-newkey", "rsa:2048",
            "-keyout", str(KEY_PATH), "-out", str(crt_pem),
            "-days", "10000", "-nodes",
            "-subj", "/CN=Android Debug/O=Android/C=US"
        ], check=True, capture_output=True)
        # convert cert to DER
        subprocess.run([
            "openssl", "x509", "-in", str(crt_pem), "-outform", "der",
            "-out", str(CERT_PATH)
        ], check=True, capture_output=True)


def build_aligned_unsigned_zip(base_apk_path, out_zip_path):
    out_zip_path.parent.mkdir(parents=True, exist_ok=True)
    if out_zip_path.exists():
        out_zip_path.unlink()

    # Read base apk entries
    entries = []
    with zipfile.ZipFile(base_apk_path, "r") as z:
        for info in z.infolist():
            name = info.filename
            if name.startswith("assets/web/"):
                basename = os.path.basename(name)
                local_file = WEB_DIR / basename
                if local_file.is_file():
                    data = local_file.read_bytes()
                else:
                    data = z.read(info)
            else:
                data = z.read(info)
            entries.append((name, data))

    # We manually construct the zip to have strict byte alignment for uncompressed resources.arsc
    # Local file header format:
    # 4B sig (0x04034b50)
    # 2B version needed (20)
    # 2B bit flag (0)
    # 2B comp method (0 for store, 8 for deflate)
    # 2B mod time (0)
    # 2B mod date (0)
    # 4B crc32
    # 4B comp size
    # 4B uncomp size
    # 2B filename len
    # 2B extra len
    # filename
    # extra
    # data

    import zlib
    
    cd_entries = []
    out_buf = bytearray()

    for name, raw_data in entries:
        filename_bytes = name.encode("utf-8")
        crc = zlib.crc32(raw_data) & 0xffffffff
        uncomp_size = len(raw_data)

        # resources.arsc MUST be uncompressed (method 0) and 4-byte aligned
        # Also 9-patch or certain assets might benefit from store, but resources.arsc is mandatory
        is_arsc = (name == "resources.arsc")
        if is_arsc:
            comp_method = 0
            comp_data = raw_data
            comp_size = uncomp_size
        else:
            comp_method = 8
            # zlib deflate without header/trailer
            compressor = zlib.compressobj(zlib.Z_BEST_COMPRESSION, zlib.DEFLATED, -15)
            comp_data = compressor.compress(raw_data) + compressor.flush()
            comp_size = len(comp_data)

        local_header_offset = len(out_buf)

        extra = b""
        if is_arsc:
            # Data starts at: local_header_offset + 30 + len(filename_bytes) + len(extra)
            header_size_without_extra = 30 + len(filename_bytes)
            data_offset = local_header_offset + header_size_without_extra
            pad = (4 - (data_offset % 4)) % 4
            if pad > 0:
                extra = b"\x00" * pad

        lfh = bytearray()
        lfh.extend(b"\x50\x4b\x03\x04") # sig
        lfh.extend(struct.pack("<H", 20)) # version needed
        lfh.extend(struct.pack("<H", 0))  # flags
        lfh.extend(struct.pack("<H", comp_method))
        lfh.extend(struct.pack("<H", 0))  # mod time
        lfh.extend(struct.pack("<H", 0x0821)) # mod date (1984-01-01)
        lfh.extend(struct.pack("<I", crc))
        lfh.extend(struct.pack("<I", comp_size))
        lfh.extend(struct.pack("<I", uncomp_size))
        lfh.extend(struct.pack("<H", len(filename_bytes)))
        lfh.extend(struct.pack("<H", len(extra)))
        lfh.extend(filename_bytes)
        lfh.extend(extra)

        out_buf.extend(lfh)
        data_pos = len(out_buf)
        if is_arsc:
            assert data_pos % 4 == 0, f"resources.arsc data pos {data_pos} not 4-byte aligned!"
        out_buf.extend(comp_data)

        cd_entries.append({
            "name": filename_bytes,
            "comp_method": comp_method,
            "crc": crc,
            "comp_size": comp_size,
            "uncomp_size": uncomp_size,
            "offset": local_header_offset,
            "extra": extra,
        })

    cd_start_offset = len(out_buf)
    cd_buf = bytearray()
    for entry in cd_entries:
        # Central directory file header
        cd = bytearray()
        cd.extend(b"\x50\x4b\x01\x02") # sig
        cd.extend(struct.pack("<H", 20)) # version made by
        cd.extend(struct.pack("<H", 20)) # version needed
        cd.extend(struct.pack("<H", 0))  # flags
        cd.extend(struct.pack("<H", entry["comp_method"]))
        cd.extend(struct.pack("<H", 0))  # mod time
        cd.extend(struct.pack("<H", 0x0821)) # mod date
        cd.extend(struct.pack("<I", entry["crc"]))
        cd.extend(struct.pack("<I", entry["comp_size"]))
        cd.extend(struct.pack("<I", entry["uncomp_size"]))
        cd.extend(struct.pack("<H", len(entry["name"])))
        cd.extend(struct.pack("<H", 0))  # extra len in CD
        cd.extend(struct.pack("<H", 0))  # file comment len
        cd.extend(struct.pack("<H", 0))  # disk number start
        cd.extend(struct.pack("<H", 0))  # internal file attrs
        cd.extend(struct.pack("<I", 0))  # external file attrs
        cd.extend(struct.pack("<I", entry["offset"])) # relative offset of local header
        cd.extend(entry["name"])
        cd_buf.extend(cd)

    cd_size = len(cd_buf)
    eocd_buf = bytearray()
    eocd_buf.extend(b"\x50\x4b\x05\x06") # EOCD sig
    eocd_buf.extend(struct.pack("<H", 0)) # disk number
    eocd_buf.extend(struct.pack("<H", 0)) # start disk
    eocd_buf.extend(struct.pack("<H", len(cd_entries))) # records on this disk
    eocd_buf.extend(struct.pack("<H", len(cd_entries))) # total records
    eocd_buf.extend(struct.pack("<I", cd_size)) # CD size
    eocd_buf.extend(struct.pack("<I", cd_start_offset)) # CD offset
    eocd_buf.extend(struct.pack("<H", 0)) # comment length

    full_unsigned = bytes(out_buf) + bytes(cd_buf) + bytes(eocd_buf)
    return full_unsigned, cd_start_offset, len(cd_buf)


def sign_apk_v2(unsigned_apk_bytes, cd_start_offset, cd_size):
    ensure_debug_keys()
    eocd_pos = unsigned_apk_bytes.rfind(b"\x50\x4b\x05\x06")
    assert eocd_pos >= 0

    # 3 sections for 1MB chunked digest:
    # 1. 0 to cd_start_offset
    # 2. cd_start_offset to eocd_pos
    # 3. EOCD with cd_start_offset unchanged (will be updated after inserting sig block)
    sec1 = unsigned_apk_bytes[:cd_start_offset]
    sec2 = unsigned_apk_bytes[cd_start_offset:eocd_pos]
    sec3 = unsigned_apk_bytes[eocd_pos:]

    # Compute chunked SHA-256
    chunks = []
    for sec in [sec1, sec2, sec3]:
        offset = 0
        while offset < len(sec):
            c = sec[offset:offset + 1048576]
            chunks.append(c)
            offset += len(c)

    chunk_digests = []
    for chunk in chunks:
        h = hashlib.sha256()
        h.update(b"\xa5")
        h.update(struct.pack("<I", len(chunk)))
        h.update(chunk)
        chunk_digests.append(h.digest())

    top_h = hashlib.sha256()
    top_h.update(b"\x5a")
    top_h.update(struct.pack("<I", len(chunks)))
    for cd in chunk_digests:
        top_h.update(cd)
    apk_digest = top_h.digest()

    cert_bytes = CERT_PATH.read_bytes()

    # Extract SubjectPublicKeyInfo DER from cert
    spki_der = subprocess.run(
        ["openssl", "x509", "-in", str(CERT_PATH), "-inform", "der", "-noout", "-pubkey"],
        check=True, capture_output=True
    ).stdout
    spki_der_bytes = subprocess.run(
        ["openssl", "rsa", "-pubin", "-outform", "der"],
        input=spki_der, check=True, capture_output=True
    ).stdout

    # Build signed_data:
    # digests: sequence of (alg_id, digest)
    # alg_id = 0x0103 (SIGNATURE_RSA_PKCS1_V1_5_WITH_SHA256)
    digest_entry = struct.pack("<I", 0x0103) + struct.pack("<I", len(apk_digest)) + apk_digest
    digests_seq = struct.pack("<I", len(digest_entry)) + digest_entry
    digests_field = struct.pack("<I", len(digests_seq)) + digests_seq

    cert_entry = struct.pack("<I", len(cert_bytes)) + cert_bytes
    certs_seq = struct.pack("<I", len(cert_entry)) + cert_entry
    certs_field = struct.pack("<I", len(certs_seq)) + certs_seq

    # attrs: empty sequence
    attrs_field = struct.pack("<I", 0)

    signed_data = digests_field + certs_field + attrs_field
    signed_data_field = struct.pack("<I", len(signed_data)) + signed_data

    # Sign signed_data with RSA private key (SHA256 PKCS1 v1.5)
    sig_proc = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", str(KEY_PATH)],
        input=signed_data, check=True, capture_output=True
    )
    sig_bytes = sig_proc.stdout

    sig_entry = struct.pack("<I", 0x0103) + struct.pack("<I", len(sig_bytes)) + sig_bytes
    sigs_seq = struct.pack("<I", len(sig_entry)) + sig_entry
    sigs_field = struct.pack("<I", len(sigs_seq)) + sigs_seq

    pk_field = struct.pack("<I", len(spki_der_bytes)) + spki_der_bytes

    signer = signed_data_field + sigs_field + pk_field
    signer_field = struct.pack("<I", len(signer)) + signer

    signers_seq = struct.pack("<I", len(signer_field)) + signer_field

    # APK v2 block ID = 0x7109871a
    # ID-value pair
    v2_pair_val = signers_seq
    v2_pair = struct.pack("<Q", 4 + len(v2_pair_val)) + struct.pack("<I", 0x7109871a) + v2_pair_val

    # APK Signing Block format:
    # size_of_block (uint64)
    # ID-value pairs...
    # size_of_block (uint64)
    # magic: 16 bytes "APK Sig Block 42"
    block_content_size = len(v2_pair) + 8 + 16 # pairs + size + magic
    sig_block = (
        struct.pack("<Q", block_content_size) +
        v2_pair +
        struct.pack("<Q", block_content_size) +
        b"APK Sig Block 42"
    )

    # Insert sig_block between sec1 and sec2, and update EOCD cd_offset
    new_cd_offset = len(sec1) + len(sig_block)
    new_eocd = (
        unsigned_apk_bytes[eocd_pos:eocd_pos+16] +
        struct.pack("<I", new_cd_offset) +
        unsigned_apk_bytes[eocd_pos+20:]
    )

    signed_apk = sec1 + sig_block + sec2 + new_eocd
    return signed_apk


def verify_signed_apk(apk_bytes):
    data = apk_bytes
    eocd_pos = data.rfind(b"\x50\x4b\x05\x06")
    cd_offset = struct.unpack("<I", data[eocd_pos+16:eocd_pos+20])[0]
    block_size = struct.unpack("<Q", data[cd_offset-24:cd_offset-16])[0]
    block_start = cd_offset - 8 - block_size
    magic = data[cd_offset-16:cd_offset]
    assert magic == b"APK Sig Block 42", "Magic mismatch"

    sec1 = data[:block_start]
    sec2 = data[cd_offset:eocd_pos]
    eocd_mod = data[eocd_pos:eocd_pos+16] + struct.pack("<I", block_start) + data[eocd_pos+20:]

    chunks = []
    for sec in [sec1, sec2, eocd_mod]:
        offset = 0
        while offset < len(sec):
            c = sec[offset:offset+1048576]
            chunks.append(c)
            offset += len(c)

    chunk_digests = []
    for chunk in chunks:
        h = hashlib.sha256()
        h.update(b"\xa5")
        h.update(struct.pack("<I", len(chunk)))
        h.update(chunk)
        chunk_digests.append(h.digest())

    top_h = hashlib.sha256()
    top_h.update(b"\x5a")
    top_h.update(struct.pack("<I", len(chunks)))
    for cd in chunk_digests:
        top_h.update(cd)
    expected_digest = top_h.digest()

    val = data[block_start+20:block_start+8+8+struct.unpack("<Q", data[block_start+8:block_start+16])[0]]
    signer = val[8:8+struct.unpack("<I", val[4:8])[0]]
    sd_len = struct.unpack("<I", signer[:4])[0]
    sd = signer[4:4+sd_len]

    digests_seq = sd[4:4+struct.unpack("<I", sd[:4])[0]]
    d_bytes = digests_seq[4:4+struct.unpack("<I", digests_seq[:4])[0]]
    actual_digest = d_bytes[8:8+32]

    assert expected_digest == actual_digest, "Digest mismatch"

    sigs_pos = 4 + sd_len
    sigs_len = struct.unpack("<I", signer[sigs_pos:sigs_pos+4])[0]
    sigs_seq = signer[sigs_pos+4:sigs_pos+4+sigs_len]
    s_len = struct.unpack("<I", sigs_seq[:4])[0]
    sig_bytes = sigs_seq[4+8:4+s_len]

    pk_pos = sigs_pos + 4 + sigs_len
    pk_len = struct.unpack("<I", signer[pk_pos:pk_pos+4])[0]
    pk_bytes = signer[pk_pos+4:pk_pos+4+pk_len]

    # Verify signature
    with tempfile.NamedTemporaryFile("wb", delete=False) as f_sd, \
         tempfile.NamedTemporaryFile("wb", delete=False) as f_sig, \
         tempfile.NamedTemporaryFile("wb", delete=False) as f_pk:
        f_sd.write(sd)
        f_sig.write(sig_bytes)
        f_pk.write(pk_bytes)
        f_sd_name = f_sd.name
        f_sig_name = f_sig.name
        f_pk_name = f_pk.name

    try:
        res = subprocess.run([
            "openssl", "dgst", "-sha256", "-verify", f_pk_name,
            "-keyform", "der", "-signature", f_sig_name, f_sd_name
        ], check=True, capture_output=True, text=True)
        assert "Verified OK" in res.stdout or "OK" in res.stdout
    finally:
        os.unlink(f_sd_name)
        os.unlink(f_sig_name)
        os.unlink(f_pk_name)

    print("APK v2 Verification Succeeded! All checks passed.")


def main():
    print("Building uncompressed aligned zip...")
    unsigned_bytes, cd_offset, cd_size = build_aligned_unsigned_zip(BASE_APK, OUTPUT_APK)
    print(f"Unsigned bytes: {len(unsigned_bytes)}, CD offset: {cd_offset}, CD size: {cd_size}")

    print("Signing APK with v2 signature scheme...")
    signed_apk_bytes = sign_apk_v2(unsigned_bytes, cd_offset, cd_size)

    OUTPUT_APK.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_APK.write_bytes(signed_apk_bytes)
    print(f"Signed APK written to {OUTPUT_APK} ({len(signed_apk_bytes)} bytes)")

    print("Verifying signed APK...")
    verify_signed_apk(signed_apk_bytes)
    print("DONE.")


if __name__ == "__main__":
    main()
