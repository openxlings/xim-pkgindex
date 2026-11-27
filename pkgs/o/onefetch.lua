-- Onefetch: command-line Git repository information.
-- Verified 2026-11-27 against o2sh/onefetch 3.3.0 and GitHub asset SHA256 digests.
-- Generic archive names are NOT architecture-neutral: linux is x86_64 ELF,
-- mac is a thin arm64 Mach-O (macOS 11+, not universal), win is x86_64 PE.
-- Linux NEEDED: libgcc_s.so.1, libm.so.6, libc.so.6; mandatory glibc symbols
-- reach GLIBC_2.34 (GLIBC_2.39 references are weak). xlings elfpatch supplies
-- the declared glibc/GCC runtime closure. macOS imports only system libraries.
-- Windows imports VCRUNTIME140.dll: deploy it app-local from xim:vcruntime.
-- Archives contain only the executable. Preserve the upstream MIT notice below
-- (https://raw.githubusercontent.com/o2sh/onefetch/3.3.0/LICENSE.md).

package = {
    spec = "2",
    name = "onefetch",
    description = "Command-line Git repository information with language statistics and commit history",
    homepage = "https://onefetch.dev",
    authors = {"Ossama Hjaji"},
    maintainers = {"https://github.com/o2sh/onefetch/graphs/contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/o2sh/onefetch",
    docs = "https://github.com/o2sh/onefetch/wiki",
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "git", "tools"},
    keywords = {"onefetch", "git", "repository", "statistics", "languages", "rust"},
    programs = {"onefetch"},
    xvm_enable = true,
    ci = { mirror = true },

    extensions = {
        autoupdate = {
            source = "https://github.com/o2sh/onefetch/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/o2sh/onefetch/releases/download/${tag}/onefetch-linux.tar.gz",
                        },
                        macosx = {
                            aarch64 = "https://github.com/o2sh/onefetch/releases/download/${tag}/onefetch-mac.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/o2sh/onefetch/releases/download/${tag}/onefetch-win.tar.gz",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            deps = { runtime = { "xim:glibc@>=2.39", "xim:gcc-runtime@15.1.0" } },
            ["latest"] = { ref = "3.3.0" },
            ["3.3.0"] = {
                x86_64 = {
                    url = "https://github.com/o2sh/onefetch/releases/download/3.3.0/onefetch-linux.tar.gz",
                    sha256 = "664ca61395157d722cd70eb20549d250b36cfcf4a71aae5229bd928b8afd2301",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "3.3.0" },
            ["3.3.0"] = {
                aarch64 = {
                    url = "https://github.com/o2sh/onefetch/releases/download/3.3.0/onefetch-mac.tar.gz",
                    sha256 = "ce507fcd2ca993c73acc247a0acc831924b55cd8d9e20efca0e2ba7fad962620",
                },
            },
        },
        windows = {
            deps = { runtime = { "xim:vcruntime" } },
            ["latest"] = { ref = "3.3.0" },
            ["3.3.0"] = {
                x86_64 = {
                    url = "https://github.com/o2sh/onefetch/releases/download/3.3.0/onefetch-win.tar.gz",
                    sha256 = "3b900747d75195fbfdc04cdd6c8f858d72918c67cba178526f26d68ab69f9653",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")
import("xim.pkgindex.shell")
import("xim.pkgindex.winpath")

local LICENSE = [[MIT License

Copyright (c) 2018 Ossama Hjaji

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
    return payload.present({ "onefetch", "LICENSE.md" })
        or payload.present({ "onefetch.exe", "LICENSE.md", "vcruntime140.dll" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("onefetch%-win%.tar%.gz$") ~= nil
    local exe = is_win and "onefetch.exe" or "onefetch"

    os.tryrm(dir)
    fs.mkdir_p(dir)
    if os.isfile(archive) then
        -- Flat tarballs: extract into a clean directory, never move a shared
        -- download directory. Use Windows' system tar, not Git's GNU tar.
        if is_win then
            local root = winpath.native(os.getenv("SystemRoot") or "C:\\Windows"):gsub("\\+$", "")
            -- exec-quoting-ok: cmd.exe sees the system tar executable first; paths are quoted
            system.exec(string.format('%s\\System32\\tar.exe -xzf "%s" -C "%s"',
                root, winpath.native(archive), winpath.native(dir)))
        else
            shell.exec({ "tar", "-xzf", archive, "-C", dir })
        end
    elseif os.isfile(parent .. "/" .. exe) then
        os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
    else
        error("onefetch: archive and extracted executable are missing: " .. archive)
    end

    local required = { exe, "LICENSE.md" }
    if is_win then
        local crt = assert(pkginfo.dep_install_dir("xim:vcruntime"),
                           "onefetch: xim:vcruntime payload directory is missing")
        os.cp(crt .. "/bin/vcruntime140.dll", dir .. "/vcruntime140.dll")
        required[#required + 1] = "vcruntime140.dll"
    else
        shell.exec({ "chmod", "+x", dir .. "/" .. exe })
    end
    local license = assert(io.open(dir .. "/LICENSE.md", "wb"))
    assert(license:write(LICENSE))
    assert(license:close())
    payload.require(required)
    return true
end

function config()
    xvm.add("onefetch", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("onefetch")
    return true
end
