-- boyter/scc: Sloc Cloc and Code counter, unrelated to Mozilla's sccache.
-- Official CGO-disabled builds; Linux executables are statically linked.
-- All archives are flat: LICENSE, README.md, and scc (scc.exe on Windows).
-- Only native 64-bit targets are declared; no shell or system configuration changes.
package = {
    spec = "2",
    name = "scc",
    description = "Fast source code line, comment, and complexity counter",
    homepage = "https://github.com/boyter/scc",
    authors = {"Ben Boyter and contributors"},
    maintainers = {"boyter"},
    licenses = {"MIT"},
    repo = "https://github.com/boyter/scc",
    docs = "https://github.com/boyter/scc/blob/master/README.md",
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"tools", "development"},
    keywords = {"scc", "sloc", "cloc", "code", "counter", "complexity"},
    programs = {"scc"},
    xvm_enable = true,
    ci = { mirror = true },

    extensions = {
        autoupdate = {
            source = "https://github.com/boyter/scc/releases",
            resources = {
                GLOBAL = { url = {
                    linux = {
                        x86_64 = "https://github.com/boyter/scc/releases/download/${tag}/scc_Linux_x86_64.tar.gz",
                        aarch64 = "https://github.com/boyter/scc/releases/download/${tag}/scc_Linux_arm64.tar.gz",
                    },
                    macosx = {
                        x86_64 = "https://github.com/boyter/scc/releases/download/${tag}/scc_Darwin_x86_64.tar.gz",
                        aarch64 = "https://github.com/boyter/scc/releases/download/${tag}/scc_Darwin_arm64.tar.gz",
                    },
                    windows = {
                        x86_64 = "https://github.com/boyter/scc/releases/download/${tag}/scc_Windows_x86_64.zip",
                        aarch64 = "https://github.com/boyter/scc/releases/download/${tag}/scc_Windows_arm64.zip",
                    },
                } },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/boyter/scc/releases/download/v${version}/scc_Linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "4.1.0" },
            ["4.1.0"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "c7328436d3027f4357d3d7853f7dc3ac2bbcb4ca08f1adad91a27c593884079b",
                    aarch64 = "6e0d2a1f8d3540ba7df185477dec40bb7340f1b214bfd303147de5cad2bd7b8b",
                },
            },
        },
        macosx = {
            source = "https://github.com/boyter/scc/releases/download/v${version}/scc_Darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "4.1.0" },
            ["4.1.0"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "7f705031228add7e55edded409179a60de6b538d41f153ba2922dee95adda50d",
                    aarch64 = "7201c7aa4aace058d43308462cba72adb18f6094c08c0741727455976d0a0747",
                },
            },
        },
        windows = {
            source = "https://github.com/boyter/scc/releases/download/v${version}/scc_Windows_${arch_alias}.zip",
            ["latest"] = { ref = "4.1.0" },
            ["4.1.0"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "4a433984f45ff29c94eeb3af6db5b511c58f5bf74063dccedafcbf473cb8ff31",
                    aarch64 = "fdc1188bec07ab46fd391686c404abcd0bed92fffb5f1bb03aa9050dd7bc7f15",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

local function required_files(exe)
    return { exe, "LICENSE", "README.md" }
end

function installed()
    return payload.present(required_files("scc"))
        or payload.present(required_files("scc.exe"))
end

function install()
    local archive = tostring(pkginfo.install_file()):gsub("\\", "/")
    if archive:match("%.zip$") then
        -- No wrapper directory: use the shared Windows System32 tar extractor.
        payload.unpack{}
        payload.require(required_files("scc.exe"))
    else
        -- The framework extracts flat tarballs beside the downloaded archive.
        local parent = archive:match("^(.*)/[^/]+$") or "."
        local dir = pkginfo.install_dir()
        fs.mkdir_p(dir)
        for _, file in ipairs(required_files("scc")) do
            os.mv(parent .. "/" .. file, dir .. "/" .. file)
        end
        payload.require(required_files("scc"))
    end
    return true
end

function config()
    xvm.add("scc", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("scc")
    return true
end
