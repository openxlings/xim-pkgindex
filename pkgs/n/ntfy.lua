-- Official portable archives only: no service, firewall, or system configuration.
-- Darwin's universal binary is client-only (upstream builds it with `noserver`).
-- Windows ARM64 has no upstream asset; only native 64-bit targets are declared.
-- Bundled YAML/service files remain inert examples inside the package directory.
package = {
    spec = "2",
    name = "ntfy",
    description = "HTTP-based pub-sub notification client and server",
    homepage = "https://ntfy.sh",
    authors = {"Philipp C. Heckel and contributors"},
    maintainers = {"binwiederhier"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/binwiederhier/ntfy",
    docs = "https://docs.ntfy.sh",
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"tools", "network"},
    keywords = {"ntfy", "notifications", "pubsub"},
    programs = {"ntfy"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/binwiederhier/ntfy/releases",
            resources = {
                GLOBAL = { url = {
                    linux = {
                        x86_64 = "https://github.com/binwiederhier/ntfy/releases/download/v${version}/ntfy_${version}_linux_amd64.tar.gz",
                        aarch64 = "https://github.com/binwiederhier/ntfy/releases/download/v${version}/ntfy_${version}_linux_arm64.tar.gz",
                    },
                    macosx = {
                        x86_64 = "https://github.com/binwiederhier/ntfy/releases/download/v${version}/ntfy_${version}_darwin_all.tar.gz",
                        aarch64 = "https://github.com/binwiederhier/ntfy/releases/download/v${version}/ntfy_${version}_darwin_all.tar.gz",
                    },
                    windows = {
                        x86_64 = "https://github.com/binwiederhier/ntfy/releases/download/v${version}/ntfy_${version}_windows_amd64.zip",
                    },
                } },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/binwiederhier/ntfy/releases/download/v${version}/ntfy_${version}_linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "2.38.2" },
            ["2.38.2"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "2040946f6e1103420e72a79a7048c841fb73cd51c17d45232e0c8f6ac7f0d531",
                    aarch64 = "c9f59415ec445e0d869f4294c689610cfe8b73f65948bf43c183233747fbf7f4",
                },
            },
        },
        macosx = {
            source = "https://github.com/binwiederhier/ntfy/releases/download/v${version}/ntfy_${version}_darwin_all.tar.gz",
            ["latest"] = { ref = "2.38.2" },
            ["2.38.2"] = {
                sha256 = {
                    x86_64 = "04afb92459357deaa16fe2b0c091b9df0e2d986a9057cc41f9cb1bed787c115c",
                    aarch64 = "04afb92459357deaa16fe2b0c091b9df0e2d986a9057cc41f9cb1bed787c115c",
                },
            },
        },
        windows = {
            source = "https://github.com/binwiederhier/ntfy/releases/download/v${version}/ntfy_${version}_windows_amd64.zip",
            ["latest"] = { ref = "2.38.2" },
            ["2.38.2"] = {
                sha256 = {
                    x86_64 = "3549ff885b65325e3ee35047a2d76a3c8be30aa045b478ca17309233f157c2e7",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

local function required_files()
    local dir = pkginfo.install_dir()
    local exe = os.isfile(dir .. "/ntfy.exe") and "ntfy.exe" or "ntfy"
    return { exe, "LICENSE", "README.md", "client/client.yml" }
end

function installed()
    return payload.present(required_files())
end

function install()
    local archive = tostring(pkginfo.install_file()):gsub("\\", "/")
    local stem = archive:match("([^/]+)$"):gsub("%.tar%.gz$", ""):gsub("%.zip$", "")
    -- Each upstream archive wraps its payload in a directory named after the archive.
    payload.unpack{ extracted = stem, strip = 1 }
    payload.require(required_files())
    return true
end

function config()
    xvm.add("ntfy", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("ntfy")
    return true
end
