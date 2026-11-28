-- git-cliff: customizable, conventional-commit-aware changelog generation.
-- Verified upstream v2.14.2 archive bytes against GitHub's SHA256 asset digests;
-- all declared tarballs also match their official .sha512 sidecars. Upstream
-- Windows ZIPs have no checksum sidecars, so their GitHub digests are the source.
-- Linux uses static musl builds instead of GNU builds (glibc/libgcc dependencies).
-- Windows x86_64 uses GNU (OS/UCRT DLLs only), not MSVC (VCRUNTIME140.dll).
-- Windows ARM64 is omitted: its MSVC build imports VCRUNTIME140.dll, while
-- xim:vcruntime currently only supplies x86_64. macOS uses system dylibs only.
-- Every archive has one git-cliff-<version>/ root containing all three tools,
-- MIT/Apache-2.0 licenses, README, changelog, completions, and a man page.
-- The completion/man-page generators are build-time helpers (require OUT_DIR),
-- not user CLIs; retain the upstream files but only route git-cliff through xvm.

package = {
    spec = "2",
    name = "git-cliff",
    description = "A highly customizable changelog generator",
    homepage = "https://git-cliff.org",
    authors = {"Orhun Parmaksız", "git-cliff contributors"},
    maintainers = {"https://github.com/orhun/git-cliff/graphs/contributors"},
    licenses = {"MIT", "Apache-2.0"},
    repo = "https://github.com/orhun/git-cliff",
    docs = "https://git-cliff.org/docs/",
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"tools", "git"},
    keywords = {"git-cliff", "changelog", "conventional-commits", "release"},
    programs = {"git-cliff"},
    xvm_enable = true,
    ci = { mirror = true },

    extensions = {
        autoupdate = {
            source = "https://github.com/orhun/git-cliff/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/orhun/git-cliff/releases/download/${tag}/git-cliff-${version}-x86_64-unknown-linux-musl.tar.gz",
                            aarch64 = "https://github.com/orhun/git-cliff/releases/download/${tag}/git-cliff-${version}-aarch64-unknown-linux-musl.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/orhun/git-cliff/releases/download/${tag}/git-cliff-${version}-x86_64-apple-darwin.tar.gz",
                            aarch64 = "https://github.com/orhun/git-cliff/releases/download/${tag}/git-cliff-${version}-aarch64-apple-darwin.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/orhun/git-cliff/releases/download/${tag}/git-cliff-${version}-x86_64-pc-windows-gnu.zip",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/orhun/git-cliff/releases/download/v${version}/git-cliff-${version}-${arch}-unknown-linux-musl.tar.gz",
            ["latest"] = { ref = "2.14.2" },
            ["2.14.2"] = {
                sha256 = {
                    x86_64 = "fa21e2fc70046fcfd0e43e5e4613873ab799aff3d9dc8559c00d31b270e417d0",
                    aarch64 = "4be21b21ec9699af4d330b224aeba8a41d41d8f5b351ca2da8a9ea2bdc36380f",
                },
            },
        },
        macosx = {
            source = "https://github.com/orhun/git-cliff/releases/download/v${version}/git-cliff-${version}-${arch}-apple-darwin.tar.gz",
            ["latest"] = { ref = "2.14.2" },
            ["2.14.2"] = {
                sha256 = {
                    x86_64 = "4e647d2deb152aca1e987f225cf42b080b991dd98f3bce4027ef95446d982ac3",
                    aarch64 = "a0be97e237d440d34c5e508ec21d070b2c85cbb8be48a46a56f9a4e8bd247f05",
                },
            },
        },
        windows = {
            source = "https://github.com/orhun/git-cliff/releases/download/v${version}/git-cliff-${version}-${arch}-pc-windows-gnu.zip",
            ["latest"] = { ref = "2.14.2" },
            ["2.14.2"] = {
                sha256 = {
                    x86_64 = "ab802a72a1fbdd1e06f17001728cb801d04a180f320efb0ec94af84d2f6adbc7",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")
import("xim.pkgindex.shell")

local function required_files(suffix)
    return {
        "git-cliff" .. suffix,
        "git-cliff-completions" .. suffix,
        "git-cliff-mangen" .. suffix,
        "LICENSE-MIT", "LICENSE-APACHE", "man/git-cliff.1",
    }
end

function installed()
    return payload.present(required_files(""))
        or payload.present(required_files(".exe"))
end

function install()
    local archive = tostring(pkginfo.install_file() or ""):gsub("\\", "/")
    if archive == "" then error("git-cliff: install_file is empty") end
    local is_win = archive:match("%.zip$") ~= nil
    local suffix = is_win and ".exe" or ""
    payload.unpack{ extracted = "git-cliff-" .. pkginfo.version(), strip = 1 }
    if not is_win then
        for _, program in ipairs(package.programs) do
            shell.exec({ "chmod", "+x", pkginfo.install_dir() .. "/" .. program })
        end
    end
    payload.require(required_files(suffix))
    return true
end

function config()
    for _, program in ipairs(package.programs) do
        xvm.add(program, { bindir = pkginfo.install_dir() })
    end
    return true
end

function uninstall()
    for _, program in ipairs(package.programs) do
        xvm.remove(program)
    end
    return true
end
