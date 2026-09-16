"""测试 node 包

node 的资源没有一条 URL 字面量: 每个资产由 `_asset()` 拼出一对
`{GLOBAL = nodejs.org/dist, CN = cdn.npmmirror.com}` 再配上 `_sha256` 表里的
per-arch 校验和。所以静态断言看两样东西 ——

* 那个构造器是唯一的 URL 来源 (谁也没法绕过 CN 单写一个 GLOBAL);
* `_sha256` 覆盖每一个被列出来的版本 (漏一个不会报错, 只会静默变成
  `sha256 = nil`, 那样 CN 镜像就没有任何东西证明它和上游同字节)。

再加一条真正求值配方的检查 (需要 lua, 没有就 skip, 同 tests/test_hostlib.py):
逐架构解析出来的 URL/hash 必须成对齐全。
"""
import os
import re
import shutil
import subprocess
from pathlib import Path

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

PKG = "node"
PKG_FILE = "pkgs/n/node.lua"

REPO = Path(__file__).resolve().parent.parent.parent
HARNESS = REPO / "tests" / "lua" / "node_resources_harness.lua"

GLOBAL_HOST = "https://nodejs.org/dist"
CN_HOST = "https://cdn.npmmirror.com/binaries/node"

# builder -> (platform, the two `_sha256` keys that builder consumes)
BUILDERS = {
    "_win_url":   ("windows", ("win_x64", "win_arm64")),
    "_linux_url": ("linux",   ("linux_x64", "linux_arm64")),
    "_mac_url":   ("macosx",  ("darwin_x64", "darwin_arm64")),
}


def _code(content: str) -> str:
    """去掉 lua 行注释 — 注释里也写了这些 host 和版本号"""
    return "\n".join(
        line for line in content.splitlines() if not line.lstrip().startswith("--")
    )


def _listed_versions(content: str) -> dict:
    """{platform: {version, ...}}, 读的是 `["24.19.0"] = _linux_url("24.19.0")` 这种行"""
    listed = {plat: set() for plat, _ in BUILDERS.values()}
    for key, builder, arg in re.findall(
            r'\["([^"]+)"\]\s*=\s*(_\w+_url)\("([^"]+)"\)', _code(content)):
        assert key == arg, f"版本键 {key} 用的却是 {builder}({arg}) 的资源"
        listed[BUILDERS[builder][0]].add(key)
    return listed


def _sha_table(content: str) -> dict:
    """{version: {key: sha256}} — 解析 `local _sha256 = { ... }`"""
    body = re.search(r'local _sha256 = \{\n(.*?)\n\}\n', content, re.S)
    assert body, "找不到 _sha256 表"
    table, current = {}, None
    for line in body.group(1).splitlines():
        head = re.match(r'\s*\["([^"]+)"\]\s*=\s*\{', line)
        if head:
            current = table.setdefault(head.group(1), {})
            continue
        entry = re.match(r'\s*(\w+)\s*=\s*"([0-9a-f]{64})",', line)
        if entry and current is not None:
            current[entry.group(1)] = entry.group(2)
    return table


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
    def test_asset_builder_is_the_only_url_source(self, meta):
        """两个 host 各只能出现一次, 都在 `_asset()` 里

        写死一条 URL 的版本块会拿到 GLOBAL 而没有 CN, 国内用户就还是走
        nodejs.org —— 而且这种块不会报错, 只是安静地少一个镜像。
        """
        code = _code(meta.raw_content)
        assert code.count(GLOBAL_HOST) == 1, "GLOBAL URL 只应由 _asset() 拼出"
        assert code.count(CN_HOST) == 1, "CN URL 只应由 _asset() 拼出"
        builder = re.search(r'local function _asset\(.*?\nend\n', code, re.S)
        assert builder, "找不到 _asset()"
        assert GLOBAL_HOST in builder.group(0) and CN_HOST in builder.group(0), \
            "两个 host 必须都在 _asset() 里, 才能保证每个资产成对"

    @pytest.mark.static
    def test_sha256_covers_every_listed_version(self, meta):
        """每个列出来的版本, 在它那个平台需要的两个 arch 上都要有 hash

        `_asset()` 查不到就返回 `sha256 = nil` —— 装得上, 但没有任何东西
        保证 CN 那份和 nodejs.org 同字节。
        """
        shas = _sha_table(meta.raw_content)
        missing = [
            f"{plat}/{ver}/{key}"
            for builder, (plat, keys) in BUILDERS.items()
            for ver in _listed_versions(meta.raw_content)[plat]
            for key in keys
            if key not in shas.get(ver, {})
        ]
        assert not missing, f"缺少 sha256: {missing}"

    @pytest.mark.static
    def test_latest_agrees_across_platforms(self, meta):
        """三个平台的 latest 必须指向同一个版本, 且那个版本在各自表里列着"""
        refs = set(re.findall(r'\["latest"\]\s*=\s*\{\s*ref\s*=\s*"([^"]+)"\s*\}',
                              _code(meta.raw_content)))
        assert len(refs) == 1, f"latest 指向了多个版本: {sorted(refs)}"
        ref = refs.pop()
        for plat, versions in _listed_versions(meta.raw_content).items():
            assert ref in versions, f"{plat} 的 latest -> {ref} 在该平台没有版本块"


@pytest.mark.skipif(
    shutil.which("lua5.4") is None and shutil.which("lua") is None,
    reason="no lua interpreter on this machine",
)
@pytest.mark.static
def test_every_resolved_asset_is_a_complete_mirror_pair():
    """求值配方, 逐平台逐架构检查解析结果 (静态断言看不到 `_asset()` 的输出)"""
    lua = shutil.which("lua5.4") or shutil.which("lua")
    out = subprocess.run([lua, str(HARNESS), str(REPO / PKG_FILE)],
                         capture_output=True, text=True, check=True).stdout

    assets = [line.split("\t")[1:] for line in out.splitlines() if line.startswith("ASSET")]
    listed = _listed_versions((REPO / PKG_FILE).read_text(encoding="utf-8"))
    expected = sum(len(v) for v in listed.values()) * 2  # 每个版本两个 arch
    assert len(assets) == expected, f"解析出 {len(assets)} 个资产, 期望 {expected}"

    for platform, version, arch, global_url, cn_url, sha in assets:
        where = f"{platform}/{version}/{arch}"
        assert global_url.startswith(GLOBAL_HOST + "/v" + version + "/"), \
            f"{where}: GLOBAL 不是 nodejs.org 上这个版本的目录 ({global_url})"
        assert cn_url.startswith(CN_HOST + "/v" + version + "/"), \
            f"{where}: 没有 CN 镜像 ({cn_url})"
        assert cn_url.rsplit("/", 1)[1] == global_url.rsplit("/", 1)[1], \
            f"{where}: CN 和 GLOBAL 指向不同文件名"
        assert re.fullmatch(r"[0-9a-f]{64}", sha), f"{where}: sha256 缺失或不合法 ({sha})"

    # 每个版本必须两个 arch 都在 —— archs 声明了 x86_64 + aarch64
    per_version = {}
    for platform, version, arch, *_ in assets:
        per_version.setdefault((platform, version), set()).add(arch)
    for key, arches in sorted(per_version.items()):
        assert arches == {"x86_64", "aarch64"}, f"{key} 只解析出 {sorted(arches)}"


# ── xlings#605: glibc compat sonames preloaded into node ────────────────────
#
# config() runs a shell script against the real payload, so these run it too:
# a forged "our loader" layout (the host's own ld.so/libc reached through a
# private lib dir on node's RPATH, exactly the shape elfpatch produces), and
# assertions on the ELF that comes out. The dlopen differential itself needs our
# real glibc -- the host's ld.so.cache would serve the soname either way -- so
# that half lives in .github/workflows/node-native-modules.yml.

PRELOAD_HARNESS = REPO / "tests" / "lua" / "node_preload_harness.lua"
COMPAT = ["libresolv.so.2", "libutil.so.1", "librt.so.1", "libanl.so.1",
          "libdl.so.2", "libpthread.so.0"]


def _tool(*names):
    for n in names:
        if shutil.which(n):
            return shutil.which(n)
    return None


_LUA = _tool("lua5.4", "lua")
_CC = _tool("cc", "gcc")
_PATCHELF = _tool("patchelf")

needs_elf_tools = pytest.mark.skipif(
    not (_LUA and _CC and _PATCHELF) or not Path("/proc/self/exe").exists(),
    reason="needs lua, a C compiler and patchelf on a Linux host",
)


def _needed(exe):
    out = subprocess.run([_PATCHELF, "--print-needed", str(exe)],
                         capture_output=True, text=True, check=True).stdout
    return out.split()


def _forge(tmp_path, ours=True):
    """An install dir holding bin/node, on our loader or on the host's."""
    install = tmp_path / "node"
    (install / "bin").mkdir(parents=True)
    src = tmp_path / "main.c"
    src.write_text('#include <stdio.h>\nint main(void){puts("v0.0.0");return 0;}\n')
    exe = install / "bin" / "node"
    subprocess.run([_CC, str(src), "-o", str(exe)], check=True)
    # Set both halves explicitly, whatever the compiler stamped: a `cc` that is
    # itself an xlings shim already links onto an xlings loader, which turned
    # the host case below into a second copy of the "ours" case.
    if not ours:
        host_interp = subprocess.run([_PATCHELF, "--print-interpreter", "/bin/sh"],
                                     capture_output=True, text=True, check=True).stdout.strip()
        subprocess.run([_PATCHELF, "--set-interpreter", host_interp,
                        "--remove-rpath", str(exe)], check=True)
    else:
        libdir = tmp_path / "glibc" / "lib64"
        libdir.mkdir(parents=True)
        interp = subprocess.run([_PATCHELF, "--print-interpreter", str(exe)],
                                capture_output=True, text=True, check=True).stdout.strip()
        host_libc = Path(subprocess.run([_CC, "-print-file-name=libc.so.6"],
                                        capture_output=True, text=True,
                                        check=True).stdout.strip()).resolve()
        (libdir / Path(interp).name).symlink_to(Path(interp).resolve())
        (libdir / "libc.so.6").symlink_to(host_libc)
        for so in COMPAT:
            cand = host_libc.parent / so
            if cand.exists():
                (libdir / so).symlink_to(cand.resolve())
        subprocess.run([_PATCHELF, "--set-interpreter", str(libdir / Path(interp).name),
                        "--force-rpath", "--set-rpath", str(libdir), str(exe)], check=True)
    return install, exe


def _config(install, patchelf_dir=None):
    args = [_LUA, str(PRELOAD_HARNESS), str(REPO / PKG_FILE), str(install)]
    if patchelf_dir:
        args.append(str(patchelf_dir))
    r = subprocess.run(args, capture_output=True, text=True,
                       env={**os.environ, "PATH": f"{Path(_PATCHELF).parent}:/usr/bin:/bin"})
    assert "CONFIG true" in r.stdout, r.stdout + r.stderr
    return r


@needs_elf_tools
@pytest.mark.static
def test_preload_on_our_loader_adds_every_compat_soname_the_libdir_ships(tmp_path):
    install, exe = _forge(tmp_path)
    shipped = [so for so in COMPAT if (tmp_path / "glibc" / "lib64" / so).exists()]
    assert "libresolv.so.2" in shipped, "forged libdir lacks libresolv; the test would be vacuous"
    assert "libresolv.so.2" not in _needed(exe)

    _config(install)

    needed = _needed(exe)
    assert all(so in needed for so in shipped), f"missing from NEEDED: {needed}"
    assert len(needed) == len(set(needed)), f"duplicate NEEDED: {needed}"
    assert subprocess.run([str(exe)], capture_output=True).returncode == 0
    assert not list((install / "bin").glob("node.xlings-preload.*")), "candidate left behind"


@needs_elf_tools
@pytest.mark.static
def test_preload_is_idempotent(tmp_path):
    install, exe = _forge(tmp_path)
    _config(install)
    before = (exe.read_bytes(), exe.stat().st_ino)
    _config(install)
    assert (exe.read_bytes(), exe.stat().st_ino) == before


@needs_elf_tools
@pytest.mark.static
def test_preload_leaves_a_host_loader_node_alone(tmp_path):
    """On the host's loader ld.so.cache already serves these; nothing to add"""
    install, exe = _forge(tmp_path, ours=False)
    before = exe.read_bytes()
    _config(install)
    assert exe.read_bytes() == before


@needs_elf_tools
@pytest.mark.static
def test_preload_keeps_the_original_when_the_candidate_cannot_run(tmp_path):
    install, exe = _forge(tmp_path)
    bogus = tmp_path / "glibc" / "lib64" / "libresolv.so.2"
    bogus.unlink()
    bogus.write_bytes(b"not an ELF")
    before = exe.read_bytes()

    r = _config(install)

    assert exe.read_bytes() == before, "a node that does not start replaced the working one"
    assert subprocess.run([str(exe)], capture_output=True).returncode == 0
    assert "xlings#605" in r.stderr, "the failure must be said, not swallowed"
    assert not list((install / "bin").glob("node.xlings-preload.*")), "candidate left behind"


@needs_elf_tools
@pytest.mark.static
def test_preload_without_patchelf_is_a_no_op_not_a_failure(tmp_path):
    install, exe = _forge(tmp_path)
    before = exe.read_bytes()
    r = subprocess.run([_LUA, str(PRELOAD_HARNESS), str(REPO / PKG_FILE), str(install)],
                       capture_output=True, text=True, env={**os.environ, "PATH": "/nonexistent"})
    assert "CONFIG true" in r.stdout, r.stdout + r.stderr
    assert exe.read_bytes() == before


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
        assert_install_succeeds(PKG)


class TestVerify:
    @pytest.mark.verify
    @skip_if_not('linux')
    def test_node_version(self):
        assert_command_output("node --version", contains="v24.19.0")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_npm_runs(self):
        assert_command_output("npm --version", regex=r"^\d+\.\d+\.\d+")

    @pytest.mark.verify
    @skip_if_not('linux')
    def test_xvm_node(self):
        assert_xvm_registered("node")
