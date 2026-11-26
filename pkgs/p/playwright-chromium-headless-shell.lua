-- playwright-chromium-headless-shell 159.0.8154.6: Chrome headless shell that Playwright uses for headless Chromium runs.
--
-- Source: Google's Chrome for Testing headless shell, rebuilt per Playwright release.
-- Playwright 1.65.1 pins this build as revision 1255 (`browsers.json`). The version
-- below is the browser's own version; the revision is what Playwright's registry
-- names the directory after. Playwright publishes no checksums: every sha256
-- below was computed from a first download of cdn.playwright.dev and equals a
-- second download of Google's own chrome-for-testing-public bucket.
--
-- NOT AUTO-UPDATED. There is no release feed for these builds; they move with
-- Playwright's `browsers.json`. Add a new version by hand, keep every old entry.
--
-- MIRROR. GitCode `xlings-res/playwright-chromium-headless-shell` carries the same bytes under the upstream
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

    name = "playwright-chromium-headless-shell",
    description = "Chrome headless shell that Playwright uses for headless Chromium runs",
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
    keywords = {"playwright", "chromium", "chrome", "headless", "browser", "testing"},

    programs = {},
    xvm_enable = true,

    xpm = {
        linux = {
            ["latest"] = { ref = "159.0.8154.6" },
            ["159.0.8154.6"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://cdn.playwright.dev/builds/cft/159.0.8154.6/linux64/chrome-headless-shell-linux64.zip",
                        CN = "https://gitcode.com/xlings-res/playwright-chromium-headless-shell/releases/download/159.0.8154.6/chrome-headless-shell-linux64.zip",
                    },
                    sha256 = "77a6442fd3c8acd3bef9e1067fc26f5ef464277d22f0e8cb58dc3e4077a3e458",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://cdn.playwright.dev/builds/cft/159.0.8154.6/linux-arm64/chrome-headless-shell-linux-arm64.zip",
                        CN = "https://gitcode.com/xlings-res/playwright-chromium-headless-shell/releases/download/159.0.8154.6/chrome-headless-shell-linux-arm64.zip",
                    },
                    sha256 = "e1262e9f4f244c441dcb54aa0e9abe4cf7b266ab02dc666fd975bd55aba9b3dc",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "159.0.8154.6" },
            ["159.0.8154.6"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://cdn.playwright.dev/builds/cft/159.0.8154.6/mac-x64/chrome-headless-shell-mac-x64.zip",
                        CN = "https://gitcode.com/xlings-res/playwright-chromium-headless-shell/releases/download/159.0.8154.6/chrome-headless-shell-mac-x64.zip",
                    },
                    sha256 = "89c56fb080ab4e9ba76656d5669af2b2dfc313c11434871e8f4e351c08a5ffca",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://cdn.playwright.dev/builds/cft/159.0.8154.6/mac-arm64/chrome-headless-shell-mac-arm64.zip",
                        CN = "https://gitcode.com/xlings-res/playwright-chromium-headless-shell/releases/download/159.0.8154.6/chrome-headless-shell-mac-arm64.zip",
                    },
                    sha256 = "b08e7beaf02a19e2ee5ed6955f9c3853ab9176cd5bb57ba87afbb82e9f81cc29",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "159.0.8154.6" },
            ["159.0.8154.6"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://cdn.playwright.dev/builds/cft/159.0.8154.6/win64/chrome-headless-shell-win64.zip",
                        CN = "https://gitcode.com/xlings-res/playwright-chromium-headless-shell/releases/download/159.0.8154.6/chrome-headless-shell-win64.zip",
                    },
                    sha256 = "5db6a6948e6d1299ea3bc87c420d467bf343feae186a316921c930ce02056af5",
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
    { exe = "chrome-headless-shell", bindir = "", program = "chrome-headless-shell" },
    { exe = "chrome-headless-shell", bindir = "", program = "chrome-headless-shell" },
    { exe = "chrome-headless-shell.exe", bindir = "", program = "chrome-headless-shell.exe" },
}

local TOPS = {
    "chrome-headless-shell-linux64",
    "chrome-headless-shell-linux-arm64",
    "chrome-headless-shell-mac-x64",
    "chrome-headless-shell-mac-arm64",
    "chrome-headless-shell-win64",
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
        error("playwright-chromium-headless-shell: install_file is empty")
    end
    local dir = pkginfo.install_dir()

    payload.unpack{ extracted = TOPS, strip = 1 }

    local l = layout()
    if not l then
        error("playwright-chromium-headless-shell: payload has none of the expected executables in " .. dir)
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
        error("playwright-chromium-headless-shell: no executable found in " .. dir)
    end
    local bindir = (l.bindir ~= "") and (dir .. "/" .. l.bindir) or dir
    xvm.add("playwright-chromium-headless-shell", { bindir = bindir, alias = l.program })
    return true
end

function uninstall()
    xvm.remove("playwright-chromium-headless-shell")
    return true
end
