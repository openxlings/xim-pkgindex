"""A recipe's declared dependencies, read the way the client reads them.

The recipe is loaded as Lua (its `import(...)` calls stubbed), so a `deps`
table spread over lines, comments and nested lists is whatever the client
sees, not what a regex over the text happens to match.

    deps = { "a", "b" }                        -> runtime a, b   build a, b
    deps = { runtime = {..}, build = {..} }    -> each list by itself
"""
import shutil
import subprocess

import pytest

from tests.lib.platform_utils import project_root

_LUA = r'''
import = function() end
dofile(arg[1])
for platform, block in pairs(package.xpm) do
    local d = type(block) == "table" and block.deps or nil
    if type(d) == "table" then
        local split = type(d.runtime) == "table" or type(d.build) == "table"
        local function emit(kind, list)
            for _, dep in ipairs(list or {}) do print(platform .. "\t" .. kind .. "\t" .. dep) end
        end
        if split then
            emit("runtime", d.runtime)
            for _, dep in ipairs(d) do print(platform .. "\truntime\t" .. dep) end
            emit("build", d.build)
        else
            emit("runtime", d)
            emit("build", d)
        end
    end
end
'''


def declared_deps(recipe: str) -> dict:
    """{platform: {"runtime": [...], "build": [...]}} for every platform with deps."""
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if not lua:
        pytest.skip("Lua is required to evaluate the descriptor")
    path = recipe if recipe.startswith("/") else f"{project_root()}/{recipe}"
    out = subprocess.run([lua, "-", path], input=_LUA, text=True,
                         capture_output=True, check=True).stdout
    result: dict = {}
    for line in out.splitlines():
        platform, kind, dep = line.split("\t")
        result.setdefault(platform, {"runtime": [], "build": []})[kind].append(dep)
    return result
