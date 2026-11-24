"""测试 jdk-temurin 包"""
import os
import re
import shutil
import subprocess

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

PKG = "jdk-temurin"
PKG_FILE = "pkgs/j/jdk-temurin.lua"

PLATFORMS = ("linux", "macosx", "windows")
# 4 个 5-asset LTS 版本 (25 / 21 / 17 / 11) + 4-asset 的 8 LTS (macosx 无 aarch64)
RESOURCE_COUNT = 24
PER_VERSION_RESOURCES = 5
VERSIONS = {
    "25.0.4+7": ("25.0.4",),
    "21.0.13.1+2": ("21", "21.0.13.1"),
    "17.0.21.1+2": ("17", "17.0.21.1"),
    "11.0.33+10": ("11", "11.0.33"),
    "8.0.512+9": ("8", "8.0.512", "8u512b09"),
}
ALIAS_TO_CANONICAL = {
    alias: canonical
    for canonical, aliases in VERSIONS.items()
    for alias in aliases
}


def _run_lua(script, *args):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if not lua:
        pytest.skip("Lua interpreter is unavailable")
    return subprocess.run(
        [lua, "-", *args], input=script, text=True, capture_output=True, check=True
    ).stdout


def _code(content: str) -> str:
    """去掉 lua 行注释, 让下面的静态断言只看真实声明 (注释里也写了这些字面量)"""
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
    def test_latest_and_version_aliases(self, meta):
        """`latest` 保持指向 25.0.4+7, 且每个 LTS 系列均覆盖主版本和 java --version 别名"""
        code = _code(meta.raw_content)
        latest_refs = re.findall(
            r'\["latest"\]\s*=\s*\{\s*ref\s*=\s*"25\.0\.4\+7"\s*\}',
            code,
        )
        assert len(latest_refs) == len(PLATFORMS), \
            f"latest 别名应保持指向 25.0.4+7 并覆盖 {PLATFORMS}, 实际 {len(latest_refs)} 个"

        for canonical, aliases in VERSIONS.items():
            blocks = re.findall(rf'\["{re.escape(canonical)}"\]\s*=\s*\{{', code)
            assert len(blocks) == len(PLATFORMS), \
                f"{canonical} 版本块应覆盖 {PLATFORMS}, 实际 {len(blocks)} 个"
            for alias in aliases:
                matches = re.findall(
                    rf'\["{re.escape(alias)}"\]\s*=\s*\{{\s*ref\s*=\s*"{re.escape(canonical)}"\s*\}}',
                    code,
                )
                assert len(matches) == len(PLATFORMS), \
                    f"{alias} -> {canonical} 别名应覆盖 {PLATFORMS}, 实际 {len(matches)} 个"

    @pytest.mark.static
    def test_manual_maintenance_without_autoupdate(self, meta):
        """多主版本 LTS (25/21/17/11/8) 统一人工维护, 不声明 extensions.autoupdate"""
        assert "autoupdate" not in _code(meta.raw_content)

    @pytest.mark.static
    def test_mirrors_and_hashes(self, meta):
        """校验每个 LTS 版本的上游/CN 镜像与 sha256 数量"""
        content = _code(meta.raw_content)
        gitcode_cn = re.findall(
            r'CN = "https://gitcode\.com/xlings-res/jdk-temurin/[^"]+"', content)
        tuna_21_cn = re.findall(
            r'CN = "https://mirrors\.tuna\.tsinghua\.edu\.cn/Adoptium/21/[^"]+"', content)
        tuna_17_cn = re.findall(
            r'CN = "https://mirrors\.tuna\.tsinghua\.edu\.cn/Adoptium/17/[^"]+"', content)
        tuna_8_cn = re.findall(
            r'CN = "https://mirrors\.tuna\.tsinghua\.edu\.cn/Adoptium/8/[^"]+"', content)
        global_25 = re.findall(
            r'GLOBAL = "https://github\.com/adoptium/temurin25-binaries/[^"]+"', content)
        global_21 = re.findall(
            r'GLOBAL = "https://github\.com/adoptium/temurin21-binaries/[^"]+"', content)
        global_17 = re.findall(
            r'GLOBAL = "https://github\.com/adoptium/temurin17-binaries/[^"]+"', content)
        global_11 = re.findall(
            r'url = "https://github\.com/adoptium/temurin11-binaries/[^"]+"', content)
        global_8_single = re.findall(
            r'url = "https://github\.com/adoptium/temurin8-binaries/[^"]+"', content)
        global_8_paired = re.findall(
            r'GLOBAL = "https://github\.com/adoptium/temurin8-binaries/[^"]+"', content)
        shas = re.findall(r'sha256 = "[0-9a-f]{64}"', content)

        assert len(global_25) == PER_VERSION_RESOURCES
        assert len(gitcode_cn) == PER_VERSION_RESOURCES
        assert len(global_21) == PER_VERSION_RESOURCES
        assert len(tuna_21_cn) == PER_VERSION_RESOURCES
        assert len(global_17) == PER_VERSION_RESOURCES
        assert len(tuna_17_cn) == PER_VERSION_RESOURCES
        assert len(global_11) == PER_VERSION_RESOURCES
        # Temurin 8: 4 architectures total (no macosx aarch64);
        # linux x86_64 is GLOBAL-only (TUNA rotated to 8u514b01),
        # while linux aarch64 / macosx x86_64 / windows x86_64 pair with TUNA CN.
        assert len(global_8_single) == 1
        assert len(global_8_paired) == 3
        assert len(tuna_8_cn) == 3
        assert len(shas) == RESOURCE_COUNT, f"sha256 数量: {len(shas)}"
        # GitCode 的 release API 会把路径里的 `+` 解成空格然后 404, 镜像 tag 用 `_`。
        assert "%2B" not in "".join(gitcode_cn), "GitCode CN 镜像 tag 不能带 URL 编码的 '+'"

    @pytest.mark.static
    def test_macos_bundle_layout(self, meta):
        """macOS 是 .jdk bundle: bin 在 Contents/Home 下, 不能按 linux 布局搬运"""
        content = _code(meta.raw_content)
        assert re.search(r'os\.host\(\)\s*==\s*"macosx"', content), \
            "install 必须区分 macosx 布局"
        assert re.search(r'"Contents"\s*,\s*"Home"', content), \
            "macOS payload 必须是 <root>/Contents/Home"

    @pytest.mark.static
    def test_hooks_handle_jdk8_and_jdk21_layouts(self, tmp_path):
        """Lua 沙箱验证 install/config/uninstall 对 JDK 8 (jdk8u512-b09, 无 jshell) 与 JDK 11+ 的处理"""
        _run_lua('''
local root = arg[2]
local cases = {
    { ver = "8.0.512+9", host = "linux",   top = "jdk8u512-b09",   progs = {"java","javac","jar","javadoc"} },
    { ver = "8.0.512+9", host = "macosx",  top = "jdk8u512-b09",   progs = {"java","javac","jar","javadoc"} },
    { ver = "8.0.512+9", host = "windows", top = "jdk8u512-b09",   progs = {"java","javac","jar","javadoc"} },
    { ver = "21.0.13.1+2", host = "linux",  top = "jdk-21.0.13.1+2", progs = {"java","javac","jar","javadoc","jshell"} },
    { ver = "21.0.13.1+2", host = "macosx", top = "jdk-21.0.13.1+2", progs = {"java","javac","jar","javadoc","jshell"} },
}
for i, c in ipairs(cases) do
    local case_dir = root .. "/case_" .. i
    local install_dir = case_dir .. "/installed"
    local src_bin = case_dir .. "/extracted/" .. c.top
        .. (c.host == "macosx" and "/Contents/Home/bin" or "/bin")
    local exe = (c.host == "windows") and ".exe" or ""
    local files = {}
    local dirs = {}
    dirs[case_dir .. "/extracted/" .. c.top] = true
    if c.host == "macosx" then
        dirs[case_dir .. "/extracted/" .. c.top .. "/Contents"] = true
        dirs[case_dir .. "/extracted/" .. c.top .. "/Contents/Home"] = true
    end
    for _, p in ipairs(c.progs) do
        files[src_bin .. "/" .. p .. exe] = true
    end

    local moved_from, moved_to
    local added, removed = {}, {}

    os.host = function() return c.host end
    os.isdir = function(p) return dirs[p] == true end
    os.isfile = function(p) return files[p] == true end
    os.tryrm = function() end
    os.mv = function(src, dst)
        moved_from, moved_to = src, dst
        dirs[dst .. "/bin"] = true
        for _, p in ipairs(c.progs) do
            files[dst .. "/bin/" .. p .. exe] = true
        end
    end
    path = {
        join = function(...)
            return table.concat({...}, "/")
        end
    }
    local current_ver = c.ver
    local current_inst = install_dir
    import = function(mod)
        if mod == "xim.libxpkg.pkginfo" then
            pkginfo = {
                version = function() return current_ver end,
                install_dir = function() return current_inst end,
            }
        elseif mod == "xim.libxpkg.xvm" then
            xvm = {
                add = function(name, opts) added[name] = opts or {} end,
                remove = function(name, ver) removed[name] = ver or true end,
            }
        elseif mod == "xim.libxpkg.log" then
            log = { info = function() end, error = function() end }
        end
    end

    dofile(arg[1])
    local expected_payload = case_dir .. "/extracted/" .. c.top
        .. (c.host == "macosx" and "/Contents/Home" or "")
    -- Run install from extracted dir by prefixing payload_dir relative path via dirs/files
    local rel_payload = c.top .. (c.host == "macosx" and "/Contents/Home" or "")
    dirs[rel_payload] = true
    assert(install() == true, "install failed for " .. c.ver .. " on " .. c.host)
    assert(moved_from == rel_payload, "unexpected payload: " .. tostring(moved_from))
    assert(moved_to == install_dir)

    assert(config() == true)
    assert(added["jdk-temurin"] and added["jdk-temurin"].type == "group")
    for _, p in ipairs(c.progs) do
        assert(added[p], "missing xvm.add for " .. p .. " on " .. c.ver)
        assert(added[p].version == c.ver .. "-temurin")
        assert(added[p].envs.JAVA_HOME == install_dir)
    end
    if c.ver == "8.0.512+9" then
        assert(added["jshell"] == nil, "JDK 8 must not register missing jshell")
    end

    assert(uninstall() == true)
    assert(removed["jdk-temurin"] == c.ver)
    for _, p in ipairs(c.progs) do
        assert(removed[p] == c.ver .. "-temurin")
    end
    if c.ver == "8.0.512+9" then
        assert(removed["jshell"] == nil, "JDK 8 uninstall should skip missing jshell")
    end
end
''', PKG_FILE, str(tmp_path))

    @pytest.mark.static
    def test_shared_names_are_flavor_scoped(self, meta):
        """java/javac 等是所有 JDK 发行版共享的名字, 必须带 flavor 版本

        用裸的数字版本注册的话, jdk-zulu/jdk-oracle 想注册同一个 `java@25.0.4+7`
        会被 xvm 直接拒绝 (another package already owns this exact name and
        version), 整个 config 批次失败 —— 等于 Temurin 一装, 别的发行版就装不上。
        """
        code = _code(meta.raw_content)
        assert re.search(r'version\s*=\s*flavor_version\(\)', code), \
            "共享程序名必须用 flavor_version() 注册"
        assert re.search(r'pkginfo\.version\(\)\s*\.\.\s*"-"\s*\.\.\s*FLAVOR', code), \
            "flavor_version 必须是 <version>-<flavor>"
        assert 'type = "group"' in code, \
            "binding root 应为 group 节点, 否则会留下永远失败的孤儿 shim"

    @pytest.mark.static
    def test_java_home_registered(self, meta):
        """JDK 只注册 shim 不给 JAVA_HOME 的话, maven/gradle 之类工具找不到它"""
        assert "JAVA_HOME" in _code(meta.raw_content), "config 应通过 xvm envs 提供 JAVA_HOME"


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
        # The JDK 25 tarball is ~200MB; the default 180s can be tight on a
        # cold cache.
        assert_install_succeeds(PKG, timeout=420)


class TestVerify:
    @staticmethod
    def _expected_version() -> str:
        raw = os.environ.get("XLINGS_TEST_VERSION", "25.0.4+7")
        return ALIAS_TO_CANONICAL.get(raw, raw)

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_java_version(self):
        # java prints its version banner on stderr. Assert the full build
        # string: the major version alone would also match a pre-existing system JDK.
        expected = self._expected_version()
        if expected.startswith("8.0."):
            update, build = expected[4:].split("+", 1)
            expected = f"1.8.0_{update}-b{int(build):02d}"
        assert_command_output("java -version 2>&1", contains=expected)

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_javac_version(self):
        expected = self._expected_version()
        if expected.startswith("8.0."):
            update = expected[4:].split("+", 1)[0]
            plain = f"1.8.0_{update}"
        else:
            plain = expected.split("+", 1)[0]
        assert_command_output("javac -version 2>&1", contains=plain)

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_java_home_points_at_xpkg(self):
        """java.home 必须落在本包的安装目录里 (macOS 上即 Contents/Home 那一层)"""
        assert_command_output(
            "java -XshowSettings:properties -version 2>&1",
            regex=r"java\.home = .*jdk-temurin",
        )

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_java_home_env_reaches_jvm(self):
        """config 注册的 JAVA_HOME 必须真的进到 java 进程的环境里 (maven/gradle 靠它)"""
        if self._expected_version().startswith("8.0."):
            pytest.skip("JDK 8 does not include jshell")
        assert_command_output(
            '''echo 'System.out.println("JH=[" + System.getenv("JAVA_HOME") + "]");' '''
            '''| jshell -s - 2>&1''',
            regex=r"JH=\[.*jdk-temurin.*\]",
        )

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_xvm_java(self):
        assert_xvm_registered("java")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_xvm_javac(self):
        assert_xvm_registered("javac")
