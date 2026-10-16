"""Shared checks for the repacked runtime-library recipes (conda-forge / Debian).

Each recipe consumes a payload built by .agents/tools/repack/repack.py and
published to xlings-res; these checks lock that shape: both mirrors for every
architecture, a sha256 each, every dependency present in this index, and the
library template (seal at install, declare at config).
"""
from pathlib import Path
import re
import shutil
import subprocess

import pytest

from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_typos, assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds,
)

LUA_CHECK = r'''
import = function() end
dofile(arg[1])
local linux = package.xpm.linux
local entry = assert(linux[linux.latest.ref], "latest names no version")
for _, dep in ipairs(linux.deps) do
    local name = assert(dep:match("^xim:([^@]+)"), "dependency without the xim namespace: " .. dep)
    local f = io.open("pkgs/" .. name:sub(1, 1) .. "/" .. name .. ".lua") or io.open("pkgs/luban/" .. name .. ".lua")
    assert(f, "no recipe for " .. dep)
    f:close()
end
for _, arch in ipairs({"x86_64", "aarch64"}) do
    local asset = assert(entry[arch], "no " .. arch .. " payload")
    local pat = "/xlings%-res/" .. package.name:gsub("%-", "%%-") .. "/releases/download/" ..
                linux.latest.ref:gsub("%.", "%%.") .. "/"
    assert(asset.url.GLOBAL:match("^https://github%.com" .. pat), "GLOBAL is not xlings-res: " .. asset.url.GLOBAL)
    assert(asset.url.CN:match("^https://gitcode%.com" .. pat), "CN is not xlings-res: " .. asset.url.CN)
    assert(asset.url.GLOBAL:match("%-linux%-" .. arch .. "%.tar%.gz$"))
    assert(#asset.sha256 == 64 and asset.sha256:match("^[0-9a-f]+$"))
end
'''


def recipe_path(name):
    return Path("pkgs") / name[0] / (name + ".lua")


def check_recipe(name):
    recipe = recipe_path(name)
    meta = parse_xpkg(str(recipe))
    for check in (assert_required_fields, assert_valid_spec, assert_valid_type):
        check(meta)
    for check in (assert_no_typos, assert_no_exec_xvm,
                  assert_no_bashrc_modification, assert_no_direct_path_modification,
                  assert_uses_new_api):
        check(str(recipe))
    text = recipe.read_text()
    # the library template: seal the payload at install, declare it at config
    assert "selfcontain.seal(dir)" in text
    assert re.search(r"sysroot\.declare_libs\(dir, \"lib\"", text)
    assert "runtime_archive" not in text
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if not lua:
        pytest.fail("Lua 5.4 is required to evaluate the resource table")
    subprocess.run([lua, "-", str(recipe)], input=LUA_CHECK, text=True, check=True)


def check_index(name):
    assert_xim_add_succeeds(str(recipe_path(name)))
