-- Core fixup creation uses bundled libgit2, not an external git process.
-- `git absorb` dispatch and optional --and-rebase require the user's Git.
-- The x86_64 musl build is static; Darwin links only system libraries;
-- the MSVC executable imports only Windows OS DLLs (no compiler runtime).
package = {
    spec = "2",
    name = "git-absorb",
    description = "Automatically create Git fixup commits from staged changes",
    homepage = "https://github.com/tummychow/git-absorb",
    repo = "https://github.com/tummychow/git-absorb",
    docs = "https://github.com/tummychow/git-absorb#readme",
    authors = {"Stephen Jung"},
    maintainers = {"Stephen Jung"},
    licenses = {"BSD-3-Clause"},
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"git", "tools"},
    keywords = {"git", "fixup", "commits", "rust"},
    programs = {"git-absorb"},
    xvm_enable = true,
    ci = { mirror = true },

    extensions = {
        autoupdate = {
            source = "https://github.com/tummychow/git-absorb/releases",
            resources = {
                GLOBAL = { url = {
                    linux = {
                        x86_64 = "https://github.com/tummychow/git-absorb/releases/download/${tag}/git-absorb-${version}-x86_64-unknown-linux-musl.tar.gz",
                    },
                    macosx = {
                        x86_64 = "https://github.com/tummychow/git-absorb/releases/download/${tag}/git-absorb-${version}-x86_64-apple-darwin.tar.gz",
                    },
                    windows = {
                        x86_64 = "https://github.com/tummychow/git-absorb/releases/download/${tag}/git-absorb-${version}-x86_64-pc-windows-msvc.zip",
                    },
                } },
            },
        },
    },

    xpm = {
        linux = {
            ["latest"] = { ref = "0.9.0" },
            ["0.9.0"] = {
                x86_64 = {
                    url = "https://github.com/tummychow/git-absorb/releases/download/0.9.0/git-absorb-0.9.0-x86_64-unknown-linux-musl.tar.gz",
                    sha256 = "517b442260a38617b05df0078b9e659b95068fabe8d0a83a33589d15f198d9a7",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "0.9.0" },
            ["0.9.0"] = {
                x86_64 = {
                    url = "https://github.com/tummychow/git-absorb/releases/download/0.9.0/git-absorb-0.9.0-x86_64-apple-darwin.tar.gz",
                    sha256 = "1df9ad9206b2a2f0ce312a89188f80d3bace8471ca2799533beec6d83371f760",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "0.9.0" },
            ["0.9.0"] = {
                x86_64 = {
                    url = "https://github.com/tummychow/git-absorb/releases/download/0.9.0/git-absorb-0.9.0-x86_64-pc-windows-msvc.zip",
                    sha256 = "3fcf1d9b4f42017dbffe90539c6be5ac415e9b119552c5ae5cdbb034d36aab87",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

local function required_files()
    local executable = tostring(pkginfo.install_file()):match("%.zip$")
        and "git-absorb.exe" or "git-absorb"
    return {
        executable, "LICENSE.md", "README.md",
        "doc/git-absorb.1", "doc/git-absorb.html", "doc/git-absorb.adoc",
    }
end

function installed()
    return payload.present(required_files())
end

function install()
    local archive = tostring(pkginfo.install_file()):gsub("\\", "/")
    local stem = archive:match("([^/]+)$"):gsub("%.tar%.gz$", ""):gsub("%.zip$", "")
    payload.unpack{ extracted = stem, strip = 1 }
    payload.require(required_files())
    return true
end

function config()
    xvm.add("git-absorb", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("git-absorb")
    return true
end
