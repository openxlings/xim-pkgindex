"""平台版本齐平检查 —— 一次 bump 必须落进每个平台段

规则:

    同一个描述符里,凡是带版本条目的平台段,必须带同一组版本条目。

一次 bump 看起来是改一行,实际要落进 N 个地方。改完 `xpm.linux` 再读一遍
文件,文件里**确实**有那个新版本 —— 作者看到的是成功,任何整文件 grep 看到的
也是成功。其余平台就这么被落下,而故障出现在别处:macOS 上
`mcpplibs.xpkg@0.0.53 not found`,对着一个字面上就含 `["0.0.53"]` 的文件。

2026-08-06 实测:xpkg 的 0.0.52 和 0.0.53 两次都只加进了 `xpm.linux`。Linux CI
连绿两次。之后这个故障被从外部诊断了八次 —— 索引 commit、发布的 artifact、
滚动指针、releases/latest、发布延迟、客户端版本钉住、装了没切、lockfile hash
—— 每一次检查**结论都是对的**,因为每一次问的都是"索引里有没有 0.0.53",而不是
"**这个平台**的段里有没有"。

真正存在差异的包显式声明退出:

    package = {
        ...
        -- <为什么各平台不同>
        platform_versions_diverge = true,
    }

这个声明是有人**特意**做出的主张,正是"有意差异"与"遗漏"的区别所在。

解析方式:括号配对,不是正则。`xpm` 里几乎总有嵌套表和注释,`\\{[^}]*\\}` 这类
模式会在第一个内层 `}` 上截断,然后对着半个表下结论 —— 而那恰恰是本规则要
防的那种"看起来对"的判断。
"""
import glob
import os
import re
import pytest


def _discover_xpkg_files():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    files = sorted(glob.glob(os.path.join(root, "pkgs", "**", "*.lua"), recursive=True))
    return [os.path.relpath(f, root) for f in files]


def _balanced(content, start):
    """从 start 处的 '{' 起返回配对到的整块(含两端花括号),跳过注释与字符串。"""
    depth, i, n = 0, start, len(content)
    while i < n:
        c = content[i]
        if c == "-" and content[i:i + 2] == "--":
            j = content.find("\n", i)
            i = n if j < 0 else j
            continue
        if c in "\"'":
            q, i = c, i + 1
            while i < n and content[i] != q:
                i += 2 if content[i] == "\\" else 1
            i += 1
            continue
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return content[start:i + 1]
        i += 1
    return None


def _strip_comments(block):
    out, i, n = [], 0, len(block)
    while i < n:
        c = block[i]
        if c == "-" and block[i:i + 2] == "--":
            j = block.find("\n", i)
            i = n if j < 0 else j
            continue
        out.append(c)
        i += 1
    return "".join(out)


def _platform_sections(content):
    """产出 (平台名, 该段内容)。只认 xpm 表内深度为 1 的键。"""
    k = content.find("xpm")
    if k < 0:
        return
    brace = content.find("{", k)
    if brace < 0:
        return
    xpm = _balanced(content, brace)
    if not xpm:
        return
    body = xpm[1:-1]
    # 深度 1 的 `<name> = {` 才是平台段
    depth, i, n = 0, 0, len(body)
    while i < n:
        c = body[i]
        if c == "-" and body[i:i + 2] == "--":
            j = body.find("\n", i)
            i = n if j < 0 else j
            continue
        if c in "\"'":
            q, i = c, i + 1
            while i < n and body[i] != q:
                i += 2 if body[i] == "\\" else 1
            i += 1
            continue
        if c == "{":
            if depth == 0:
                m = re.search(r'([A-Za-z_][A-Za-z0-9_]*)\s*=\s*$', body[:i])
                if m:
                    blk = _balanced(body, i)
                    if blk:
                        yield m.group(1), blk
                        i += len(blk)
                        continue
            depth += 1
        elif c == "}":
            depth -= 1
        i += 1


_VERSION_KEY = re.compile(r'\["(\d[\d.]*)"\]\s*=')


def _version_keys(block):
    """该段里深度为 1 的版本键。嵌套表里的同形键不算。"""
    body = _strip_comments(block)[1:-1]
    keys, depth, i, n = set(), 0, 0, len(body)
    while i < n:
        c = body[i]
        if c in "\"'":
            q, j = c, i + 1
            while j < n and body[j] != q:
                j += 2 if body[j] == "\\" else 1
            if depth == 0:
                m = _VERSION_KEY.match(body, max(0, i - 1))
                if m:
                    keys.add(m.group(1))
            i = j + 1
            continue
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
        i += 1
    return keys


@pytest.mark.static
@pytest.mark.parametrize("pkg_file", _discover_xpkg_files(),
                         ids=lambda f: os.path.basename(f).replace(".lua", ""))
def test_every_platform_carries_every_version(pkg_file):
    """[版本齐平] 一次 bump 必须落进每个带版本的平台段"""
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    with open(os.path.join(root, pkg_file), encoding="utf-8") as f:
        content = f.read()

    if re.search(r'platform_versions_diverge\s*=\s*true', content):
        pytest.skip("declared platform_versions_diverge")

    sets = {}
    for plat, block in _platform_sections(content):
        keys = _version_keys(block)
        if keys:
            sets[plat] = keys
    if len(sets) < 2:
        return

    union = set().union(*sets.values())
    missing = {p: sorted(union - s) for p, s in sets.items() if union - s}
    assert not missing, (
        f"{pkg_file}: platform sections carry different version sets — "
        + "; ".join(f"xpm.{p} is missing {', '.join(v)}" for p, v in sorted(missing.items()))
        + ". A version bump has to land in every platform block; editing one "
          "leaves a file that still contains the version, so the omission reads "
          "as 'not found' on the platforms that lack it. If they genuinely "
          "differ, set `platform_versions_diverge = true` and say why."
    )
