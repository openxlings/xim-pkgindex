-- Official v0.9.0 ZIPs contain only `jless` (no bundled libraries/licenses).
-- Linux x86_64 needs libxcb{,-render,-shape,-xfixes}.so, libgcc_s and glibc
-- >=2.34. Seal bin/ against those declared providers; never use host X11 libs.
-- macOS x86_64/aarch64 link only system frameworks and /usr/lib libraries.
-- Upstream provides neither Linux ARM64 nor Windows release assets.
package = {
    spec = "2",
    name = "jless",
    description = "A terminal JSON and YAML viewer with structural navigation and regex search",
    homepage = "https://jless.io",
    authors = {"Paul Julius Martinez"},
    licenses = {"MIT"},
    repo = "https://github.com/PaulJuliusMartinez/jless",
    docs = "https://jless.io/user-guide.html",
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "tools"},
    keywords = {"json", "yaml", "viewer", "pager", "search"},
    programs = {"jless"},
    xvm_enable = true,
    ci = { mirror = true },
    extensions = {
        autoupdate = {
            source = "https://github.com/PaulJuliusMartinez/jless/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/PaulJuliusMartinez/jless/releases/download/${tag}/jless-${tag}-x86_64-unknown-linux-gnu.zip",
                        },
                        macosx = {
                            x86_64 = "https://github.com/PaulJuliusMartinez/jless/releases/download/${tag}/jless-${tag}-x86_64-apple-darwin.zip",
                            aarch64 = "https://github.com/PaulJuliusMartinez/jless/releases/download/${tag}/jless-${tag}-aarch64-apple-darwin.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },
    xpm = {
        linux = {
            deps = {
                runtime = {"xim:glibc@>=2.34", "xim:gcc-runtime@>=15.1.0", "xim:libxcb@>=1.17.0"},
            },
            ["latest"] = { ref = "0.9.0" },
            ["0.9.0"] = {
                x86_64 = {
                    url = "https://github.com/PaulJuliusMartinez/jless/releases/download/v0.9.0/jless-v0.9.0-x86_64-unknown-linux-gnu.zip",
                    sha256 = "a1e0eb63ef347adc649989ac5c7d2dc896df6d494622b953c86e3a248e733a93",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "0.9.0" },
            ["0.9.0"] = {
                x86_64 = {
                    url = "https://github.com/PaulJuliusMartinez/jless/releases/download/v0.9.0/jless-v0.9.0-x86_64-apple-darwin.zip",
                    sha256 = "8228d44b918af7e904a75df10f85dabf29cdedac17156d870c80968e6836b04f",
                },
                aarch64 = {
                    url = "https://github.com/PaulJuliusMartinez/jless/releases/download/v0.9.0/jless-v0.9.0-aarch64-apple-darwin.zip",
                    sha256 = "1967568762e44d3a5a7b09211c55ff9680419878a5a7045876d2cc6870e40390",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")
import("xim.pkgindex.selfcontain")
import("xim.pkgindex.shell")

function installed()
    return payload.present({"bin/jless"})
end

function install()
    local archive = tostring(pkginfo.install_file()):gsub("\\", "/")
    local parent = assert(archive:match("^(.*)/[^/]+$"), "jless: archive has no parent")
    local stem = archive:match("([^/]+)$"):gsub("%.zip$", "")
    -- These flat, singleton ZIPs are already extracted by the framework.
    -- Move only their executable, not the shared download directory.
    local source = parent .. "/jless"
    if not os.isfile(source) then source = parent .. "/" .. stem .. "/jless" end
    assert(os.isfile(source), "jless: extracted executable is missing beside " .. archive)
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    fs.mkdir_p(dir .. "/bin")
    os.mv(source, dir .. "/bin/jless")
    payload.require({"bin/jless"})
    shell.exec({"chmod", "+x", dir .. "/bin/jless"})
    if archive:find("-unknown-linux-gnu", 1, true) then
        if type(selfcontain.seal) ~= "function" or not selfcontain.seal(dir, {"bin"}) then
            error("jless: runtime sealing is unavailable; run xlings self update")
        end
    end
    return true
end

function config()
    xvm.add("jless", { bindir = pkginfo.install_dir() .. "/bin" })
    return true
end

function uninstall()
    xvm.remove("jless")
    return true
end
