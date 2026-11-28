"""Offline checks for the GTK private-runtime resource builder and source lock."""

import importlib.util
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "gtk4_runtime_builder", ROOT / "tools/res/gtk4_runtime.py"
)
BUILDER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUILDER)


@pytest.mark.parametrize(
    "arch,subdir,gtk_sha",
    [
        (
            "x86_64", "linux-64",
            "1a55eeb2a6eb6b82d2944c7ef935b76558e517ea8515f57035b5d73c06d1b7f5",
        ),
        (
            "aarch64", "linux-aarch64",
            "4cd13e4aaea88be14c56d93d0e0779a3a50caf3540e527ac7e7d03c4246b5821",
        ),
    ],
)
def test_official_dual_architecture_lock(arch, subdir, gtk_sha):
    lock = BUILDER._load_lock(arch)
    sources = {source["name"]: source for source in lock["architectures"][arch]["sources"]}
    assert lock["architectures"][arch]["subdir"] == subdir
    assert sources["gtk4"]["version"] == "4.24.2"
    assert sources["gtk4"]["sha256"] == gtk_sha
    assert sources["libsoup"]["version"] == "3.6.6"
    assert sources["python"]["exclude_reason"]
    assert sources["packaging"]["exclude_reason"]
    assert sources[f"ld_impl_{subdir}"]["exclude_reason"]
    assert {"glib-networking", "gdk-pixbuf", "librsvg", "fontconfig", "adwaita-icon-theme"} <= sources.keys()
    assert any(source["name"].startswith("font-ttf-") for source in sources.values())
    assert not any(source["name"] in {"glibc", "libc6", "sysroot_linux-64", "sysroot_linux-aarch64"}
                   for source in sources.values())
    assert lock["external_runtime"]["package"] == "xim:glibc@>=2.38"
    assert lock["data_sources"][0]["data_only"] is True
    assert lock["mime_generator"]["version"] == "2.4"


def test_relative_library_symlinks_are_preserved(tmp_path):
    (tmp_path / "libwidget.so.1.2").write_bytes(b"upstream file")
    (tmp_path / "libwidget.so.1").symlink_to("libwidget.so.1.2")
    (tmp_path / "libwidget.so").symlink_to("libwidget.so.1")
    files = {f"lib/{path.name}": (path, "widget") for path in tmp_path.iterdir()}
    assert BUILDER._resolve("lib/libwidget.so", files) == [
        "lib/libwidget.so", "lib/libwidget.so.1", "lib/libwidget.so.1.2"
    ]


@pytest.mark.parametrize("target", ["/usr/lib/libwidget.so.1", "../../libwidget.so.1"])
def test_host_and_escaping_library_symlinks_are_rejected(tmp_path, target):
    path = tmp_path / "libwidget.so"
    path.symlink_to(target)
    with pytest.raises(ValueError, match="absolute upstream symlink|escapes payload"):
        BUILDER._resolve("lib/libwidget.so", {"lib/libwidget.so": (path, "widget")})


def test_missing_and_cyclic_library_symlinks_are_rejected(tmp_path):
    first = tmp_path / "first.so"
    second = tmp_path / "second.so"
    first.symlink_to(second.name)
    files = {"lib/first.so": (first, "widget")}
    with pytest.raises(ValueError, match="missing upstream path"):
        BUILDER._resolve("lib/first.so", files)
    second.symlink_to(first.name)
    files["lib/second.so"] = (second, "widget")
    with pytest.raises(ValueError, match="cyclic upstream symlink"):
        BUILDER._resolve("lib/first.so", files)
