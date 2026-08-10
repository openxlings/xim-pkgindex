"""依赖查询坐标检查 —— 一个 recipe 必须按它声明的坐标去问

`pkginfo.dep_install_dir(name)` 有两条应答路径,两条都要求 **namespaced** 坐标:

    resolved_deps            解析器按声明的 spec 建键(`xim:glibc@>=2.39`)
    dependency_store_roots   按 `<root>/<ns>-x-<bare>/<ver>` 定位

裸名字(`"glibc"`)在第二条上**结构性无解** —— 它没说是哪个命名空间,
`compat-x-zlib` 和 `other-x-zlib` 之间只能靠猜,而不猜正是这套 roots 存在的理由。
第一条在 libxpkg 0.0.56 之后能按唯一性回答裸名字,但那只是**兜底**,不是契约:
同名第二个 provider 一出现就失败关闭。

xlings 2026.8.10.1 开始无条件填 `dependency_store_roots`,于是索引里 7 个真实
调用点断了 6 个(openxlings/xlings#524):

    gcc / meson   config hook 失败 —— 任何冷 home 都装不上
    llvm          同一条 helper
    godot         **静默**回落宿主 GL,即 mcpp#352 —— 它声明 graphics 就是为了防这个
    graphics      **静默**把横幅显示成 unknown,GPU 与 llvmpipe 再次无法区分
    clangd        跳过 clangd 配置

「装不上」当天就会被发现,「静默回落」不会。所以这条规则由**静态检查**兜底,
而不是靠下一个人记得。

规则:
  1. `dep_install_dir("<字面量>")` 的名字必须带命名空间。
  2. 该名字必须出现在这个 recipe 自己的 `deps` 里 —— 传递依赖没有 resolver
     记录(xlings 只记录节点自己的 runtime_deps),问了也是 nil。
     要用就要声明。
  3. hook 自己 `pkgmanager.install()` 装的载荷不是依赖,应当走
     `tool_payload_dir`(它保留自己的 scan),不走 `dep_install_dir`。

**变量实参不在本检查范围内**(例如 `__sentinel_state(name)` 把名字转了一手)。
静态地判断那种写法要求实现取值分析,收益不抵复杂度;这里只报出来,让它可见。
注释和字符串在扫描前就被剥掉 —— 本文件自身的说明里就有 `dep_install_dir(`
字样,不剥的话检查会把注释当调用。
"""
import glob
import os
import re
import pytest


def _discover_xpkg_files():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    files = sorted(glob.glob(os.path.join(root, "pkgs", "**", "*.lua"), recursive=True))
    files += sorted(glob.glob(os.path.join(root, "sub-index", "**", "*.lua"), recursive=True))
    return [os.path.relpath(f, root) for f in files]


def _strip_comments(content):
    """去掉 lua 行注释与长注释,保留字符串字面量。

    先剥注释再扫调用,不是可选项:recipe 的注释里经常写着示例调用
    (`-- pkginfo.dep_install_dir("libcuda-host-link")..."/lib/..."`),
    直接正则会把它当成真实调用点,然后对着一句注释判失败。
    """
    out = []
    i, n = 0, len(content)
    while i < n:
        c = content[i]
        if c == "-" and content[i:i + 2] == "--":
            m = re.match(r"--\[(=*)\[", content[i:])
            if m:                                    # 长注释 --[[ ]] / --[==[ ]==]
                close = "]" + m.group(1) + "]"
                j = content.find(close, i)
                i = n if j < 0 else j + len(close)
            else:                                    # 行注释
                j = content.find("\n", i)
                i = n if j < 0 else j
            continue
        if c in "\"'":
            q = c
            out.append(c)
            i += 1
            while i < n and content[i] != q:
                if content[i] == "\\":
                    out.append(content[i:i + 2])
                    i += 2
                    continue
                out.append(content[i])
                i += 1
            out.append(q)
            i += 1
            continue
        out.append(c)
        i += 1
    return "".join(out)


_LITERAL_CALL = re.compile(
    r'pkginfo\.dep_install_dir\s*\(\s*(["\'])([^"\']+)\1')
_VARIABLE_CALL = re.compile(
    r'pkginfo\.dep_install_dir\s*\(\s*(?!["\'])[A-Za-z_]')


def _declared_dep_names(code):
    """recipe 里声明过的依赖坐标(去掉 @version 半边)。

    刻意宽松:任何 `deps` 表里出现的 `ns:name` 都算数,不区分平台段。
    这里要判的是「问的东西声明过没有」,而不是复算解析器的平台逻辑 ——
    后者会让这条检查变成解析器的第二份实现。
    """
    names = set()
    for block in re.finditer(r'\bdeps\b\s*=\s*\{', code):
        # 从 `{` 起做括号配对,注释已经剥掉了
        start = code.find("{", block.start())
        depth, i, n = 0, start, len(code)
        while i < n:
            if code[i] == "{":
                depth += 1
            elif code[i] == "}":
                depth -= 1
                if depth == 0:
                    break
            i += 1
        for lit in re.findall(r'["\']([^"\']+)["\']', code[start:i + 1]):
            names.add(lit.split("@")[0])
    return names


@pytest.mark.static
@pytest.mark.parametrize("pkg_file", _discover_xpkg_files(),
                         ids=lambda f: os.path.basename(f).replace(".lua", ""))
def test_dep_install_dir_uses_declared_namespaced_coordinate(pkg_file):
    """[deps] dep_install_dir 的字面量必须带命名空间,且必须是本包声明过的依赖"""
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    with open(os.path.join(root, pkg_file), encoding="utf-8") as f:
        code = _strip_comments(f.read())

    declared = _declared_dep_names(code)
    problems = []
    for _, name in _LITERAL_CALL.findall(code):
        if ":" not in name:
            problems.append(
                f'dep_install_dir("{name}") 是裸名字。显式依赖 store roots 只认'
                f' namespaced 坐标,裸名字在那条路径上无解;按声明写成'
                f' "<ns>:{name}"。')
        elif name not in declared:
            problems.append(
                f'dep_install_dir("{name}") 问的不是本包声明的依赖'
                f'(deps: {sorted(declared) or "<none>"})。解析器只记录节点自己的'
                f' runtime_deps,传递依赖没有记录 —— 要用就要声明,'
                f'或者改用 tool_payload_dir。')

    assert not problems, (
        f"{pkg_file}:\n  " + "\n  ".join(problems))


@pytest.mark.static
def test_variable_argument_call_sites_are_visible():
    """[deps] 变量实参的 dep_install_dir 调用点被记录在案(不判失败,只保持可见)

    这些没法静态判定,但正是 graphics.lua 那种把名字转了一手的形状 ——
    #524 里它静默失败了,横幅显示 unknown。清单变长时,新增的那个应当同样
    被人工核对一遍。
    """
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    seen = []
    for pkg_file in _discover_xpkg_files():
        with open(os.path.join(root, pkg_file), encoding="utf-8") as f:
            code = _strip_comments(f.read())
        if _VARIABLE_CALL.search(code):
            seen.append(pkg_file)

    known = {
        # __sentinel_state(name, marker) 把名字转了一手。两个调用点传的都是
        # namespaced 且已声明的坐标,人工核对过。
        "pkgs/g/graphics.lua",
    }
    unexpected = sorted(set(seen) - known)
    assert not unexpected, (
        "新增了变量实参的 dep_install_dir 调用点,静态检查无法覆盖它们:\n  "
        + "\n  ".join(unexpected)
        + "\n人工确认传进去的名字是 namespaced 且已声明,然后把文件加进本测试的"
          " known 集合。")
