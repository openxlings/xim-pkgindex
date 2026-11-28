-- playwright-chromium 159.0.8154.6: Chrome for Testing build of Chromium that Playwright drives.
--
-- Source: Google's Chrome for Testing, rebuilt per Playwright release (the `builds/cft/<version>` tree).
-- Playwright 1.65.1 pins this build as revision 1255 (`browsers.json`). The version
-- below is the browser's own version; the revision is what Playwright's registry
-- names the directory after. Playwright publishes no checksums: every sha256
-- below was computed from a first download of cdn.playwright.dev and equals a
-- second download of Google's own chrome-for-testing-public bucket.
--
-- NOT AUTO-UPDATED. There is no release feed for these builds; they move with
-- Playwright's `browsers.json`. Add a new version by hand, keep every old entry.
--
-- MIRROR. GitCode `xlings-res/playwright-chromium` carries the same bytes under the upstream
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

    name = "playwright-chromium",
    description = "Chrome for Testing build of Chromium that Playwright drives",
    homepage = "https://playwright.dev",
    authors = {"Microsoft Corporation"},
    maintainers = {"https://github.com/microsoft/playwright/graphs/contributors"},
    licenses = {"BSD-3-Clause"},
    repo = "https://github.com/microsoft/playwright",
    docs = "https://playwright.dev/docs/browsers",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"browser", "testing", "tools"},
    keywords = {"playwright", "chromium", "chrome", "browser", "testing", "automation"},

    programs = {},
    xvm_enable = true,

    xpm = {
        linux = {
            ["latest"] = { ref = "159.0.8154.6" },
            ["159.0.8154.6"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://cdn.playwright.dev/builds/cft/159.0.8154.6/linux64/chrome-linux64.zip",
                        CN = "https://gitcode.com/xlings-res/playwright-chromium/releases/download/159.0.8154.6/chrome-linux64.zip",
                    },
                    sha256 = "370601106c1b5619aae5f06f7a3fdc60836486135934779461e2a208d777f596",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://cdn.playwright.dev/builds/cft/159.0.8154.6/linux-arm64/chrome-linux-arm64.zip",
                        CN = "https://gitcode.com/xlings-res/playwright-chromium/releases/download/159.0.8154.6/chrome-linux-arm64.zip",
                    },
                    sha256 = "4a9ea5f9422e268fff9df19908365b6d1e92da154607d0f90c7138cf6c42ce38",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "159.0.8154.6" },
            ["159.0.8154.6"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://cdn.playwright.dev/builds/cft/159.0.8154.6/mac-x64/chrome-mac-x64.zip",
                        CN = "https://gitcode.com/xlings-res/playwright-chromium/releases/download/159.0.8154.6/chrome-mac-x64.zip",
                    },
                    sha256 = "6864109aa423785d5d5d52fd06bc1138e02b002fcd400955a2011358c5a8321f",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://cdn.playwright.dev/builds/cft/159.0.8154.6/mac-arm64/chrome-mac-arm64.zip",
                        CN = "https://gitcode.com/xlings-res/playwright-chromium/releases/download/159.0.8154.6/chrome-mac-arm64.zip",
                    },
                    sha256 = "43609676a41e29d1c7667935eb914a422eca98b2e49dcbfd6f3e9794202de12a",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "159.0.8154.6" },
            ["159.0.8154.6"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://cdn.playwright.dev/builds/cft/159.0.8154.6/win64/chrome-win64.zip",
                        CN = "https://gitcode.com/xlings-res/playwright-chromium/releases/download/159.0.8154.6/chrome-win64.zip",
                    },
                    sha256 = "3e2514fddb71f6727e2079369e03a6a4e105adcb28f05a6bfd875b782bddc431",
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
    { exe = "chrome", bindir = "", program = "chrome" },
    { exe = "Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing", bindir = "Google Chrome for Testing.app/Contents/MacOS", program = "Google Chrome for Testing" },
    { exe = "chrome.exe", bindir = "", program = "chrome.exe" },
}

local TOPS = {
    "chrome-linux64",
    "chrome-linux-arm64",
    "chrome-mac-x64",
    "chrome-mac-arm64",
    "chrome-win64",
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
        error("playwright-chromium: install_file is empty")
    end
    local dir = pkginfo.install_dir()

    payload.unpack{ extracted = TOPS, strip = 1 }

    local l = layout()
    if not l then
        error("playwright-chromium: payload has none of the expected executables in " .. dir)
    end
    if not is_windows() then
        shell.exec({ "chmod", "+x", dir .. "/" .. l.exe })
    end
    -- the .app is only intact when the zip's symlinks survived the extraction
    local fw = dir .. "/Google Chrome for Testing.app/Contents/Frameworks/Google Chrome for Testing Framework.framework"
    if os.isdir(dir .. "/Google Chrome for Testing.app") and not os.isdir(fw .. "/Versions/Current") then
        error("playwright-chromium: the app bundle lost its symlinks (" .. fw .. "/Versions/Current)")
    end
    return true
end

function config()
    local dir = pkginfo.install_dir()
    local l = layout()
    if not l then
        error("playwright-chromium: no executable found in " .. dir)
    end
    local bindir = (l.bindir ~= "") and (dir .. "/" .. l.bindir) or dir
    xvm.add("playwright-chromium", { bindir = bindir, alias = l.program })
    return true
end

function uninstall()
    xvm.remove("playwright-chromium")
    return true
end
