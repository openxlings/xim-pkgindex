"""The Android package stores an APK without implicitly modifying devices."""
from pathlib import Path
import re

import pytest
from tests.lib.xpkg_parser import parse_xpkg
from tests.lib.assertions import (
    assert_required_fields, assert_valid_spec, assert_valid_type,
    assert_no_exec_xvm, assert_no_bashrc_modification,
    assert_no_direct_path_modification, assert_uses_new_api,
    assert_xim_add_succeeds,
)
from tests.e.test_eden import run_lua

PKG_FILE = "pkgs/e/eden-android.lua"


@pytest.mark.static
def test_metadata():
    meta = parse_xpkg(PKG_FILE)
    assert_required_fields(meta)
    assert_valid_spec(meta)
    assert_valid_type(meta)


@pytest.mark.isolation
def test_no_implicit_device_installation():
    assert_no_exec_xvm(PKG_FILE)
    assert_no_bashrc_modification(PKG_FILE)
    assert_no_direct_path_modification(PKG_FILE)
    assert_uses_new_api(PKG_FILE)
    src = Path(PKG_FILE).read_text()
    assert set(re.findall(r'import\("([^"]+)"\)', src)) <= {
        "xim.libxpkg.pkginfo", "xim.libxpkg.xvm"}
    assert not re.search(r'\b(?:system\.exec|os\.exec|path\.|is_host\(|raise\()', src)
    assert 'type = "group"' in src


@pytest.mark.static
def test_same_arm64_apk_on_every_host():
    run_lua('''
import = function() end
dofile(arg[1])
local first
for _, platform in ipairs({"linux", "windows", "macosx"}) do
    local p = package.xpm[platform]
    for _, arch in ipairs({"x86_64", "aarch64"}) do
        local r = assert(p[p.latest.ref][arch])
        assert(r.url:match("^https://stable%.eden%-emu%.dev/.*%-standard%.apk$"))
        assert(#r.sha256 == 64 and r.sha256:match("^%x+$"))
        if first then assert(r.url == first.url and r.sha256 == first.sha256) end
        first = r
    end
end
''', PKG_FILE)


@pytest.mark.index
def test_index():
    assert_xim_add_succeeds(PKG_FILE)
