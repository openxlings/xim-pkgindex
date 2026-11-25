-- shfmt — a shell parser, formatter, and interpreter with bash, POSIX, mksh,
-- and zsh support (mvdan/sh).
--
-- Distribution: upstream publishes raw single-file binaries built with
-- `CGO_ENABLED=0 go build -trimpath -ldflags="-w -s"` (per v3.14.1 release notes).
-- Because the filename is not a recognized archive format, xlings downloads
-- the raw binary directly into runtimedir without extracting; `install()` moves
-- `pkginfo.install_file()` to `<install_dir>/shfmt` (or `shfmt.exe` on Windows)
-- and marks it executable on Unix.
--
-- Verified against mvdan/sh release v3.14.1 (SHA-256 matched GitHub release digests):
--   linux/x86_64    shfmt_v3.14.1_linux_amd64    (ELF64 static, readelf -d: no dynamic section, ldd: not dynamic)
--   linux/aarch64   shfmt_v3.14.1_linux_arm64    (ELF64 static, readelf -d: no dynamic section)
--   macosx/x86_64   shfmt_v3.14.1_darwin_amd64   (Mach-O 64-bit x86_64)
--   macosx/aarch64  shfmt_v3.14.1_darwin_arm64   (Mach-O 64-bit arm64)
--   windows/x86_64  shfmt_v3.14.1_windows_amd64.exe (PE32+ console, imports kernel32.dll only)
-- Upstream v3.14.1 publishes no windows/arm64 binary, so windows covers x86_64 only.

package = {
    spec = "2",

    name = "shfmt",
    description = "A shell formatter, parser, and interpreter with bash, POSIX, and zsh support",
    homepage = "https://github.com/mvdan/sh",
    maintainers = {"mvdan"},
    licenses = {"BSD-3-Clause"},
    repo = "https://github.com/mvdan/sh",
    docs = "https://pkg.go.dev/mvdan.cc/sh/v3",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "shell", "formatter", "tools"},
    keywords = {"shfmt", "shell", "bash", "posix", "zsh", "formatter", "linter"},

    programs = {"shfmt"},
    xvm_enable = true,

    -- Verified upstream release assets; no CN mirror has been verified.
    extensions = {
        autoupdate = {
            source = "https://github.com/mvdan/sh/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/mvdan/sh/releases/download/${tag}/shfmt_v${version}_linux_amd64",
                            aarch64 = "https://github.com/mvdan/sh/releases/download/${tag}/shfmt_v${version}_linux_arm64",
                        },
                        macosx = {
                            x86_64 = "https://github.com/mvdan/sh/releases/download/${tag}/shfmt_v${version}_darwin_amd64",
                            aarch64 = "https://github.com/mvdan/sh/releases/download/${tag}/shfmt_v${version}_darwin_arm64",
                        },
                        windows = {
                            x86_64 = "https://github.com/mvdan/sh/releases/download/${tag}/shfmt_v${version}_windows_amd64.exe",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/mvdan/sh/releases/download/v${version}/shfmt_v${version}_linux_${arch_alias}",
            ["latest"] = { ref = "3.14.1" },
            ["3.14.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "76e77641faa025814b77f153b29796b8e6fa2fca03e0c76a691608b86c7ea7bf",
                    aarch64 = "5f2db09dae91fca848f7adbdd014632e921a383863a2ad7e0450ad3aba0c6489",
                },
            },
        },
        macosx = {
            source = "https://github.com/mvdan/sh/releases/download/v${version}/shfmt_v${version}_darwin_${arch_alias}",
            ["latest"] = { ref = "3.14.1" },
            ["3.14.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "d33eee0da0f92835b3562e9767a05cee7e4eaeef47daa03bfd09da17b4b590a6",
                    aarch64 = "b7c872db63553ccffc7253aba3ed7d4885a27d83f1ba567b1138c6315a5847e5",
                },
            },
        },
        windows = {
            source = "https://github.com/mvdan/sh/releases/download/v${version}/shfmt_v${version}_windows_${arch_alias}.exe",
            ["latest"] = { ref = "3.14.1" },
            ["3.14.1"] = {
                arch_alias = { x86_64 = "amd64" },
                sha256 = {
                    x86_64 = "13629ce28442ca80b6b5a819f7574ab39e1c28c6e26734ca816c9714e04851df",
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
    return os.isfile(dir .. "/shfmt") or os.isfile(dir .. "/shfmt.exe")
end

function install()
    local src = pkginfo.install_file()
    local dir = pkginfo.install_dir()
    local is_win = _is_windows_payload(src)
    local target = dir .. (is_win and "/shfmt.exe" or "/shfmt")

    os.tryrm(dir)
    os.mkdir(dir)
    os.mv(src, target)
    if not is_win then
        system.exec(string.format([[chmod +x "%s"]], target))
    end
    if not os.isfile(target) then
        error("shfmt: executable missing after install at " .. target)
    end
    return true
end

function config()
    xvm.add("shfmt", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("shfmt")
    return true
end
