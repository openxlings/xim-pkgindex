"""vcruntime: the MSVC runtime DLLs, as a dependency prebuilt programs take.

Static checks, and a behaviour check in a sandbox: install() runs against a
synthetic burn bundle (a PE carrying a UX CAB, then the payload container)
with `system.exec` forged to unpack what the real 7-Zip would -- so what is
checked on this machine is the part that decides correctness: the LAST CAB
signature is taken for the payload container, a payload is identified by
what it unpacks to (`*_amd64` files, not `_arm64`), the suffix is stripped
on landing, and a missing DLL is named. The real 7-Zip extraction, and the
real redistributable, are the Windows install job of this recipe's own PR.
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
    assert_xim_add_succeeds, assert_valid_xvm_node_kinds,
)

PKG = "vcruntime"
PKG_FILE = "pkgs/v/vcruntime.lua"

# The bundle this recipe carves: a PE with a UX cab, then the payload
# container. The recipe must take the LAST MSCF, not the first.
SYNTHETIC_EXE = (
    b"MZ\x90\x00fake-PE-header"
    b"MSCF" + b"ux-cab-content"
    b"MSCF" + b"payload-container-bytes"
)


def _run_lua(script, *args):
    lua = shutil.which("lua5.4") or shutil.which("lua")
    if not lua:
        pytest.skip("Lua interpreter is unavailable")
    r = subprocess.run([lua, "-", *args], input=script, text=True,
                       capture_output=True)
    assert r.returncode == 0, "lua stderr:\n" + r.stderr + "\nstdout:\n" + r.stdout
    return r.stdout


@pytest.fixture(scope="module")
def meta():
    return parse_xpkg(PKG_FILE)


def _code(src: str):
    """The recipe's lines with Lua comments removed (a name in a comment is
    documentation; one in code is code)."""
    for line in src.splitlines():
        stripped = line.lstrip()
        if stripped.startswith("--"):
            continue
        cut = line.find(" --")
        yield line if cut == -1 else line[:cut]


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
    def test_windows_x64_only(self, meta):
        assert set(meta.platforms.keys()) == {"windows"}
        assert 'archs = {"x86_64"}' in meta.raw_content

    @pytest.mark.static
    def test_url_is_the_pinned_official_one(self):
        code = "\n".join(_code(Path(PKG_FILE).read_text(encoding="utf-8")))
        url = re.search(r'url = "(https://download\.visualstudio\.microsoft\.com/download/pr/[^"]+)"', code)
        sha = re.search(r'sha256 = "([0-9a-f]{64})"', code)
        assert url and sha, "the entry must pin the versioned URL and its hash"
        segment = url.group(1).split("/")[6]
        assert segment.lower() == sha.group(1), (
            "the URL's embedded digest must equal the pinned sha256")
        assert "aka.ms" not in code, "the moving alias must not be pinned"

    @pytest.mark.static
    def test_no_programs_no_mirror(self):
        # nothing callable (a group node, not a program); no unverified CN
        code = "\n".join(_code(Path(PKG_FILE).read_text(encoding="utf-8")))
        assert not re.search(r'\bprograms\s*=', code), "nothing is callable"
        assert not re.search(r'\bmirror\s*=', code), "no unverified CN mirror"

    @pytest.mark.static
    def test_valid_xvm_node_kinds(self, meta):
        assert_valid_xvm_node_kinds(meta)

    @pytest.mark.static
    def test_extraction_sandbox(self, tmp_path):
        exe = tmp_path / "VC_redist.x64.exe"
        exe.write_bytes(SYNTHETIC_EXE)
        pkg = tmp_path / "payload"
        _run_lua('''
import = function() end
winpath = assert(loadfile("libs/winpath.lua"))()
payload = assert(loadfile("libs/payload.lua"))()

local EXE, PKG = arg[2], arg[3]

-- plain-Lua os: the few calls the recipe makes, as real as tmp_path allows
os.host = function() return "windows" end
os.isfile = function(p)
    local f = io.open(p, "rb")
    if f then f:close() return true end
    return false
end
os.tryrm = function(p) os.execute(string.format('rm -rf "%s"', p)) end
os.mv = function(s, d)
    local i = assert(io.open(s, "rb"))
    local b = i:read("*a")
    i:close()
    local o = assert(io.open(d, "wb"))
    o:write(b)
    o:close()
    os.remove(s)
end

-- the staged filesystem: the forged exec records what it "unpacks", and the
-- listing a real fs.files would answer is that same record
local staged = {}
fs = {
    mkdir_p = function(p) os.execute(string.format('mkdir -p "%s"', p)) end,
    files = function(dir)
        local out = {}
        for _, p in ipairs(staged[dir] or {}) do out[#out + 1] = p end
        return out
    end,
}
local execs = {}
local carved = nil
system = { exec = function(cmd)
    execs[#execs + 1] = cmd
    -- the recipe hands 7-Zip native-separator paths; this POSIX sandbox
    -- normalizes them back before touching the filesystem
    local dir = cmd:match('%-o"([^"]+)"'):gsub("\\\\", "/")
    local cab = cmd:match('"([^"]+)"$'):gsub("\\\\", "/")
    local function unpack_into(name, bytes)
        local path = dir .. "/" .. name
        local f = assert(io.open(path, "wb"))
        f:write(bytes)
        f:close()
        -- a fresh unpack of the directory (-y overwrites), not an append:
        -- the listing must not replay files a previous install already moved
        staged[dir] = staged[dir] ~= nil and staged[dir] or {}
        local fresh = {}
        for _, p in ipairs(staged[dir]) do
            if p ~= path then fresh[#fresh + 1] = p end
        end
        fresh[#fresh + 1] = path
        staged[dir] = fresh
    end
    if cab:match("%.vcruntime%-stage%.cab$") then
        -- capture what was carved, before install() cleans up after itself
        local f = assert(io.open(cab, "rb"))
        carved = f:read("*a")
        f:close()
        -- the container: an MSI without CAB magic (must be skipped by the
        -- magic read), and the x64 CRT package's cab
        unpack_into("a0.msi", "D0CF-not-a-cab")
        unpack_into("a12", "MSCF" .. "crt-cab")
    elseif cab:match("/a12$") then
        for _, name in ipairs({
            "vcruntime140.dll", "vcruntime140_1.dll", "vcruntime140_threads.dll",
            "msvcp140.dll", "msvcp140_1.dll", "msvcp140_2.dll",
            "msvcp140_atomic_wait.dll", "msvcp140_codecvt_ids.dll",
            "concrt140.dll", "vcamp140.dll", "vcomp140.dll", "vccorlib140.dll",
        }) do
            unpack_into(name .. "_amd64", "PE64")
        end
        unpack_into("msvcp140.dll_arm64", "PEAA")   -- a different package's file
    else
        error("unexpected extraction: " .. cmd)
    end
end }
local adds = {}
xvm = { add = function(name, opts) table.insert(adds, {name, opts}) end,
        remove = function() end }
pkginfo = {
    name = function() return "vcruntime" end,
    version = function() return "14.44.35211" end,
    install_file = function() return EXE end,
    install_dir = function() return PKG end,
    build_dep = function() return { path = "C:/tools/7zip" } end,
}
log = { info = function() end, warn = function() end, error = function() end }

dofile(arg[1])

assert(install())

-- the container carved out starts at the LAST cab signature (magic
-- included -- 7-Zip needs the CAB header), not at the UX one
assert(carved == "MSCF" .. "payload-container-bytes",
       "the wrong container was carved: " .. tostring(carved))

-- two extractions: the container, then the one file that is a cab; the MSI
-- decoy never ran
assert(#execs == 2, #execs .. " extractions: " .. table.concat(execs, " | "))

-- the DLLs landed under canonical names; the arm64 file did not move
local bin = {}
local handle = io.popen("ls -1 " .. PKG .. "/bin")
for name in handle:lines() do bin[#bin + 1] = name end
handle:close()
table.sort(bin)
assert(#bin == 12 and bin[1] == "concrt140.dll" and bin[12] == "vcruntime140_threads.dll",
       "the twelve canonical DLLs, got: " .. table.concat(bin, ","))

-- the group node, not a program
assert(config())
assert(adds[1][1] == "vcruntime" and adds[1][2].type == "group")

assert(installed())

-- a removed DLL makes installed() false, and a rebuild restores the set
os.remove(PKG .. "/bin/vcruntime140.dll")
assert(not installed())
assert(install())
assert(installed())
''', PKG_FILE, str(exe), str(pkg))


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

    @pytest.mark.isolation
    def test_portable_lua_and_libxpkg_only(self):
        src = Path(PKG_FILE).read_text(encoding="utf-8")
        assert set(re.findall(r'import\("([^"]+)"\)', src)) <= {
            "xim.libxpkg.fs", "xim.libxpkg.log", "xim.libxpkg.pkginfo",
            "xim.libxpkg.system", "xim.libxpkg.xvm",
            "xim.pkgindex.payload", "xim.pkgindex.winpath",
        }
        assert not re.search(r'\b(?:is_host\(|raise\()', src)
