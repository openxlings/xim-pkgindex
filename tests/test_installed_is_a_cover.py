"""`installed()` 必须是「这份 recipe 产出的状态」的覆盖,不是抽样。

来历:2026-08-16 那一轮 MSVC 生态,九层缺陷有四层是同一条 ——
`installed()` 比"能用"弱,于是每一层的 windows-test 都是绿的,
而包对使用者是坏的:

  * 只查 `cl.exe` / `std.ixx` → 少了动态 CRT 导入库,默认构建链接不了
  * 只查**目录** → 少了带 `kernel32.lib` 的 MSI,目录还在,任何链接都失败
  * 一个 payload 一条断言没做到 → 少了 um 头 / shared 头 / rc / mt
  * 不表达"什么不该在" → 已经装了旧布局的机器永远拉不回来

这条 lint 挡住的是第三条:**多 payload 的包,断言数不能退化成抽样。**
规则本身写在 `.agents/skills/xpkg-creater/SKILL.md` §2.2.1。
"""
import re
import pathlib
import pytest

REPO = pathlib.Path(__file__).resolve().parent.parent

# 多 payload 包:install() 自己下载/解压一组 payload,而不是框架单 url 下载。
# 这类包正是"少一个 payload 也说装好了"能发生的地方。
PAYLOAD_SET_MARKER = re.compile(r"^\s*local\s+PAYLOADS\s*=\s*\{", re.M)


def _payload_names(src: str) -> list[str]:
    """PAYLOADS 表里的 name = "..." 条目。"""
    start = PAYLOAD_SET_MARKER.search(src)
    if not start:
        return []
    body = src[start.end():]
    end = body.find("\n}")
    if end != -1:
        body = body[:end]
    return re.findall(r'name\s*=\s*"([^"]+)"', body)


def _asserted_paths(src: str) -> list[str]:
    """required_files() / installed() 里按名字断言的文件(去掉注释行)。"""
    for anchor in ("local function required_files", "function installed()"):
        i = src.find(anchor)
        if i != -1:
            break
    else:
        return []
    j = src.find("function install()", i)
    body = src[i: j if j != -1 else len(src)]
    code = "\n".join(l for l in body.splitlines()
                     if not l.lstrip().startswith("--"))
    # path.join(..., "name.ext") 的最后一段字面量
    return re.findall(r'"([^"/\\]+\.[A-Za-z0-9_]+)"', code)


def _multi_payload_recipes():
    out = []
    for lua in sorted((REPO / "pkgs").rglob("*.lua")):
        src = lua.read_text(encoding="utf-8", errors="replace")
        names = _payload_names(src)
        # 只看真正抓一组 payload 的包;单 payload 的包没有这个失效模式
        if len(names) >= 2:
            out.append((lua, src, names))
    return out


@pytest.mark.static
def test_a_multi_payload_recipe_asserts_more_than_one_file():
    """一个 payload 一条断言 —— 至少不能只断言一个文件。

    这是"覆盖 vs 抽样"能被机械检查的那一半:抓了 N 个 payload 却只查 1 个
    文件,意味着 N-1 个 payload 没下来时 `installed()` 照样说 yes。
    """
    bad = []
    for lua, src, names in _multi_payload_recipes():
        asserted = set(_asserted_paths(src))
        if len(asserted) < 2:
            bad.append(f"{lua.relative_to(REPO)}: "
                       f"{len(names)} payload,只断言 {sorted(asserted)}")
    assert not bad, (
        "多 payload 的包必须逐个 payload 断言(SKILL.md §2.2.1):\n  "
        + "\n  ".join(bad))


@pytest.mark.static
def test_installed_checks_files_not_directories():
    """`installed()` 不许用 os.isdir 当判据。

    目录存在不代表里面有链接需要的文件 —— windows-sdk 正是这样绿着发布的。
    """
    bad = []
    for lua, src, _ in _multi_payload_recipes():
        i = src.find("function installed()")
        if i == -1:
            continue
        j = src.find("function install()", i)
        body = src[i: j if j != -1 else len(src)]
        code = "\n".join(l for l in body.splitlines()
                         if not l.lstrip().startswith("--"))
        if "os.isdir" in code:
            bad.append(str(lua.relative_to(REPO)))
    assert not bad, (
        "installed() 用了 os.isdir —— 目录在不代表能用(SKILL.md §2.2.1):\n  "
        + "\n  ".join(bad))


@pytest.mark.static
def test_the_recipes_this_rule_came_from_still_obey_it():
    """回归钉子:msvc 和 windows-sdk 是这条规则的来源,不能悄悄退化。

    单独钉住是因为上面两条是通用下限,而这两个包的断言集是**逐 payload 推导
    出来的**(解 MSI 的 File/Component/Directory 表算出来的),退化成"还剩两条
    断言"仍然会通过通用检查。
    """
    expect = {
        "pkgs/w/windows-sdk.lua": {"corecrt.h", "winnt.h", "windef.h",
                                   "kernel32.lib", "gdi32.lib",
                                   "rc.exe", "mt.exe"},
        "pkgs/m/msvc.lua": {"cl.exe", "std.ixx", "libcpmt.lib", "msvcprt.lib"},
    }
    for rel, want in expect.items():
        src = (REPO / rel).read_text(encoding="utf-8")
        got = set(_asserted_paths(src))
        missing = want - got
        assert not missing, f"{rel}: installed() 不再断言 {sorted(missing)}"


@pytest.mark.static
def test_msvc_still_rejects_a_payload_carrying_vctip():
    """"什么不该在"这一半 —— 见 SKILL.md §2.2.1 (c)。

    包版本号不随 recipe 变,所以这是唯一能把已经装了旧布局的机器拉回来的东西。
    """
    src = (REPO / "pkgs/m/msvc.lua").read_text(encoding="utf-8")
    i = src.index("function installed()")
    j = src.index("function install()", i)
    code = "\n".join(l for l in src[i:j].splitlines()
                     if not l.lstrip().startswith("--"))
    assert "vctip.exe" in code, (
        "installed() 不再排除 vctip.exe —— 老机器会永远卸不掉")
