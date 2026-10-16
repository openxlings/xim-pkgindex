"""平台段复用检查 —— 客户端查找的平台段必须是版本表本身

规则:

    linux、macosx、windows 这三个平台段(客户端按本机平台查找的键)不得写成
    `{ ref = "<平台>" }` 或 `{ inherits = "<平台>" }`。几个平台共用同一组版本时,
    在 `package` 之前定义一个 local 版本表,各平台段引用它。

xlings 2026.10.16.1 及更早的客户端不读平台级的 `ref` 与 `inherits`:`ref` 被当成
一个名为 `ref` 的版本,其 url 是字符串 `"linux"`。2026-10-16 实测:macOS、Windows
上 `xlings install luban-os` 安装 `xim:luban-fonts@ref`,失败于
`download failed: Only HTTPS is supported`。Linux CI 不经过这条路径,因此没有发现。

ubuntu、debian 等发行版键不受此限:客户端不查找它们。
"""
import glob
import os
import re

import pytest

LOOKED_UP = ("linux", "macosx", "windows")
_ALIAS = re.compile(r'(?<![\w"\[])(%s)\s*=\s*\{\s*(ref|inherits)\s*=' % "|".join(LOOKED_UP))


def _strip_comments(content):
    return re.sub(r"--[^\n]*", "", content)


def _xpkg_files():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    return sorted(glob.glob(os.path.join(root, "pkgs", "**", "*.lua"), recursive=True))


@pytest.mark.static
def test_looked_up_platforms_hold_their_versions():
    offenders = []
    for path in _xpkg_files():
        with open(path, encoding="utf-8") as handle:
            content = _strip_comments(handle.read())
        for match in _ALIAS.finditer(content):
            offenders.append(f"{os.path.relpath(path)}: {match.group(1)} = {{ {match.group(2)} = ... }}")
    assert not offenders, (
        "a platform the client looks up names another platform instead of holding its versions; "
        "share one local version table instead:\n  " + "\n  ".join(offenders))


@pytest.mark.static
def test_the_rule_sees_the_shape():
    assert _ALIAS.search('xpm = { macosx = { ref = "linux" } }')
    assert _ALIAS.search('windows = {inherits = "linux"}')
    assert not _ALIAS.search('["latest"] = { ref = "1.0" }')
    assert not _ALIAS.search('ubuntu = { ref = "linux" }')
    assert not _ALIAS.search('macosx = versions,')
