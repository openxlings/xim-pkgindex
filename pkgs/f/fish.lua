package = {
    spec = "2",

    name = "fish",
    description = "Friendly interactive shell — smart, user-friendly, modern command-line",
    homepage = "https://fishshell.com",
    maintainers = {"fish-shell"},
    licenses = {"GPL-2.0"},
    repo = "https://github.com/fish-shell/fish-shell",
    ci = { mirror = true },
    docs = "https://fishshell.com/docs/current/",

    type = "package",
    -- 4.8.1: upstream's static x86_64 and aarch64 builds; older versions
    -- x86_64 only (an aarch64 reader refuses them, below).
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"shell", "cli"},
    keywords = {"fish", "shell", "interactive", "rust"},

    -- Upstream ships a single self-contained binary (static-pie linked,
    -- no glibc/musl runtime dep), so the only declared program is `fish`.
    programs = {"fish"},
    xvm_enable = true,

    -- 4.6.0 ships static-pie binaries on linux only; the macOS release
    -- tarballs are .app bundles / .pkg installers (not flat CLI tarballs)
    -- and Windows is upstream-unsupported, so this xpkg is linux-only.
    extensions = {
        autoupdate = {
            source = "https://github.com/fish-shell/fish-shell/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            aarch64 = "https://github.com/fish-shell/fish-shell/releases/download/${version}/fish-${version}-linux-aarch64.tar.xz",
                            x86_64 = "https://github.com/fish-shell/fish-shell/releases/download/${version}/fish-${version}-linux-x86_64.tar.xz",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {

            ["latest"] = { ref = "4.9.3" },
            ["4.8.1"] = {
                x86_64 = {
                    url = "https://github.com/fish-shell/fish-shell/releases/download/4.8.1/fish-4.8.1-linux-x86_64.tar.xz",
                    sha256 = "39cab35242ab77bfdbce73b473000c3b045aaf2fe0951b042199bb7fdba3df78",
                },
                aarch64 = {
                    url = "https://github.com/fish-shell/fish-shell/releases/download/4.8.1/fish-4.8.1-linux-aarch64.tar.xz",
                    sha256 = "a03c8a445570a2a37e114cb13cebe41842cf17c4dd67a6530a57f742db04eee4",
                },
            },
            ["4.8.0"] = {
                url = "https://github.com/fish-shell/fish-shell/releases/download/4.8.0/fish-4.8.0-linux-x86_64.tar.xz",
                sha256 = "98f7916878fc76be797cabf284f185b56f31a35681e3aec9b9faf7a4a6aa0d74",
            },
            ["4.6.0"] = {
                url = "https://github.com/fish-shell/fish-shell/releases/download/4.6.0/fish-4.6.0-linux-x86_64.tar.xz",
                sha256 = "497c9c4e3fb3c006fe9d2c9a5a5447c1c90490b6b4ce6bfaf75e53b495c82f36",
            },
            ["4.9.3"] = {
                aarch64 = {
                    url = "https://github.com/fish-shell/fish-shell/releases/download/4.9.3/fish-4.9.3-linux-aarch64.tar.xz",
                    sha256 = "57349f0111728c64b703a84e611aa97ff4d1fa8466385d64e67bd5bc3ffa49fc",
                },
                x86_64 = {
                    url = "https://github.com/fish-shell/fish-shell/releases/download/4.9.3/fish-4.9.3-linux-x86_64.tar.xz",
                    sha256 = "8f643d10ad1abb0ef7072764c01ceb5cf61b2d373fda400cf60f0bad69b7e095",
                },
            },
        },
    },
}

local recipe_arch = (os.arch and os.arch())
if recipe_arch == "aarch64" or recipe_arch == "arm64" then
    package.xpm.linux["4.8.0"] = nil
    package.xpm.linux["4.6.0"] = nil
end

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

-- The fish-<ver>-linux-<arch>.tar.xz archives are flat: a single `fish`
-- binary lands directly in the runtime download dir, with no enclosing
-- folder. Mirror the fzf pattern: explicitly mv the bare binary into a
-- fresh install_dir so xlings's auto-stage (which sees an empty install_dir
-- otherwise) doesn't pull unrelated runtimedir entries in.
function install()
    os.tryrm(pkginfo.install_dir())
    os.mkdir(pkginfo.install_dir())
    local download_dir = path.directory(pkginfo.install_file())
    os.mv(path.join(download_dir, "fish"), path.join(pkginfo.install_dir(), "fish"))
    return true
end

function config()
    xvm.add("fish", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("fish")
    return true
end
