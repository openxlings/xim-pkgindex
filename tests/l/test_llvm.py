"""测试 llvm 包"""
import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds, assert_install_succeeds,
    assert_command_output, assert_xvm_registered,
)
from tests.lib.platform_utils import skip_if_not

PKG = "llvm"
PKG_FILE = "pkgs/l/llvm.lua"


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
    def test_supports_22_1_8(self, meta):
        # 22.1.8 available on macOS (slim carve) + windows (XLINGS_RES);
        # linux 22.1.8 is pending the maintainer slim-build pipeline.
        rc = meta.raw_content
        assert '["22.1.8"]' in rc, "missing 22.1.8 version entry"
        assert "llvm-22.1.8-macosx-arm64.tar.xz" in rc, \
            "macosx must reference the 22.1.8 slim toolchain asset"

    @pytest.mark.static
    def test_macosx_uses_slim_dual_mirror(self, meta):
        # macOS ships the slim carved toolchain on both mirrors (the 1.4GB
        # upstream monolith is no longer mirrored).
        rc = meta.raw_content
        assert "llvm-20.1.7-macosx-arm64.tar.xz" in rc
        assert "github.com/xlings-res/llvm" in rc and "gitcode.com/xlings-res/llvm" in rc


    @pytest.mark.static
    def test_dll_and_exe_filters_are_payload_gated(self, meta):
        """`.dll`/`.exe`是文件本身的属性，不是 host 的属性。

        两个过滤器原先都写在 `os.host() == "windows"` 里，读起来像"这种
        文件只会出现在那儿"。并不是：把另一台机器的 store 搬过来、或者在
        真实 home 上跑一次 Windows 目标的测试，Linux 的 store 里就会躺着
        Windows 载荷。于是 Linux 上把 libomp.dll 注册成了 program，把
        clang.exe 注册成了名叫 "clang.exe" 的 program —— 29 条注册，没有
        一条能跑。
        """
        rc = meta.raw_content
        assert 'os.host() == "windows" and name:sub(-4) == ".dll"' not in rc, \
            "a .dll is never a program on any host"
        assert 'os.host() == "windows" and filename:sub(-4):lower() == ".exe"' not in rc, \
            "the .exe suffix belongs to the file, not to the host"
        assert 'if name:sub(-4):lower() == ".dll" then' in rc, \
            "the .dll filter must apply on every host"

    @pytest.mark.static
    def test_alias_table_all_missing_fails_the_install(self, meta):
        """alias 全军覆没必须是失败，不是 6 条 warning + 报告成功。

        这是 #447 那道门禁（"声明了 program 却零注册即失败"）的补集：
        那条抓"一个都没注册"，这条抓"注册了，但没有一个是本平台 alias 表
        里点名的工具" —— 正是 Windows 载荷落在 Linux 上的形状。
        """
        rc = meta.raw_content
        assert "alias_hits" in rc, "the alias loop must count its hits"
        assert "#aliases > 0 and alias_hits == 0" in rc, \
            "an alias table where every entry missed must fail the install"


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
    def test_install(self):
        assert_install_succeeds(PKG)


class TestVerify:
    @pytest.mark.verify
    def test_clang(self):
        assert_command_output("clang --version")

    @pytest.mark.verify
    def test_xvm_llvm(self):
        assert_xvm_registered("llvm")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_clang_compile_c(self):
        assert_command_output(
            r'''
tmpdir="$(mktemp -d)"
cat >"$tmpdir/hello.c" <<'SRC'
#include <stdio.h>
int main() { printf("hello from llvm clang c\n"); return 0; }
SRC
clang -fuse-ld=lld "$tmpdir/hello.c" -o "$tmpdir/hello"
"$tmpdir/hello"
''',
            contains="hello from llvm clang c",
        )

    @pytest.mark.verify
    @skip_if_not('macosx')
    def test_clangxx_cpp23_import_std(self):
        assert_command_output(
            r'''
tmpdir="$(mktemp -d)"
cat >"$tmpdir/main.cpp" <<'CPP'
import std;

int main() {
    std::println("hello from llvm clang++ c++23");
    return 0;
}
CPP
resdir="$(clang++ --print-resource-dir)"
llvm_home="$(cd "$resdir/../../.." && pwd)"
stdcppm="$llvm_home/share/libc++/v1/std.cppm"
clang++ -std=c++23 -fexperimental-library -x c++-module --precompile "$stdcppm" -o "$tmpdir/std.pcm"
clang++ -std=c++23 -fexperimental-library "$tmpdir/main.cpp" -fmodule-file=std="$tmpdir/std.pcm" -o "$tmpdir/hello"
"$tmpdir/hello"
''',
            contains="hello from llvm clang++ c++23",
        )
