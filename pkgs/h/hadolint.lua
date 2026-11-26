-- hadolint - Dockerfile linter, validate inline bash, written in Haskell.
--
-- Distribution: upstream publishes raw single-file binaries (not archives).
-- Because the filename is not a recognized archive format, xlings downloads
-- the raw binary directly into runtimedir without extracting; `install()` moves
-- `pkginfo.install_file()` to `<install_dir>/hadolint` (or `hadolint.exe` on
-- Windows) and marks it executable on Unix.
--
-- Official prebuilt binaries verified against hadolint/hadolint v2.15.1:
--   linux/x86_64    hadolint-linux-x86_64        (ELF64 static, readelf -d: no dynamic section, ldd: not dynamic)
--   linux/aarch64   hadolint-linux-arm64         (ELF64 static, readelf -d: no dynamic section)
--   macosx/x86_64   hadolint-macos-x86_64        (Mach-O 64-bit x86_64; system dylibs only)
--   macosx/aarch64  hadolint-macos-arm64         (Mach-O 64-bit arm64; system dylibs only)
--   windows/x86_64  hadolint-windows-x86_64.exe  (PE32+ console x86-64; Windows OS & UCRT DLLs only, no VCRUNTIME140.dll; no windows/aarch64 asset)

package = {
    spec = "2",

    name = "hadolint",
    description = "Dockerfile linter, validate inline bash, written in Haskell",
    homepage = "https://github.com/hadolint/hadolint",
    maintainers = {"hadolint"},
    licenses = {"GPL-3.0"},
    repo = "https://github.com/hadolint/hadolint",
    docs = "https://github.com/hadolint/hadolint#readme",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "linter", "docker", "tools"},
    keywords = {"hadolint", "dockerfile", "docker", "linter", "haskell", "shellcheck"},

    programs = {"hadolint"},
    xvm_enable = true,

    -- Verified upstream release assets; no CN mirror has been verified.
    extensions = {
        autoupdate = {
            source = "https://github.com/hadolint/hadolint/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/hadolint/hadolint/releases/download/${tag}/hadolint-linux-x86_64",
                            aarch64 = "https://github.com/hadolint/hadolint/releases/download/${tag}/hadolint-linux-arm64",
                        },
                        macosx = {
                            x86_64 = "https://github.com/hadolint/hadolint/releases/download/${tag}/hadolint-macos-x86_64",
                            aarch64 = "https://github.com/hadolint/hadolint/releases/download/${tag}/hadolint-macos-arm64",
                        },
                        windows = {
                            x86_64 = "https://github.com/hadolint/hadolint/releases/download/${tag}/hadolint-windows-x86_64.exe",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/hadolint/hadolint/releases/download/v${version}/hadolint-linux-${arch_alias}",
            ["latest"] = { ref = "2.15.1" },
            ["2.15.1"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "c7187db94eeeeca956519a6af171adc31453941a1e777961f6e680f697c8c507",
                    aarch64 = "f6198ef8090f404dbb771abfee086eb8c48ac177f30da7fd3510aca35b344b5d",
                },
            },
        },
        macosx = {
            source = "https://github.com/hadolint/hadolint/releases/download/v${version}/hadolint-macos-${arch_alias}",
            ["latest"] = { ref = "2.15.1" },
            ["2.15.1"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "ffe9bb18b23d5ed1eae50237aecdbb523d016e96da0bd4e7aa432040acfc3fde",
                    aarch64 = "5c09f3213f8e40406abe048233d985eebef336d4a6a20021be47fadb6cf480a2",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "2.15.1" },
            ["2.15.1"] = {
                x86_64 = {
                    url = "https://github.com/hadolint/hadolint/releases/download/v2.15.1/hadolint-windows-x86_64.exe",
                    sha256 = "01d927294962b5387f9ead4f18679158452be4f17c765ad0bdffe5264b9c7b0a",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

local function _is_windows_payload(file)
    return tostring(file):lower():match("%.exe$") ~= nil
end

function installed()
    local dir = pkginfo.install_dir()
    return os.isfile(dir .. "/hadolint") or os.isfile(dir .. "/hadolint.exe")
end

function install()
    local src = pkginfo.install_file()
    local dir = pkginfo.install_dir()
    local is_win = _is_windows_payload(src)
    local target = dir .. (is_win and "/hadolint.exe" or "/hadolint")

    os.tryrm(dir)
    fs.mkdir_p(dir)
    os.mv(src, target)
    if not is_win then
        system.exec(string.format([[chmod +x "%s"]], target))
    end
    if not os.isfile(target) then
        error("hadolint: executable missing after install at " .. target)
    end
    return true
end

function config()
    xvm.add("hadolint", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("hadolint")
    return true
end
