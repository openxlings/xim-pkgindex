"""测试 emsdk 包"""
import glob
import os
import re
import subprocess

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
    assert_command_output, assert_xvm_registered, assert_valid_xvm_node_kinds,
)
from tests.lib.platform_utils import skip_if_not, xpkgs_dir

PKG = "emsdk"
PKG_FILE = "pkgs/e/emsdk.lua"

# The module surface's shape, measured directly off the pinned 6.0.9 payload
# and recorded in the recipe's own header comment: 110 std/*.inc partitions,
# 21 std.compat/*.inc partitions, plus std.cppm/std.compat.cppm/CMakeLists.txt.
EXPECTED_STD_INC_COUNT = 110
EXPECTED_STD_COMPAT_INC_COUNT = 21
EXPECTED_LIBCPP_VERSION = "220108"

IMPORT_STD_PROBE = r'''
import std;
int main() {
  std::vector<int> v{3,1,2};
  std::ranges::sort(v);
  std::print("{}-{}-{}\n", v[0], v[1], v[2]);
}
'''


def _code(content: str) -> str:
    """Strip lua line comments so static assertions see only real declarations."""
    return "\n".join(
        line for line in content.splitlines() if not line.lstrip().startswith("--")
    )


@pytest.fixture(scope='module')
def meta():
    return parse_xpkg(PKG_FILE)


class TestStatic:
    @pytest.mark.static
    def test_required_fields(self, meta):
        assert_required_fields(meta)

    @pytest.mark.static
    def test_valid_spec(self, meta):
        assert_valid_spec(meta)

    @pytest.mark.static
    def test_valid_type(self, meta):
        assert_valid_type(meta)

    @pytest.mark.static
    def test_no_typos(self):
        assert_no_typos(PKG_FILE)

    @pytest.mark.static
    def test_valid_xvm_node_kinds(self, meta):
        assert_valid_xvm_node_kinds(meta)

    @pytest.mark.static
    def test_does_not_use_os_arch(self, meta):
        """`os.arch()` is not bound in the xim install-hook runtime on this
        engine (node.lua / jdk-zulu.lua record the workaround). Unlike
        those, this archive's top-level directory is named `install` on
        every architecture this recipe declares, so this recipe has no
        reason to call it at all."""
        code = _code(meta.raw_content)
        assert "os.arch()" not in code

    @pytest.mark.static
    def test_no_invented_cn_mirror(self, meta):
        """storage.googleapis.com is not re-hosted; the recipe follows the
        'not yet mirrored' shape (qemu-user-aarch64.lua) rather than
        inventing a gitcode.com/xlings-res URL that does not exist."""
        code = _code(meta.raw_content)
        assert "gitcode.com" not in code
        assert "storage.googleapis.com/webassembly/emscripten-releases-builds" in code

    @pytest.mark.static
    def test_per_arch_sha256_declared(self, meta):
        rc = meta.raw_content
        assert re.search(r'x86_64\s*=\s*"[0-9a-f]{64}"', rc), "no x86_64 sha256"
        assert re.search(r'aarch64\s*=\s*"[0-9a-f]{64}"', rc), "no aarch64 sha256"

    @pytest.mark.static
    def test_url_bakes_in_a_commit_hash_not_a_moving_alias(self, meta):
        """emscripten-releases-tags.json's `latest` alias moves upstream
        several times a week; the recipe must resolve it once, here, to a
        specific git hash rather than re-resolving `latest` at install
        time."""
        rc = meta.raw_content
        assert re.search(r'emscripten-releases-builds/linux/[0-9a-f]{40}/', rc), \
            "the source URL must name a resolved 40-hex-char commit hash"

    @pytest.mark.static
    def test_records_the_libcpp_version_pairing(self, meta):
        """Task-required: the _LIBCPP_VERSION <-> llvmorg pairing must be a
        comment AND an enforced check, not just documentation."""
        code = _code(meta.raw_content)
        assert "EXPECTED_LIBCPP_VERSION" in code
        assert f'"{EXPECTED_LIBCPP_VERSION}"' in code
        assert "__check_libcxx_version" in code
        rc = meta.raw_content
        assert "22.1.8" in rc, "the llvmorg tag this _LIBCPP_VERSION maps to must be documented"

    @pytest.mark.static
    def test_declares_the_measured_elf_closure_as_runtime_deps(self, meta):
        """Enumerated from `readelf -d` over every ELF file in the payload
        (30 files, 8 external NEEDED entries), not written from memory --
        contributing.md R7."""
        code = _code(meta.raw_content)
        for dep in ("xim:glibc", "xim:gcc-runtime", "xim:zlib", "xim:node"):
            assert dep in code, f"missing declared dependency {dep}"

    @pytest.mark.static
    def test_declares_patchelf_as_a_build_dep(self, meta):
        code = _code(meta.raw_content)
        assert "xim:patchelf" in code

    @pytest.mark.static
    def test_does_not_register_bin_tools_under_bare_names(self, meta):
        """bin/clang, bin/wasm-opt etc. must never be registered under
        their bare names: xim:llvm already owns `clang`/`clang++`, and
        registering this payload's copies under the same names would
        silently shadow one toolchain with the other depending on install
        order. `"clang"` legitimately appears elsewhere (the install()
        completeness probe checks the file exists); what must never appear
        is an xvm registration call naming it."""
        code = _code(meta.raw_content)
        for name in ("clang", "clang++", "wasm-opt", "lld"):
            assert f'xvm.add("{name}"' not in code, f'xvm.add("{name}" must not appear'
            assert f"alias = \"{name}\"" not in code, f'alias = "{name}" must not appear'

    @pytest.mark.static
    def test_entry_points_come_from_the_emscripten_dir_not_bin(self, meta):
        code = _code(meta.raw_content)
        assert 'path.join(dir, "emscripten")' in code
        # bindir for xvm.add must never be the native-tool `bin/` directory.
        assert 'bindir = path.join(dir, "bin")' not in code

    @pytest.mark.static
    def test_config_writes_final_paths_before_first_invocation(self, meta):
        """DO NOT RELOCATE finding: `.emscripten` must be written with the
        final install_dir-based paths, and the first-ever `em++` invocation
        must happen after that write, or a later path change wipes
        emscripten/cache/sysroot (measured)."""
        code = _code(meta.raw_content)
        install_body = code[code.index("function install()"):]
        assert install_body.index("os.mv(extracted, dir)") \
            < install_body.index("__write_emscripten_config(dir") \
            < install_body.index("__selfcheck_import_std(dir")

    @pytest.mark.static
    def test_selfcheck_runs_the_precompile_and_link_and_run_sequence(self, meta):
        code = _code(meta.raw_content)
        assert "--precompile" in code
        assert "-fmodule-file=std=" in code
        assert '"1-2-3"' in code or "'1-2-3'" in code


class TestIndex:
    @pytest.mark.index
    def test_xim_add(self):
        assert_xim_add_succeeds(PKG_FILE)


class TestIsolation:
    @pytest.mark.isolation
    def test_no_exec_xvm(self):
        assert_no_exec_xvm(PKG_FILE)

    @pytest.mark.isolation
    def test_no_bashrc(self):
        assert_no_bashrc_modification(PKG_FILE)

    @pytest.mark.isolation
    def test_no_path_modification(self):
        assert_no_direct_path_modification(PKG_FILE)

    @pytest.mark.isolation
    def test_new_api(self):
        assert_uses_new_api(PKG_FILE)


class TestLifecycle:
    @pytest.mark.lifecycle
    @skip_if_not('linux')
    def test_install(self):
        # install() itself compiles the module surface to a BMI, links and
        # runs an `import std` probe under node -- slower than a plain
        # unpack-and-move install, and a ~285 MB download besides.
        assert_install_succeeds(PKG, timeout=600)


def _payload_dir() -> str:
    for ns in ("xim", "local"):
        hits = sorted(d for d in glob.glob(os.path.join(xpkgs_dir(), f"{ns}-x-emsdk", "*"))
                      if os.path.isdir(d))
        if hits:
            return hits[-1]
    pytest.fail(f"no emsdk payload in the store ({xpkgs_dir()})")


def _node_bin() -> str:
    for ns in ("xim", "local"):
        hits = sorted(d for d in glob.glob(os.path.join(xpkgs_dir(), f"{ns}-x-node", "*"))
                      if os.path.isdir(d))
        if hits:
            node = os.path.join(hits[-1], "bin", "node")
            if os.path.isfile(node):
                return node
    pytest.fail(f"no xim:node payload in the store ({xpkgs_dir()})")


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_emcc_version(self):
        assert_command_output("emcc --version", contains="Emscripten")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_xvm_emsdk(self):
        assert_xvm_registered("emsdk")
        assert_xvm_registered("em++")
        assert_xvm_registered("emcc")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_installed_layout(self):
        """The layout the recipe's header comment documents as what a
        consumer (mcpp's toolchain registry) hardcodes."""
        d = _payload_dir()
        assert os.path.isfile(os.path.join(d, "bin", "clang"))
        assert os.path.isfile(os.path.join(d, "emscripten", "em++"))
        assert os.path.isfile(os.path.join(d, "emscripten", ".emscripten"))
        assert os.path.isdir(os.path.join(d, "emscripten", "cache", "sysroot"))

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_module_surface_file_count(self):
        """The 134-file generated surface, present as shipped -- this
        recipe generates nothing (see the header comment: unlike
        xim:android-ndk, this vendor's tarball already carries it,
        self-consistent with its own libc++ by construction)."""
        d = _payload_dir()
        v1 = os.path.join(d, "emscripten", "cache", "sysroot", "share", "libc++", "v1")
        assert os.path.isfile(os.path.join(v1, "std.cppm"))
        assert os.path.isfile(os.path.join(v1, "std.compat.cppm"))
        std_incs = [f for f in os.listdir(os.path.join(v1, "std")) if f.endswith(".inc")]
        compat_incs = [f for f in os.listdir(os.path.join(v1, "std.compat")) if f.endswith(".inc")]
        assert len(std_incs) == EXPECTED_STD_INC_COUNT, \
            f"expected {EXPECTED_STD_INC_COUNT} std/*.inc, found {len(std_incs)}"
        assert len(compat_incs) == EXPECTED_STD_COMPAT_INC_COUNT, \
            f"expected {EXPECTED_STD_COMPAT_INC_COUNT} std.compat/*.inc, found {len(compat_incs)}"

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_libcpp_version_matches_the_recorded_pairing(self):
        d = _payload_dir()
        cfg = os.path.join(d, "emscripten", "cache", "sysroot", "include", "c++", "v1", "__config")
        with open(cfg) as f:
            content = f.read()
        m = re.search(r'_LIBCPP_VERSION\s+(\d+)', content)
        assert m, "no _LIBCPP_VERSION in __config"
        assert m.group(1) == EXPECTED_LIBCPP_VERSION

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_no_home_dependence(self):
        """A fresh install must not have left a config file under $HOME --
        that is what a CI runner / sandbox looks like. `em++` resolves its
        own embedded `.emscripten` beside itself instead (see the recipe's
        EM++ IS A WRAPPER header comment)."""
        home_cfg = os.path.expanduser("~/.emscripten")
        assert not os.path.isfile(home_cfg), \
            f"{home_cfg} exists; emsdk must resolve its own embedded .emscripten"

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_import_std_compiles_links_and_runs_under_node(self):
        """The task's own end-to-end proof, run again independently of
        install()'s self-check, directly against the installed payload and
        the installed xim:node dependency -- no shim, no $HOME, no PATH
        beyond what a plain python3 needs."""
        d = _payload_dir()
        emxx = os.path.join(d, "emscripten", "em++")
        stdcppm = os.path.join(d, "emscripten", "cache", "sysroot", "share", "libc++", "v1", "std.cppm")
        node = _node_bin()

        tmpdir = subprocess.run(["mktemp", "-d"], capture_output=True, text=True, check=True).stdout.strip()
        app_cpp = os.path.join(tmpdir, "app.cpp")
        std_pcm = os.path.join(tmpdir, "std.pcm")
        app_js = os.path.join(tmpdir, "app.js")
        with open(app_cpp, "w") as f:
            f.write(IMPORT_STD_PROBE)

        env = {"HOME": "/nonexistent", "PATH": "/usr/bin:/bin"}

        r1 = subprocess.run([emxx, "-std=c++23", "--precompile", stdcppm, "-o", std_pcm],
                             capture_output=True, text=True, env=env, timeout=120)
        assert r1.returncode == 0, f"precompile failed: {r1.stdout}\n{r1.stderr}"
        assert os.path.isfile(std_pcm)

        r2 = subprocess.run(
            [emxx, "-std=c++23", f"-fmodule-file=std={std_pcm}", app_cpp, std_pcm, "-o", app_js],
            capture_output=True, text=True, env=env, timeout=120,
        )
        assert r2.returncode == 0, f"compile/link failed: {r2.stdout}\n{r2.stderr}"
        assert os.path.isfile(app_js)
        assert os.path.getsize(os.path.join(tmpdir, "app.wasm")) > 0

        r3 = subprocess.run([node, app_js], capture_output=True, text=True, env=env, timeout=30)
        assert r3.returncode == 0, f"node failed: {r3.stdout}\n{r3.stderr}"
        assert "1-2-3" in r3.stdout, f"unexpected node output: {r3.stdout!r}"
