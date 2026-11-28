-- Official v1.1.3 archives are flat and contain only jid[.exe]. All six
-- SHA256s match upstream checksums.txt and GitHub asset digests. Linux builds
-- are static Go binaries; Windows amd64/arm64 import only kernel32.dll.
package = {
    spec = "2",
    name = "jid",
    description = "Interactively drill down JSON with filtering and JMESPath queries",
    homepage = "https://github.com/simeji/jid",
    authors = { "simeji" },
    licenses = { "MIT" },
    repo = "https://github.com/simeji/jid",
    docs = "https://github.com/simeji/jid#readme",
    type = "package",
    archs = { "x86_64", "aarch64" },
    status = "stable",
    categories = { "tools", "cli" },
    keywords = { "json", "interactive", "filter", "jmespath" },
    programs = { "jid" },
    xvm_enable = true,
    ci = { mirror = true },
    extensions = {
        autoupdate = {
            source = "https://github.com/simeji/jid/releases",
            resources = {
                GLOBAL = { url = {
                    linux = {
                        x86_64 = "https://github.com/simeji/jid/releases/download/${tag}/jid_linux_amd64.zip",
                        aarch64 = "https://github.com/simeji/jid/releases/download/${tag}/jid_linux_arm64.zip",
                    },
                    macosx = {
                        x86_64 = "https://github.com/simeji/jid/releases/download/${tag}/jid_darwin_amd64.zip",
                        aarch64 = "https://github.com/simeji/jid/releases/download/${tag}/jid_darwin_arm64.zip",
                    },
                    windows = {
                        x86_64 = "https://github.com/simeji/jid/releases/download/${tag}/jid_windows_amd64.zip",
                        aarch64 = "https://github.com/simeji/jid/releases/download/${tag}/jid_windows_arm64.zip",
                    },
                } },
            },
        },
    },
    xpm = {
        linux = {
            source = "https://github.com/simeji/jid/releases/download/v${version}/jid_linux_${arch_alias}.zip",
            ["latest"] = { ref = "1.1.3" },
            ["1.1.3"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "e3731dfbf3948113df78b4ef642c4f85b7bd6732c11f66f71489cf9152a42701",
                    aarch64 = "ee4eb30853597c48d304b63fc6fb9e058ff2c039b296ce3506fc7b1a77a9b58b",
                },
            },
        },
        macosx = {
            source = "https://github.com/simeji/jid/releases/download/v${version}/jid_darwin_${arch_alias}.zip",
            ["latest"] = { ref = "1.1.3" },
            ["1.1.3"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "bc04fa1d0faeae545eff9cec176ebae437451546c149090e2877babf61ef4755",
                    aarch64 = "2f63039c83581be6ac26da38fdcf1b575f15f38a128089c9642647b5fcb8b2e1",
                },
            },
        },
        windows = {
            source = "https://github.com/simeji/jid/releases/download/v${version}/jid_windows_${arch_alias}.zip",
            ["latest"] = { ref = "1.1.3" },
            ["1.1.3"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "02153d3edae1ec7bfdcfb21de5904469fac75cbbac8f6199639d31b69c8aef3b",
                    aarch64 = "a19dba7ad4ca0939f1722fc29aa5b89a179fd60bfc7f8f697d619fee9c8bd07f",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")
import("xim.pkgindex.shell")

local function required_files()
    return { os.getenv("OS") == "Windows_NT" and "jid.exe" or "jid" }
end

function installed()
    return payload.present(required_files())
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then error("jid: install_file is empty") end
    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local exe = required_files()[1]

    os.tryrm(dir)
    fs.mkdir_p(dir)
    if os.isfile(archive) then
        if exe == "jid.exe" then
            payload.unpack{}
        else
            shell.exec({ "unzip", "-q", "-o", archive, "-d", dir })
        end
    elseif os.isfile(parent .. "/" .. exe) then
        os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
    else
        error("jid: neither archive nor extracted " .. exe .. " found in " .. parent)
    end
    payload.require(required_files())
    if exe == "jid" then shell.exec({ "chmod", "+x", dir .. "/jid" }) end
    return true
end

function config()
    xvm.add("jid", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("jid")
    return true
end
