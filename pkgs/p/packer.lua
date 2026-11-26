-- HashiCorp Packer - Automated machine image builder (binary: `packer`).
--
-- Verified 2026-11-26 against the official HashiCorp release 1.16.3: every
-- SHA256 below was verified against `packer_1.16.3_SHA256SUMS` and downloaded
-- archives. All five archives are flat `.zip` files (no enclosing directory)
-- containing `packer[.exe]` and `LICENSE.txt`.
-- The Linux binaries (x86_64 and aarch64) are statically linked Go executables
-- (`readelf -d`: no dynamic section, `ldd`: not a dynamic executable); the
-- Windows PE32+ binary imports only `kernel32.dll`.
package = {
    spec = "2",

    name = "packer",
    description = "Tool for creating identical machine images for multiple platforms from a single source configuration",
    homepage = "https://www.packer.io",
    authors = {"HashiCorp"},
    maintainers = {"https://github.com/hashicorp/packer"},
    licenses = {"BUSL-1.1"},
    repo = "https://github.com/hashicorp/packer",
    docs = "https://developer.hashicorp.com/packer/docs",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"devops", "iac", "cloud", "cli", "tools"},
    keywords = {"packer", "hashicorp", "image", "ami", "vm", "devops"},

    programs = {"packer"},
    xvm_enable = true,

    xpm = {
        linux = {
            source = "https://releases.hashicorp.com/packer/${version}/packer_${version}_linux_${arch_alias}.zip",
            ["latest"] = { ref = "1.16.3" },
            ["1.16.3"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "9d625866a239583652e6ea210234abfd6416a27459cd482e5a03a845b9726d6c",
                    aarch64 = "47f27ba2f2b313fc259e549d6bf9512b8f2a10fda9fdf4abd6aff8f267e7a032",
                },
            },
        },
        macosx = {
            source = "https://releases.hashicorp.com/packer/${version}/packer_${version}_darwin_${arch_alias}.zip",
            ["latest"] = { ref = "1.16.3" },
            ["1.16.3"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "b524e8aba9083ecc1945a9c1de28846e141caad36dca8ee6700b24d3bac580b3",
                    aarch64 = "ff6184d8c9c633c177d6b6e96965cf735fdfb797d9401d14ab0d7644850a2e08",
                },
            },
        },
        windows = {
            source = "https://releases.hashicorp.com/packer/${version}/packer_${version}_windows_${arch_alias}.zip",
            ["latest"] = { ref = "1.16.3" },
            ["1.16.3"] = {
                arch_alias = { x86_64 = "amd64" },
                sha256 = {
                    x86_64 = "257bb1af9ff9771aaa5542ee764c439d0983b6e28d6ae2f6e0e3b586489bc108",
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

function installed()
    return payload.present({ "packer", "LICENSE.txt" })
        or payload.present({ "packer.exe", "LICENSE.txt" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("packer: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."

    os.tryrm(dir)
    fs.mkdir_p(dir)

    if os.isfile(parent .. "/packer.exe") then
        for _, f in ipairs({ "packer.exe", "LICENSE.txt" }) do
            if os.isfile(parent .. "/" .. f) then
                os.mv(parent .. "/" .. f, dir .. "/" .. f)
            end
        end
    elseif os.isfile(parent .. "/packer") then
        for _, f in ipairs({ "packer", "LICENSE.txt" }) do
            if os.isfile(parent .. "/" .. f) then
                os.mv(parent .. "/" .. f, dir .. "/" .. f)
            end
        end
    elseif os.isfile(archive) then
        payload.unpack{}
    else
        error("packer: archive not found at " .. archive .. " and no extracted binary in " .. parent)
    end

    local is_win = os.isfile(dir .. "/packer.exe")
    local exe = is_win and "packer.exe" or "packer"

    if not is_win and os.isfile(dir .. "/" .. exe) then
        system.exec(string.format('chmod +x "%s"', dir .. "/" .. exe))
    end

    payload.require({ exe, "LICENSE.txt" })
    return true
end

function config()
    xvm.add("packer", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("packer")
    os.tryrm(pkginfo.install_dir())
    return true
end
