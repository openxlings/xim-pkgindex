local base = "https://persistent.oaistatic.com/codex-app-prod/"

local function deb(version, arch, sha256)
    return {
        url = base .. "linux/deb/pool/main/c/chatgpt/chatgpt_" .. version .. "_" .. arch .. ".deb",
        sha256 = sha256,
    }
end

local function mac(version, sha256)
    return { aarch64 = {
        url = base .. "ChatGPT-darwin-arm64-" .. version .. ".zip",
        sha256 = sha256,
    } }
end

package = {
    spec = "2",
    name = "chatgpt",
    description = "Official ChatGPT desktop app with xlings-managed versions",
    homepage = "https://learn.chatgpt.com/docs/app",
    docs = "https://learn.chatgpt.com/docs/linux/linux-app",
    licenses = {"LicenseRef-OpenAI-Proprietary"},
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"app", "ai", "tools"},
    keywords = {"chatgpt", "openai", "desktop"},
    programs = {"chatgpt"},
    xvm_enable = true,
    xpm = {
        linux = {
            -- Linux arm64 debs exist upstream, but glibc and gcc-runtime have
            -- no arm64 payload yet, so only x86_64 is offered here.
            --
            -- Put first on every ELF's RUNPATH by elfpatch: the bundled
            -- libvips the native image module links against.
            exports = { runtime = { libdirs = {
                "app",
                "app/resources/cua_node/lib/node_modules/@img/sharp-libvips-linux-x64/lib",
            } } },
            -- Grouped by how the app reaches them. Everything under `runtime`
            -- is the app's own closure; 7zip only unpacks the deb in
            -- install(), so it is a build dep and is never put on the user's
            -- PATH. install() reaches it by pkginfo.build_dep("7zip") -- the
            -- bare name, because xlings exports the payload namespace-free
            -- (XLINGS_BUILDDEP_7ZIP_PATH) and libxpkg <= 0.0.59 spells the key
            -- from the string it is given, so "xim:7zip" misses on every
            -- released client.
            deps = {
                runtime = {
                    -- DT_NEEDED of ChatGPT and its native modules (readelf -d)
                    "xim:glibc", "xim:gcc-runtime", "xim:glib", "xim:dbus", "xim:expat",
                    "xim:nss", "xim:nspr", "xim:atk", "xim:at-spi2-atk", "xim:at-spi2-core",
                    "xim:libcups", "xim:cairo", "xim:pango", "xim:gdk-pixbuf", "xim:gtk3",
                    "xim:libxcb", "xim:libxkbcommon", "xim:libX11", "xim:libXext",
                    "xim:libXcomposite", "xim:libXdamage", "xim:libXfixes", "xim:libXrandr",
                    "xim:alsa-lib", "xim:mesa", "xim:libudev", "xim:libusb", "xim:openssl",
                    "xim:tpm2-tss",
                    -- dlopen'd by Chromium/Electron: the keyring-backed credential
                    -- store (without it: a plain-text store) and notifications
                    "xim:libsecret", "xim:libnotify",
                    -- GL/EGL/Vulkan discovery for the GPU process
                    "xim:graphics",
                },
                build = { "xim:7zip@26.02" },
            },
            ["latest"] = { ref = "26.924.22138" },
            -- Revision 1: install() no longer keeps libqt5_shim.so and
            -- libqt6_shim.so (see there), and xim:qt5 / xim:qt-base left the
            -- deps. xlings replaces a payload of revision 0 on its next
            -- install, after which those two packages can be collected.
            ["26.924.22138"] = {
                x86_64 = deb("26.924.22138", "amd64", "ce3bb1aa82ccdfe3037ada2fd8d187796ea4a0d5ed031d0e4ec8adce8b7014e7"),
                revision = 1,
            },
            ["26.917.71314"] = {
                x86_64 = deb("26.917.71314", "amd64", "851ec28b65bde2ff1da9f37dcdf5b6e20a915c7568f8b2ce993c00428f018ae5"),
                revision = 1,
            },
        },
        macosx = {
            ["latest"] = { ref = "26.924.22138" },
            ["26.924.22138"] = mac("26.924.22138", "7cf9569b116a32af61a6ab4e9979466774b6dc8e9dbcf70264596a1ae2dfd57d"),
            ["26.917.71314"] = mac("26.917.71314", "e3f436f729295bdb72b9acc9115bbf767a1fda7d081f2f83de84f70b93fdca9c"),
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.libxpkg.json")
import("xim.libxpkg.elfpatch")
import("xim.pkgindex.graphics")

local function quote(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function apparmor_profile(dir)
    return dir .. "/share/apparmor/xlings-chatgpt"
end

-- `chatgpt` on Linux. Where the host restricts unprivileged user namespaces
-- and this version's profile is not loaded, Chromium's sandbox cannot start
-- and ChatGPT dies with "No usable sandbox!". Running it is the first moment
-- a user sees anything (hook output is not shown), so the launcher says what
-- to do there instead: load the profile (root), or run with --no-sandbox.
-- It only prints the choice; an explicit --no-sandbox is the user's call.
local LAUNCHER = [==[#!/bin/sh
app=%s
profile=%s
source=%s
case " $* " in *" --no-sandbox "*) exec "$app/ChatGPT" "$@" ;; esac
if [ "$(cat /proc/sys/kernel/apparmor_restrict_unprivileged_userns 2>/dev/null)" = 1 ] &&
   ! grep -qsx "$profile" /sys/kernel/security/apparmor/policy/profiles/*/name; then
    cat >&2 <<EOF
chatgpt: Chromium's sandbox cannot start on this host.

The kernel lets a program create the user namespaces the sandbox needs only
under an AppArmor profile (kernel.apparmor_restrict_unprivileged_userns=1),
and none is loaded for this install. Either:

1. Load the profile once. Needs root; the sandbox stays on. It grants user
   namespaces to this ChatGPT executable and nothing else:

$(sed 's/^/       | /' "$source")

   Run:

       sudo install -m 0644 '$source' /etc/apparmor.d/$profile
       sudo apparmor_parser -r /etc/apparmor.d/$profile
       chatgpt

   An upgrade installs a new path: repeat this for the new version.

2. Run without Chromium's sandbox. No root, but web content is not isolated
   from the rest of the app:

       chatgpt --no-sandbox

EOF
    exit 1
fi
exec "$app/ChatGPT" "$@"
]==]

-- True for an x86_64 ELF that the dynamic loader has to resolve: it asks for
-- an interpreter (PT_INTERP) or names a library (DT_NEEDED). The app also
-- ships statically linked helpers -- the codex app-server,
-- codex-code-mode-host, node_repl, rg, tectonic -- which do neither, and
-- prebuilt native modules for other architectures, which this loader cannot
-- serve either way.
local function dynamic_elf(file)
    local f = io.open(file, "rb")
    if not f then return false end
    local h = f:read(64)
    if not h or #h < 64 or h:sub(1, 4) ~= "\127ELF" or h:byte(5) ~= 2
       or string.unpack("<I2", h, 0x13) ~= 62 then                  -- EM_X86_64
        f:close()
        return false
    end
    local phoff = string.unpack("<I8", h, 0x21)
    local phentsize, phnum = string.unpack("<I2I2", h, 0x37)
    f:seek("set", phoff)
    local ph = f:read(phentsize * phnum) or ""
    local dynamic = false
    for i = 0, phnum - 1 do
        local at = i * phentsize + 1
        if #ph < at + 39 then break end
        local ptype = string.unpack("<I4", ph, at)
        if ptype == 3 then f:close() return true end            -- PT_INTERP
        if ptype == 2 then                                       -- PT_DYNAMIC
            f:seek("set", string.unpack("<I8", ph, at + 8))
            local d = f:read(string.unpack("<I8", ph, at + 32)) or ""
            for j = 1, #d - 15, 16 do
                local tag = string.unpack("<i8", d, j)
                if tag == 0 then break end                       -- DT_NULL
                if tag == 1 then dynamic = true break end        -- DT_NEEDED
            end
        end
    end
    f:close()
    return dynamic
end

-- Stamp this payload's loader and dependency closure onto the dynamically
-- linked x86_64 ELF files only. Auto-elfpatch treats every ELF alike and
-- gives one without PT_INTERP an RPATH; on a static-pie that is corruption --
-- the helpers above dump core, the app-server with them, and the app stops at
-- "Organization settings could not be loaded". So this package takes its
-- patching over through the elfpatch interface, until auto-elfpatch skips
-- such files itself (openxlings/libxpkg#43).
local function patch_dynamic_elves(root)
    elfpatch.skip()
    -- glibc.lua exports this loader as exports.runtime.loader
    local loader = assert(pkginfo.resolved_dep("xim:glibc"), "xim:glibc is not resolved").install_dir
        .. "/lib64/ld-linux-x86-64.so.2"
    assert(os.isfile(loader), "no loader at " .. loader)
    local rpath = elfpatch.closure_lib_paths()
    local p = assert(io.popen("find " .. quote(root) .. " -type f"))
    for file in p:lines() do
        if dynamic_elf(file) then
            elfpatch.patch_elf_loader_rpath(file, { loader = loader, rpath = rpath })
        end
    end
    p:close()
end

function install()
    local dir = pkginfo.install_dir()
    local archive = pkginfo.install_file()
    local parent = assert(archive:match("^(.*)/[^/]+$"))
    local version = pkginfo.version()
    os.mkdir(dir)

    if archive:match("%.deb$") then
        local unpack = dir .. "/.unpack"
        local z = quote(assert(pkginfo.build_dep("7zip"), "xim:7zip (build dep) is not available").path .. "/7zz")
        os.tryrm(unpack)
        os.mkdir(unpack)
        -- ar -> xz -> tar as one stream: the 1.5 GiB data.tar never lands on
        -- disk, and only the application directory is written out.
        system.exec(z .. " e -so -tAr " .. quote(archive) .. " data.tar.xz | "
            .. z .. " x -si -txz -so | "
            .. z .. " x -si -ttar -y -o" .. quote(unpack) .. " './usr/lib/chatgpt/*' >/dev/null")
        local app = unpack .. "/usr/lib/chatgpt"
        local metadata = json.loadfile(app .. "/resources/linux-package-metadata.json")
        assert(metadata.version == version, "ChatGPT archive version mismatch")
        assert(os.isfile(app .. "/ChatGPT"), "ChatGPT executable is missing")
        assert(os.isfile(app .. "/resources/app.asar"), "ChatGPT app.asar is missing")
        os.tryrm(dir .. "/app")
        os.mv(app, dir .. "/app")
        os.tryrm(unpack)
        -- Chromium's Qt UI integration. ChatGPT dlopens libqt%d_shim.so only
        -- on KDE (version from KDE_SESSION_VERSION) or with --ui-toolkit=qt;
        -- everywhere else it uses GTK, and gtk3 is already a DT_NEEDED of
        -- ChatGPT. Without the shims a KDE session or that flag falls back to
        -- GTK. Keeping them meant declaring xim:qt5 and xim:qt-base: ten
        -- packages and ~620 MB in every install's closure, for a theme.
        os.tryrm(dir .. "/app/libqt5_shim.so")
        os.tryrm(dir .. "/app/libqt6_shim.so")
        patch_dynamic_elves(dir .. "/app")
        -- The deb's postinst loads an AppArmor profile that grants user
        -- namespaces to /usr/lib/chatgpt/ChatGPT, which Chromium's sandbox
        -- needs on hosts that restrict them (Ubuntu 23.10+). The same profile
        -- for this path; loading it needs root, so it is the user's step
        -- (.agents/docs/chatgpt.md).
        os.mkdir(dir .. "/share/apparmor")
        local f = assert(io.open(apparmor_profile(dir), "w"))
        f:write("abi <abi/4.0>,\ninclude <tunables/global>\n\n",
                "profile xlings-chatgpt-", version, " \"", dir, "/app/ChatGPT\" flags=(unconfined) {\n",
                "  userns,\n}\n")
        f:close()
        os.mkdir(dir .. "/bin")
        local launcher = dir .. "/bin/chatgpt"
        f = assert(io.open(launcher, "w"))
        f:write(string.format(LAUNCHER, quote(dir .. "/app"), "xlings-chatgpt-" .. version,
                              quote(apparmor_profile(dir))))
        f:close()
        system.exec("chmod 0755 " .. quote(launcher))
    elseif archive:match("%.zip$") then
        local app = parent .. "/ChatGPT.app"
        system.exec("test \"$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' " ..
            quote(app .. "/Contents/Info.plist") .. ")\" = " .. quote(version))
        system.exec("/usr/bin/codesign --verify --deep --strict " .. quote(app))
        os.tryrm(dir .. "/ChatGPT.app")
        os.mv(app, dir .. "/ChatGPT.app")
    else
        error("Unsupported ChatGPT archive")
    end

    return os.isfile(dir .. "/bin/chatgpt") or os.isfile(dir .. "/ChatGPT.app/Contents/MacOS/ChatGPT")
end

function config()
    local dir = pkginfo.install_dir()
    local bindir, alias = dir .. "/bin", "chatgpt"
    local envs = { CODEX_SPARKLE_ENABLED = "false" }
    if os.isfile(dir .. "/ChatGPT.app/Contents/MacOS/ChatGPT") then
        bindir, alias = dir .. "/ChatGPT.app/Contents/MacOS", "ChatGPT"
    else
        -- XDG_DATA_DIRS among these reaches <subos>/share, where gtk3
        -- places its compiled GSettings schemas
        envs = graphics.consumer_envs()
        envs.CODEX_SPARKLE_ENABLED = "false"
    end
    -- The updater switch reaches this app and its children only
    xvm.add("chatgpt", {
        bindir = bindir,
        alias = alias,
        envs = envs,
    })
    return true
end

function uninstall()
    xvm.remove("chatgpt")
    return true
end
