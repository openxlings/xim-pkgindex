-- playwright-firefox 159.0: Firefox build with the patches that let Playwright drive it.
--
-- Source: Playwright's patched Firefox (`builds/firefox/<revision>`), not Mozilla's own release.
-- Playwright 1.65.1 pins this build as revision 1572 (`browsers.json`). The version
-- below is the browser's own version; the revision is what Playwright's registry
-- names the directory after. Playwright publishes no checksums: every sha256
-- below was computed from a first download of cdn.playwright.dev and equals a
-- second download from playwright.download.prss.microsoft.com.
--
-- NOT AUTO-UPDATED. There is no release feed for these builds; they move with
-- Playwright's `browsers.json`. Add a new version by hand, keep every old entry.
--
-- MIRROR. GitCode `xlings-res/playwright-firefox` carries the same bytes under the upstream
-- file names (published with gtc, each file with a .sha256 sidecar and downloaded
-- back and compared), so the one sha256 checks both URLs. `ci.mirror` is not declared:
-- the CN copy already exists and the GLOBAL file names are not unique per URL template.
--
-- LAYOUT. Each archive has one top-level directory; install() strips it.
--
-- HOST LIBRARIES, NO LOADER DEPENDENCY. On Linux these ELF files use the host's loader and
-- the host's GTK/NSS/ALSA/... libraries, the same pattern as zed.lua and blender.lua. Declaring
-- xim:glibc would make elfpatch rewrite the loader and the browser would lose the host's
-- ld.so.cache. Playwright's own `install-dependencies` uses apt; this package never does.
-- `programs` is empty: chrome.exe prints nothing for --version on Windows and a GUI
-- browser would open a window in CI.

package = {
    spec = "2",

    name = "playwright-firefox",
    description = "Firefox build with the patches that let Playwright drive it",
    homepage = "https://playwright.dev",
    authors = {"Microsoft Corporation"},
    maintainers = {"https://github.com/microsoft/playwright/graphs/contributors"},
    licenses = {"MPL-2.0"},
    repo = "https://github.com/microsoft/playwright",
    docs = "https://playwright.dev/docs/browsers",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"browser", "testing", "tools"},
    keywords = {"playwright", "firefox", "browser", "testing", "automation"},

    programs = {},
    xvm_enable = true,

    xpm = {
        linux = {
            ["latest"] = { ref = "159.0" },
            ["159.0"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://cdn.playwright.dev/builds/firefox/1572/firefox-ubuntu-22.04.zip",
                        CN = "https://gitcode.com/xlings-res/playwright-firefox/releases/download/159.0/firefox-ubuntu-22.04.zip",
                    },
                    sha256 = "9cd951e188273ea7f0478a31116499ec600372e822b19464ba2d8a2d976a3318",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://cdn.playwright.dev/builds/firefox/1572/firefox-ubuntu-22.04-arm64.zip",
                        CN = "https://gitcode.com/xlings-res/playwright-firefox/releases/download/159.0/firefox-ubuntu-22.04-arm64.zip",
                    },
                    sha256 = "3c1ea2de01172441c915f7aff5c37b80b6278e38412fa13c0c50bd6748e42a15",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "159.0" },
            ["159.0"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://cdn.playwright.dev/builds/firefox/1572/firefox-mac.zip",
                        CN = "https://gitcode.com/xlings-res/playwright-firefox/releases/download/159.0/firefox-mac.zip",
                    },
                    sha256 = "f31ac41e6450c5c9040fc7290f3da8a6a5f5672b0075f18b37cbd28fbf95ad36",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://cdn.playwright.dev/builds/firefox/1572/firefox-mac-arm64.zip",
                        CN = "https://gitcode.com/xlings-res/playwright-firefox/releases/download/159.0/firefox-mac-arm64.zip",
                    },
                    sha256 = "9691b4a07405d8faf8a44f6378d66db480d36159d9e9c4ed1d6066687697e1f2",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "159.0" },
            ["159.0"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://cdn.playwright.dev/builds/firefox/1572/firefox-win64.zip",
                        CN = "https://gitcode.com/xlings-res/playwright-firefox/releases/download/159.0/firefox-win64.zip",
                    },
                    sha256 = "17abdb829293f482dae4c85be9e0dff5995a66457d8b3ca7a7efc6f5ef9c08c5",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")
import("xim.pkgindex.shell")

-- The executable of each platform, relative to the install directory, and the shim
-- (`bindir` relative, program name) registered for it.
local LAYOUTS = {
    { exe = "firefox", bindir = "", program = "firefox" },
    { exe = "Nightly.app/Contents/MacOS/firefox", bindir = "Nightly.app/Contents/MacOS", program = "firefox" },
    { exe = "firefox.exe", bindir = "", program = "firefox.exe" },
}

local TOPS = {
    "firefox",
}

local function layout()
    local dir = pkginfo.install_dir()
    for _, l in ipairs(LAYOUTS) do
        if os.isfile(dir .. "/" .. l.exe) then return l end
    end
    return nil
end

function installed()
    return layout() ~= nil
end

local function is_windows()
    if os.getenv("OS") == "Windows_NT" then return true end
    local dir = tostring(pkginfo.install_dir() or "")
    return dir:match("^[A-Za-z]:") ~= nil or dir:find("\\", 1, true) ~= nil
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("playwright-firefox: install_file is empty")
    end
    local dir = pkginfo.install_dir()

    payload.unpack{ extracted = TOPS, strip = 1 }

    local l = layout()
    if not l then
        error("playwright-firefox: payload has none of the expected executables in " .. dir)
    end
    if not is_windows() then
        shell.exec({ "chmod", "+x", dir .. "/" .. l.exe })
    end
    return true
end

function config()
    local dir = pkginfo.install_dir()
    local l = layout()
    if not l then
        error("playwright-firefox: no executable found in " .. dir)
    end
    local bindir = (l.bindir ~= "") and (dir .. "/" .. l.bindir) or dir
    xvm.add("playwright-firefox", { bindir = bindir, alias = l.program })
    return true
end

function uninstall()
    xvm.remove("playwright-firefox")
    return true
end
