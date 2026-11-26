-- playwright-webkit 27.2: WebKit build with the patches that let Playwright drive it.
--
-- Source: Playwright's patched WebKit (`builds/webkit/<revision>`), not Apple's Safari.
-- Playwright 1.65.1 pins this build as revision 2388 (`browsers.json`). The version
-- below is the browser's own version; the revision is what Playwright's registry
-- names the directory after. Playwright publishes no checksums: every sha256
-- below was computed from a first download of cdn.playwright.dev and equals a
-- second download from playwright.download.prss.microsoft.com.
--
-- NOT AUTO-UPDATED. There is no release feed for these builds; they move with
-- Playwright's `browsers.json`. Add a new version by hand, keep every old entry.
--
-- MIRROR. GitCode `xlings-res/playwright-webkit` carries the same bytes under the upstream
-- file names (published with gtc, each file with a .sha256 sidecar and downloaded
-- back and compared), so the one sha256 checks both URLs. `ci.mirror` is not declared:
-- the CN copy already exists and the GLOBAL file names are not unique per URL template.
--
-- LAYOUT. The archives are flat (no top-level directory), so install() extracts them
-- straight into the payload. Linux holds minibrowser-gtk/ (MiniBrowser is the wrapper
-- that sets its own library path) and minibrowser-wpe/; macOS holds Playwright.app;
-- Windows holds Playwright.exe. The macOS build is the one for macOS 15.
--
-- HOST LIBRARIES, NO LOADER DEPENDENCY. On Linux these ELF files use the host's loader and
-- the host's GTK/NSS/ALSA/... libraries, the same pattern as zed.lua and blender.lua. Declaring
-- xim:glibc would make elfpatch rewrite the loader and the browser would lose the host's
-- ld.so.cache. Playwright's own `install-dependencies` uses apt; this package never does.
--
-- THE ONE LIBRARY FROM THE XLINGS ECOSYSTEM. Started through its own wrapper (which puts
-- lib/ and sys/lib/ on LD_LIBRARY_PATH), MiniBrowser misses exactly one library: libavif.so.13,
-- Ubuntu 22.04's libavif13. sys/lib already carries libjxl, libbacktrace, libsoup, libbrotli
-- and libdrm. libavif.so.13 comes from xim:libavif (conda-forge's 0.9.3, with its xim:aom);
-- install() links it into each variant's sys/lib. Nothing is patched. GTK 4, GStreamer and the
-- rest of the closure still come from the host (Playwright's install-dependencies names ~120
-- apt packages); only what was found missing is supplied here.
-- `programs` is empty: chrome.exe prints nothing for --version on Windows and a GUI
-- browser would open a window in CI.

package = {
    spec = "2",

    name = "playwright-webkit",
    description = "WebKit build with the patches that let Playwright drive it",
    homepage = "https://playwright.dev",
    authors = {"Microsoft Corporation"},
    maintainers = {"https://github.com/microsoft/playwright/graphs/contributors"},
    licenses = {"LGPL-2.0-or-later", "BSD-2-Clause"},
    repo = "https://github.com/microsoft/playwright",
    docs = "https://playwright.dev/docs/browsers",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"browser", "testing", "tools"},
    keywords = {"playwright", "webkit", "safari", "browser", "testing", "automation"},

    programs = {},
    xvm_enable = true,

    xpm = {
        linux = {
            -- libavif.so.13, the one library the bundle's sys/lib does not carry (see the header).
            deps = { runtime = { "xim:libavif@0.9.3" } },
            ["latest"] = { ref = "27.2" },
            ["27.2"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://cdn.playwright.dev/builds/webkit/2388/webkit-ubuntu-22.04.zip",
                        CN = "https://gitcode.com/xlings-res/playwright-webkit/releases/download/27.2/webkit-ubuntu-22.04.zip",
                    },
                    sha256 = "1751fe258449b0ce4c8e5418d55d9a7f29fece742a847958f3daebf9717d86d1",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://cdn.playwright.dev/builds/webkit/2388/webkit-ubuntu-22.04-arm64.zip",
                        CN = "https://gitcode.com/xlings-res/playwright-webkit/releases/download/27.2/webkit-ubuntu-22.04-arm64.zip",
                    },
                    sha256 = "dbedfb625d4bee997033d500c83d9a6a1af1f985100d23f0841072d3364121d2",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "27.2" },
            ["27.2"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://cdn.playwright.dev/builds/webkit/2388/webkit-mac-15.zip",
                        CN = "https://gitcode.com/xlings-res/playwright-webkit/releases/download/27.2/webkit-mac-15.zip",
                    },
                    sha256 = "c1220c739a2dbb6450059bfd678d5f5057e807d1d004464ef890ee1e6a9db727",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://cdn.playwright.dev/builds/webkit/2388/webkit-mac-15-arm64.zip",
                        CN = "https://gitcode.com/xlings-res/playwright-webkit/releases/download/27.2/webkit-mac-15-arm64.zip",
                    },
                    sha256 = "50b4238e145b8018e48aacefc15e9b3a43fafd18eee42ed4cb29a2e5c5a2e385",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "27.2" },
            ["27.2"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://cdn.playwright.dev/builds/webkit/2388/webkit-win64.zip",
                        CN = "https://gitcode.com/xlings-res/playwright-webkit/releases/download/27.2/webkit-win64.zip",
                    },
                    sha256 = "0b390661995316d8f90fe0f7a0498f3a88c451c097fc8e4047342e1fbd36548b",
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

-- The executable of each platform, relative to the install directory, and the shim
-- (`bindir` relative, program name) registered for it.
local LAYOUTS = {
    { exe = "minibrowser-gtk/MiniBrowser", bindir = "minibrowser-gtk", program = "MiniBrowser", needs = "minibrowser-gtk/sys/lib/libavif.so.13" },
    { exe = "Playwright.app/Contents/MacOS/Playwright", bindir = "Playwright.app/Contents/MacOS", program = "Playwright" },
    { exe = "Playwright.exe", bindir = "", program = "Playwright.exe" },
}

local TOPS = nil

local function layout()
    local dir = pkginfo.install_dir()
    for _, l in ipairs(LAYOUTS) do
        if os.isfile(dir .. "/" .. l.exe) then return l end
    end
    return nil
end

function installed()
    local l = layout()
    if l and l.needs then
        return os.isfile(pkginfo.install_dir() .. "/" .. l.needs)
    end
    return l ~= nil
end

local function is_windows()
    if os.getenv("OS") == "Windows_NT" then return true end
    local dir = tostring(pkginfo.install_dir() or "")
    return dir:match("^[A-Za-z]:") ~= nil or dir:find("\\", 1, true) ~= nil
end

-- libavif.so.13 from xim:libavif, linked into the sys/lib of each variant: the wrapper
-- script puts that directory on LD_LIBRARY_PATH. libavif's own RUNPATH reaches libaom.
local function link_libavif(dir)
    local avif = pkginfo.dep_install_dir("xim:libavif")
    if not avif or not os.isfile(avif .. "/lib/libavif.so.13") then
        error("playwright-webkit: xim:libavif has no lib/libavif.so.13 (" .. tostring(avif) .. ")")
    end
    for _, variant in ipairs({ "minibrowser-gtk", "minibrowser-wpe" }) do
        local syslib = dir .. "/" .. variant .. "/sys/lib"
        if os.isdir(syslib) then
            shell.exec({ "ln", "-sf", avif .. "/lib/libavif.so.13", syslib .. "/libavif.so.13" })
        end
    end
    if not os.isfile(dir .. "/minibrowser-gtk/sys/lib/libavif.so.13") then
        error("playwright-webkit: libavif.so.13 is not linked into minibrowser-gtk/sys/lib")
    end
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("playwright-webkit: install_file is empty")
    end
    local dir = pkginfo.install_dir()

    -- Flat archive: extract it again into the payload alone, so another flat archive
    -- in the shared runtime directory is never carried along.
    if is_windows() then
        payload.unpack{}
    else
        os.tryrm(dir)
        fs.mkdir_p(dir)
        shell.exec({ "unzip", "-q", "-o", archive, "-d", dir })
    end

    local l = layout()
    if not l then
        error("playwright-webkit: payload has none of the expected executables in " .. dir)
    end
    if not is_windows() then
        shell.exec({ "chmod", "+x", dir .. "/" .. l.exe })
        if l.needs then link_libavif(dir) end
    end
    return true
end

function config()
    local dir = pkginfo.install_dir()
    local l = layout()
    if not l then
        error("playwright-webkit: no executable found in " .. dir)
    end
    local bindir = (l.bindir ~= "") and (dir .. "/" .. l.bindir) or dir
    xvm.add("playwright-webkit", { bindir = bindir, alias = l.program })
    return true
end

function uninstall()
    xvm.remove("playwright-webkit")
    return true
end
