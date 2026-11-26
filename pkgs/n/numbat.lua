-- numbat: statically typed programming language for scientific computations
-- with first class support for physical dimensions and units (sharkdp/numbat).
--
-- Official prebuilt archives verified against sharkdp/numbat release v1.24.0:
--   * linux/x86_64:   numbat-v1.24.0-x86_64-unknown-linux-musl.tar.gz
--                     static-pie ELF (readelf -d: statically linked, no PT_INTERP, no DT_NEEDED)
--   * linux/aarch64:  numbat-v1.24.0-aarch64-unknown-linux-musl.tar.gz
--                     static ELF (no PT_INTERP, no dynamic section)
--   * macosx:         x86_64-apple-darwin and aarch64-apple-darwin `.tar.gz` (Mach-O 64-bit)
--   * windows/x86_64: numbat-v1.24.0-x86_64-pc-windows-msvc.zip
--                     PE32+ console x86-64 importing VCRUNTIME140.dll and UCRT API sets,
--                     so `xim:vcruntime` DLLs are copied app-local beside numbat.exe.
--   * windows/aarch64: upstream v1.24.0 publishes no Windows ARM64 release asset
--                     and `xim:vcruntime` is x86_64-only.
--
-- All release archives wrap files inside `numbat-v<ver>-<target>/` containing
-- `numbat` (or `numbat.exe`), `modules/` (standard library `.nbt` modules),
-- `assets/`, `LICENSE-APACHE`, `LICENSE-MIT`, and `README.md`. The full
-- directory layout is preserved in `install_dir` so bundled modules remain
-- alongside the binary.
package = {
    spec = "2",

    name = "numbat",
    description = "A statically typed programming language for scientific computations with first class support for physical dimensions and units",
    homepage = "https://numbat.dev",
    authors = {"David Peter"},
    maintainers = {"David Peter"},
    licenses = {"MIT", "Apache-2.0"},
    repo = "https://github.com/sharkdp/numbat",
    docs = "https://numbat.dev/docs/",
    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "math", "science", "tools"},
    keywords = {"numbat", "calculator", "units", "physics", "dimensions", "cli", "rust"},

    programs = {"numbat"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/sharkdp/numbat/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/sharkdp/numbat/releases/download/${tag}/numbat-${tag}-x86_64-unknown-linux-musl.tar.gz",
                            aarch64 = "https://github.com/sharkdp/numbat/releases/download/${tag}/numbat-${tag}-aarch64-unknown-linux-musl.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/sharkdp/numbat/releases/download/${tag}/numbat-${tag}-x86_64-apple-darwin.tar.gz",
                            aarch64 = "https://github.com/sharkdp/numbat/releases/download/${tag}/numbat-${tag}-aarch64-apple-darwin.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/sharkdp/numbat/releases/download/${tag}/numbat-${tag}-x86_64-pc-windows-msvc.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/sharkdp/numbat/releases/download/v${version}/numbat-v${version}-${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.24.0" },
            ["1.24.0"] = {
                arch_alias = {
                    x86_64 = "x86_64-unknown-linux-musl",
                    aarch64 = "aarch64-unknown-linux-musl",
                },
                sha256 = {
                    x86_64 = "2025bc4196774336b774c1f7a9c6f45a003b9b2cbac62e577809ddd3a431c9ca",
                    aarch64 = "c6ceb781a860ea0aa3369b37c9503b20068034e2eaf70388d898a2e679410148",
                },
            },
        },
        macosx = {
            source = "https://github.com/sharkdp/numbat/releases/download/v${version}/numbat-v${version}-${arch}-apple-darwin.tar.gz",
            ["latest"] = { ref = "1.24.0" },
            ["1.24.0"] = {
                sha256 = {
                    x86_64 = "5894c60d674732a4fccfdc248539f101c8e2944805505f3f7591ed588cd84ef1",
                    aarch64 = "947e0d6e2dbff56a3d6c85282787b62013502a6d35d317d919e09f620433d177",
                },
            },
        },
        windows = {
            deps = {
                runtime = { "xim:vcruntime" },
            },
            source = "https://github.com/sharkdp/numbat/releases/download/v${version}/numbat-v${version}-${arch}-pc-windows-msvc.zip",
            ["latest"] = { ref = "1.24.0" },
            ["1.24.0"] = {
                sha256 = {
                    x86_64 = "450027111a5df0dd3ee4ce97a557c4847fc76b05851fccb9e26e875433084049",
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
    return payload.present({ "numbat", "modules/prelude.nbt", "modules/all.nbt" })
        or payload.present({ "numbat.exe", "modules/prelude.nbt", "modules/all.nbt" })
end

function install()
    local archive = tostring(pkginfo.install_file())
    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local stem = (normalized:match("([^/]+)$") or ""):gsub("%.tar%.gz$", ""):gsub("%.zip$", "")
    local is_win = normalized:match("%.zip$") ~= nil

    payload.unpack{ extracted = stem, strip = 1 }

    if is_win then
        if not pkginfo.dep_install_dir then
            error("numbat: xim:vcruntime runtime dep lookup is unavailable")
        end
        local crt = assert(pkginfo.dep_install_dir("xim:vcruntime"),
                           "numbat: xim:vcruntime payload directory is missing")
        local copied = 0
        for _, dll in ipairs(fs.files(crt .. "/bin") or {}) do
            os.cp(dll, dir)
            copied = copied + 1
        end
        if copied == 0 then
            error("numbat: no CRT DLLs found in " .. crt .. "/bin")
        end
    end

    payload.require({ is_win and "numbat.exe" or "numbat", "modules/prelude.nbt", "modules/all.nbt" })
    return true
end

function config()
    xvm.add("numbat", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("numbat")
    return true
end
