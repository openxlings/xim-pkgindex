"""Mirror and fail-closed native acceptance tests for gtk4-runtime.

L4 needs an installed, relocated/sealed payload, its explicit xim:glibc provider,
cc + libc headers and a display (CI: xvfb-run -a pytest ... -m verify). Set
GTK4_RUNTIME_ROOT and GTK4_LIBC_ROOT to select exact installed roots; otherwise
only unambiguous installed package roots are accepted. By default a temporary
local recipe installs official dbpp 0.4.2 binaries, then removes the installation
and local registration. GTK4_CONSUMER_ROOT selects an existing real consumer.
Missing prerequisites fail, never pass via skips. Non-Linux L3/L4 are inapplicable.
"""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys

import pytest

from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_no_direct_pkg_manager,
    assert_uses_new_api, assert_valid_xvm_node_kinds,
    assert_xim_add_succeeds, assert_install_succeeds, assert_uninstall_succeeds,
    assert_xvm_registered,
)
from tests.lib.platform_utils import project_root, skip_if_not, under_test, xlings_home, xpkgs_dir
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.xlings_client import XlingsClient

VERSION = "4.24.2"
PKG = "gtk4-runtime"
PKG_FILE = "pkgs/g/gtk4-runtime.lua"
ROOT = Path(project_root())
VERIFIER = ROOT / ".agents/tools/graphics/verify-gtk4-runtime.py"


@pytest.fixture(scope="module")
def meta():
    return parse_xpkg(PKG_FILE)


@pytest.fixture(scope="module")
def verifier():
    spec = importlib.util.spec_from_file_location("gtk4_runtime_verifier", VERIFIER)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def _elf(path, *, machine=62, needed=(), soname=None, runpath="$ORIGIN"):
    """Small synthetic ELF for parser/error-path unit tests, never native evidence."""
    strings = bytearray(b"\0")

    def string(value):
        offset = len(strings)
        strings.extend(value.encode() + b"\0")
        return offset

    entries = [(1, string(name)) for name in needed]
    if soname:
        entries.append((14, string(soname)))
    if runpath is not None:
        entries.append((29, string(runpath)))
    dynoff = 64 + 2 * 56
    stroff = dynoff + (len(entries) + 3) * 16
    entries += [(5, stroff), (10, len(strings)), (0, 0)]
    size = stroff + len(strings)
    ident = b"\x7fELF\x02\x01\x01" + bytes(9)
    header = struct.pack("<16sHHIQQQIHHHHHH", ident, 3, machine, 1, 0, 64, 0, 0,
                         64, 56, 2, 64, 0, 0)
    load = struct.pack("<IIQQQQQQ", 1, 4, 0, 0, 0, size, size, 4096)
    dynamic = struct.pack("<IIQQQQQQ", 2, 4, dynoff, dynoff, 0, len(entries) * 16, len(entries) * 16, 8)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(header + load + dynamic + b"".join(struct.pack("<qQ", *e) for e in entries) + strings)
    return path


class TestStatic:
    @pytest.mark.static
    def test_metadata(self, meta):
        for check in (assert_required_fields, assert_valid_spec, assert_valid_type, assert_valid_xvm_node_kinds):
            check(meta)
        assert meta.name == PKG
        assert meta.spec == "2"
        assert meta.has_installed and meta.has_install and meta.has_config and meta.has_uninstall
        assert_no_typos(PKG_FILE)

    @pytest.mark.static
    def test_dual_arch_resources_and_private_export(self):
        lua = shutil.which("lua5.4") or shutil.which("lua")
        assert lua, "Lua is required to evaluate real recipe metadata"
        script = r'''
import = function() end
dofile(arg[1])
assert(#package.archs == 2)
local archs = {}
for _, arch in ipairs(package.archs) do archs[arch] = true end
assert(archs.x86_64 and archs.aarch64)
local linux = assert(package.xpm.linux)
assert(linux.latest.ref == "4.24.2")
local entry = assert(linux["4.24.2"])
for _, arch in ipairs({"x86_64", "aarch64"}) do
    local res = assert(entry[arch], "missing " .. arch)
    assert(type(res.sha256) == "string" and #res.sha256 == 64 and res.sha256:match("^[0-9a-f]+$"))
    local url = type(res.url) == "table" and res.url.GLOBAL or res.url
    assert(type(url) == "string" and url:match("^https://"))
    assert(url:find("gtk4%-runtime") and url:find(arch, 1, true))
end
local runtime = linux.deps.runtime or linux.deps
local providers = {}
for _, dep in ipairs(runtime) do providers[dep] = true end
assert(providers["xim:glibc@>=2.38"])
for dep in pairs(providers) do
    assert(dep == "xim:glibc@>=2.38", "unexpected external runtime provider: " .. dep)
end
assert(#linux.exports.runtime.libdirs == 1 and linux.exports.runtime.libdirs[1] == "lib")
'''
        result = subprocess.run([lua, "-", str(ROOT / PKG_FILE)], input=script,
                                text=True, capture_output=True, timeout=15)
        assert result.returncode == 0, result.stdout + result.stderr

    @pytest.mark.static
    def test_actual_elf_architecture_not_filename(self, verifier, tmp_path):
        path = _elf(tmp_path / "looks-like-aarch64.so", machine=62)
        with pytest.raises(verifier.Broken, match="wrong ELF architecture"):
            verifier.read_elf(path, "aarch64")
        assert verifier.read_elf(path, "x86_64").path == path

    @pytest.mark.static
    def test_truncated_elf_is_failure(self, verifier, tmp_path):
        path = _elf(tmp_path / "broken.so")
        path.write_bytes(path.read_bytes()[:-2])
        with pytest.raises(verifier.Broken, match="truncated ELF"):
            verifier.read_elf(path, "x86_64")

    @pytest.mark.static
    def test_missing_dependency_cannot_use_host(self, verifier, tmp_path):
        _elf(tmp_path / "libgtk.so", needed=("libX11.so.6",))
        objects = verifier.scan(tmp_path, "x86_64")
        with pytest.raises(verifier.Broken, match="missing dependency.*libX11.so.6"):
            verifier.check_closure(objects, {}, (tmp_path,))

    @pytest.mark.static
    def test_provider_presence_does_not_replace_runpath(self, verifier, tmp_path):
        _elf(tmp_path / "gtk/libgtk.so", needed=("libpango.so.0",), runpath="$ORIGIN")
        _elf(tmp_path / "other/libpango.so.0", soname="libpango.so.0")
        objects = verifier.scan(tmp_path, "x86_64")
        assert "libpango.so.0" in verifier.providers(objects)
        with pytest.raises(verifier.Broken, match="missing dependency"):
            verifier.check_closure(objects, {}, (tmp_path,))

    @pytest.mark.static
    def test_non_elf_named_provider_is_not_evidence(self, verifier, tmp_path):
        _elf(tmp_path / "libgtk.so", needed=("libpango.so.0",))
        (tmp_path / "libpango.so.0").write_text("not an ELF")
        objects = verifier.scan(tmp_path, "x86_64")
        with pytest.raises(verifier.Broken, match="non-ELF provider"):
            verifier.check_closure(objects, {}, (tmp_path,))

    @pytest.mark.static
    def test_escaping_symlink_cannot_be_provider(self, verifier, tmp_path):
        root = tmp_path / "runtime"
        root.mkdir()
        outside = _elf(tmp_path / "host/libX11.so.6")
        (root / "libX11.so.6").symlink_to(outside)
        with pytest.raises(verifier.Broken, match="escaping payload symlink"):
            verifier.scan(root, "x86_64")

    @pytest.mark.static
    def test_only_explicit_c_runtime_can_be_external(self, verifier, tmp_path):
        obj = _elf(tmp_path / "libgtk.so", needed=("libc.so.6",))
        objects = verifier.scan(tmp_path, "x86_64")
        with pytest.raises(verifier.Broken, match="missing explicit glibc provider"):
            verifier.check_closure(objects, {}, (tmp_path,))
        verifier.check_closure(objects, {"libc.so.6": tmp_path / "explicit-libc"}, (tmp_path,))
        _elf(obj, needed=("libX11.so.6",))
        with pytest.raises(verifier.Broken, match="missing dependency"):
            verifier.check_closure(verifier.scan(tmp_path, "x86_64"),
                                   {"libX11.so.6": tmp_path / "wrong-provider"}, (tmp_path,))

    @pytest.mark.static
    def test_absolute_host_runpath_is_rejected(self, verifier, tmp_path):
        outside = _elf(tmp_path / "host/libX11.so.6")
        root = tmp_path / "runtime"
        _elf(root / "libgtk.so", needed=(outside.name,), runpath=str(outside.parent))
        with pytest.raises(verifier.Broken, match="outside provider"):
            verifier.check_closure(verifier.scan(root, "x86_64"), {}, (root,))

    @pytest.mark.static
    def test_dlopen_host_provider_is_failure(self, verifier, tmp_path):
        log = tmp_path / "audit.log"
        log.write_text("/usr/lib/libgtk-4.so.1\n")
        with pytest.raises(verifier.Broken, match="host/outside library was actually loaded"):
            verifier.check_loaded(log, {}, {}, set())
        log.write_text("")
        with pytest.raises(verifier.Broken, match="no evidence"):
            verifier.check_loaded(log, {}, {}, set())

    @pytest.mark.static
    def test_unapplied_prefix_is_failure(self, verifier, tmp_path):
        placeholder = "/conda/build/_h_env_placehold_"
        target = tmp_path / "module.cache"
        target.write_text(placeholder + "/lib/module.so")
        (tmp_path / "RELOCATE.json").write_text(json.dumps({
            "schema": 1, "entries": [{"path": target.name, "placeholder": placeholder, "mode": "text"}],
        }))
        with pytest.raises(verifier.Broken, match="unapplied relocation"):
            verifier.check_relocated(tmp_path)

    @pytest.mark.static
    def test_no_implicit_host_libc(self, verifier, tmp_path, capsys):
        assert verifier.main(["--runtime-root", str(tmp_path), "--arch", "aarch64"]) == 3
        assert "--libc-root" in capsys.readouterr().err


    @pytest.mark.static
    def test_wrong_soname_is_not_a_provider(self, verifier, tmp_path):
        _elf(tmp_path / "libgtk.so", needed=("libpango.so.0",))
        _elf(tmp_path / "libpango.so.0", soname="libunrelated.so.0")
        with pytest.raises(verifier.Broken, match="wrong SONAME provider"):
            verifier.check_closure(verifier.scan(tmp_path, "x86_64"), {}, (tmp_path,))


class TestIsolation:
    @pytest.mark.isolation
    def test_subos_isolation(self, meta):
        for check in (assert_no_exec_xvm, assert_no_bashrc_modification,
                      assert_no_direct_path_modification, assert_no_direct_pkg_manager, assert_uses_new_api):
            check(PKG_FILE)
        allowed = {"xim.pkgindex.payload", "xim.pkgindex.relocate", "xim.pkgindex.selfcontain", "xim.pkgindex.sysroot"}
        assert all(name.startswith("xim.libxpkg.") or name in allowed for name in meta.imports)


class TestIndex:
    @pytest.mark.index
    def test_xim_add(self):
        assert_xim_add_succeeds(PKG_FILE)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_install(self):
        assert_install_succeeds(under_test(PKG, VERSION), timeout=600)

    @pytest.mark.lifecycle
    @skip_if_not("linux")
    def test_uninstall(self):
        assert_uninstall_succeeds(under_test(PKG, VERSION))


def _installed_root(variable, name, version=None):
    explicit = os.environ.get(variable)
    if explicit:
        root = Path(explicit).resolve()
        assert root.is_dir(), f"{variable} is not an installed directory: {root}"
        return root
    base = Path(xpkgs_dir())
    matches = [root for store in base.glob(f"*-x-{name}") for root in store.iterdir()
               if root.is_dir() and (version is None or root.name == version)]
    assert len(matches) == 1, f"set {variable} to one exact installed {name} root; found {matches}"
    return matches[0].resolve()


@pytest.fixture
def real_consumer(tmp_path):
    """Install real upstream dbpp against this candidate runtime, never host GTK."""
    if os.environ.get("GTK4_CONSUMER_ROOT"):
        yield _installed_root("GTK4_CONSUMER_ROOT", "dbpp", "0.4.2")
        return

    name = "gtk4-runtime-dbpp-probe"
    coordinate = f"local:{name}@0.4.2"
    registered_recipe = Path(xlings_home()) / "data/xim-pkgindex-local/pkgs/g" / f"{name}.lua"
    assert not registered_recipe.exists(), f"refusing to replace existing local fixture: {registered_recipe}"
    existing = [p for store in Path(xpkgs_dir()).glob(f"*-x-{name}") for p in store.iterdir() if p.is_dir()]
    assert not existing, f"refusing to reuse or remove an existing consumer fixture: {existing}"
    xlings = shutil.which("xlings")
    assert xlings, "xlings is required to install the real dbpp acceptance consumer"
    recipe = tmp_path / f"{name}.lua"
    runtime_coordinate = json.dumps(under_test(PKG, VERSION))
    recipe.write_text('''
package = {
    spec = "2",
    name = "gtk4-runtime-dbpp-probe",
    description = "Test-only real dbpp consumer of the candidate GTK4 runtime",
    type = "package",
    archs = {"x86_64", "aarch64"},
    programs = {},
    xvm_enable = true,
    xpm = {
        linux = {
            deps = {
                runtime = {RUNTIME_COORDINATE, "xim:glibc@>=2.38"},
                build = {"xim:patchelf@>=0.19.3"},
            },
            ["latest"] = { ref = "0.4.2" },
            ["0.4.2"] = {
                x86_64 = {
                    url = "https://github.com/FarnaHerry/dbpp/releases/download/v0.4.2/dbpp-0.4.2-linux-x86_64.tar.gz",
                    sha256 = "510a95352142e06f71d3c2811ba0163c6006df8c03fc043a797f209c4c93ece3",
                },
                aarch64 = {
                    url = "https://github.com/FarnaHerry/dbpp/releases/download/v0.4.2/dbpp-0.4.2-linux-aarch64.tar.gz",
                    sha256 = "0715252a400db32681379b40936b227a74adc8469a7275db3e4322d185b5cf75",
                },
            },
        },
    },
}
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")
local files = {
    "dbpp", "lib/libhuxerui.so", "lib/libadbc_driver_manager.so.113",
    "lib/libadbc_driver_sqlite.so.113.0.0", "dbpp.resources/huxerui/resources.bin",
}
function installed()
    return payload.present(files)
end
function install()
    payload.unpack{ extracted = {"build-linux-x86_64", "build-linux-arm64"} }
    return payload.require(files)
end
function config()
    xvm.add("gtk4-runtime-dbpp-probe", { type = "group" })
end
function uninstall()
    xvm.remove("gtk4-runtime-dbpp-probe")
    return true
end
'''.replace("RUNTIME_COORDINATE", runtime_coordinate))
    registered = False
    installation_attempted = False
    try:
        registered, output = XlingsClient.xim_add_xpkg(str(recipe))
        assert registered, output
        assert under_test(name, "0.4.2") == coordinate
        installation_attempted = True
        installed, output = XlingsClient.install(coordinate, timeout=600)
        assert installed, output
        yield _installed_root("GTK4_CONSUMER_ROOT", name, "0.4.2")
    finally:
        failures = []
        if installation_attempted:
            removed, output = XlingsClient.remove(coordinate)
            if not removed:
                failures.append(f"consumer uninstall failed: {output}")
        if registered or registered_recipe.exists():
            result = subprocess.run([xlings, "config", "--remove-xpkg", name],
                                    text=True, capture_output=True, timeout=45)
            if result.returncode or registered_recipe.exists():
                failures.append(f"consumer local registration cleanup failed: {result.stdout}{result.stderr}")
        assert not failures, "\n".join(failures)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not("linux")
    def test_xvm_registered(self):
        assert_xvm_registered(PKG)

    @pytest.mark.verify
    @skip_if_not("linux")
    def test_native_runtime_and_real_consumer(self, real_consumer):
        runtime = _installed_root("GTK4_RUNTIME_ROOT", PKG, VERSION)
        libc = _installed_root("GTK4_LIBC_ROOT", "glibc")
        import platform
        arch = {"arm64": "aarch64", "AMD64": "x86_64"}.get(platform.machine(), platform.machine())
        assert arch in {"x86_64", "aarch64"}, f"unsupported native architecture: {arch}"
        command = [sys.executable, str(VERIFIER), "--runtime-root", str(runtime),
                   "--libc-root", str(libc), "--arch", arch,
                   "--consumer-root", str(real_consumer)]
        if not (os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY")):
            xvfb = shutil.which("xvfb-run")
            if xvfb:
                command = [xvfb, "-a", *command]
        if not os.environ.get("DBUS_SESSION_BUS_ADDRESS"):
            dbus = shutil.which("dbus-run-session")
            if dbus:
                command = [dbus, "--", *command]
        result = subprocess.run(command, text=True, capture_output=True, timeout=360)
        assert result.returncode == 0, result.stdout + result.stderr
        assert "complete native gtk4-runtime acceptance" in result.stdout
