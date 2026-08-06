"""deps 形状检查 — 混合形状在旧客户端上静默丢弃 build deps

三种形状会到达 loader:

    deps = { "a", "b" }                        数组   -> 同时填 runtime 和 build
    deps = { runtime = {...}, build = {...} }  分离   -> 两个列表各自独立
    deps = { "a", "b", build = {...} }         混合   -> 见下

混合形状是作者在已有 runtime 列表上想加一个安装期工具时自然会写出的写法。
它能解析、读起来和分离形状一模一样,而 **libxpkg 0.0.52 之前的每一个客户端**
都会对它走数组分支:`build` 被丢掉,数组项被复制进 build_deps 顶替。没有任何
提示,安装照常报成功 —— 两件事都没做。

2026-08-06 在 nvidia-gl-host-link 上实测:`deps.build = {"xim:patchelf"}`
与五个 runtime dep 并列,patchelf 一个都没装,症状是两层之外的另一个子系统
(elfpatch)报了一句"patchelf 解析到 host"。

0.0.52 起 loader 会正确处理混合形状,但索引要服务的是所有版本的客户端,而
recipe 里没有办法探测 loader 的形状能力(不像 Lua 函数可以 type() 探测)。
所以索引侧的规则是:**不要写混合形状**。分离形状在所有存在过的客户端上含义
一致。
"""
import glob
import os
import pytest


def _discover_xpkg_files():
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    files = sorted(glob.glob(os.path.join(project_root, "pkgs", "**", "*.lua"), recursive=True))
    files += sorted(glob.glob(os.path.join(project_root, "sub-index", "**", "*.lua"), recursive=True))
    return [os.path.relpath(f, project_root) for f in files]


def _balanced_block(content, start):
    """从 start 处的 '{' 起,返回配对到的整块内容(含两端花括号)。

    括号配对,不是正则。deps 表里几乎总有嵌套表和注释,`\\{[^}]*\\}` 这类
    模式会在第一个内层 '}' 上截断,然后对着半个表下结论。
    """
    depth = 0
    i = start
    n = len(content)
    while i < n:
        c = content[i]
        if c == "-" and content[i:i + 2] == "--":            # 行注释
            j = content.find("\n", i)
            i = n if j < 0 else j
            continue
        if c == '"' or c == "'":                              # 字符串
            q = c
            i += 1
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


def _deps_blocks(content):
    """产出每个 `deps = { ... }` 的块内容。"""
    idx = 0
    while True:
        k = content.find("deps", idx)
        if k < 0:
            return
        idx = k + 4
        # 必须是独立的键名:`build_deps = ` / `xlings-deps` 不算
        if k > 0 and (content[k - 1].isalnum() or content[k - 1] in "_-"):
            continue
        rest = content[k + 4:]
        stripped = rest.lstrip()
        if not stripped.startswith("="):
            continue
        after_eq = stripped[1:].lstrip()
        if not after_eq.startswith("{"):
            continue
        brace = content.find("{", k + 4)
        block = _balanced_block(content, brace)
        if block:
            yield block


def _top_level_items(block):
    """块内深度为 1 的片段(去掉嵌套表),用于判断顶层有什么。"""
    out = []
    depth = 0
    buf = []
    i = 0
    n = len(block)
    while i < n:
        c = block[i]
        if c == "-" and block[i:i + 2] == "--":
            j = block.find("\n", i)
            i = n if j < 0 else j
            continue
        if c == '"' or c == "'":
            q = c
            j = i + 1
            while j < n and block[j] != q:
                j += 2 if block[j] == "\\" else 1
            if depth == 1:
                buf.append(block[i:j + 1])
            i = j + 1
            continue
        if c == "{":
            depth += 1
            if depth == 1:
                i += 1
                continue
        elif c == "}":
            depth -= 1
            if depth == 0:
                break
        if depth == 1:
            buf.append(c)
        i += 1
    text = "".join(buf)
    return [s.strip() for s in text.split(",") if s.strip()]


@pytest.mark.static
@pytest.mark.parametrize("pkg_file", _discover_xpkg_files(),
                         ids=lambda f: os.path.basename(f).replace(".lua", ""))
def test_deps_is_not_the_mixed_shape(pkg_file):
    """[deps] 不得把位置列表与 runtime/build 键混在同一个 deps 表里"""
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    with open(os.path.join(root, pkg_file), encoding="utf-8") as f:
        content = f.read()

    for block in _deps_blocks(content):
        items = _top_level_items(block)
        positional = [s for s in items if s.startswith(('"', "'"))]
        keyed = [s for s in items
                 if s.split("=")[0].strip() in ("runtime", "build") and "=" in s]
        assert not (positional and keyed), (
            f"{pkg_file}: `deps` mixes a positional list {positional[:3]} with "
            f"{[s.split('=')[0].strip() for s in keyed]}. Every client before "
            f"libxpkg 0.0.52 drops the keyed half and copies the positional "
            f"entries into build_deps instead -- silently. Write the split "
            f"form: deps = {{ runtime = {{...}}, build = {{...}} }}."
        )
