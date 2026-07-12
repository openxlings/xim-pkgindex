#!/usr/bin/env python3
"""CI-only xpkg mirror/update helper.

The package manifest remains the runtime contract.  This tool consumes the
optional package.ci opt-in and delegates release/version semantics to the
existing, tested version-check implementation.

Commands:
  inspect  Parse package.ci metadata without network access.
  scan     Run the opt-in upstream scanner and emit JSON.
  verify   Validate a mirror manifest without publishing anything.
  mirror   Publish a verified manifest (requires --execute; dry-run default).
  propose  Run the version bump proposer (requires --apply to edit files).
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import re
import subprocess
import sys
import tempfile
import time
import tarfile
import zipfile
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
VC_PATH = ROOT / ".github" / "scripts" / "version-check.py"
GITCODE_RELEASE_TIMEOUT = 60
# GitCode's upload callback is especially slow for large release assets.
GITCODE_UPLOAD_TIMEOUT = 600
GITCODE_VERIFY_TIMEOUT = 20


def load_vcheck():
    spec = importlib.util.spec_from_file_location("version_check", VC_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"unable to load {VC_PATH}")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def ci_block(text: str) -> str:
    m = re.search(r"\bci\s*=\s*\{", text)
    if not m:
        return ""
    depth = 1
    i = m.end()
    while i < len(text) and depth:
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
        i += 1
    return text[m.end() : i - 1] if depth == 0 else ""


def bool_field(body: str, name: str) -> bool:
    return re.search(rf"\b{re.escape(name)}\s*=\s*true\b", body) is not None


def source_value(text: str) -> str | dict[str, str] | None:
    m = re.search(r"\bsource\s*=\s*\"([^\"]+)\"", text)
    if m:
        return m.group(1)
    m = re.search(r"\bsource\s*=\s*\{((?:[^{}]|\$\{[^{}]*\})*)\}", text)
    if not m:
        return None
    values = dict(re.findall(r"\b([A-Za-z][A-Za-z0-9_]*)\s*=\s*\"([^\"]+)\"", m.group(1)))
    return values or None


def inspect_package(path: Path) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8")
    body = ci_block(text)
    repo = re.search(r"\brepo\s*=\s*\"([^\"]+)\"", text)
    name = re.search(r"\bname\s*=\s*\"([^\"]+)\"", text)
    platforms = []
    for platform in ("linux", "macosx", "windows"):
        if re.search(rf"\b{platform}\s*=\s*\{{", text):
            platforms.append(platform)
    return {
        "package": name.group(1) if name else path.stem,
        "path": str(path),
        "repo": repo.group(1) if repo else None,
        "source": source_value(text),
        "mirror": bool_field(body, "mirror"),
        "update": bool_field(body, "update"),
        "platforms": platforms,
    }


def cmd_inspect(args: argparse.Namespace) -> int:
    root = Path(args.workspace)
    records = [inspect_package(p) for p in sorted((root / "pkgs").glob("*/*.lua"))]
    if args.only:
        records = [r for r in records if r["package"] == args.only]
    print(json.dumps({"packages": records}, indent=2, ensure_ascii=False))
    return 0


def cmd_scan(args: argparse.Namespace) -> int:
    root = Path(args.workspace)
    vcheck = load_vcheck()
    policy = vcheck.load_ci_policy(root)
    state_path = Path(args.state_file) if args.state_file else None
    state = {}
    if state_path and state_path.is_file():
        try:
            state = json.loads(state_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            state = {}
    interval_days = int(str(policy["interval"]).removesuffix("d"))
    now = int(time.time())
    records = []
    skipped_due = 0
    for path in sorted((root / "pkgs").glob("*/*.lua")):
        if args.only and path.stem != args.only:
            continue
        metadata = inspect_package(path)
        if not metadata["update"]:
            continue
        last_checked = int(state.get(path.stem, 0) or 0)
        if not args.force and last_checked and now - last_checked < interval_days * 86400:
            skipped_due += 1
            continue
        record = vcheck.check_package(path, args.token)
        if record is not None:
            records.append(record)
        state[path.stem] = now
    if len(records) > int(policy["max_packages_per_run"]):
        return fail(f"scan set {len(records)} exceeds policy max_packages_per_run")
    if state_path:
        state_path.parent.mkdir(parents=True, exist_ok=True)
        state_path.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"policy": policy, "skipped_due": skipped_due, "packages": records}, indent=2))
    return 0


def validate_manifest(manifest: dict[str, Any]) -> list[str]:
    errors = []
    required = ("format", "package", "version", "assets")
    for key in required:
        if key not in manifest:
            errors.append(f"missing manifest field: {key}")
    assets = manifest.get("assets")
    if not isinstance(assets, list) or not assets:
        errors.append("manifest.assets must be a non-empty list")
        return errors
    seen = set()
    for asset in assets:
        for key in ("os", "arch", "filename", "size", "sha256", "source_url"):
            if key not in asset:
                errors.append(f"asset missing field: {key}")
        identity = (asset.get("os"), asset.get("arch"))
        if identity in seen:
            errors.append(f"duplicate platform/arch asset: {identity}")
        seen.add(identity)
        if not isinstance(asset.get("size"), int) or asset.get("size", 0) <= 0:
            errors.append(f"invalid asset size: {asset.get('filename')}")
        if not re.fullmatch(r"[0-9a-f]{64}", str(asset.get("sha256", ""))):
            errors.append(f"invalid asset sha256: {asset.get('filename')}")
        url = str(asset.get("source_url", ""))
        if not url.startswith("https://"):
            errors.append(f"source_url must use https: {asset.get('filename')}")
    return errors


def find_block(text: str, key: str) -> tuple[int, int] | None:
    match = re.search(rf'\["{re.escape(key)}"\]\s*=\s*\{{', text)
    if not match:
        return None
    body_start = match.end()
    depth = 1
    i = body_start
    while i < len(text) and depth:
        if text[i] == "{": depth += 1
        elif text[i] == "}": depth -= 1
        i += 1
    return (body_start, i - 1) if depth == 0 else None


def lua_string(body: str, key: str) -> str | None:
    match = re.search(rf'\b{re.escape(key)}\s*=\s*"([^"]+)"', body)
    return match.group(1) if match else None


def source_templates(body: str) -> dict[str, str] | None:
    match = re.search(r"\bsource\s*=\s*\{((?:[^{}]|\$\{[^{}]*\})*)\}", body)
    if not match:
        return None
    values = dict(re.findall(r"\b([A-Za-z][A-Za-z0-9_]*)\s*=\s*\"([^\"]+)\"", match.group(1)))
    return values or None


def declared_arches(text: str) -> list[str]:
    match = re.search(r'\barchs\s*=\s*\{([^}]*)\}', text)
    return re.findall(r'"([^"]+)"', match.group(1)) if match else []


def expand_template(template: str, package: str, version: str,
                    platform: str, arch: str,
                    aliases: dict[str, str] | None = None) -> str:
    aliases = aliases or {"x86_64": "amd64", "aarch64": "arm64"}
    values = {
        "name": package, "version": version, "os": platform,
        "arch": arch, "arch_alias": aliases.get(arch, arch),
        "ext": "zip" if platform == "windows" else "tar.gz",
    }
    for key, value in values.items():
        template = template.replace("${" + key + "}", value)
        template = template.replace("{" + key + "}", value)
    return template


def validate_archive(path: Path) -> str | None:
    try:
        if path.name.endswith(".tar.gz") or path.name.endswith(".tar.xz") or path.name.endswith(".tar.bz2"):
            with tarfile.open(path, "r:*") as archive:
                if archive.next() is None:
                    return "tar archive is empty"
        elif path.name.endswith(".zip"):
            with zipfile.ZipFile(path) as archive:
                if archive.testzip() is not None:
                    return "zip CRC check failed"
                if not archive.namelist():
                    return "zip archive is empty"
        else:
            return "unsupported archive extension"
    except (OSError, tarfile.TarError, zipfile.BadZipFile, StopIteration) as exc:
        return str(exc) or "archive validation failed"
    return None


def materialize(args: argparse.Namespace) -> int:
    """Download a declared version and emit an immutable mirror manifest."""
    root = Path(args.workspace)
    recipe = root / "pkgs" / args.package[0] / f"{args.package}.lua"
    if not recipe.is_file():
        return fail(f"package recipe not found: {recipe}")
    text = recipe.read_text(encoding="utf-8")
    xpm_match = re.search(r"\bxpm\s*=\s*\{", text)
    if not xpm_match:
        return fail("xpm block not found")
    start = xpm_match.end()
    depth = 1
    i = start
    while i < len(text) and depth:
        if text[i] == "{": depth += 1
        elif text[i] == "}": depth -= 1
        i += 1
    xpm_body = text[start:i - 1]
    arches = declared_arches(text) or ["x86_64"]
    assets = []
    chosen_version = args.version
    for platform in ("linux", "macosx", "windows"):
        platform_match = re.search(rf'\b{platform}\s*=\s*\{{', xpm_body)
        if not platform_match:
            continue
        ps = platform_match.end(); depth = 1; j = ps
        while j < len(xpm_body) and depth:
            if xpm_body[j] == "{": depth += 1
            elif xpm_body[j] == "}": depth -= 1
            j += 1
        platform_body = xpm_body[ps:j - 1]
        ref = re.search(r'\["latest"\]\s*=\s*\{\s*ref\s*=\s*"([^"]+)"', platform_body)
        version = args.version or (ref.group(1) if ref else None)
        if not version:
            return fail(f"{platform}: latest ref/version missing")
        chosen_version = chosen_version or version
        if version != chosen_version:
            return fail(f"platform latest refs disagree: {chosen_version} vs {version}")
        version_block = find_block(platform_body, version)
        if not version_block:
            return fail(f"{platform}: version {version} block missing")
        body = platform_body[version_block[0]:version_block[1]]
        url = lua_string(body, "url")
        source_match = re.search(r'\bsource\s*=\s*"([^"]+)"', platform_body)
        if not source_match:
            source_match = re.search(r'\bsource\s*=\s*"([^"]+)"', xpm_body)
        source_map = source_templates(platform_body) or source_templates(xpm_body) or {}
        template = url or source_map.get("GLOBAL") or (source_match.group(1) if source_match else None)
        if url == "XLINGS_RES" or template == "xlings-res":
            return fail(f"{platform}: cannot materialize an already mirrored XLINGS_RES source")
        if not template:
            return fail(f"{platform}: URL/template missing")
        aliases = dict(re.findall(r'(x86_64|aarch64|x86)\s*=\s*"([^"]+)"', body))
        if len(arches) > 1 and "${arch}" not in template and "{arch}" not in template:
            return fail(f"{platform}: multi-arch package needs an arch-aware URL template")
        use_arches = arches if ("${arch}" in template or "{arch}" in template) else [arches[0]]
        for arch in use_arches:
            final_url = expand_template(template, args.package, version, platform, arch, aliases)
            if not final_url.startswith("https://"):
                return fail(f"{platform}/{arch}: source URL must use https")
            filename = final_url.rsplit("/", 1)[-1]
            output = Path(args.output) / filename
            output.parent.mkdir(parents=True, exist_ok=True)
            request = urllib.request.Request(final_url, headers={"User-Agent": "xim-pkgindex-xpkg-ci"})
            digest = hashlib.sha256(); size = 0
            try:
                with urllib.request.urlopen(request, timeout=180) as response, output.open("wb") as stream:
                    while True:
                        chunk = response.read(64 * 1024)
                        if not chunk: break
                        stream.write(chunk); digest.update(chunk); size += len(chunk)
            except Exception as exc:
                output.unlink(missing_ok=True)
                return fail(f"failed to download {final_url}: {exc}")
            archive_error = validate_archive(output)
            if archive_error:
                output.unlink(missing_ok=True)
                return fail(f"invalid archive {filename}: {archive_error}")
            sidecar = output.with_name(output.name + ".sha256")
            sidecar.write_text(f"{digest.hexdigest()}  {output.name}\n", encoding="utf-8")
            assets.append({"os": platform, "arch": arch, "filename": filename,
                           "size": size, "sha256": digest.hexdigest(),
                           "source_url": final_url, "path": str(output),
                           "sidecar_path": str(sidecar)})
    manifest = {"format": 1, "package": args.package, "version": chosen_version,
                "source_repo": lua_string(text, "repo"), "assets": assets}
    errors = validate_manifest(manifest)
    if errors:
        return fail("; ".join(errors))
    manifest_path = Path(args.output) / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest, indent=2))
    return 0


def cmd_verify(args: argparse.Namespace) -> int:
    path = Path(args.manifest)
    try:
        manifest = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return fail(f"cannot read manifest: {exc}")
    errors = validate_manifest(manifest)
    if errors:
        for error in errors:
            print(f"error: {error}", file=sys.stderr)
        return 1
    print(json.dumps({"status": "verified", "manifest": str(path)}, indent=2))
    return 0


GITHUB_RELEASE_BASE = "https://github.com"
GITCODE_RELEASE_BASE = "https://gitcode.com"


def _download_sha256(url: str, timeout: int = 300) -> tuple[str | None, str]:
    """Stream a mirror asset and return (hex_digest, "") or (None, error)."""
    request = urllib.request.Request(url, headers={"User-Agent": "xim-pkgindex-xpkg-ci"})
    digest = hashlib.sha256()
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            while True:
                chunk = response.read(1024 * 1024)
                if not chunk:
                    break
                digest.update(chunk)
    except (OSError, urllib.error.URLError) as exc:
        return None, str(exc) or "download failed"
    return digest.hexdigest(), ""


def verify_mirror_content(repo: str, gitcode_repo: str, tag: str,
                          assets: list[dict[str, Any]]) -> str | None:
    """Fail-closed three-way check: the bytes actually served by GitHub RES and
    GitCode RES must hash to the authoritative sha256 recorded in the manifest.

    A ranged-GET availability probe only proves an object exists at the URL; it
    does not prove the mirror stored the correct bytes.  This downloads every
    archive asset from both mirrors and compares against the manifest digest,
    which was computed from the authoritative upstream source at materialize
    time.  Returns an error string on the first mismatch, or None when all
    mirrors agree with the manifest.
    """
    for asset in assets:
        expected = str(asset["sha256"])
        filename = asset["filename"]
        sources = (
            ("GitHub", f"{GITHUB_RELEASE_BASE}/{repo}/releases/download/{tag}/{filename}"),
            ("GitCode", f"{GITCODE_RELEASE_BASE}/{gitcode_repo}/releases/download/{tag}/{filename}"),
        )
        for host, url in sources:
            actual, error = _download_sha256(url)
            if actual is None:
                return f"{host} content fetch failed for {filename}: {error}"
            if actual != expected:
                return (f"{host} content mismatch for {filename}: "
                        f"expected {expected}, served {actual}")
    return None


def _gh_repo_exists(repo: str) -> bool:
    result = subprocess.run(
        ["gh", "repo", "view", repo, "--json", "name"],
        text=True, capture_output=True,
    )
    return result.returncode == 0


def _gitcode_main_exists(repo: str) -> bool:
    result = subprocess.run(
        ["git", "ls-remote", "--heads", f"https://gitcode.com/{repo}.git", "main"],
        text=True, capture_output=True,
    )
    return result.returncode == 0 and bool(result.stdout.strip())


def ensure_mirror_repos(package: str, repo: str, gitcode_repo: str) -> str | None:
    """Idempotently ensure both mirror repos exist and are non-empty.

    A brand-new mirror package has no xlings-res repo yet, and both `gh release
    create` and `gtc release create --target main` need a repo that already has
    a commit on `main`.  Existence is probed read-only first, so an already
    provisioned package makes no write call and needs no repo-create token
    scope.  Only a genuinely new package triggers creation (and a README seed on
    GitCode so its `main` branch exists).  Returns an error string on failure,
    or None when both repos are ready.
    """
    description = f"xlings-res immutable mirror for {package}"
    if not _gh_repo_exists(repo):
        created = subprocess.run(
            ["gh", "repo", "create", repo, "--public", "--add-readme",
             "--description", description],
            text=True, capture_output=True,
        )
        if created.returncode != 0:
            return f"failed to create GitHub repo {repo}: {created.stderr.strip()}"
    if not _gitcode_main_exists(gitcode_repo):
        created = subprocess.run(
            ["tools/gtc", "repo", "create", gitcode_repo, "--description", description],
            text=True, capture_output=True,
        )
        if created.returncode != 0:
            return f"failed to create GitCode repo {gitcode_repo}: {created.stderr.strip()}"
        with tempfile.TemporaryDirectory() as seed:
            readme = Path(seed) / "README.md"
            readme.write_text(f"# {package}\n\n{description}.\n", encoding="utf-8")
            pushed = subprocess.run(
                ["tools/gtc", "repo", "push", gitcode_repo, seed, "-m", "seed mirror repo"],
                text=True, capture_output=True,
            )
            if pushed.returncode != 0:
                return f"failed to seed GitCode repo {gitcode_repo}: {pushed.stderr.strip()}"
    return None


def cmd_ensure_repo(args: argparse.Namespace) -> int:
    package = args.package
    repo = f"xlings-res/{package}"
    problem = ensure_mirror_repos(package, repo, repo)
    if problem:
        return fail(problem)
    print(json.dumps({"status": "ready", "package": package, "repo": repo}, indent=2))
    return 0


def cmd_mirror(args: argparse.Namespace) -> int:
    path = Path(args.manifest)
    try:
        manifest = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return fail(f"cannot read manifest: {exc}")
    errors = validate_manifest(manifest)
    if errors:
        for error in errors:
            print(f"error: {error}", file=sys.stderr)
        return 1
    package = manifest["package"]
    tag = str(manifest["version"])
    repo = f"xlings-res/{package}"
    gitcode_repo = f"xlings-res/{package}"
    files = [str(path)]
    for asset in manifest["assets"]:
        if asset.get("path"):
            files.append(str(asset["path"]))
        if asset.get("sidecar_path"):
            files.append(str(asset["sidecar_path"]))
    gh_command = ["gh", "release", "create", tag, "--repo", repo, *files]
    gtc_command = ["tools/gtc", "release", "create", gitcode_repo, "--tag", tag]
    if not args.execute:
        print(json.dumps({"status": "dry-run", "github": gh_command, "gitcode": gtc_command}, indent=2))
        return 0
    if getattr(args, "ensure_repos", True):
        problem = ensure_mirror_repos(package, repo, gitcode_repo)
        if problem:
            return fail(problem)
    view = subprocess.run(
        ["gh", "release", "view", tag, "--repo", repo, "--json", "assets"],
        text=True, capture_output=True,
    )
    expected_names = {Path(f).name for f in files}
    if view.returncode == 0:
        try:
            existing_names = {a["name"] for a in json.loads(view.stdout).get("assets", [])}
        except (json.JSONDecodeError, KeyError, TypeError):
            return fail("existing GitHub release has invalid asset metadata")
        if not expected_names.issubset(existing_names):
            return fail(f"immutable GitHub release {tag} exists with different assets")
        result = subprocess.CompletedProcess(gh_command, 0, "already synchronized\n", "")
    else:
        result = subprocess.run(gh_command, text=True, capture_output=True)
        if result.returncode != 0:
            print(result.stderr, file=sys.stderr)
            return result.returncode
    def asset_available(filename: str) -> bool:
        url = (
            f"https://gitcode.com/{gitcode_repo}/releases/download/"
            f"{tag}/{filename}"
        )
        try:
            # GitCode's release endpoint may not implement HEAD reliably. A
            # one-byte ranged GET validates the actual download path without
            # fetching the complete asset.
            request = urllib.request.Request(url, headers={"Range": "bytes=0-0"})
            with urllib.request.urlopen(request, timeout=GITCODE_VERIFY_TIMEOUT) as response:
                response.read(1)
                return response.status in (200, 206)
        except (OSError, urllib.error.URLError):
            return False

    def finalize(message: str) -> int:
        # Availability probes above only prove the objects exist. Before
        # declaring success, confirm the bytes GitHub RES and GitCode RES
        # actually serve hash to the authoritative manifest digest.
        if getattr(args, "content_verify", True):
            problem = verify_mirror_content(repo, gitcode_repo, tag, manifest["assets"])
            if problem:
                return fail(problem)
        print(result.stdout)
        print(message)
        return 0

    # GitCode's release-create endpoint is idempotent. If every immutable
    # asset is already downloadable, the package is fully mirrored and this
    # job should succeed without calling gtc again.
    if all(asset_available(Path(file).name) for file in files):
        return finalize(f"GitCode assets already verified for {gitcode_repo}@{tag}; skipping upload")

    # Otherwise create the release and upload only the missing assets.
    try:
        gitcode = subprocess.run(
            gtc_command,
            text=True,
            capture_output=True,
            timeout=GITCODE_RELEASE_TIMEOUT,
        )
    except subprocess.TimeoutExpired:
        return fail("gtc release create timed out")
    if gitcode.returncode != 0:
        print(gitcode.stderr, file=sys.stderr)
        return gitcode.returncode

    # GitCode may finish the upload but hang while waiting for obs_callback.
    # Upload one file at a time, bound the subprocess, and accept a timed-out
    # command when the immutable download URL is already available.
    for file in files:
        filename = Path(file).name
        upload = ["tools/gtc", "release", "upload", gitcode_repo, "--tag", tag, file]
        uploaded = False
        last_error = ""
        if asset_available(filename):
            continue
        for attempt in range(3):
            try:
                result_upload = subprocess.run(
                    upload,
                    text=True,
                    capture_output=True,
                    timeout=GITCODE_UPLOAD_TIMEOUT,
                )
                last_error = result_upload.stderr.strip()
            except subprocess.TimeoutExpired:
                last_error = "gtc upload timed out"
            if asset_available(filename):
                uploaded = True
                break
            if attempt < 2:
                time.sleep(2 ** attempt)
        if not uploaded:
            return fail(f"GitCode asset upload failed for {filename}: {last_error}")

    return finalize(f"GitCode assets verified for {gitcode_repo}@{tag}")


def cmd_propose(args: argparse.Namespace) -> int:
    vcheck = load_vcheck()
    command = [sys.executable, str(VC_PATH), "--workspace", args.workspace]
    if args.only:
        command.extend(["--only", args.only])
    if args.apply:
        command.append("--apply")
    result = subprocess.run(command)
    return result.returncode


def fail(message: str) -> int:
    print(f"error: {message}", file=sys.stderr)
    return 2


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", default=str(ROOT))
    sub = parser.add_subparsers(dest="command", required=True)

    for name, func in (("inspect", cmd_inspect), ("scan", cmd_scan)):
        p = sub.add_parser(name)
        p.add_argument("--only")
        p.add_argument("--token", default=None)
        if name == "scan":
            p.add_argument("--state-file")
            p.add_argument("--force", action="store_true")
        p.set_defaults(func=func)
    p = sub.add_parser("verify")
    p.add_argument("manifest")
    p.set_defaults(func=cmd_verify)
    p = sub.add_parser("mirror")
    p.add_argument("manifest")
    p.add_argument("--execute", action="store_true")
    p.add_argument("--no-ensure-repos", dest="ensure_repos", action="store_false",
                   help="skip bootstrapping missing xlings-res repos")
    p.add_argument("--no-content-verify", dest="content_verify", action="store_false",
                   help="skip the three-way GitHub/GitCode byte-hash verification")
    p.set_defaults(func=cmd_mirror, ensure_repos=True, content_verify=True)
    p = sub.add_parser("ensure-repo")
    p.add_argument("package")
    p.set_defaults(func=cmd_ensure_repo)
    p = sub.add_parser("materialize")
    p.add_argument("package")
    p.add_argument("--version")
    p.add_argument("--output", required=True)
    p.set_defaults(func=materialize)
    p = sub.add_parser("propose")
    p.add_argument("--only")
    p.add_argument("--apply", action="store_true")
    p.set_defaults(func=cmd_propose)
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
