-- gron v0.7.1: official tomnomnom/gron release archives, downloaded and SHA256
-- checked for all six targets. Archives contain only gron / gron.exe at root.
-- Linux amd64 needs glibc's loader, libc and libpthread (GLIBC_2.3.2 maximum).
-- Use the managed glibc loader without adding RPATH: patchelf's RPATH rewrite
-- moves this Go binary's writable .dynamic into an RX LOAD and breaks startup.
-- glibc >=2.44.3 finds its libraries beside its loader; arm64 remains static.
-- Windows imports only kernel32.dll, with no VC runtime dependency. macOS uses Mach-O.
-- Upstream provides neither checksum assets nor GitHub asset digests for this
-- release. Its binaries report "gron version dev" despite the v0.7.1 release tag.
-- Upstream archives omit LICENSE, so install the exact v0.7.1 MIT notice below.
package = {
    spec = "2",
    name = "gron",
    description = "Make JSON greppable and convert filtered assignments back to JSON",
    homepage = "https://github.com/tomnomnom/gron",
    repo = "https://github.com/tomnomnom/gron",
    docs = "https://github.com/tomnomnom/gron#readme",
    authors = {"Tom Hudson"},
    maintainers = {"tomnomnom"},
    licenses = {"MIT"},
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"tools", "cli"},
    keywords = {"gron", "json", "grep", "ungron"},
    programs = {"gron"},
    xvm_enable = true,
    ci = { mirror = true },
    extensions = {
        autoupdate = {
            source = "https://github.com/tomnomnom/gron/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/tomnomnom/gron/releases/download/${tag}/gron-linux-amd64-${version}.tgz",
                            aarch64 = "https://github.com/tomnomnom/gron/releases/download/${tag}/gron-linux-arm64-${version}.tgz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/tomnomnom/gron/releases/download/${tag}/gron-darwin-amd64-${version}.tgz",
                            aarch64 = "https://github.com/tomnomnom/gron/releases/download/${tag}/gron-darwin-arm64-${version}.tgz",
                        },
                        windows = {
                            x86_64 = "https://github.com/tomnomnom/gron/releases/download/${tag}/gron-windows-amd64-${version}.zip",
                            aarch64 = "https://github.com/tomnomnom/gron/releases/download/${tag}/gron-windows-arm64-${version}.zip",
                        },
                    },
                },
            },
        },
    },
    xpm = {
        linux = {
            source = "https://github.com/tomnomnom/gron/releases/download/v${version}/gron-linux-${arch_alias}-${version}.tgz",
            deps = { runtime = { "xim:glibc@>=2.44.3" } },
            ["latest"] = { ref = "0.7.1" },
            ["0.7.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "ca0335826b02b044fa05d7e951521e45c6ced1c381a73ed5803450088e18bf22",
                    aarch64 = "5d1d4764723a0f768d9ddef0685a052f564c8bbf5e475382342faf4224a07d80",
                },
            },
        },
        macosx = {
            source = "https://github.com/tomnomnom/gron/releases/download/v${version}/gron-darwin-${arch_alias}-${version}.tgz",
            ["latest"] = { ref = "0.7.1" },
            ["0.7.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "59034d4aa883c5815784b290567d104669a51f20eaf97f1d8baa4f74e22047d6",
                    aarch64 = "1b9b987c6ead684a992db91b7a32fd15ef946013dfabfe84d00b2fa6f55d7182",
                },
            },
        },
        windows = {
            source = "https://github.com/tomnomnom/gron/releases/download/v${version}/gron-windows-${arch_alias}-${version}.zip",
            ["latest"] = { ref = "0.7.1" },
            ["0.7.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "5ed427a4a504d8e03a1770b71d4ad16a3764179e085b5ae84e51a57b299f300d",
                    aarch64 = "9bd38a241f1afdbd3c8f952b92b7090e7a446cac5251bfed3fdf28f219c9dda8",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.elfpatch")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

local LICENSE = [[MIT License

Copyright (c) 2016 Tom Hudson

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

function installed()
    assert(type(payload.present) == "function", "gron requires the index payload module")
    return payload.present({ "gron", "LICENSE" })
        or payload.present({ "gron.exe", "LICENSE" })
end

function install()
    assert(type(payload.require) == "function", "gron requires the index payload module")
    local archive = tostring(pkginfo.install_file() or ""):gsub("\\", "/")
    local parent = archive:match("^(.*)/[^/]+$") or "."
    local dir = pkginfo.install_dir()
    local windows = archive:match("%.zip$") ~= nil
    local exe = windows and "gron.exe" or "gron"

    if os.isfile(parent .. "/" .. exe) then
        os.tryrm(dir)
        fs.mkdir_p(dir)
        os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
    elseif windows then
        payload.unpack{}
    else
        error("gron: extracted binary not found in " .. parent)
    end
    if not windows then
        system.exec(string.format('chmod +x "%s"', dir .. "/" .. exe))
    end
    if archive:find("gron-linux-", 1, true) then
        assert(type(elfpatch.skip) == "function"
            and type(elfpatch.set_interpreter) == "function",
            "gron requires elfpatch interpreter control; run xlings self update")
        -- Like bun.lua, take ownership of relocation through supported APIs:
        -- preserve .dynamic and leave the static aarch64 ELF untouched.
        elfpatch.skip()
        if archive:find("gron-linux-amd64-", 1, true) then
            local exports = _RUNTIME and _RUNTIME.deps_exports
            assert(type(exports) == "table", "gron: no resolved runtime exports")
            local loader
            for _, runtime in pairs(exports) do
                if type(runtime) == "table" and type(runtime.loader) == "string"
                    and runtime.loader ~= "" then
                    assert(not loader or loader == runtime.loader, "gron: ambiguous runtime loader")
                    loader = runtime.loader
                end
            end
            assert(loader and os.isfile(loader), "gron: managed glibc loader is missing")
            local result = elfpatch.set_interpreter(dir .. "/gron", loader)
            assert(type(result) == "table" and result.failed == 0 and result.patched == 1,
                "gron: managed glibc interpreter could not be set")
        end
    end
    local license = assert(io.open(dir .. "/LICENSE", "wb"))
    assert(license:write(LICENSE))
    assert(license:close())
    payload.require({ exe, "LICENSE" })
    return true
end

function config()
    xvm.add("gron", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("gron")
    return true
end
