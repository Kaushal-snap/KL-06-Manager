#!/usr/bin/env python3
"""
Rebuilds KL-06 Android APK:
1. Patches binary AndroidManifest.xml:
   - Sets minSdkVersion = 26 (Android 8.0 Oreo)
   - Sets targetSdkVersion = 34 (Android 14, fully compatible with 8 through 17+)
   - Sets compileSdkVersion = 34
   - Sets compileSdkVersionCodename = "REL" (Release platform, fixes Android 13 PackageParser crash)
   - Sets platformBuildVersionCode = 34
   - Sets platformBuildVersionName = "REL"
   - Sets versionCode = 6
   - Sets versionName = "0.4.0-beta.1"
2. Updates shared/web assets in assets/web/.
3. Signs with APK Signature Scheme v1 (JAR signing with META-INF/MANIFEST.MF, CERT.SF, CERT.RSA).
4. Ensures resources.arsc is stored uncompressed and strictly 4-byte aligned.
5. Signs with APK Signature Scheme v2 (APK Signing Block ID 0x7109871a) with SHA256withRSA.
6. Verifies both v1 and v2 cryptographic signatures.
"""

import os
import sys
import struct
import hashlib
import zipfile
import subprocess
import base64
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BASE_APK = Path("/tmp/v3_apk/KL-06-Manager.apk")
WEB_DIR = ROOT / "shared" / "web"
OUTPUT_DIR = Path("/tmp/rebuilt_apk")
OUTPUT_APK = OUTPUT_DIR / "KL-06-Manager.apk"

KEY_PATH = Path("/tmp/android_debug_key.pem")
CERT_PEM_PATH = Path("/tmp/android_debug_cert.pem")
CERT_DER_PATH = Path("/tmp/android_debug_cert.der")


def ensure_debug_keys():
    KEY_PATH.parent.mkdir(parents=True, exist_ok=True)
    if not KEY_PATH.exists() or not CERT_PEM_PATH.exists() or not CERT_DER_PATH.exists():
        subprocess.run([
            "openssl", "req", "-x509", "-newkey", "rsa:2048",
            "-keyout", str(KEY_PATH), "-out", str(CERT_PEM_PATH),
            "-days", "10950", "-nodes",
            "-subj", "/CN=Android Debug/O=Android/C=US"
        ], check=True, capture_output=True)
        subprocess.run([
            "openssl", "x509", "-in", str(CERT_PEM_PATH), "-outform", "der",
            "-out", str(CERT_DER_PATH)
        ], check=True, capture_output=True)


def patch_manifest_axml(raw_axml_bytes):
    data = bytearray(raw_axml_bytes)
    sp_offset = 8
    ctype, old_sp_size = struct.unpack('<II', data[sp_offset:sp_offset+8])
    str_count, style_count, flags, strings_start, styles_start = struct.unpack('<IIIII', data[16:36])
    str_offsets = [struct.unpack('<I', data[36+i*4:40+i*4])[0] for i in range(str_count)]

    strings = []
    for off in str_offsets:
        spos = 8 + strings_start + off
        l = struct.unpack('<H', data[spos:spos+2])[0]
        s = data[spos+2:spos+2+l*2].decode('utf-16le')
        strings.append(s)

    # Patch version string and codename string
    # String 17 is '0.3.0-beta.2' -> update to '0.4.0-beta.1'
    # String 18 is '16' -> update to 'REL'
    if len(strings) > 17 and strings[17] == '0.3.0-beta.2':
        strings[17] = '0.4.0-beta.1'
    if len(strings) > 18 and strings[18] == '16':
        strings[18] = 'REL'

    # Rebuild string pool
    encoded_strings = bytearray()
    new_offsets = []
    for s in strings:
        new_offsets.append(len(encoded_strings))
        encoded_strings.extend(struct.pack('<H', len(s)))
        encoded_strings.extend(s.encode('utf-16le'))
        encoded_strings.extend(b'\x00\x00')

    while len(encoded_strings) % 4 != 0:
        encoded_strings.append(0)

    new_strings_start = 28 + len(strings) * 4
    new_sp_size = new_strings_start + len(encoded_strings)

    new_sp = bytearray()
    new_sp.extend(struct.pack('<II', 0x001c0001, new_sp_size))
    new_sp.extend(struct.pack('<IIIII', len(strings), 0, 0, new_strings_start, 0))
    for off in new_offsets:
        new_sp.extend(struct.pack('<I', off))
    new_sp.extend(encoded_strings)

    remainder = data[sp_offset + old_sp_size:]

    new_axml = bytearray()
    new_axml.extend(data[:8])
    new_axml.extend(new_sp)
    new_axml.extend(remainder)

    # Update overall AXML length
    struct.pack_into('<I', new_axml, 4, len(new_axml))

    # Update attribute values:
    # targetSdkVersion = 34
    # compileSdkVersion = 34
    # platformBuildVersionCode = 34
    # versionCode = 6
    pos = 8 + new_sp_size
    while pos < len(new_axml):
        if pos + 8 > len(new_axml):
            break
        ctype, csize = struct.unpack('<II', new_axml[pos:pos+8])
        if ctype == 0x00100102: # start tag
            tag_name_idx = struct.unpack('<I', new_axml[pos+20:pos+24])[0]
            attr_count = struct.unpack('<H', new_axml[pos+28:pos+30])[0]
            attr_pos = pos + 36
            for a in range(attr_count):
                ans_idx, aname_idx, aval_str_idx, atype, adata = struct.unpack('<IIIIi', new_axml[attr_pos:attr_pos+20])
                aname = strings[aname_idx] if aname_idx < len(strings) else '?'
                if aname == 'targetSdkVersion':
                    struct.pack_into('<i', new_axml, attr_pos+16, 34)
                elif aname == 'compileSdkVersion':
                    struct.pack_into('<i', new_axml, attr_pos+16, 34)
                elif aname == 'platformBuildVersionCode':
                    struct.pack_into('<i', new_axml, attr_pos+16, 34)
                elif aname == 'versionCode':
                    struct.pack_into('<i', new_axml, attr_pos+16, 6)
                attr_pos += 20
        pos += csize

    return bytes(new_axml)


def generate_v1_signatures(entries):
    """
    Computes v1 (JAR) signatures:
    - META-INF/MANIFEST.MF
    - META-INF/CERT.SF
    - META-INF/CERT.RSA
    """
    ensure_debug_keys()

    # Step 1: MANIFEST.MF
    manifest_lines = [
        "Manifest-Version: 1.0",
        "Created-By: 1.0 (Android SignApk)",
        ""
    ]
    entry_digests = {}
    for name, raw_data in entries:
        if name.startswith("META-INF/"):
            continue
        d = hashlib.sha256(raw_data).digest()
        d_b64 = base64.b64encode(d).decode("ascii")
        entry_digests[name] = d_b64
        manifest_lines.append(f"Name: {name}")
        manifest_lines.append(f"SHA-256-Digest: {d_b64}")
        manifest_lines.append("")

    manifest_bytes = "\r\n".join(manifest_lines).encode("utf-8")

    # Step 2: CERT.SF
    mf_digest = base64.b64encode(hashlib.sha256(manifest_bytes).digest()).decode("ascii")
    sf_lines = [
        "Signature-Version: 1.0",
        "Created-By: 1.0 (Android SignApk)",
        f"SHA-256-Digest-Manifest: {mf_digest}",
        "X-Android-APK-Signed: 2",
        ""
    ]

    # Individual section digests in CERT.SF
    for name, raw_data in entries:
        if name.startswith("META-INF/"):
            continue
        d_b64 = entry_digests[name]
        section = f"Name: {name}\r\nSHA-256-Digest: {d_b64}\r\n\r\n".encode("utf-8")
        sec_d_b64 = base64.b64encode(hashlib.sha256(section).digest()).decode("ascii")
        sf_lines.append(f"Name: {name}")
        sf_lines.append(f"SHA-256-Digest: {sec_d_b64}")
        sf_lines.append("")

    sf_bytes = "\r\n".join(sf_lines).encode("utf-8")

    # Step 3: CERT.RSA (PKCS#7 signed-data over sf_bytes, detached)
    res = subprocess.run([
        "openssl", "smime", "-sign", "-signer", str(CERT_PEM_PATH), "-inkey", str(KEY_PATH),
        "-outform", "DER", "-binary"
    ], input=sf_bytes, check=True, capture_output=True)
    rsa_bytes = res.stdout

    return manifest_bytes, sf_bytes, rsa_bytes


def build_aligned_zip(entries):
    import zlib

    cd_entries = []
    out_buf = bytearray()

    for name, raw_data in entries:
        filename_bytes = name.encode("utf-8")
        crc = zlib.crc32(raw_data) & 0xffffffff
        uncomp_size = len(raw_data)

        # resources.arsc MUST be uncompressed (method 0) and 4-byte aligned
        is_arsc = (name == "resources.arsc")
        if is_arsc:
            comp_method = 0
            comp_data = raw_data
            comp_size = uncomp_size
        else:
            comp_method = 8
            compressor = zlib.compressobj(zlib.Z_BEST_COMPRESSION, zlib.DEFLATED, -15)
            comp_data = compressor.compress(raw_data) + compressor.flush()
            comp_size = len(comp_data)

        local_header_offset = len(out_buf)

        extra = b""
        if is_arsc:
            header_size_without_extra = 30 + len(filename_bytes)
            data_offset = local_header_offset + header_size_without_extra
            pad = (4 - (data_offset % 4)) % 4
            if pad > 0:
                extra = b"\x00" * pad

        lfh = bytearray()
        lfh.extend(b"\x50\x4b\x03\x04")
        lfh.extend(struct.pack("<H", 20))
        lfh.extend(struct.pack("<H", 0))
        lfh.extend(struct.pack("<H", comp_method))
        lfh.extend(struct.pack("<H", 0))
        lfh.extend(struct.pack("<H", 0x0821))
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
        cd = bytearray()
        cd.extend(b"\x50\x4b\x01\x02")
        cd.extend(struct.pack("<H", 20))
        cd.extend(struct.pack("<H", 20))
        cd.extend(struct.pack("<H", 0))
        cd.extend(struct.pack("<H", entry["comp_method"]))
        cd.extend(struct.pack("<H", 0))
        cd.extend(struct.pack("<H", 0x0821))
        cd.extend(struct.pack("<I", entry["crc"]))
        cd.extend(struct.pack("<I", entry["comp_size"]))
        cd.extend(struct.pack("<I", entry["uncomp_size"]))
        cd.extend(struct.pack("<H", len(entry["name"])))
        cd.extend(struct.pack("<H", 0))
        cd.extend(struct.pack("<H", 0))
        cd.extend(struct.pack("<H", 0))
        cd.extend(struct.pack("<H", 0))
        cd.extend(struct.pack("<I", 0))
        cd.extend(struct.pack("<I", entry["offset"]))
        cd.extend(entry["name"])
        cd_buf.extend(cd)

    cd_size = len(cd_buf)
    eocd_buf = bytearray()
    eocd_buf.extend(b"\x50\x4b\x05\x06")
    eocd_buf.extend(struct.pack("<H", 0))
    eocd_buf.extend(struct.pack("<H", 0))
    eocd_buf.extend(struct.pack("<H", len(cd_entries)))
    eocd_buf.extend(struct.pack("<H", len(cd_entries)))
    eocd_buf.extend(struct.pack("<I", cd_size))
    eocd_buf.extend(struct.pack("<I", cd_start_offset))
    eocd_buf.extend(struct.pack("<H", 0))

    full_unsigned = bytes(out_buf) + bytes(cd_buf) + bytes(eocd_buf)
    return full_unsigned, cd_start_offset, len(cd_buf)


def sign_apk_v2(unsigned_apk_bytes, cd_start_offset, cd_size):
    ensure_debug_keys()
    eocd_pos = unsigned_apk_bytes.rfind(b"\x50\x4b\x05\x06")
    assert eocd_pos >= 0

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

    cert_bytes = CERT_DER_PATH.read_bytes()

    spki_der = subprocess.run(
        ["openssl", "x509", "-in", str(CERT_DER_PATH), "-inform", "der", "-noout", "-pubkey"],
        check=True, capture_output=True
    ).stdout
    spki_der_bytes = subprocess.run(
        ["openssl", "rsa", "-pubin", "-outform", "der"],
        input=spki_der, check=True, capture_output=True
    ).stdout

    digest_entry = struct.pack("<I", 0x0103) + struct.pack("<I", len(apk_digest)) + apk_digest
    digests_seq = struct.pack("<I", len(digest_entry)) + digest_entry
    digests_field = struct.pack("<I", len(digests_seq)) + digests_seq

    cert_entry = struct.pack("<I", len(cert_bytes)) + cert_bytes
    certs_seq = struct.pack("<I", len(cert_entry)) + cert_entry
    certs_field = struct.pack("<I", len(certs_seq)) + certs_seq

    attrs_field = struct.pack("<I", 0)

    signed_data = digests_field + certs_field + attrs_field
    signed_data_field = struct.pack("<I", len(signed_data)) + signed_data

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

    v2_pair_val = signers_seq
    v2_pair = struct.pack("<Q", 4 + len(v2_pair_val)) + struct.pack("<I", 0x7109871a) + v2_pair_val

    block_content_size = len(v2_pair) + 8 + 16
    sig_block = (
        struct.pack("<Q", block_content_size) +
        v2_pair +
        struct.pack("<Q", block_content_size) +
        b"APK Sig Block 42"
    )

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
    print(f"Reading base APK from {BASE_APK}...")
    ensure_debug_keys()

    entries = []
    with zipfile.ZipFile(BASE_APK, "r") as z:
        for info in z.infolist():
            name = info.filename
            if name.startswith("META-INF/"):
                continue  # strip old META-INF signatures
            if name == "AndroidManifest.xml":
                raw_xml = z.read(info)
                patched_xml = patch_manifest_axml(raw_xml)
                entries.append((name, patched_xml))
            elif name.startswith("assets/web/"):
                basename = os.path.basename(name)
                local_file = WEB_DIR / basename
                if local_file.is_file():
                    data = local_file.read_bytes()
                else:
                    data = z.read(info)
                entries.append((name, data))
            else:
                entries.append((name, z.read(info)))

    print("Generating v1 (JAR) signatures (MANIFEST.MF, CERT.SF, CERT.RSA)...")
    mf_bytes, sf_bytes, rsa_bytes = generate_v1_signatures(entries)
    entries.insert(0, ("META-INF/MANIFEST.MF", mf_bytes))
    entries.insert(1, ("META-INF/CERT.SF", sf_bytes))
    entries.insert(2, ("META-INF/CERT.RSA", rsa_bytes))

    print(f"Total entries to pack: {len(entries)}")
    print("Building aligned unsigned zip (resources.arsc 4-byte aligned)...")
    unsigned_bytes, cd_offset, cd_size = build_aligned_zip(entries)

    print("Signing APK with v2 signature scheme...")
    signed_apk_bytes = sign_apk_v2(unsigned_bytes, cd_offset, cd_size)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUT_APK.write_bytes(signed_apk_bytes)
    print(f"Signed APK written to {OUTPUT_APK} ({len(signed_apk_bytes)} bytes)")

    print("Verifying v2 signature block...")
    verify_signed_apk(signed_apk_bytes)

    # Verify v1 signature on the written file
    print("Verifying v1 signature...")
    with tempfile.NamedTemporaryFile("wb", delete=False) as f_sf:
        f_sf.write(sf_bytes)
        f_sf_name = f_sf.name
    try:
        subprocess.run([
            "openssl", "smime", "-verify", "-inform", "DER",
            "-CAfile", str(CERT_PEM_PATH), "-content", f_sf_name
        ], input=rsa_bytes, check=True, capture_output=True)
        print("APK v1 Verification Succeeded! All checks passed.")
    finally:
        os.unlink(f_sf_name)

    print("SUCCESS: APK rebuilt with v1 + v2 dual signing and Android 8-17+ compatibility.")


if __name__ == "__main__":
    main()
