"""Behavioral coverage for merging library payloads and preparing runtime data."""

import hashlib
import importlib.util
import io
import json
from pathlib import Path
import sys
import tarfile
from types import SimpleNamespace

import pytest


pytestmark = [
    pytest.mark.static,
    pytest.mark.skipif(sys.platform != "linux", reason="Linux payloads use GNU tar"),
]

PREFIX = "/build/_h_env_placehold_placehold_placehold"


@pytest.fixture
def repack():
    path = Path(__file__).resolve().parents[1] / ".agents/tools/repack/repack.py"
    spec = importlib.util.spec_from_file_location("runtime_repack", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def source(tmp_path, name, payload_path=None):
    archive = tmp_path / f"{name}-1.0-0.tar.bz2"
    payload_path = payload_path or f"lib/lib{name}.so"
    files = {
        "info/index.json": json.dumps({"name": name, "version": "1.0", "build": "0", "license": "MIT"}).encode(),
        "info/paths.json": json.dumps({"paths": [{"_path": payload_path, "prefix_placeholder": PREFIX, "file_mode": "text"}]}).encode(),
        "info/licenses/LICENSE": f"{name} license".encode(),
        payload_path: f"{name} library contents".encode(),
        f"bin/{name}-build-tool": b"not part of the runtime",
    }
    with tarfile.open(archive, "w:bz2") as output:
        for name, data in files.items():
            entry = tarfile.TarInfo(name)
            entry.size = len(data)
            output.addfile(entry, io.BytesIO(data))
    return f"{archive.as_uri()}#{hashlib.sha256(archive.read_bytes()).hexdigest()}"


def arguments(tmp_path, sources):
    return SimpleNamespace(
        name="merged-runtime", version="1.0", arch="x86_64", src=sources,
        keep=[], drop=[], relocate=[], host=[], inert=[], require=[],
        out=str(tmp_path / "dist"), cache=str(tmp_path / "cache"),
    )


def test_multiple_conda_sources_preserve_libraries_licenses_and_provenance(repack, tmp_path):
    args = arguments(tmp_path, [source(tmp_path, "alpha"), source(tmp_path, "beta")])
    args.require = ["lib/libalpha.so", "lib/libbeta.so"]
    repack.build(args)
    archive = Path(args.out) / "merged-runtime-1.0-linux-x86_64.tar.gz"
    with tarfile.open(archive) as payload:
        for name in ("alpha", "beta"):
            assert payload.extractfile(f"merged-runtime-1.0/lib/lib{name}.so").read() == f"{name} library contents".encode()
            assert payload.extractfile(f"merged-runtime-1.0/licenses/{name}/LICENSE").read() == f"{name} license".encode()
        assert not any(name.startswith("merged-runtime-1.0/info/") for name in payload.getnames())
        provenance = payload.extractfile("merged-runtime-1.0/PROVENANCE.md").read().decode()
        for spec in args.src:
            url, digest = spec.split("#")
            assert url in provenance
            assert digest in provenance
    assert archive.with_name(archive.name + ".sha256").read_text().split() == [
        hashlib.sha256(archive.read_bytes()).hexdigest(), archive.name,
    ]


def test_real_payload_conflicts_are_not_discarded_with_conda_metadata(repack, tmp_path):
    args = arguments(tmp_path, [source(tmp_path, "alpha", "lib/shared.so"), source(tmp_path, "beta", "lib/shared.so")])
    with pytest.raises(repack.Broken):
        repack.build(args)
    assert not list(Path(args.out).glob("*.tar.gz"))


@pytest.mark.parametrize("classify_generated_path", [False, True])
def test_prepared_data_is_required_and_placeholder_audited(repack, tmp_path, classify_generated_path):
    args = arguments(tmp_path, [source(tmp_path, "alpha")])
    args.require = ["share/generated.txt"]
    if classify_generated_path:
        args.relocate = ["share/generated.txt"]

    def prepare(root):
        assert not (root / "bin/alpha-build-tool").exists()
        (root / "share").mkdir()
        (root / "share/generated.txt").write_text(PREFIX + "/share/mime")

    if not classify_generated_path:
        with pytest.raises(repack.Broken):
            repack.build(args, prepare=prepare)
        assert not list(Path(args.out).glob("*.tar.gz"))
        return
    repack.build(args, prepare=prepare)
    archive = Path(args.out) / "merged-runtime-1.0-linux-x86_64.tar.gz"
    with tarfile.open(archive) as payload:
        assert payload.extractfile("merged-runtime-1.0/share/generated.txt").read().decode() == PREFIX + "/share/mime"
        relocation = json.load(payload.extractfile("merged-runtime-1.0/RELOCATE.json"))
        assert any(entry["path"] == "share/generated.txt" for entry in relocation["entries"])
