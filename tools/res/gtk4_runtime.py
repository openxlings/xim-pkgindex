#!/usr/bin/env python3
"""Build the locked GTK 4.24.2 private Linux runtime using the shared repacker.

Example:
    python3 tools/res/gtk4_runtime.py --arch aarch64 --output /tmp/gtk-dist \
        --cache /tmp/gtk-source-cache

No solver, package installation, target executable, or host library is used at
build time. The accompanying JSON records the complete official micromamba /
libsolv transaction, including sources excluded as build-only dependencies.
Re-solving/updating that lock is deliberately not a builder operation.

After installation, apply RELOCATE.json and seal every ELF against xim:glibc
and this package's private lib directory before executing the native cache
tools: glib-compile-schemas, gio-querymodules, gdk-pixbuf-query-loaders, and
(optionally) fc-cache and gtk4-update-icon-cache. Cache paths must refer to the
installed prefix, never the build staging directory. Native verification is a
separate step, not implied by successful resource generation.
"""

import argparse
from concurrent.futures import ThreadPoolExecutor
import fnmatch
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
from types import SimpleNamespace


LOCK = Path(__file__).with_name("gtk4-runtime-4.24.2.json")
REPO = Path(__file__).resolve().parents[2]
REPACK = REPO / ".agents/tools/repack/repack.py"
CACHE_TOOLS = (
    "bin/glib-compile-schemas",
    "bin/gio-querymodules",
    "bin/gdk-pixbuf-query-loaders",
    "bin/gtk4-update-icon-cache",
    "bin/fc-cache",
)
# These are runtime dlopen/plugin roots, not dependencies discoverable through
# DT_NEEDED alone. Preserve actual upstream modules and helper executables.
MODULES = (
    "lib/gio/modules/**",
    "lib/gdk-pixbuf-2.0/**",
    "lib/gtk-4.0/**",
    "lib/ossl-modules/**",
    "lib/engines-3/**",
    "libexec/gio-launch-desktop",
    "libexec/gtk-4.0/**",
    "libexec/gdk-pixbuf-2.0/**",
    "libexec/librsvg/**",
    "libexec/glycin-loaders/**",
)
DATA = (
    "etc/fonts/**",
    "etc/ssl/**",
    "ssl/*.pem",
    "ssl/openssl.cnf",
    "ssl/ct_log_list.cnf",
    "fonts/**",
    "share/fonts/**",
    "share/fontconfig/**",
    "share/xml/fontconfig/**",
    "share/icons/Adwaita/**",
    "share/icons/hicolor/index.theme",
    "share/glib-2.0/schemas/**",
    "share/mime/**",
    "share/X11/xkb/**",
    "share/gtk-4.0/emoji/**",
)
ROOT_LIBRARIES = (
    "lib/libgtk-4.so.1",
    "lib/libsoup-3.0.so.0",
    "lib/librsvg-2.so.2",
    "lib/libvulkan.so.1",
    "lib/libEGL.so.1",
    "lib/libGL.so.1",
    "lib/libGLX.so.0",
)
REQUIRED_DATA = (
    "etc/fonts/fonts.conf",
    "lib/gio/modules/libgioopenssl.so",
    "lib/gdk-pixbuf-2.0/2.10.0/loaders/libpixbufloader_svg.so",
    "share/glib-2.0/schemas/org.gtk.gtk4.Settings.FileChooser.gschema.xml",
    "share/icons/Adwaita/index.theme",
    "share/mime/packages/gtk-mime.xml",
    "share/mime/packages/freedesktop.org.xml",
)


def _matches(path, patterns):
    return any(fnmatch.fnmatchcase(path, pattern) for pattern in patterns)


def _load_repacker():
    spec = importlib.util.spec_from_file_location("gtk_runtime_repack", REPACK)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _load_lock(arch):
    lock = json.loads(LOCK.read_text())
    if (lock.get("schema"), lock.get("name"), lock.get("version")) != (
        1, "gtk4-runtime", "4.24.2"
    ):
        raise ValueError("unexpected GTK runtime lock identity")
    sources = lock["architectures"][arch]["sources"]
    roots = {source["name"]: source["version"] for source in sources}
    if roots.get("gtk4") != "4.24.2" or roots.get("libsoup") != "3.6.6":
        raise ValueError("lock must contain GTK 4.24.2 and libsoup 3.6.6")
    expected_subdir = lock["architectures"][arch]["subdir"]
    for source in sources:
        if not re.fullmatch(r"[0-9a-f]{64}", source["sha256"]):
            raise ValueError(f"invalid source SHA256: {source['name']}")
        if source["subdir"] not in (expected_subdir, "noarch"):
            raise ValueError(f"wrong source architecture: {source['name']}")
        prefix = f"https://conda.anaconda.org/conda-forge/{source['subdir']}/"
        if not source["url"].startswith(prefix):
            raise ValueError(f"non-authoritative source URL: {source['url']}")
    for source in lock["data_sources"]:
        if source.get("format") != "deb" or not source.get("data_only"):
            raise ValueError("only the authorized data-only Debian exception is permitted")
        if not source["url"].startswith("https://snapshot.debian.org/"):
            raise ValueError("Debian data must use an immutable Snapshot URL")
        if not re.fullmatch(r"[0-9a-f]{64}", source["sha256"]):
            raise ValueError("invalid Debian data SHA256")
    return lock


def _stage_sources(repack, sources, cache, temporary):
    def stage(source):
        archive = repack.fetch(source["url"], source["sha256"], cache)
        destination = temporary / source["name"]
        destination.mkdir()
        if source.get("format") == "deb":
            repack.extract_deb(archive, destination, "x86_64")
        else:
            repack.extract_conda(archive, destination)
        return source, destination

    # Only download locked inputs; no package installation or post-link script.
    with ThreadPoolExecutor(max_workers=6) as pool:
        return list(pool.map(stage, sources))


def _inventory(repack, stages):
    files = {}
    for source, directory in stages:
        for path, relative in repack.walk_files(directory):
            if relative.startswith(("info/", "licenses/")):
                continue
            if relative in files:
                previous = files[relative][0]
                if path.is_symlink() and previous.is_symlink():
                    identical = os.readlink(path) == os.readlink(previous)
                elif not path.is_symlink() and not previous.is_symlink():
                    identical = repack.sha256_of(path) == repack.sha256_of(previous)
                else:
                    identical = False
                if not identical:
                    raise ValueError(f"conflicting upstream runtime path: {relative}")
                continue
            files[relative] = (path, source["name"])
    return files


def _resolve(relative, files):
    visited = []
    while True:
        if relative not in files:
            raise ValueError(f"missing upstream path/symlink target: {relative}")
        if relative in visited:
            raise ValueError(f"cyclic upstream symlink: {relative}")
        visited.append(relative)
        path = files[relative][0]
        if not path.is_symlink():
            return visited
        target = os.readlink(path)
        if target.startswith("/"):
            raise ValueError(f"absolute upstream symlink: {relative} -> {target}")
        relative = os.path.normpath(str(Path(relative).parent / target))
        if relative == ".." or relative.startswith("../"):
            raise ValueError(f"upstream symlink escapes payload: {relative}")


def _elf_dependencies(path):
    with path.open("rb") as stream:
        if stream.read(4) != b"\x7fELF":
            return None
    dynamic = subprocess.run(
        ["readelf", "--dynamic", "--wide", str(path)],
        check=True, capture_output=True, text=True, env={**os.environ, "LC_ALL": "C"},
    ).stdout
    return re.findall(r"\(NEEDED\).*?Shared library: \[([^\]]+)\]", dynamic)


def _runtime_files(files, external):
    for required in ROOT_LIBRARIES + CACHE_TOOLS + REQUIRED_DATA:
        if required not in files:
            raise ValueError(f"locked runtime lacks {required}")
    if not any(path.startswith(("fonts/", "share/fonts/")) and path.endswith(
        (".ttf", ".otf")
    ) for path in files):
        raise ValueError("locked runtime lacks actual font files")

    desired = {
        path for path in files
        if _matches(path, DATA + MODULES) and not path.endswith((".a", ".la"))
    }
    desired.update(ROOT_LIBRARIES + CACHE_TOOLS)
    libraries = {}
    for relative in files:
        if relative.startswith("lib/") and ".so" in Path(relative).name:
            libraries.setdefault(Path(relative).name, []).append(relative)
    pending = sorted(desired)
    inspected = set()
    external_needed = set()
    while pending:
        relative = pending.pop()
        chain = _resolve(relative, files)
        desired.update(chain)
        actual = chain[-1]
        if actual in inspected:
            continue
        inspected.add(actual)
        needed = _elf_dependencies(files[actual][0])
        if needed is None:
            continue
        for soname in needed:
            if soname in external:
                external_needed.add(soname)
                continue
            candidates = libraries.get(soname, [])
            if len(candidates) != 1:
                raise ValueError(
                    f"{actual}: need exactly one private provider for {soname}; "
                    f"found {candidates}"
                )
            dependency = candidates[0]
            if dependency not in inspected:
                pending.append(dependency)
            desired.add(dependency)
    providers = {files[path][1] for path in desired}
    desired.update(path for path in files
                   if path.startswith("share/locale/") and files[path][1] in providers
                   and files[path][1] != "shared-mime-info")
    return desired, external_needed


def _license_material(repack, lock, stages, contributing):
    directories = {source["name"]: directory for source, directory in stages}
    sources = {source["name"]: source for source, _ in stages}
    distributed = {source["name"] for source in contributing}
    material, provenance = {}, []
    for extraction in lock["license_extractions"]:
        if extraction["package"] not in distributed:
            continue
        source = extraction["source"]
        path = directories[source] / extraction["path"]
        data = path.read_bytes()
        if extraction["kind"] == "info-copying-node":
            nodes = [node for node in data.split(b"\x1f")
                     if b"Node: Copying," in node.partition(b"\n")[2].partition(b"\n")[0]]
            if len(nodes) != 1 or b"Version 3, 29 June 2007" not in nodes[0]:
                raise ValueError("GCC documentation lacks the complete GPLv3 Copying node")
            data = nodes[0]
        elif extraction["kind"] == "initial-comment":
            if not data.startswith(b"/*") or b"*/" not in data:
                raise ValueError("SQLite header lacks its initial copyright comment")
            data = data[:data.index(b"*/") + 2] + b"\n"
            if b"The author disclaims copyright" not in data:
                raise ValueError("SQLite public-domain notice has changed")
        elif extraction["kind"] != "file":
            raise ValueError(f"unknown license extraction: {extraction['kind']}")
        material[extraction["target"]] = data
        provenance.append({
            **extraction, "source_url": sources[source]["url"],
            "source_file_sha256": repack.sha256_of(path),
            "license_sha256": hashlib.sha256(data).hexdigest(),
        })
    return material, provenance


def _preparer(repack, lock, arch, contributing, external, stages):
    licenses, license_provenance = _license_material(repack, lock, stages, contributing)
    generator = shutil.which("update-mime-database")
    if not generator:
        raise RuntimeError("update-mime-database 2.4 is required to generate private MIME data")
    environment = {**os.environ, "LC_ALL": "C"}
    version = subprocess.run([generator, "-v"], check=True, capture_output=True,
                             text=True, env=environment)
    banner = (version.stdout + version.stderr).splitlines()[0]
    if banner != lock["mime_generator"]["version_banner"]:
        raise RuntimeError(f"locked MIME generator version required; found {banner}")
    versions = {"python": sys.version, "update-mime-database": banner}
    for tool in ("readelf", "tar", "gzip", "zstd"):
        result = subprocess.run([tool, "--version"], check=True, capture_output=True,
                                text=True, env=environment)
        versions[tool] = (result.stdout + result.stderr).splitlines()[0]
    metadata = {
        "schema": 1, "name": "gtk4-runtime", "version": "4.24.2", "arch": arch,
        "reproduction": {
            "command": shlex.join([sys.executable, *sys.argv]),
            "working_directory": "xim-pkgindex repository root",
            "tool_versions": versions,
            "builder_sha256": repack.sha256_of(Path(__file__)),
            "repacker_sha256": repack.sha256_of(REPACK),
            "source_lock_sha256": repack.sha256_of(LOCK),
            "mime_command": "LC_ALL=C XDG_DATA_DIRS=<payload>/share update-mime-database <payload>/share/mime",
        },
        "source_lock": lock,
        "distributed_sources": [source["url"] for source in contributing],
        "license_extractions": license_provenance,
        "external_glibc_sonames": sorted(external),
        "native_validation": "Not performed by the resource builder.",
    }

    def prepare(root):
        for relative, data in licenses.items():
            destination = root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(data)
        for source in contributing:
            directory = root / "licenses" / source["name"]
            if not directory.is_dir() or not any(
                path.is_file() and path.stat().st_size for path in directory.rglob("*")
            ):
                raise ValueError(f"missing nonempty upstream license: {source['name']}")
        subprocess.run([generator, str(root / "share/mime")], check=True,
                       env={**environment, "XDG_DATA_DIRS": str(root / "share")})
        (root / "BUILD-METADATA.json").write_text(
            json.dumps(metadata, indent=2, sort_keys=True) + "\n"
        )

    return prepare


def build(arch, output, cache):
    if not shutil.which("readelf"):
        raise RuntimeError("readelf is required for architecture-independent ELF closure selection")
    repack = _load_repacker()
    lock = _load_lock(arch)
    sources = [source for source in lock["architectures"][arch]["sources"]
               if "exclude_reason" not in source] + lock["data_sources"]
    # Separate architecture caches avoid concurrent builds racing on shared
    # noarch archive names in the repacker's download cache.
    cache = cache / arch
    with tempfile.TemporaryDirectory(prefix="gtk4-runtime-inputs-") as temporary:
        stages = _stage_sources(repack, sources, cache, Path(temporary))
        files = _inventory(repack, stages)
        desired, external = _runtime_files(files, set(lock["external_runtime"]["sonames"]))
        providers = {files[path][1] for path in desired}
        providers.update(extraction["source"] for extraction in lock["license_extractions"]
                         if extraction["package"] in providers)
        contributing = [source for source in sources if source["name"] in providers]
        # This is an allowlist, not a whole Conda environment: all compiler,
        # Python, header, static-library, documentation and generator files go.
        # Licenses are collected per source by the shared Conda extractor.
        args = SimpleNamespace(
            name="gtk4-runtime", version="4.24.2", arch=arch,
            src=[f"{source['url']}#{source['sha256']}" for source in contributing],
            keep=sorted(desired) + ["licenses/**"], drop=["*"],
            relocate=["*"], host=[], inert=[],
            require=list(ROOT_LIBRARIES + CACHE_TOOLS + REQUIRED_DATA)
                    + ["share/mime/mime.cache", "BUILD-METADATA.json"],
            out=str(output), cache=str(cache),
        )
        repack.build(args, prepare=_preparer(repack, lock, arch, contributing, external, stages))
    print(json.dumps({
        "arch": arch, "runtime_sources": len(contributing),
        "runtime_files": len(desired), "external_glibc_sonames": sorted(external),
        "native_validation": "not performed; resource generation only",
    }, sort_keys=True))


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--arch", required=True, choices=("x86_64", "aarch64"))
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--cache", type=Path, default=Path(tempfile.gettempdir()) / "gtk4-runtime-cache")
    args = parser.parse_args()
    previous_umask = os.umask(0o022)
    try:
        build(args.arch, args.output.resolve(), args.cache.resolve())
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"gtk4-runtime: {error}\n")
    finally:
        os.umask(previous_umask)


if __name__ == "__main__":
    main()
