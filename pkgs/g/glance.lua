-- Glance: a self-hosted, configurable dashboard for feeds and local widgets.
-- Verified 2026-11-28 against upstream v0.8.8: all six downloaded archives
-- match the SHA256 digests in GitHub's release asset API (no checksum file).
-- Tarballs contain only `glance`; Windows zips contain only `glance.exe`.
-- Linux amd64/arm64 are static Go ELFs with no interpreter or dynamic section,
-- so neither a host libc nor a packaged runtime dependency is required.
--
-- AGPL-3.0 upstream binaries are downloaded unmodified from their release:
-- https://github.com/glanceapp/glance/releases/tag/v0.8.8
-- Corresponding source and license: https://github.com/glanceapp/glance/tree/v0.8.8
-- No daemon, service, configuration file, or environment change is installed.
-- Start explicitly with `glance --config /path/to/glance.yml`; configuration
-- location, bind address, and service management remain the user's choice.
package = {
    spec = "2",
    name = "glance",
    description = "A self-hosted dashboard that puts all your feeds in one place",
    homepage = "https://github.com/glanceapp/glance",
    authors = {"Glance contributors"},
    maintainers = {"https://github.com/glanceapp/glance/graphs/contributors"},
    licenses = {"AGPL-3.0"},
    repo = "https://github.com/glanceapp/glance",
    docs = "https://github.com/glanceapp/glance/blob/main/docs/configuration.md",
    ci = { mirror = true },
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"dashboard", "server", "tools"},
    keywords = {"glance", "dashboard", "self-hosted", "feeds", "rss"},
    programs = {"glance"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/glanceapp/glance/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/glanceapp/glance/releases/download/${tag}/glance-linux-amd64.tar.gz",
                            aarch64 = "https://github.com/glanceapp/glance/releases/download/${tag}/glance-linux-arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/glanceapp/glance/releases/download/${tag}/glance-darwin-amd64.tar.gz",
                            aarch64 = "https://github.com/glanceapp/glance/releases/download/${tag}/glance-darwin-arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/glanceapp/glance/releases/download/${tag}/glance-windows-amd64.zip",
                            aarch64 = "https://github.com/glanceapp/glance/releases/download/${tag}/glance-windows-arm64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/glanceapp/glance/releases/download/v${version}/glance-linux-${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.8.8" },
            ["0.8.8"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "396b1ee30337afd5cac8d2e744dd449674d9691156536363096c1b92d96b291b",
                    aarch64 = "3aee9fee61b9c5ce9a2b68f415db0806a5e0096e335d0bb4f1fee064932d2124",
                },
            },
        },
        macosx = {
            source = "https://github.com/glanceapp/glance/releases/download/v${version}/glance-darwin-${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.8.8" },
            ["0.8.8"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "0ad5d935975bdbcd049d110444f6ade47835eec286efe060665d8b30e4d7fd21",
                    aarch64 = "03e295be98e1f70cc8a6a2aa1900de37ebc2a09700412f95e80a668c19b45c1b",
                },
            },
        },
        windows = {
            source = "https://github.com/glanceapp/glance/releases/download/v${version}/glance-windows-${arch_alias}.zip",
            ["latest"] = { ref = "0.8.8" },
            ["0.8.8"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "e14a9efccb845e9f6abce363302eafdc915a8cb348be1d8423269b75ef66bfe7",
                    aarch64 = "d27ab0982c52c0e0d8d8922332d72a99a5c1b6a6a329367ce832dd9cf7663514",
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

function installed()
    return payload.present({ "glance" }) or payload.present({ "glance.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" or not os.isfile(archive) then
        error("glance: archive not found: " .. archive)
    end
    local normalized = archive:gsub("\\", "/")
    local is_win = normalized:match("%.zip$") ~= nil
    local dir = pkginfo.install_dir()

    -- Flat archives must be extracted into a clean package-owned directory,
    -- not moved from the shared extraction directory (which can hold other tools).
    if is_win then
        payload.unpack{}
    else
        os.tryrm(dir)
        fs.mkdir_p(dir)
        shell.exec({ "tar", "-xzf", normalized, "-C", dir })
        shell.exec({ "chmod", "+x", dir .. "/glance" })
    end
    payload.require({ is_win and "glance.exe" or "glance" })
    return true
end

function config()
    xvm.add("glance", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("glance")
    return true
end
