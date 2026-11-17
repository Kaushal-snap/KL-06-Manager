#!/usr/bin/env python3
"""Exact tested-artifact transfer: private Drive App -> PRIVATE GitHub prerelease.
Fail closed. Never execute/extract/rebuild the ZIP; no stored Drive key/token.
An offline owner SSH signature authenticates the checksum-bound test declaration.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import http.client
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import subprocess
import tempfile
import time
from urllib.parse import quote, urlencode, urlsplit
import zipfile

SCHEMA = "KL06_OWNER_TESTED_RELEASE_V1"
APPROVAL_NAME = "KL06-RELEASE-APPROVAL.json"
SIGNATURE_NAME = APPROVAL_NAME + ".sig"
MAX_ZIP = 256 * 1024 * 1024
MAX_UNCOMPRESSED = 1024 * 1024 * 1024
PLATFORMS = frozenset(("macos", "windows", "android", "ios"))
TESTS = ("nativeBuild", "launchedOnPhysicalDevice", "realTelemetryReviewed", "supportedControlsReadBack", "conflictSafeRestore", "privacyReviewed", "preservedBootAndData", "quitAndRemovalReviewed")
PHONE_TESTS = ("phoneLocalControls", "pinnedLaptopPairing", "laptopWriteConfirmation", "disconnectAndExpiry")
DESKTOP_TESTS = ("companionPairingAndRevocation", "staleTelemetryWithheld")
VERSION = re.compile(r"v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)-beta\.(0|[1-9][0-9]*)(?:\.[a-zA-Z0-9-]+)?")
HEX = re.compile(r"[a-f0-9]{64}")
DRIVE_ID = re.compile(r"[A-Za-z0-9_-]{10,200}")


class Refused(Exception):
    """Intentionally short, non-secret error suitable for CI logs."""


def require(condition, reason):
    if not condition:
        raise Refused(reason)


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, "Duplicate JSON key refused.")
        result[key] = value
    return result


def decode(raw):
    try:
        return json.loads(raw, object_pairs_hook=unique_object,
                          parse_constant=lambda _: (_ for _ in ()).throw(Refused("Nonfinite JSON refused.")))
    except (ValueError, UnicodeError, RecursionError) as error:
        raise Refused("Invalid bounded JSON.") from error


def canonical(value):
    return (json.dumps(value, sort_keys=True, indent=2, allow_nan=False, ensure_ascii=True) + "\n").encode()


def utc(value):
    require(isinstance(value, str) and re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z", value), "Use a UTC second-resolution timestamp.")
    try:
        return dt.datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=dt.timezone.utc).timestamp()
    except ValueError as error:
        raise Refused("Invalid UTC date.") from error


def validate_approval(value, *, now=None):
    now = time.time() if now is None else now
    keys = {"schema", "artifactKind", "repository", "version", "sourceCommit", "driveFileId", "fileName", "size", "sha256", "approvedAt", "expiresAt", "platformTests"}
    require(isinstance(value, dict) and set(value) == keys, "Approval schema mismatch.")
    require(value["schema"] == SCHEMA and value["artifactKind"] == "owner-tested-app-zip", "Source/unreviewed artifact is not an app release approval.")
    require(isinstance(value["repository"], str) and re.fullmatch(r"[A-Za-z0-9_.-]+/KL-06-Manager", value["repository"]), "Only the new KL-06-Manager app repository is allowed.")
    require(isinstance(value["version"], str) and VERSION.fullmatch(value["version"]), "Only an explicit beta prerelease tag is allowed.")
    require(isinstance(value["sourceCommit"], str) and re.fullmatch(r"[a-f0-9]{40}", value["sourceCommit"]), "An exact source commit is required.")
    require(isinstance(value["driveFileId"], str) and DRIVE_ID.fullmatch(value["driveFileId"]), "A concrete uploaded Drive file ID is required.")
    require(isinstance(value["fileName"], str) and re.fullmatch(r"KL-06-[A-Za-z0-9._-]{1,110}-tested\.zip", value["fileName"]), "Use a plain KL-06-…-tested.zip filename.")
    require(type(value["size"]) is int and 0 < value["size"] <= MAX_ZIP, "ZIP size outside transfer limit.")
    require(isinstance(value["sha256"], str) and HEX.fullmatch(value["sha256"]), "Exact lowercase ZIP SHA-256 required.")
    approved, expires = utc(value["approvedAt"]), utc(value["expiresAt"])
    require(0 < expires - approved <= 7 * 86400 and approved <= now + 120 and now < expires, "Approval is expired, future-dated or longer than seven days.")
    platform_tests = value["platformTests"]
    require(isinstance(platform_tests, dict) and 1 <= len(platform_tests) <= 4 and set(platform_tests) <= PLATFORMS, "Explicit actually-tested platform list required.")
    for platform, result in platform_tests.items():
        expected = set(TESTS) | set(PHONE_TESTS if platform in ("android", "ios") else DESKTOP_TESTS)
        if platform == "macos":
            expected |= {"f13RunningOnly", "workingGraphicsFnAudioUSBPreserved", "hdrRemainsOff"}
        require(isinstance(result, dict) and set(result) == expected | {"testedAt", "osMajor"}, "All platform-specific owner test fields are required.")
        require(all(result[key] is True for key in expected), "An incomplete/failed owner test blocks publication.")
        tested = utc(result["testedAt"])
        require(approved - 7 * 86400 <= tested <= approved + 120 and tested <= now + 120, "Owner test date must precede this recent approval.")
        require(type(result["osMajor"]) is int and result["osMajor"] > 0, "Numeric tested OS major required; no device identities.")
        if platform == "macos":
            require(13 <= result["osMajor"] <= 26, "macOS 27+ release is blocked; 13–26 still requires actual tests.")
    return value


def verify_signature(raw, signature, signers: Path):
    require(shutil.which("ssh-keygen") is not None, "Installed ssh-keygen with -Y verification is required.")
    require(signers.is_file() and not signers.is_symlink() and signers.stat().st_size <= 16384, "Owner public-key trust file is missing/unsafe; automation stays off.")
    lines = [line.strip() for line in signers.read_text(encoding="ascii").splitlines() if line.strip() and not line.lstrip().startswith("#")]
    require(len(lines) == 1 and re.fullmatch(r"kl06-owner ssh-ed25519 [A-Za-z0-9+/]+={0,2}(?: [\x20-\x7e]*)?", lines[0]), "Exactly one plain owner Ed25519 public key is required; no trust options/CA/wildcards.")
    require(0 < len(raw) <= 32768 and 0 < len(signature) <= 8192, "Approval/signature length refused.")
    with tempfile.TemporaryDirectory(prefix="kl06-signature-") as work:
        path = Path(work) / "approval.sig"
        path.write_bytes(signature)
        try:
            result = subprocess.run(["ssh-keygen", "-Y", "verify", "-f", str(signers), "-I", "kl06-owner", "-n", "kl06-drive-release", "-s", str(path)], input=raw, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=15, check=False)
        except (OSError, subprocess.TimeoutExpired) as error:
            raise Refused("Signature verification could not run.") from error
    require(result.returncode == 0, "Owner signature mismatch. Nothing will be released.")


def audit_zip(path: Path, platforms):
    """Structural/minimisation guard, NOT malware scanning, signing or a native test."""
    require(path.is_file() and not path.is_symlink() and 0 < path.stat().st_size <= MAX_ZIP, "Unsafe ZIP.")
    found = set()
    forbidden_parts = {"efi", "opencore", "uploads", "raw-reports", "reports", "__macosx", ".git", ".ssh", "node_modules", "credentials", "private-backups"}
    forbidden_names = {".ds_store", ".env", "id_rsa", "id_ed25519", "key.pem", "cert.pem", "session.json", "restore-v1.plist", "restore-v1.json", "upload-receipt.json", "detailed-development-brief.txt"}
    try:
        with zipfile.ZipFile(path) as archive:
            items, names, total = archive.infolist(), set(), 0
            require(0 < len(items) <= 15000, "ZIP member limit.")
            for item in items:
                name = item.filename
                parts = PurePosixPath(name).parts
                require(name and not name.startswith("/") and "\\" not in name and "\x00" not in name and ":" not in name and all(p not in ("", ".", "..") for p in name.rstrip("/").split("/")), "Unsafe ZIP path.")
                folded = name.casefold()
                require(folded not in names, "Duplicate/case-colliding ZIP paths refused.")
                names.add(folded)
                require(not (set(p.casefold() for p in parts) & forbidden_parts), "Private/EFI/dependency content in release ZIP.")
                require(parts[-1].casefold() not in forbidden_names and not folded.endswith((".p12", ".pfx", ".mobileprovision", ".key", ".csv", ".log")), "Credential/raw-history/log file in ZIP; review and repackage.")
                mode = item.external_attr >> 16
                require(not stat.S_ISLNK(mode) and (stat.S_IFMT(mode) in (0, stat.S_IFREG, stat.S_IFDIR)), "ZIP links/special files refused.")
                require(not item.flag_bits & 1 and item.compress_type in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED), "Encrypted/unsupported ZIP refused.")
                total += item.file_size
                require(item.file_size <= MAX_ZIP and total <= MAX_UNCOMPRESSED and (item.file_size <= 1048576 or item.file_size <= max(1, item.compress_size) * 200), "ZIP expansion limit.")
                if item.is_dir():
                    continue
                with archive.open(item) as stream:
                    first = stream.read(8)
                if ".app/contents/macos/" in folded and first[:4] in (b"\xcf\xfa\xed\xfe", b"\xce\xfa\xed\xfe", b"\xca\xfe\xba\xbe", b"\xbe\xba\xfe\xca"):
                    found.add("macos")
                if folded.endswith(".exe") and first.startswith(b"MZ"):
                    found.add("windows")
                if folded.endswith(".apk") and first.startswith(b"PK\x03\x04"):
                    found.add("android")
                if folded.endswith(".ipa") and first.startswith(b"PK\x03\x04"):
                    found.add("ios")
            # Read every member to EOF: validates CRC without extraction or execution.
            require(archive.testzip() is None, "ZIP CRC failure.")
    except (zipfile.BadZipFile, OSError, RuntimeError, NotImplementedError) as error:
        raise Refused("Unreadable/invalid ZIP.") from error
    require(set(platforms) == found, "Declared platforms do not match structurally recognizable app payloads. Source-only ZIPs are never released.")
    return {"members": len(items), "uncompressedBytes": total, "platforms": sorted(found), "scope": "structural-only-not-native-signing-or-malware-validation"}


class API:
    """No redirects and strict HTTPS host allowlist; never log responses or tokens."""
    def __init__(self, github_token, drive_token=""):
        self.github_token, self.drive_token = github_token, drive_token

    def _open(self, method, url, *, body=None, file=None):
        parsed = urlsplit(url)
        require(parsed.scheme == "https" and parsed.hostname in ("api.github.com", "uploads.github.com", "www.googleapis.com") and parsed.port in (None, 443) and not parsed.username and not parsed.password, "Unexpected API host.")
        token = self.drive_token if parsed.hostname == "www.googleapis.com" else self.github_token
        require(isinstance(token, str) and token and "\n" not in token and "\r" not in token, "Missing native CI authorization; never paste tokens into chat.")
        connection = http.client.HTTPSConnection(parsed.hostname, timeout=90)
        headers = {"Authorization": "Bearer " + token, "User-Agent": "KL06-Exact-Tested-Artifact", "Accept": "application/vnd.github+json" if parsed.hostname != "www.googleapis.com" else "application/json"}
        if parsed.hostname != "www.googleapis.com":
            headers["X-GitHub-Api-Version"] = "2022-11-28"
        payload = canonical(body) if body is not None else None
        if payload is not None:
            headers.update({"Content-Type": "application/json", "Content-Length": str(len(payload))})
        if file is not None:
            headers.update({"Content-Type": "application/octet-stream", "Content-Length": str(Path(file).stat().st_size)})
        try:
            path = parsed.path + ("?" + parsed.query if parsed.query else "")
            if file is None:
                connection.request(method, path, body=payload, headers=headers)
            else:
                connection.putrequest(method, path)
                for key, value in headers.items():
                    connection.putheader(key, value)
                connection.endheaders()
                with Path(file).open("rb") as stream:
                    while block := stream.read(1024 * 1024):
                        connection.send(block)
            response = connection.getresponse()
            return connection, response
        except Exception:
            connection.close()
            raise Refused("HTTPS API request failed; no retry/rebuild was performed.") from None

    def json(self, method, url, body=None, *, allow404=False, file=None):
        connection, response = self._open(method, url, body=body, file=file)
        try:
            if response.status == 404 and allow404:
                return None
            require(200 <= response.status < 300, f"API refused request (HTTP {response.status}); private details omitted.")
            raw = response.read(2 * 1024 * 1024 + 1)
            require(len(raw) <= 2 * 1024 * 1024, "API JSON size limit.")
            return decode(raw)
        finally:
            connection.close()

    def download(self, url, destination: Path, limit):
        connection, response = self._open("GET", url)
        try:
            require(response.status == 200, f"Drive download refused (HTTP {response.status}).")
            length = response.getheader("Content-Length")
            require(length is None or length.isdigit() and int(length) <= limit, "Download size limit.")
            total = 0
            with destination.open("xb") as output:
                while block := response.read(1024 * 1024):
                    total += len(block)
                    require(total <= limit, "Bounded download exceeded.")
                    output.write(block)
            return total
        finally:
            connection.close()


def repo_preflight(api, repository):
    require(isinstance(repository, str) and re.fullmatch(r"[A-Za-z0-9_.-]+/KL-06-Manager", repository), "Wrong repository name; unrelated repositories are protected.")
    repo = api.json("GET", f"https://api.github.com/repos/{repository}")
    require(isinstance(repo, dict) and repo.get("full_name", "").casefold() == repository.casefold() and repo.get("private") is True and repo.get("visibility") == "private" and repo.get("default_branch") == "main" and repo.get("archived") is False and repo.get("fork") is False, "Only a non-fork PRIVATE KL-06-Manager repository with default main is eligible.")
    return repo


def drive_meta(api, identifier):
    require(isinstance(identifier, str) and DRIVE_ID.fullmatch(identifier), "Invalid Drive file ID.")
    fields = "id,name,mimeType,size,md5Checksum,parents,trashed,version"
    value = api.json("GET", "https://www.googleapis.com/drive/v3/files/" + quote(identifier, safe="") + "?" + urlencode({"fields": fields, "supportsAllDrives": "true"}))
    require(isinstance(value, dict) and value.get("id") == identifier and value.get("trashed") is False and value.get("mimeType") != "application/vnd.google-apps.shortcut", "Unavailable/shortcut Drive item.")
    return value


def child(api, folder, name):
    query = f"'{folder}' in parents and trashed = false and name = '{name}'"
    listing = api.json("GET", "https://www.googleapis.com/drive/v3/files?" + urlencode({"q": query, "fields": "files(id),nextPageToken", "pageSize": 10, "supportsAllDrives": "true", "includeItemsFromAllDrives": "true"}))
    require(isinstance(listing, dict) and not listing.get("nextPageToken") and isinstance(listing.get("files"), list) and len(listing["files"]) == 1, "Exactly one approval and one signature must exist directly in the configured App folder.")
    return listing["files"][0]["id"]


def bounded_download(api, meta, folder, path, limit):
    require(meta.get("parents") == [folder] and isinstance(meta.get("size"), str) and meta["size"].isdigit() and 0 < int(meta["size"]) <= limit, "Drive item is not a bounded direct child of the configured App folder.")
    require(isinstance(meta.get("md5Checksum"), str) and re.fullmatch(r"[a-f0-9]{32}", meta["md5Checksum"]), "Drive checksum unavailable.")
    size = api.download("https://www.googleapis.com/drive/v3/files/" + quote(meta["id"], safe="") + "?alt=media&supportsAllDrives=true", path, limit)
    require(size == int(meta["size"]) and hashlib.md5(path.read_bytes(), usedforsecurity=False).hexdigest() == meta["md5Checksum"], "Drive transfer checksum/size mismatch.")
    return path


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        while block := stream.read(1024 * 1024):
            digest.update(block)
    return digest.hexdigest()


def tag_commit(api, repository, version):
    """Resolve a bounded lightweight/annotated tag, never trust target_commitish alone."""
    value = api.json("GET", f"https://api.github.com/repos/{repository}/git/ref/tags/" + quote(version, safe=""), allow404=True)
    if value is None:
        return None
    require(isinstance(value, dict) and value.get("ref") == "refs/tags/" + version, "Ambiguous beta tag reference.")
    obj = value.get("object")
    seen = set()
    for _ in range(5):
        require(isinstance(obj, dict) and isinstance(obj.get("sha"), str) and re.fullmatch(r"[a-f0-9]{40}", obj["sha"]), "Invalid beta tag object.")
        if obj.get("type") == "commit":
            return obj["sha"]
        require(obj.get("type") == "tag" and obj["sha"] not in seen, "Unsupported/cyclic beta tag target.")
        seen.add(obj["sha"])
        value = api.json("GET", f"https://api.github.com/repos/{repository}/git/tags/" + obj["sha"])
        obj = value.get("object") if isinstance(value, dict) else None
    raise Refused("Annotated beta tag chain exceeds the fixed limit.")


def release_assets(api, repository, approval, paths, dry_run, *, now=None):
    version, commit = approval["version"], approval["sourceCommit"]
    repo_preflight(api, repository)
    comparison = api.json("GET", f"https://api.github.com/repos/{repository}/compare/{commit}...main")
    require(comparison.get("status") in ("ahead", "identical"), "Tested source commit is not on main.")
    existing_commit = tag_commit(api, repository, version)
    require(existing_commit is None or existing_commit == commit, "Existing beta tag points elsewhere; never moved or replaced.")
    expected = {path.name: (path.stat().st_size, "sha256:" + sha256(path)) for path in paths}
    base = f"https://api.github.com/repos/{repository}/releases"
    release = api.json("GET", base + "/tags/" + quote(version, safe=""), allow404=True)
    marker = "KL06_TESTED_DRIVE_V1"
    if release is not None:
        require(release.get("prerelease") is True and marker in release.get("body", "") and release.get("target_commitish") == commit, "Existing release is not this exact managed beta; no mutation allowed.")
        assets = release.get("assets", [])
        actual = {a.get("name"): (a.get("size"), a.get("digest")) for a in assets}
        require(len(assets) == len(expected) and actual == expected, "Existing/partial release differs or has no verifiable server digests; owner review required. Nothing replaced.")
        if not release.get("draft"):
            require(existing_commit == commit, "Published beta tag is missing or changed; owner review required.")
            return "already-published-exact-artifact"
        if dry_run:
            return "dry-run-exact-draft-ready"
    elif dry_run:
        return "dry-run-passed-no-release-created"
    # Creating an absent exact beta ref is intentional; an existing tag is never moved.
    # Draft creation alone does not guarantee when GitHub materializes its tag.
    validate_approval(approval, now=now)
    if existing_commit is None:
        created = api.json("POST", f"https://api.github.com/repos/{repository}/git/refs", {"ref": "refs/tags/" + version, "sha": commit})
        obj = created.get("object") if isinstance(created, dict) else None
        require(isinstance(created, dict) and created.get("ref") == "refs/tags/" + version and isinstance(obj, dict) and obj.get("type") == "commit" and obj.get("sha") == commit, "Exact beta tag creation was not confirmed; no release published.")
    if release is None:
        body = (f"{marker}\n\nOwner-tested beta app ZIP, transferred without rebuilding or executing it.\n"
                f"SHA-256: `{approval['sha256']}`\nSource: `{commit}`\n"
                f"Owner-tested platforms only: {', '.join(sorted(approval['platformTests']))}.\n"
                "Native/device results are owner assertions authenticated by an offline key, not independent agent certification. "
                "No stable/public release, EFI, raw hardware reports or private Drive coordinates. "
                "Structural archive checks are not malware scanning, code-signing or notarization.")
        release = api.json("POST", base, {"tag_name": version, "target_commitish": commit, "name": "KL-06 Manager " + version,
                                          "body": body, "draft": True, "prerelease": True, "make_latest": "false", "generate_release_notes": False})
        require(type(release.get("id")) is int, "GitHub draft ID missing.")
        for path in paths:
            uploaded = api.json("POST", f"https://uploads.github.com/repos/{repository}/releases/{release['id']}/assets?" + urlencode({"name": path.name}), file=path)
            require((uploaded.get("size"), uploaded.get("digest")) == expected[path.name], "GitHub asset digest mismatch; draft retained for owner review, never published.")
    # Recheck actual tag, repository privacy and expiry immediately before publishing.
    # Human changes racing the API call cannot be made an atomic policy transaction;
    # protect visibility/tag/workflow settings through owner-controlled repo rules.
    require(tag_commit(api, repository, version) == commit, "Beta tag changed during transfer; draft not published.")
    repo_preflight(api, repository)
    validate_approval(approval, now=now)
    updated = api.json("PATCH", base + "/" + str(release["id"]), {"draft": False, "prerelease": True, "make_latest": "false"})
    require(updated.get("draft") is False and updated.get("prerelease") is True, "Publication confirmation missing; inspect the private repository.")
    return "published-private-owner-tested-prerelease"


def run(api, repository, folder, signers, work, *, now=None, dry_run=True):
    repo_preflight(api, repository)
    require(DRIVE_ID.fullmatch(folder or ""), "Configure the exact private Drive App folder ID in repository variables.")
    folder_meta = drive_meta(api, folder)
    require(folder_meta.get("mimeType") == "application/vnd.google-apps.folder" and folder_meta.get("name") == "App", "The configured direct folder must be the intended App folder, not another ZIP/source subfolder.")
    approval_meta = drive_meta(api, child(api, folder, APPROVAL_NAME))
    signature_meta = drive_meta(api, child(api, folder, SIGNATURE_NAME))
    bounded_download(api, approval_meta, folder, work / APPROVAL_NAME, 32768)
    bounded_download(api, signature_meta, folder, work / SIGNATURE_NAME, 8192)
    raw, signature = (work / APPROVAL_NAME).read_bytes(), (work / SIGNATURE_NAME).read_bytes()
    verify_signature(raw, signature, signers)
    approval = validate_approval(decode(raw), now=now)
    require(approval["repository"].casefold() == repository.casefold(), "Signed approval belongs to a different repository.")
    artifact_meta = drive_meta(api, approval["driveFileId"])
    require(artifact_meta.get("name") == approval["fileName"] and artifact_meta.get("size") == str(approval["size"]) and artifact_meta.get("mimeType") in ("application/zip", "application/x-zip-compressed", "application/octet-stream"), "Uploaded artifact name/size/type differs from signed approval.")
    artifact = bounded_download(api, artifact_meta, folder, work / approval["fileName"], MAX_ZIP)
    require(sha256(artifact) == approval["sha256"], "Exact tested ZIP SHA-256 mismatch; no release.")
    audit = audit_zip(artifact, approval["platformTests"])
    for original in (approval_meta, signature_meta, artifact_meta):
        require(drive_meta(api, original["id"]) == original, "Drive item changed during validation; rerun with a new deliberate approval.")
    # Re-evaluate expiry after downloads and before writes; no raw approval/Drive IDs attached to release.
    validate_approval(approval, now=time.time() if now is None else now)
    checksums = work / "SHA256SUMS"
    checksums.write_text(approval["sha256"] + "  " + approval["fileName"] + "\n", encoding="ascii")
    receipt = work / "RELEASE-VERIFICATION.json"
    receipt.write_bytes(canonical({"schema": "KL06_RELEASE_RECEIPT_V1", "version": approval["version"], "sourceCommit": approval["sourceCommit"],
                                   "fileName": approval["fileName"], "sha256": approval["sha256"], "size": approval["size"],
                                   "ownerSignatureVerified": True, "ownerTestedPlatforms": sorted(approval["platformTests"]),
                                   "testEvidence": "owner-signed-assertions-not-independent-device-certification", "archiveAudit": audit,
                                   "rebuilt": False, "executed": False, "publicRelease": False}))
    return release_assets(api, repository, approval, [artifact, checksums, receipt], dry_run, now=now)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--preflight-only", action="store_true")
    args = parser.parse_args()
    try:
        repository = os.environ.get("GITHUB_REPOSITORY", "")
        api = API(os.environ.get("GITHUB_TOKEN", ""), os.environ.get("DRIVE_ACCESS_TOKEN", ""))
        if args.preflight_only:
            repo_preflight(api, repository)
            print("Private app-only main-repository preflight passed. No Drive or release write attempted.")
            return
        require(args.dry_run or os.environ.get("KL06_ENABLE_DRIVE_RELEASES") == "true", "Publishing is disabled; a manual read-only dry run is allowed before explicit activation.")
        signers = Path(__file__).resolve().with_name("owner-release-signers")
        with tempfile.TemporaryDirectory(prefix="kl06-tested-release-") as directory:
            result = run(api, repository, os.environ.get("KL06_DRIVE_APP_FOLDER_ID", ""), signers, Path(directory), dry_run=args.dry_run)
        print(result + ". No private Drive IDs, tokens or raw owner records were logged.")
    except Refused as error:
        parser.exit(1, "Release gate refused: " + str(error) + "\n")
    except Exception:
        parser.exit(1, "Release gate failed safely. No archive was executed or automatically repaired. Inspect configuration privately.\n")


if __name__ == "__main__":
    main()
