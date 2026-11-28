"""验证 jj 的资源契约、隔离安装及本地 Git 仓库操作。"""
import os
from pathlib import Path
import shutil
import subprocess
from tempfile import TemporaryDirectory

import pytest

from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_config_registers_package_name, assert_no_exec_xvm,
    assert_no_bashrc_modification, assert_no_direct_path_modification,
    assert_no_direct_pkg_manager, assert_uses_new_api,
)
from tests.lib.platform_utils import under_test, xlings_home
from tests.lib.xpkg_parser import parse_xpkg

ROOT = Path(__file__).resolve().parents[2]
PKG_FILE = "pkgs/j/jj.lua"


def run_command(args, **kwargs):
    """直接运行参数数组，避免登录 Shell 覆盖隔离环境。"""
    result = subprocess.run(args, text=True, capture_output=True, timeout=180, **kwargs)
    assert result.returncode == 0, result.stdout + result.stderr
    assert "[error]" not in result.stderr.lower(), result.stderr
    return result.stdout


def xlings(*args):
    """通过测试环境的固定客户端执行包操作。"""
    suffix = ".exe" if os.name == "nt" else ""
    binary = Path(xlings_home()) / "bin" / ("xlings" + suffix)
    return run_command([str(binary), *args], cwd=ROOT)


def jj_binary():
    """定位当前隔离环境的 jj 路由。"""
    filename = "jj.exe" if os.name == "nt" else "jj"
    for subos in (os.environ.get("XLINGS_TEST_SUBOS", "current"), "default"):
        binary = Path(xlings_home()) / "subos" / subos / "bin" / filename
        if binary.is_file():
            return str(binary)
    pytest.fail("The isolated jj shim is missing")


class TestStatic:
    @pytest.mark.static
    def test_metadata(self):
        """检查必要元数据和程序注册声明。"""
        meta = parse_xpkg(PKG_FILE)
        for check in (assert_required_fields, assert_valid_spec, assert_valid_type,
                      assert_config_registers_package_name):
            check(meta)

    @pytest.mark.static
    def test_resource_matrix_and_dependencies(self):
        """验证下载与更新模板一致，并拒绝依赖未覆盖的平台。"""
        script = r'''
import = function() end
dofile(arg[1])
assert(package.spec == "2" and package.ci.mirror)
assert(package.xpm.macosx == nil)
local expected = {linux = {"x86_64", "aarch64"}, windows = {"x86_64"}}
for platform, arches in pairs(expected) do
    local p = package.xpm[platform]
    assert(p.deps.runtime[1] == "xim:git@>=2.42.0")
    local version = p.latest.ref
    local entry = p[version]
    local count = 0
    for _ in pairs(entry.sha256) do count = count + 1 end
    assert(count == #arches)
    for _, arch in ipairs(arches) do
        assert(#entry.sha256[arch] == 64 and entry.sha256[arch]:match("^%x+$"))
        local url = p.source:gsub("%${version}", version):gsub("%${arch_alias}", entry.arch_alias[arch])
        local update = package.extensions.autoupdate.resources.GLOBAL.url[platform][arch]
        assert(url == update:gsub("%${tag}", "v" .. version))
    end
end
'''
        run_command([shutil.which("lua5.4") or "lua", "-", PKG_FILE], input=script, cwd=ROOT)


class TestIsolation:
    @pytest.mark.isolation
    def test_hooks_preserve_user_environment(self):
        """禁止安装钩子修改 Shell、PATH 或调用宿主包管理器。"""
        for check in (assert_no_exec_xvm, assert_no_bashrc_modification,
                      assert_no_direct_path_modification, assert_no_direct_pkg_manager,
                      assert_uses_new_api):
            check(PKG_FILE)


class TestIndex:
    @pytest.mark.index
    def test_register(self):
        """注册当前工作树中的待测配方。"""
        xlings("config", "--add-xpkg", str(ROOT / PKG_FILE))


class TestLifecycle:
    @pytest.mark.lifecycle
    def test_install(self):
        """安装待测版本并确认真实程序路由存在。"""
        xlings("install", under_test("jj"), "-y")
        assert Path(jj_binary()).is_file()


class TestVerify:
    @pytest.mark.verify
    def test_version(self):
        """检查安装的程序版本。"""
        expected = os.environ.get("XLINGS_TEST_VERSION", "0.47.1")
        assert expected in run_command([jj_binary(), "--version"])

    @pytest.mark.verify
    def test_local_repository_and_restore(self, tmp_path):
        """在临时仓库中记录更改，再恢复文件以验证实际版本控制操作。"""
        # Windows 的索引段文件名长达 128 字符，短路径可容纳完整仓库布局
        with TemporaryDirectory(prefix="jj") as short_root:
            self.check_repository(Path(short_root), tmp_path)

    def check_repository(self, repo, tmp_path):
        """验证本地仓库内修改与恢复文件的行为。"""
        env = os.environ.copy()
        env.update(JJ_CONFIG=str(tmp_path / "empty.toml"), JJ_USER="Package Test",
                   JJ_EMAIL="package-test@example.invalid", GIT_CONFIG_NOSYSTEM="1",
                   GIT_CONFIG_GLOBAL=str(tmp_path / "gitconfig"))
        binary = jj_binary()
        run_command([binary, "git", "init", str(repo)], env=env)
        (repo / "sample.txt").write_text("before\n", encoding="utf-8")
        run_command([binary, "describe", "-m", "first snapshot"], cwd=repo, env=env)
        run_command([binary, "new"], cwd=repo, env=env)
        (repo / "sample.txt").write_text("after\n", encoding="utf-8")
        assert "after" in run_command([binary, "diff", "--git"], cwd=repo, env=env)
        run_command([binary, "restore", "sample.txt"], cwd=repo, env=env)
        assert (repo / "sample.txt").read_text(encoding="utf-8") == "before\n"
