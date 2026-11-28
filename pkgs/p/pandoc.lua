-- Pandoc - a universal document converter.
--
-- Official prebuilt binaries verified against jgm/pandoc 3.14:
--   * linux/x86_64: statically linked ELF64 executable (no PT_INTERP, no
--     dynamic section / DT_NEEDED; no xim:glibc or xim:gcc-runtime needed)
--   * linux/aarch64: statically linked ELF64 executable (no PT_INTERP, no
--     dynamic section / DT_NEEDED)
--   * macosx/x86_64 & macosx/aarch64: Mach-O 64-bit executables linking only
--     system dylibs (libSystem.B, libiconv.2, libffi, Security.framework,
--     libcharset.1)
--   * windows/x86_64: PE32+ executable importing only Windows OS / UCRT DLLs
--     (no VCRUNTIME140.dll or MSVCP140.dll; no windows/aarch64 release asset)
--
-- Archive layouts:
--   * linux .tar.gz: pandoc-<ver>/bin/pandoc (+ pandoc-lua, pandoc-server symlinks), share/
--   * macosx .zip: pandoc-<ver>-{x86_64,arm64}/bin/pandoc (+ symlinks), share/
--   * windows .zip: pandoc-<ver>/pandoc.exe, COPYRIGHT.txt, COPYING.rtf, MANUAL.html

package = {
    spec = "2",

    name = "pandoc",
    description = "A universal document converter",
    homepage = "https://pandoc.org",
    authors = {"John MacFarlane"},
    maintainers = {"https://github.com/jgm/pandoc"},
    licenses = {"GPL-2.0-or-later"},
    repo = "https://github.com/jgm/pandoc",
    docs = "https://pandoc.org/MANUAL.html",
    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "converter", "document", "markdown", "tools"},
    keywords = {"pandoc", "markdown", "html", "latex", "docx", "epub", "converter"},

    programs = {"pandoc"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/jgm/pandoc/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/jgm/pandoc/releases/download/${tag}/pandoc-${version}-linux-amd64.tar.gz",
                            aarch64 = "https://github.com/jgm/pandoc/releases/download/${tag}/pandoc-${version}-linux-arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/jgm/pandoc/releases/download/${tag}/pandoc-${version}-x86_64-macOS.zip",
                            aarch64 = "https://github.com/jgm/pandoc/releases/download/${tag}/pandoc-${version}-arm64-macOS.zip",
                        },
                        windows = {
                            x86_64 = "https://github.com/jgm/pandoc/releases/download/${tag}/pandoc-${version}-windows-x86_64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/jgm/pandoc/releases/download/${version}/pandoc-${version}-linux-${arch_alias}.tar.gz",
            ["latest"] = { ref = "3.14" },
            ["3.14"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "c5f4720cdefb3f7bdc5d07202ef579feef0d1370773c873804dd8fdaa8c4f1b8",
                    aarch64 = "c692f3d78a415741bbbac4cdbbbe26fa7edca1f43d2301b982fbf4009cc8cf7f",
                },
            },
        },
        macosx = {
            source = "https://github.com/jgm/pandoc/releases/download/${version}/pandoc-${version}-${arch_alias}-macOS.zip",
            ["latest"] = { ref = "3.14" },
            ["3.14"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "891708579061e7b1c1a6ce0df30ebb3cb2b6d0ca045ed3c8554ab830c1e0c270",
                    aarch64 = "58d6593884fec9d4424b641b92503c316d9c36decb2891ff8d73ae74dd3b6304",
                },
            },
        },
        windows = {
            source = "https://github.com/jgm/pandoc/releases/download/${version}/pandoc-${version}-windows-${arch}.zip",
            ["latest"] = { ref = "3.14" },
            ["3.14"] = {
                sha256 = {
                    x86_64 = "0144b96e8c7b023fd382ec5ef5bdc475e873f1019d6fa72502492df2c9a94a3b",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

function installed()
    return payload.present({ "bin/pandoc" }) or payload.present({ "pandoc.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file())
    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local is_win = normalized:match("windows") ~= nil or normalized:match("%.exe$") ~= nil
    local ver = pkginfo.version()
    local exe = is_win and "pandoc.exe" or "bin/pandoc"
    local extracted = "pandoc-" .. ver
    if normalized:match("arm64%-macOS") then
        extracted = { "pandoc-" .. ver .. "-arm64", extracted }
    elseif normalized:match("x86_64%-macOS") then
        extracted = { "pandoc-" .. ver .. "-x86_64", extracted }
    end

    payload.unpack{ extracted = extracted, strip = 1 }

    if not is_win then
        system.exec(string.format('chmod +x "%s"', dir .. "/" .. exe))
    end

    payload.require({ exe })
    return true
end

function config()
    local dir = pkginfo.install_dir()
    if os.isfile(dir .. "/pandoc.exe") then
        xvm.add("pandoc", { bindir = dir, alias = "pandoc.exe" })
    else
        xvm.add("pandoc", { bindir = dir .. "/bin" })
    end
    return true
end

function uninstall()
    xvm.remove("pandoc")
    return true
end
