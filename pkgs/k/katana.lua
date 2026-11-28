-- Official v1.8.0 ZIPs: all six hashes match upstream checksums, release asset
-- digests, and downloaded bytes. Linux amd64/arm64 are static Go ELF files;
-- Windows amd64/arm64 import only kernel32.dll. macOS uses native system libs.
-- Standard crawling needs no browser. Headless/hybrid crawling is an explicit
-- upstream opt-in requiring Chrome/Chromium and its platform dependencies;
-- these hooks never install or launch a browser or write user configuration.
package = {
    spec = "2",
    name = "katana",
    description = "Fast web crawler for automation with standard and optional headless crawling",
    type = "package",
    licenses = { "MIT" },
    repo = "https://github.com/projectdiscovery/katana",
    homepage = "https://github.com/projectdiscovery/katana",
    archs = { "x86_64", "aarch64" },
    status = "stable",
    programs = { "katana" },
    xvm_enable = true,
    ci = { mirror = true },

    xpm = {
        linux = {
            source = "https://github.com/projectdiscovery/katana/releases/download/v${version}/katana_${version}_linux_${arch_alias}.zip",
            ["latest"] = { ref = "1.8.0" },
            ["1.8.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "cb027ae99d0757061b70c07a15c7a80f62c5a535ab52c4a329f80c4b0a7309d2",
                    aarch64 = "80e269210727a855511ffac8dfb01297b2344742acec71a35e8ba4a67a90f0f2",
                },
            },
        },
        macosx = {
            source = "https://github.com/projectdiscovery/katana/releases/download/v${version}/katana_${version}_macOS_${arch_alias}.zip",
            ["latest"] = { ref = "1.8.0" },
            ["1.8.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "806256316dd45e0fe0e3985fd7283ddffc376c95cbaa3dcfd14cde6e1de61aaf",
                    aarch64 = "52e9802e9f83012a089fe57fb1ac476b936f181ac033c71bfa55f913c07cede6",
                },
            },
        },
        windows = {
            source = "https://github.com/projectdiscovery/katana/releases/download/v${version}/katana_${version}_windows_${arch_alias}.zip",
            ["latest"] = { ref = "1.8.0" },
            ["1.8.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "8013253e3092e08524527a5c3f7ebd70747acc4bb51414858f8e6dffeb17f907",
                    aarch64 = "4b7c2e5759c8ea1a72081d75930e1ef24853a933c1d35e114ef6787bfc8ae058",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

local function required_files()
    local exe = os.getenv("OS") == "Windows_NT" and "katana.exe" or "katana"
    return { exe, "LICENSE.md", "README.md" }
end

function installed()
    return payload.present(required_files())
end

function install()
    if os.getenv("OS") == "Windows_NT" then
        -- Flat ZIP: re-extract only this archive with the shared native helper.
        payload.unpack{}
    else
        -- The framework extracts the flat ZIP beside install_file on POSIX.
        -- Move only its complete manifest, never the shared extraction directory.
        local archive = tostring(pkginfo.install_file()):gsub("\\", "/")
        local parent = archive:match("^(.*)/[^/]+$") or "."
        local dir = pkginfo.install_dir()
        os.tryrm(dir)
        fs.mkdir_p(dir)
        for _, file in ipairs(required_files()) do
            os.mv(parent .. "/" .. file, dir .. "/" .. file)
        end
    end
    payload.require(required_files())
    return true
end

function config()
    xvm.add("katana", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("katana")
    return true
end
