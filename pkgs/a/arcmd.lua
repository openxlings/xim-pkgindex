-- ArcMD -- native Markdown and rich-text editor built with Go and MyGo Native UI.
--
-- Verified 2026-11-26 against official upstream release `Ciao1019/ArcMD` v0.4.0.
-- Every SHA256 below matches upstream `SHA256SUMS.txt`, GitHub Release asset
-- digests, and locally downloaded archives:
--   * linux/x86_64    : arcmd-0.4.0-linux-amd64.tar.gz (flat archive: `arcmd`,
--                       `LICENSE`, `icon.png`, `icon.icns`, `arcmd.desktop`,
--                       `arcmd.png`, `arcmd.xml`, `.mygo-files`, `third_party/`)
--   * linux/aarch64   : arcmd-0.4.0-linux-arm64.tar.gz (same flat layout)
--   * macosx/x86_64   : arcmd-0.4.0-darwin-amd64.tar.gz (`ArcMD.app/` bundle,
--                       Mach-O 64-bit x86_64 at `Contents/MacOS/ArcMD`)
--   * macosx/aarch64  : arcmd-0.4.0-darwin-arm64.tar.gz (`ArcMD.app/` bundle,
--                       Mach-O 64-bit arm64 at `Contents/MacOS/ArcMD`)
--   * windows/x86_64  : arcmd-0.4.0-windows-amd64.zip (flat archive: `ArcMD.exe`
--                       PE32+ GUI executable importing only `kernel32.dll` — no
--                       `VCRUNTIME140.dll` — plus `LICENSE`, icons, `third_party/`)
--   * windows/aarch64 : omitted — upstream v0.4.0 publishes no Windows ARM64 asset.
--
-- Linux linking: `arcmd` is a dynamically linked Go + MyGo binary (`DT_NEEDED`:
-- `libdl.so.2`, `libpthread.so.0`, `libc.so.6`) that dynamically `dlopen()`s host
-- desktop libraries (GTK3, GDK3, Wayland, Cairo, Pango, HarfBuzz, Fontconfig,
-- Epoxy, WebKit2GTK, Poppler, libsecret, AppIndicator) when opening the GUI.
-- Keep it on the host loader with no `deps` (as `blender.lua` and `zed.lua` do):
-- declaring `xim:glibc` removes the host `/etc/ld.so.cache` fallback and breaks
-- GUI launch.
--
-- `programs` is omitted deliberately (`{}`): `arcmd` defaults to launching the
-- desktop GUI for unrecognized positional arguments (including Windows CI's `/?`
-- and `--version` probes), which would block headless CI. `config()` still
-- registers `arcmd` via `xvm.add` (supporting `--help`, `status`, `space`,
-- `doc`, `board`, `db`, `format-guide`, `skill`, `mcp`, `ask`) and creates a
-- Windows Start Menu shortcut.

package = {
    spec = "2",

    name = "arcmd",
    description = "Native Markdown and rich-text editor built with Go and MyGo Native UI",
    homepage = "https://arcmd.wl.do",
    authors = {"Ciao1019"},
    maintainers = {"https://github.com/Ciao1019/ArcMD/graphs/contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/Ciao1019/ArcMD",
    docs = "https://github.com/Ciao1019/ArcMD#readme",
    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "dev", -- upstream v0.4.0 is an early preview
    categories = {"editor", "markdown", "app", "tools"},
    keywords = {"arcmd", "markdown", "editor", "notes", "rich-text", "mygo", "go"},

    programs = {},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/Ciao1019/ArcMD/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/Ciao1019/ArcMD/releases/download/${tag}/arcmd-${version}-linux-amd64.tar.gz",
                            aarch64 = "https://github.com/Ciao1019/ArcMD/releases/download/${tag}/arcmd-${version}-linux-arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/Ciao1019/ArcMD/releases/download/${tag}/arcmd-${version}-darwin-amd64.tar.gz",
                            aarch64 = "https://github.com/Ciao1019/ArcMD/releases/download/${tag}/arcmd-${version}-darwin-arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/Ciao1019/ArcMD/releases/download/${tag}/arcmd-${version}-windows-amd64.zip",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/Ciao1019/ArcMD/releases/download/v${version}/arcmd-${version}-linux-${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.5.2" },
            ["0.5.0"] = {
                x86_64 = {
                    url = "https://github.com/Ciao1019/ArcMD/releases/download/v0.5.0/arcmd-0.5.0-linux-amd64.tar.gz",
                    sha256 = "7ec772be0973115840b8641283d92503b94651cba914d0638605209e30f5d573",
                },
                aarch64 = {
                    url = "https://github.com/Ciao1019/ArcMD/releases/download/v0.5.0/arcmd-0.5.0-linux-arm64.tar.gz",
                    sha256 = "0cbad646662137ea5846715dbe7ed75d4d2048618656827eb3173f763dae883f",
                },
            },
            ["0.4.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "66d427b182f0d7fa367b046272c4dbda231e563c2c7924a3a710b8b34ddba137",
                    aarch64 = "6a2b8909f6cb62c4e70e3c64ee41fbd14e9e04bb49899cfeb5fa8f6560eb2cc6",
                },
            },
            ["0.5.2"] = {
                x86_64 = {
                    url = "https://github.com/Ciao1019/ArcMD/releases/download/v0.5.2/arcmd-0.5.2-linux-amd64.tar.gz",
                    sha256 = "f36092f934182649b333ca75b54bf0a3eee1fc6a7b32217e828d980ce5529fa4",
                },
                aarch64 = {
                    url = "https://github.com/Ciao1019/ArcMD/releases/download/v0.5.2/arcmd-0.5.2-linux-arm64.tar.gz",
                    sha256 = "3171316432a60235c5bc2c66989d0fe0eb3039c4e06de5c5193e4cf6f6668349",
                },
            },
        },
        macosx = {
            source = "https://github.com/Ciao1019/ArcMD/releases/download/v${version}/arcmd-${version}-darwin-${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.5.2" },
            ["0.5.0"] = {
                x86_64 = {
                    url = "https://github.com/Ciao1019/ArcMD/releases/download/v0.5.0/arcmd-0.5.0-darwin-amd64.tar.gz",
                    sha256 = "87f8696ed127c26bb84cf1e3614ab968ea5de8cfa867a954fd85b34381ab41e5",
                },
                aarch64 = {
                    url = "https://github.com/Ciao1019/ArcMD/releases/download/v0.5.0/arcmd-0.5.0-darwin-arm64.tar.gz",
                    sha256 = "b70deb2953b6ec0dc9d9ad88c84449c5c17277c662a1643341a2c13007ac30c8",
                },
            },
            ["0.4.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "fa553018f9d0392a6e8f05387ad3cd86d37707dcbd5dca1f6218d17a799d88b1",
                    aarch64 = "036f100e1f00e2ffc395cc3ac223f949aae80a9b6cb73ac8d67122061c2112d6",
                },
            },
            ["0.5.2"] = {
                x86_64 = {
                    url = "https://github.com/Ciao1019/ArcMD/releases/download/v0.5.2/arcmd-0.5.2-darwin-amd64.tar.gz",
                    sha256 = "7f9ca58762df6fa3931481add5422811d97ce3cfea18f9f12aa1484fa59762b9",
                },
                aarch64 = {
                    url = "https://github.com/Ciao1019/ArcMD/releases/download/v0.5.2/arcmd-0.5.2-darwin-arm64.tar.gz",
                    sha256 = "744d8e1681e03c036c981835f57fbeb805209be306651be8d60b3d3ddb326d5c",
                },
            },
        },
        windows = {
            source = "https://github.com/Ciao1019/ArcMD/releases/download/v${version}/arcmd-${version}-windows-${arch_alias}.zip",
            ["latest"] = { ref = "0.5.2" },
            ["0.5.0"] = {
                x86_64 = {
                    url = "https://github.com/Ciao1019/ArcMD/releases/download/v0.5.0/arcmd-0.5.0-windows-amd64.zip",
                    sha256 = "93003a1c706e3ce3a605f881d6dc6f3d699d050b718e7422839baaf3fff57c45",
                },
            },
            ["0.4.0"] = {
                arch_alias = { x86_64 = "amd64" },
                sha256 = {
                    x86_64 = "890452d64234acd43d0e5057397c1efb8a7792f5510c708c39c55e4020ca0117",
                },
            },
            ["0.5.2"] = {
                x86_64 = {
                    url = "https://github.com/Ciao1019/ArcMD/releases/download/v0.5.2/arcmd-0.5.2-windows-amd64.zip",
                    sha256 = "8c741d28c3dd7e1e4e97b0b4afc2cfb0660e0c6da376ad518ee1866afb300348",
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
import("xim.pkgindex.shortcut")

local LINUX_FILES = { "arcmd", "LICENSE", "icon.png", "third_party/README.md" }
local MACOS_FILES = {
    "ArcMD.app/Contents/MacOS/ArcMD",
    "ArcMD.app/Contents/Info.plist",
    "ArcMD.app/Contents/Resources/LICENSE",
}
local WINDOWS_FILES = { "ArcMD.exe", "LICENSE", "icon.png", "third_party/README.md" }

local function is_windows()
    if os.getenv("OS") == "Windows_NT" then return true end
    local dir = tostring(pkginfo.install_dir() or "")
    if dir:match("^[A-Za-z]:") or dir:find("\\", 1, true) then return true end
    local archive = tostring(pkginfo.install_file() or "")
    return archive:match("%.zip$") ~= nil
end

function installed()
    return payload.present(LINUX_FILES)
        or payload.present(MACOS_FILES)
        or payload.present(WINDOWS_FILES)
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("arcmd: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."

    os.tryrm(dir)

    if is_windows() then
        -- Flat Windows zip: extract straight into install_dir via System32\tar.exe.
        payload.unpack{}
        payload.require(WINDOWS_FILES)
        return true
    end

    -- Linux archives are flat (no wrapper dir) and macOS archives hold ArcMD.app/:
    -- unpack directly from the archive into install_dir so unrelated files in the
    -- shared runtime download directory are never carried along.
    if os.isfile(archive) then
        fs.mkdir_p(dir)
        shell.exec({ "tar", "-xzf", archive, "-C", dir })
    elseif os.isdir(parent .. "/ArcMD.app") then
        fs.mkdir_p(dir)
        os.mv(parent .. "/ArcMD.app", dir .. "/ArcMD.app")
    else
        error("arcmd: archive not found at " .. archive)
    end

    if os.isfile(dir .. "/ArcMD.app/Contents/MacOS/ArcMD") then
        shell.exec({ "chmod", "+x", dir .. "/ArcMD.app/Contents/MacOS/ArcMD" })
        payload.require(MACOS_FILES)
    else
        shell.exec({ "chmod", "+x", dir .. "/arcmd" })
        payload.require(LINUX_FILES)
    end

    return true
end

function config()
    local dir = pkginfo.install_dir()
    if os.isfile(dir .. "/ArcMD.exe") then
        xvm.add("arcmd", { bindir = dir, alias = "ArcMD.exe" })
        shortcut.create{
            name = "ArcMD",
            target = dir .. "/ArcMD.exe",
            description = "Native Markdown and rich-text editor",
        }
    elseif os.isfile(dir .. "/ArcMD.app/Contents/MacOS/ArcMD") then
        xvm.add("arcmd", { bindir = dir .. "/ArcMD.app/Contents/MacOS", alias = "ArcMD" })
    else
        xvm.add("arcmd", { bindir = dir })
    end
    return true
end

function uninstall()
    shortcut.remove{ name = "ArcMD" }
    xvm.remove("arcmd")
    return true
end
