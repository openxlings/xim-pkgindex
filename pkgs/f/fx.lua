-- fx — terminal JSON viewer & processor (antonmedv/fx).
--
-- Distribution: upstream publishes raw single-file binaries (not archives).
-- Because the filename is not a recognized archive format, xlings downloads
-- the raw binary directly into runtimedir without extracting; `install()` moves
-- `pkginfo.install_file()` to `<install_dir>/fx` (or `fx.exe` on Windows)
-- and marks it executable on Unix.
--
-- Verified against antonmedv/fx release 40.0.2:
--   linux/x86_64    fx_linux_amd64        (ELF64 static, readelf -d: no dynamic section, ldd: not dynamic)
--   linux/aarch64   fx_linux_arm64        (ELF64 static, readelf -d: no dynamic section, ldd: not dynamic)
--   macosx/x86_64   fx_darwin_amd64       (Mach-O 64-bit x86_64)
--   macosx/aarch64  fx_darwin_arm64       (Mach-O 64-bit arm64)
--   windows/x86_64  fx_windows_amd64.exe  (PE32+ console x86-64, imports kernel32.dll only)
--   windows/aarch64 fx_windows_arm64.exe  (PE32+ console ARM64, imports kernel32.dll only)

package = {
    spec = "2",

    name = "fx",
    description = "Terminal JSON viewer & processor",
    homepage = "https://fx.wtf",
    maintainers = {"antonmedv"},
    licenses = {"MIT"},
    repo = "https://github.com/antonmedv/fx",
    docs = "https://fx.wtf",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "json", "tools"},
    keywords = {"fx", "json", "viewer", "tui", "cli", "go"},

    programs = {"fx"},
    xvm_enable = true,

    -- Verified upstream release assets; no CN mirror has been verified.
    extensions = {
        autoupdate = {
            source = "https://github.com/antonmedv/fx/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/antonmedv/fx/releases/download/${tag}/fx_linux_amd64",
                            aarch64 = "https://github.com/antonmedv/fx/releases/download/${tag}/fx_linux_arm64",
                        },
                        macosx = {
                            x86_64 = "https://github.com/antonmedv/fx/releases/download/${tag}/fx_darwin_amd64",
                            aarch64 = "https://github.com/antonmedv/fx/releases/download/${tag}/fx_darwin_arm64",
                        },
                        windows = {
                            x86_64 = "https://github.com/antonmedv/fx/releases/download/${tag}/fx_windows_amd64.exe",
                            aarch64 = "https://github.com/antonmedv/fx/releases/download/${tag}/fx_windows_arm64.exe",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/antonmedv/fx/releases/download/${version}/fx_linux_${arch_alias}",
            ["latest"] = { ref = "40.0.2" },
            ["40.0.2"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "1bafc3685d531a2440cdf14d756d7aa396b1ed401eb51dda90148685e4eba9a8",
                    aarch64 = "fea049506ea3cbe64384d45e53df2ca11b433af05c1b72aa1f846fa4bed4ed0c",
                },
            },
        },
        macosx = {
            source = "https://github.com/antonmedv/fx/releases/download/${version}/fx_darwin_${arch_alias}",
            ["latest"] = { ref = "40.0.2" },
            ["40.0.2"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "41ea20ec4addf232a5c9dcd786af76b10c54ec3d9cf71086af58b02038af87ce",
                    aarch64 = "dc72348c27b6716388076857580f28d0d09bfc1b01d6d9986694e771ecdcc1ca",
                },
            },
        },
        windows = {
            source = "https://github.com/antonmedv/fx/releases/download/${version}/fx_windows_${arch_alias}.exe",
            ["latest"] = { ref = "40.0.2" },
            ["40.0.2"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "9bd2715d51cbbb478720f060a04fc0501ca5a66e24782652ff423aa86735fe06",
                    aarch64 = "43f0b5d98fe78843734d483c0f604953a22616e021530540a4ca2925be933c40",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.system")

local function _is_windows_payload(file)
    return tostring(file):lower():match("%.exe$") ~= nil
end

function installed()
    local dir = pkginfo.install_dir()
    return os.isfile(dir .. "/fx") or os.isfile(dir .. "/fx.exe")
end

function install()
    local src = pkginfo.install_file()
    local dir = pkginfo.install_dir()
    local is_win = _is_windows_payload(src)
    local target = dir .. (is_win and "/fx.exe" or "/fx")

    os.tryrm(dir)
    os.mkdir(dir)
    os.mv(src, target)
    if not is_win then
        system.exec(string.format([[chmod +x "%s"]], target))
    end
    if not os.isfile(target) then
        error("fx: executable missing after install at " .. target)
    end
    return true
end

function config()
    xvm.add("fx", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("fx")
    return true
end
