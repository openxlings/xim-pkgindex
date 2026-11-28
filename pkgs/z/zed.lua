-- Zed is a code editor written in Rust that draws with the GPU. The package
-- installs the release Zed publishes on GitHub and puts its command-line
-- launcher, `zed`, on PATH: `zed <path>` opens a file or a folder, and
-- `zed --version` names the editor the launcher starts.
--
-- Verified 2026-11-22 against the GitHub Releases API: v1.29.3 is the latest
-- release (published 2026-11-20). Every hash below is the sha256 digest GitHub
-- records for the asset, and each asset was downloaded and hashed to the same
-- value.
--
-- Windows is not declared. Zed publishes Zed-x86_64.exe and Zed-aarch64.exe,
-- and both are Inno Setup 6.4 installers rather than archives (measured with
-- `strings`: "Inno Setup Setup Data (6.4.3)"). Running one installs into the
-- user's profile and registry, outside the install directory; unpacking one
-- needs an extractor this index does not have. Windows is added when that is
-- solved.
--
-- Linux: the archive holds zed.app/ with bin/zed (the launcher),
-- libexec/zed-editor (the editor), lib/ (the X11, xcb, xkbcommon, libbsd and
-- libstdc++ libraries it carries) and share/ (the icon and a desktop file,
-- which this recipe does not install). The launcher finds the editor at
-- ../libexec/zed-editor relative to itself, so the tree is kept whole.
--
-- ON THE HOST'S LOADER, AND WITHOUT A LOADER DEPENDENCY. Both ELF files use
-- /lib64/ld-linux-x86-64.so.2 and find the libraries Zed carries through
-- DT_RPATH $ORIGIN/../lib; libexec/zed-editor adds /usr/lib/x86_64-linux-gnu.
-- Measured on the x86_64 payload with LD_TRACE_LOADED_OBJECTS=1, what comes
-- from the host is glibc (libc, libm, libdl, libpthread, libgcc_s), GLib
-- (libgio, libgobject, libglib, libgmodule and their libz, libmount,
-- libselinux, libffi, libpcre2, libblkid) and ALSA (libasound). At run time
-- the editor also opens the host's Vulkan driver and its X11 or Wayland
-- session. That is the desktop the user is logged into, as with code.lua.
-- Declaring xim:glibc would make elfpatch rewrite the DT_RPATH, and Zed would
-- stop finding its own lib/ while the install still reported success.
--
-- macOS: the disk image holds Zed.app; Contents/MacOS/cli is the launcher
-- (Zed installs it as `zed`) and Contents/MacOS/zed the editor. The bundle is
-- copied with ditto, which keeps its signature.
--
-- Mirrored to GitCode as xlings-res/zed@1.29.3: the four assets and their
-- .sha256 sidecars, downloaded back and hashed to the values below. The
-- mirror job (ci.mirror) publishes the same release to github.com/xlings-res
-- and keeps both in step after an update. Zed is GPL-3.0-or-later; the mirror
-- carries Zed's own unmodified release, and its corresponding source is the
-- tag of the same name in the repository below.
package = {
    spec = "2",

    homepage = "https://zed.dev",
    name = "zed",
    description = "Code editor written in Rust that draws with the GPU",

    maintainers = {"https://github.com/zed-industries/zed/graphs/contributors"},
    licenses = {"GPL-3.0-or-later"},
    repo = "https://github.com/zed-industries/zed",
    docs = "https://zed.dev/docs",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"editor"},
    keywords = {"zed", "editor", "ide", "lsp", "rust"},

    programs = {"zed"},
    xvm_enable = true,

    -- CN is optional: GitCode receives a new release only after the update is
    -- merged (ci.mirror), and no institutional mirror carries Zed's releases
    -- (mirrors.nju.edu.cn/github-release has no zed-industries/zed, measured
    -- 2026-11-22). A client falls back to GitHub until the mirror job runs.
    extensions = {
        autoupdate = {
            source = "https://github.com/zed-industries/zed/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/zed-industries/zed/releases/download/v${version}/zed-linux-x86_64.tar.gz",
                            aarch64 = "https://github.com/zed-industries/zed/releases/download/v${version}/zed-linux-aarch64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/zed-industries/zed/releases/download/v${version}/Zed-x86_64.dmg",
                            aarch64 = "https://github.com/zed-industries/zed/releases/download/v${version}/Zed-aarch64.dmg",
                        },
                    },
                    required = true,
                },
                CN = {
                    url = {
                        linux = {
                            x86_64 = "https://gitcode.com/xlings-res/zed/releases/download/${version}/zed-linux-x86_64.tar.gz",
                            aarch64 = "https://gitcode.com/xlings-res/zed/releases/download/${version}/zed-linux-aarch64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://gitcode.com/xlings-res/zed/releases/download/${version}/Zed-x86_64.dmg",
                            aarch64 = "https://gitcode.com/xlings-res/zed/releases/download/${version}/Zed-aarch64.dmg",
                        },
                    },
                    required = false,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = {
                GLOBAL = "https://github.com/zed-industries/zed/releases/download/v${version}/zed-linux-${arch}.tar.gz",
                CN     = "https://gitcode.com/xlings-res/zed/releases/download/${version}/zed-linux-${arch}.tar.gz",
            },
            ["latest"] = { ref = "1.30.2" },
            ["1.29.3"] = {
                sha256 = {
                    x86_64  = "44b0f350aa7bf4551d1b0aaa2d3b673a6de2c03bc5e979b3592fd2180b4f77c1",
                    aarch64 = "5f1de233ac02d8c9eff68e9ab4207274df3ddbd2cf9fa6f8a80ef5487f03e8ee",
                },
            },
            ["1.30.2"] = {
                x86_64 = {
                    url = "https://github.com/zed-industries/zed/releases/download/v1.30.2/zed-linux-x86_64.tar.gz",
                    sha256 = "210e6a08dc5343123254dfa9b9dd7a6e828e6ac2b10f98cd4ed1bd7d68cca2df",
                },
                aarch64 = {
                    url = "https://github.com/zed-industries/zed/releases/download/v1.30.2/zed-linux-aarch64.tar.gz",
                    sha256 = "497e1732287e974fce9268f828e1053ae384fdec193cbd81f8b0c294ae0efe6f",
                },
            },
        },
        macosx = {
            source = {
                GLOBAL = "https://github.com/zed-industries/zed/releases/download/v${version}/Zed-${arch}.dmg",
                CN     = "https://gitcode.com/xlings-res/zed/releases/download/${version}/Zed-${arch}.dmg",
            },
            ["latest"] = { ref = "1.30.2" },
            ["1.29.3"] = {
                sha256 = {
                    x86_64  = "b4779577003b79cb05ab6be18205babdebf81b45d96acdf21fce43dd4a6d6083",
                    aarch64 = "b692c9effdfcec874c47f56c3b27df069a63c6b3d23ecd070ffec9238a708bb8",
                },
            },
            ["1.30.2"] = {
                x86_64 = {
                    url = "https://github.com/zed-industries/zed/releases/download/v1.30.2/Zed-x86_64.dmg",
                    sha256 = "64cbedeea2feedb4eda9b2139c91ea87016061b57cb14966fbbf00d582e914e0",
                },
                aarch64 = {
                    url = "https://github.com/zed-industries/zed/releases/download/v1.30.2/Zed-aarch64.dmg",
                    sha256 = "36ab60379627730fc3ac6ab79bc57dba7a1cf6d6df8117b8e22190d9b639fff5",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

local function quote(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function macos_bundle()
    return pkginfo.install_dir() .. "/Zed.app"
end

-- One file per part, each one only that part provides: the launcher, the
-- editor, and on Linux a library Zed carries in lib/.
local function required_files()
    local dir = pkginfo.install_dir()
    if os.isfile(macos_bundle() .. "/Contents/MacOS/cli") then
        return { macos_bundle() .. "/Contents/MacOS/cli", macos_bundle() .. "/Contents/MacOS/zed" }
    end
    return { dir .. "/bin/zed", dir .. "/libexec/zed-editor", dir .. "/lib/libxkbcommon.so.0" }
end

function installed()
    for _, file in ipairs(required_files()) do
        if not os.isfile(file) then return false end
    end
    return true
end

function install()
    local archive, dir = pkginfo.install_file(), pkginfo.install_dir()
    os.tryrm(dir)
    if archive:match("%.dmg$") then
        os.mkdir(dir)
        local mount = dir .. "/.mount"
        os.mkdir(mount)
        system.exec("/usr/bin/hdiutil attach -readonly -nobrowse -mountpoint " ..
            quote(mount) .. " " .. quote(archive))
        local ok, err = pcall(function()
            system.exec("/usr/bin/ditto " .. quote(mount .. "/Zed.app") .. " " .. quote(macos_bundle()))
        end)
        system.exec("/usr/bin/hdiutil detach " .. quote(mount))
        os.tryrm(mount)
        if not ok then error(err) end
    else
        -- The archive unpacks beside itself as zed.app/.
        local parent = archive:match("^(.*)/[^/]+$") or "."
        os.mv(parent .. "/zed.app", dir)
    end
    local missing = {}
    for _, file in ipairs(required_files()) do
        if not os.isfile(file) then table.insert(missing, file) end
    end
    if #missing > 0 then
        error("zed is missing after install:\n    " .. table.concat(missing, "\n    "))
    end
    return true
end

function config()
    if os.isfile(macos_bundle() .. "/Contents/MacOS/cli") then
        xvm.add("zed", { bindir = macos_bundle() .. "/Contents/MacOS", alias = "cli" })
    else
        xvm.add("zed", { bindir = pkginfo.install_dir() .. "/bin" })
    end
    return true
end

function uninstall()
    xvm.remove("zed")
    return true
end
