"""lua 包文件解析器 — 通过正则提取元数据，不依赖 lua 运行时"""
import re
import os
from dataclasses import dataclass, field


@dataclass
class XpkgMeta:
    filepath: str = ""
    name: str = ""
    spec: str = ""
    description: str = ""
    pkg_type: str = ""
    programs: list = field(default_factory=list)
    platforms: dict = field(default_factory=dict)
    is_ref: bool = False
    ref_target: str = ""
    imports: list = field(default_factory=list)
    has_install: bool = False
    has_config: bool = False
    has_uninstall: bool = False
    has_installed: bool = False
    has_xvm_enable: bool = False
    raw_content: str = ""


def parse_xpkg(lua_path: str) -> XpkgMeta:
    """解析 .lua 包文件，提取元数据"""
    if not os.path.isabs(lua_path):
        from tests.lib.platform_utils import project_root
        lua_path = os.path.join(project_root(), lua_path)

    with open(lua_path, "r", encoding="utf-8") as f:
        content = f.read()

    meta = XpkgMeta(filepath=lua_path, raw_content=content)

    # ref 包检测
    ref_match = re.search(r'package\s*=\s*\{[^}]*\bref\s*=\s*"([^"]+)"', content)
    if ref_match:
        meta.is_ref = True
        meta.ref_target = ref_match.group(1)
        meta.spec = _extract_field(content, "spec") or ""
        meta.pkg_type = _extract_field(content, "type") or ""
        return meta

    meta.name = _extract_field(content, "name") or ""
    meta.spec = _extract_field(content, "spec") or ""
    meta.description = _extract_field(content, "description") or ""
    meta.pkg_type = _extract_field(content, "type") or ""
    meta.has_xvm_enable = "xvm_enable = true" in content

    # programs 列表
    # `--` 行注释要先剥掉再扫引号字符串,否则注释里被注释掉的程序名会被当作
    # declared (e.g. musl-gcc.lua 里 `-- "musl-gcc-static", "musl-g++-static"`).
    prog_match = re.search(r'programs\s*=\s*\{([^}]+)\}', content)
    if prog_match:
        prog_body = re.sub(r'--[^\n]*', '', prog_match.group(1))
        meta.programs = re.findall(r'"([^"]+)"', prog_body)

    # 平台支持
    for plat in ["linux", "windows", "macosx", "ubuntu", "debian", "archlinux", "manjaro"]:
        if re.search(rf'^\s*{plat}\s*=', content, re.MULTILINE):
            meta.platforms[plat] = True
        elif re.search(rf'^\s*\["{plat}"\]\s*=', content, re.MULTILINE):
            meta.platforms[plat] = True

    # import 语句
    meta.imports = re.findall(r'import\("([^"]+)"\)', content)

    # hook 函数
    meta.has_install = bool(re.search(r'^function\s+install\s*\(', content, re.MULTILINE))
    meta.has_config = bool(re.search(r'^function\s+config\s*\(', content, re.MULTILINE))
    meta.has_uninstall = bool(re.search(r'^function\s+uninstall\s*\(', content, re.MULTILINE))
    meta.has_installed = bool(re.search(r'^function\s+installed\s*\(', content, re.MULTILINE))

    return meta


def _extract_field(content: str, field_name: str) -> str | None:
    match = re.search(rf'{field_name}\s*=\s*"([^"]*)"', content)
    if match:
        return match.group(1)
    match = re.search(rf'{field_name}\s*=\s*\[\[(.*?)\]\]', content, re.DOTALL)
    return match.group(1).strip() if match else None
