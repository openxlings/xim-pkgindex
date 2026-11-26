-- dua -- View disk space usage and delete unwanted data, fast (Byron/dua-cli).
--
-- Verified against upstream GitHub release Byron/dua-cli v3.0.3:
--   Every SHA256 below matches the GitHub release asset digests and was
--   verified locally with sha256sum on the downloaded archives.
--   All archives contain a single top-level directory `dua-v<ver>-<target>/`
--   holding `dua` (or `dua.exe`), `LICENSE`, `README.md`, `CHANGELOG.md`, and `complete/`.
--   * linux/x86_64   : dua-v3.0.3-x86_64-unknown-linux-musl.tar.gz
--                      static-pie ELF (no PT_INTERP, zero DT_NEEDED; ldd: "statically linked")
--   * linux/aarch64  : dua-v3.0.3-aarch64-unknown-linux-musl.tar.gz
--                      statically linked ELF (no .dynamic section, no DT_NEEDED)
--   * macosx/x86_64  : dua-v3.0.3-x86_64-apple-darwin.tar.gz
--   * macosx/aarch64 : dua-v3.0.3-aarch64-apple-darwin.tar.gz
--   * windows/x86_64 : dua-v3.0.3-x86_64-pc-windows-msvc.zip
--                      PE32+ x86_64 importing VCRUNTIME140.dll and UCRT API sets,
--                      so `xim:vcruntime` DLLs are copied app-local beside dua.exe.
--   * windows/aarch64: omitted (`dua-v3.0.3-aarch64-pc-windows-msvc.zip` also imports
--                      VCRUNTIME140.dll while `xim:vcruntime` currently covers `x86_64` only).

package = {
    spec = "2",

    name = "dua",
    description = "View disk space usage and delete unwanted data, fast",
    homepage = "https://github.com/Byron/dua-cli",
    authors = {"Byron"},
    maintainers = {"https://github.com/Byron/dua-cli/graphs/contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/Byron/dua-cli",
    docs = "https://github.com/Byron/dua-cli#readme",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "filesystem", "disk-usage", "tools"},
    keywords = {"dua", "du", "disk-usage", "filesystem", "rust"},

    programs = {"dua"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/Byron/dua-cli/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/Byron/dua-cli/releases/download/${tag}/dua-v${version}-x86_64-unknown-linux-musl.tar.gz",
                            aarch64 = "https://github.com/Byron/dua-cli/releases/download/${tag}/dua-v${version}-aarch64-unknown-linux-musl.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/Byron/dua-cli/releases/download/${tag}/dua-v${version}-x86_64-apple-darwin.tar.gz",
                            aarch64 = "https://github.com/Byron/dua-cli/releases/download/${tag}/dua-v${version}-aarch64-apple-darwin.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/Byron/dua-cli/releases/download/${tag}/dua-v${version}-x86_64-pc-windows-msvc.zip",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/Byron/dua-cli/releases/download/v${version}/dua-v${version}-${arch}-unknown-linux-musl.tar.gz",
            ["latest"] = { ref = "3.0.3" },
            ["3.0.3"] = {
                sha256 = {
                    x86_64 = "68c3142969cf19b29353dbab3c456a483753d49116dbf19ae44ddd545a0abad8",
                    aarch64 = "aa95a658bd6216621c11686b41be09437a1aec7c49361b5a6a21a2188024a701",
                },
            },
        },
        macosx = {
            source = "https://github.com/Byron/dua-cli/releases/download/v${version}/dua-v${version}-${arch}-apple-darwin.tar.gz",
            ["latest"] = { ref = "3.0.3" },
            ["3.0.3"] = {
                sha256 = {
                    x86_64 = "5721d1764698147e2d5e12a7a6597b47f601247ac0bbd23db4725cd83e75f977",
                    aarch64 = "1336047f5ea3a111c10492861ade03233545a26ffd4cadd4fd3ebc2f4db14b65",
                },
            },
        },
        windows = {
            deps = {
                runtime = { "xim:vcruntime" },
            },
            source = "https://github.com/Byron/dua-cli/releases/download/v${version}/dua-v${version}-${arch}-pc-windows-msvc.zip",
            ["latest"] = { ref = "3.0.3" },
            ["3.0.3"] = {
                sha256 = {
                    x86_64 = "2fb9181079471f5e6a7a525c1508eb2a171bd2e12280a4fd2c598ec0d7993ab6",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

function installed()
    return payload.present({ "dua", "LICENSE" })
        or payload.present({ "dua.exe", "LICENSE" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("dua: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local stem = (normalized:match("([^/]+)$") or ""):gsub("%.tar%.gz$", ""):gsub("%.zip$", "")
    local is_win = normalized:match("%.zip$") ~= nil or os.getenv("OS") == "Windows_NT"

    payload.unpack{ extracted = stem, strip = 1 }

    if is_win then
        if not pkginfo.dep_install_dir then
            error("dua: xim:vcruntime runtime dep lookup is unavailable")
        end
        local crt = assert(pkginfo.dep_install_dir("xim:vcruntime"),
                           "dua: xim:vcruntime payload directory is missing")
        local copied = 0
        for _, dll in ipairs(fs.files(crt .. "/bin") or {}) do
            os.cp(dll, dir)
            copied = copied + 1
        end
        if copied == 0 then
            error("dua: no CRT DLLs found in " .. crt .. "/bin")
        end
    end

    payload.require({ is_win and "dua.exe" or "dua", "LICENSE" })
    return true
end

function config()
    xvm.add("dua", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("dua")
    return true
end
