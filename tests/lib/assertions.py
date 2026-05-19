"""通用断言函数 — 覆盖静态分析、隔离合规、生命周期、功能验证"""
import re
import os
import subprocess
import pytest
from tests.lib.xpkg_parser import XpkgMeta, parse_xpkg
from tests.lib.xvm_client import XvmClient
from tests.lib.xlings_client import XlingsClient

# ═══════════════════════════════════════════
#  L0: 静态分析
# ═══════════════════════════════════════════

KNOWN_TYPOS = {
    r"\bdebain\b": "debian",
}


def assert_required_fields(meta: XpkgMeta):
    """检查包必填字段: name, description, type, spec"""
    if meta.is_ref:
        return
    missing = []
    if not meta.name:
        missing.append("name")
    if not meta.description:
        missing.append("description")
    if not meta.pkg_type:
        missing.append("type")
    if not meta.spec:
        missing.append("spec")
    assert not missing, f"缺少必填字段: {', '.join(missing)}"


def assert_valid_spec(meta: XpkgMeta):
    """spec 版本必须是已知值"""
    if meta.is_ref:
        return
    assert meta.spec in ("0", "1"), f"未知 spec 版本: {meta.spec}"


def assert_valid_type(meta: XpkgMeta):
    """type 必须是已知值"""
    if meta.is_ref:
        return
    valid = {"package", "script", "config", "template", "bugfix"}
    assert meta.pkg_type in valid, f"未知 type: {meta.pkg_type}, 应为 {valid}"


def assert_config_registers_package_name(meta: XpkgMeta):
    """[Spec D1] config hook 必须通过 xvm.add() 注册 package.name

    豁免条件:
    - ref 包 (无 config hook)
    - 有自定义 installed() hook 的包
    - type 为 script/config/bugfix/template 的包
    """
    if meta.is_ref:
        return
    if meta.has_installed:
        return
    if meta.pkg_type in ("script", "config", "bugfix", "template"):
        return
    if not meta.has_config:
        pytest.fail(
            f"[Spec D3] '{meta.name}': 普通包必须定义 config hook，"
            f"且在其中通过 xvm.add(package.name) 注册包名"
        )

    content = meta.raw_content
    # Check for xvm.add(package.name) or xvm:add(package.name) — the standard pattern
    has_pkg_name_var = bool(re.search(r'xvm[.:]\s*add\s*\(\s*package\.name', content))
    # Also accept xvm.add("literal-name") where literal matches meta.name
    has_pkg_name_lit = bool(re.search(
        rf'xvm[.:]\s*add\s*\(\s*["\']' + re.escape(meta.name) + r'["\']',
        content
    ))
    assert has_pkg_name_var or has_pkg_name_lit, (
        f"[Spec D1] '{meta.name}': config hook 必须通过 xvm.add(package.name) "
        f"注册包名。当前 config 中未找到 xvm.add(package.name) 或 "
        f'xvm.add("{meta.name}", ...)。'
        f"\n  fix: 在 config() 中添加 xvm.add(package.name) 注册为 marker"
    )


def assert_no_typos(lua_path: str):
    """检查已知拼写错误"""
    if not os.path.isabs(lua_path):
        from tests.lib.platform_utils import project_root
        lua_path = os.path.join(project_root(), lua_path)
    with open(lua_path, "r", encoding="utf-8") as f:
        content = f.read()
    for pattern, correct in KNOWN_TYPOS.items():
        match = re.search(pattern, content)
        assert not match, f"拼写错误: '{match.group()}' 应为 '{correct}'"


# ═══════════════════════════════════════════
#  L2: 隔离合规
# ═══════════════════════════════════════════

def _read_lua(lua_path: str) -> str:
    if not os.path.isabs(lua_path):
        from tests.lib.platform_utils import project_root
        lua_path = os.path.join(project_root(), lua_path)
    with open(lua_path, "r", encoding="utf-8") as f:
        return f.read()


def assert_no_exec_xvm(lua_path: str):
    """不应通过 os.exec 直接调用 xvm add/remove，应使用 xvm.add() API"""
    content = _read_lua(lua_path)
    assert not re.search(r'os\.exec\(.*xvm\s+add', content), \
        "使用了 os.exec(\"xvm add ...\"), 应改为 xvm.add() API"


def assert_no_bashrc_modification(lua_path: str):
    """不应修改用户 shell 配置文件"""
    content = _read_lua(lua_path)
    assert not re.search(r'append_bashrc|append_to_shell_profile', content), \
        "修改了用户 shell 配置 (bashrc/profile), 破坏 subos 隔离"


def assert_no_direct_path_modification(lua_path: str):
    """不应直接操作 PATH 环境变量"""
    content = _read_lua(lua_path)
    assert not re.search(r'os\.addenv\(.*PATH|os\.setenv\(.*PATH', content), \
        "直接操作 PATH 环境变量, 应通过 xvm shim 路由"


def assert_uses_new_api(lua_path: str):
    """应使用新版 API (xim.libxpkg.*)，不使用旧版 (xim.base.runtime 等)"""
    content = _read_lua(lua_path)
    old_apis = []
    if 'import("xim.base.runtime")' in content:
        old_apis.append("xim.base.runtime")
    if 'import("common")' in content:
        old_apis.append("common")
    if 'import("platform")' in content:
        old_apis.append("platform")
    assert not old_apis, f"使用旧 API: {', '.join(old_apis)}, 建议迁移到 xim.libxpkg.*"


def assert_no_direct_pkg_manager(lua_path: str):
    """不应直接调用系统包管理器"""
    content = _read_lua(lua_path)
    patterns = [
        (r'(?<!")brew\s+install\b', "brew install"),
        (r'apt\s+install\b', "apt install"),
        (r'pacman\s+-S\b', "pacman -S"),
    ]
    for pat, name in patterns:
        assert not re.search(pat, content), \
            f"直接调用 {name}, 应通过 deps 声明或 pkgmanager"


# ═══════════════════════════════════════════
#  L1: 索引注册
# ═══════════════════════════════════════════

def assert_xim_add_succeeds(lua_path: str):
    """xlings config --add-xpkg 能成功注册"""
    if not os.path.isabs(lua_path):
        from tests.lib.platform_utils import project_root
        lua_path = os.path.join(project_root(), lua_path)
    ok, out = XlingsClient.xim_add_xpkg(lua_path)
    assert ok, f"xlings config --add-xpkg 失败: {out}"


# ═══════════════════════════════════════════
#  L3: 生命周期
# ═══════════════════════════════════════════

def assert_install_succeeds(pkg_name: str, timeout: int = 180):
    """xlings install 成功"""
    ok, out = XlingsClient.install(pkg_name, timeout=timeout)
    assert ok, f"安装失败: {out[-200:]}"


def assert_uninstall_succeeds(pkg_name: str):
    """xlings remove 成功"""
    ok, out = XlingsClient.remove(pkg_name)
    assert ok, f"卸载失败: {out[-200:]}"


# ═══════════════════════════════════════════
#  L4: 功能验证
# ═══════════════════════════════════════════

def assert_command_available(cmd: str):
    """命令可执行"""
    r = subprocess.run(
        ["bash", "-l", "-c", f"which {cmd}"],
        capture_output=True, text=True, timeout=5
    )
    assert r.returncode == 0, f"命令不可用: {cmd}"


def assert_command_output(cmd: str, contains: str = None, regex: str = None):
    """命令输出包含指定内容"""
    r = subprocess.run(
        ["bash", "-l", "-c", cmd],
        capture_output=True, text=True, timeout=15
    )
    out = r.stdout + r.stderr
    assert r.returncode == 0, f"命令执行失败 (exit={r.returncode}): {out[:200]}"
    if contains:
        assert contains in out, f"输出中未找到 '{contains}', 实际输出: {out[:200]}"
    if regex:
        assert re.search(regex, out), f"输出不匹配 regex '{regex}', 实际输出: {out[:200]}"


def assert_xvm_registered(target: str):
    """目标已在 xvm 中注册"""
    assert XvmClient.is_registered(target), f"xvm 未注册: {target}"


def assert_xvm_shim_exists(target: str):
    """subos/current/bin 中存在对应 shim"""
    assert XvmClient.shim_exists(target), f"shim 不存在: {target}"


def assert_platform_supported(meta: XpkgMeta, platform: str):
    """包支持指定平台"""
    assert platform in meta.platforms, f"不支持平台: {platform}, 支持: {list(meta.platforms.keys())}"
