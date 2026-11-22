-- magpie — one local gateway and one model picker for every AI coding agent
-- (Claude Code, Codex, Gemini CLI, OpenCode, ...), from a menu bar / window app.
--
-- Upstream publishes TWO builds of the same program per platform:
--
--   magpie-<os>-<arch>[.exe|.zip]      the desktop app (this recipe)
--   magpie-cli-<os>-<arch>[.exe]       the terminal build (pkgs/m/magpie-cli.lua)
--
-- Both unpack to a command named `magpie` and answer `magpie --version`.
-- xvm refuses two packages that register the same name at the same version
-- ("another package already owns this exact name and version"), so the
-- terminal build is registered as `magpie-cli` and renames its payload. That
-- is what lets both packages be installed side by side; the desktop build
-- owns the plain `magpie` command.
--
-- PLATFORM MATRIX — what upstream publishes, and what xlings can address:
--
--   linux    x86_64, aarch64   raw ELF (GUI build)
--   macosx   x86_64, aarch64   zip containing the signed `magpie.app`
--   windows  x86_64, aarch64   raw .exe (GUI build)
--
-- The CLI release additionally publishes `magpie-cli-android-arm64` for
-- Termux. xlings looks up a host platform among linux/macosx/windows only
-- (XPackage V2 "Resolution order"), so Android is not a section that can ever
-- be selected; it is deliberately absent rather than dead data.
--
-- WHAT THE LINUX GUI BINARY NEEDS — measured with readelf -d, not assumed:
-- it is dynamically linked against the host's GTK 3, WebKitGTK 4.1
-- (libwebkit2gtk-4.1, libjavascriptcoregtk-4.1, libsoup-3.0), Wayland/X11 and
-- glibc. Upstream's own install.sh installs GTK 3 + WebKitGTK 4.1 through the
-- distribution's package manager for that reason. This index has no
-- WebKitGTK package, and declaring `xim:gtk3`/`xim:glibc` would only hand
-- elfpatch a loader provider and rewrite the interpreter of a binary whose
-- remaining libraries still have to come from the host. So the recipe
-- declares no runtime deps: the desktop app is a host application, like
-- `cc-switch`, and the host must provide those libraries. The terminal build
-- (`magpie-cli`) is the headless alternative and is a static Go binary.
--
-- GLOBAL is the authoritative upstream release. There is no verified CN
-- mirror, so the recipe declares none.
--
-- MANUAL MAINTENANCE — there is deliberately no extensions.autoupdate.
-- yetone/magpie has more than 1000 releases (many per day); GitHub's
-- list-releases API answers page 11 with 422 "Only the first 1000 results
-- are available", and the pinned xpkgindex-update treats that as an error,
-- so automatic discovery cannot enumerate this project. Bump by hand: take
-- the newest release tag, copy each asset's sha256 from that release's
-- SHA256SUMS, and move every platform's `latest` ref together.

package = {
    spec = "2",

    name = "magpie",
    description = "Menu bar / desktop app that points every AI coding agent at the model you pick, through one local gateway",
    homepage = "https://usemagpie.ai",
    repo = "https://github.com/yetone/magpie",
    docs = "https://usemagpie.ai/docs/start",
    authors = {"yetone"},
    maintainers = {"yetone"},
    licenses = {"MIT"},

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"ai", "app", "tools"},
    keywords = {"magpie", "ai-agent", "claude-code", "codex", "gateway", "model-router", "tauri"},
    programs = {"magpie"},
    xvm_enable = true,

    xpm = {
        linux = {
            ["latest"] = { ref = "0.1.4657" },
            ["0.1.4657"] = {
                x86_64 = {
                    url = "https://github.com/yetone/magpie/releases/download/v0.1.4657/magpie-linux-amd64",
                    sha256 = "dd7c38f9fa24f862e091dc0e3d3e9c6615b6a2eaec2012f717f46a6b28a4279d",
                },
                aarch64 = {
                    url = "https://github.com/yetone/magpie/releases/download/v0.1.4657/magpie-linux-arm64",
                    sha256 = "e761eea9b332c8d8687412a25b815d7a6f53b1c4322ae6e2e4be688b3032e4f3",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "0.1.4657" },
            ["0.1.4657"] = {
                x86_64 = {
                    url = "https://github.com/yetone/magpie/releases/download/v0.1.4657/magpie-darwin-amd64.zip",
                    sha256 = "8ad6f3ac9060550f6cbd7f00bcd9a4366bddf4325934e3576f1001f65835438f",
                },
                aarch64 = {
                    url = "https://github.com/yetone/magpie/releases/download/v0.1.4657/magpie-darwin-arm64.zip",
                    sha256 = "8dc23b344e0e8ce1583c31373ace4a86502bc780ab2c961aae73c4e1e8e85c2d",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "0.1.4657" },
            ["0.1.4657"] = {
                x86_64 = {
                    url = "https://github.com/yetone/magpie/releases/download/v0.1.4657/magpie-windows-amd64.exe",
                    sha256 = "07e1f5779508ae0296365b64f6174131e7b01db37fcec9cb71104bbfd19c1f00",
                },
                aarch64 = {
                    url = "https://github.com/yetone/magpie/releases/download/v0.1.4657/magpie-windows-arm64.exe",
                    sha256 = "4949207245c8aa5c93b5e0c716fd178ac0be67fc275e5deb032e77611d8be4e1",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

local function install_dir()
    return pkginfo.install_dir()
end

local function app_dir()
    return path.join(install_dir(), "magpie.app")
end

local function app_binary()
    return path.join(app_dir(), "Contents", "MacOS", "magpie")
end

local function exe_path()
    if os.isfile(app_binary()) then
        return app_binary()
    end
    local exe = path.join(install_dir(), "magpie.exe")
    if os.isfile(exe) then
        return exe
    end
    return path.join(install_dir(), "magpie")
end

-- Layout:
--   Linux   the download IS the ELF executable (raw, no archive wrapper)
--   Windows the download IS the GUI .exe (raw, no archive wrapper)
--   macOS   the download is a zip whose top-level entry is `magpie.app`
--
-- xlings extracts an archive beside the download (the install hook's
-- contract), so the bundle is found in the download directory. The bundle
-- keeps Contents/Resources and its code signature together; only the inner
-- binary is registered.
function install()
    local dir = install_dir()
    local file = pkginfo.install_file()
    os.tryrm(dir)
    os.mkdir(dir)

    if file:lower():match("%.zip$") then
        -- Archives are extracted into the download directory. Accept the
        -- archive-stem layout too, so a client that stages an archive under
        -- its own directory still finds the bundle.
        local app = path.join(path.directory(file), "magpie.app")
        if not os.isdir(app) then
            app = path.join((file:gsub("%.zip$", "")), "magpie.app")
        end
        os.mv(app, app_dir())
        -- Zip entries carry their Unix mode, but a download that lost it
        -- would still have the bundle in place and fail only at launch.
        system.exec(string.format([[chmod +x "%s"]], app_binary()))
        return os.isfile(app_binary())
    end

    local windows = file:lower():match("%.exe$") ~= nil
    local exe = path.join(dir, windows and "magpie.exe" or "magpie")
    os.mv(file, exe)
    if not windows then
        system.exec(string.format([[chmod +x "%s"]], exe))
    end
    return os.isfile(exe)
end

function installed()
    return os.isfile(exe_path())
end

function config()
    local bindir = install_dir()
    if os.isdir(app_dir()) then
        bindir = path.join(app_dir(), "Contents", "MacOS")
    end
    xvm.add("magpie", { bindir = bindir })
    return true
end

function uninstall()
    xvm.remove("magpie")
    return true
end