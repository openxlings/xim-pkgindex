-- Official v1.9.1 bare binaries, renamed to the upstream CLI command tldr.
-- SHA256 values match both GitHub asset digests and upstream .sha256 files.
-- Linux assets are static musl ELF; macOS assets are native Mach-O binaries.
-- Windows x64 imports VCRUNTIME140.dll, supplied app-locally by xim:vcruntime.
-- Windows ARM64 is omitted: its required ARM64 CRT is not indexed yet.
-- Cargo.toml at v1.9.1 declares MIT OR Apache-2.0 (at the user's option):
-- https://github.com/tealdeer-rs/tealdeer/blob/v1.9.1/Cargo.toml
-- License texts are separate official release assets, not inside bare binaries:
-- https://github.com/tealdeer-rs/tealdeer/releases/tag/v1.9.1
-- Hooks deliberately never fetch licenses, pages/cache, or user configuration.
package = {
    spec = "2",
    name = "tealdeer",
    description = "A fast tldr client with simplified command examples",
    homepage = "https://tealdeer.org",
    authors = {"Danilo Bargen", "Niklas Mohrin"},
    licenses = {"MIT", "Apache-2.0"},
    repo = "https://github.com/tealdeer-rs/tealdeer",
    docs = "https://docs.tealdeer.org",
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"tools", "cli"},
    keywords = {"tealdeer", "tldr", "documentation"},
    programs = {"tldr"},
    xvm_enable = true,
    extensions = {
        autoupdate = {
            source = "https://github.com/tealdeer-rs/tealdeer/releases",
            resources = {
                GLOBAL = { url = {
                    linux = {
                        x86_64 = "https://github.com/tealdeer-rs/tealdeer/releases/download/${tag}/tealdeer-linux-x86_64-musl",
                        aarch64 = "https://github.com/tealdeer-rs/tealdeer/releases/download/${tag}/tealdeer-linux-aarch64-musl",
                    },
                    macosx = {
                        x86_64 = "https://github.com/tealdeer-rs/tealdeer/releases/download/${tag}/tealdeer-macos-x86_64",
                        aarch64 = "https://github.com/tealdeer-rs/tealdeer/releases/download/${tag}/tealdeer-macos-aarch64",
                    },
                    windows = {
                        x86_64 = "https://github.com/tealdeer-rs/tealdeer/releases/download/${tag}/tealdeer-windows-x86_64-msvc.exe",
                    },
                } },
            },
        },
    },
    xpm = {
        linux = {
            source = "https://github.com/tealdeer-rs/tealdeer/releases/download/v${version}/tealdeer-linux-${arch}-musl",
            ["latest"] = { ref = "1.9.1" },
            ["1.9.1"] = { sha256 = {
                x86_64 = "5a9c3f0691b9cf375ee5c99de802885f3d50498cf686a539e2ddda028eb6b4f6",
                aarch64 = "247746dd2d18f0135da79b849bb6b49e45262e2fe4318adfc3082dc6ce3ee968",
            } },
        },
        macosx = {
            source = "https://github.com/tealdeer-rs/tealdeer/releases/download/v${version}/tealdeer-macos-${arch}",
            ["latest"] = { ref = "1.9.1" },
            ["1.9.1"] = { sha256 = {
                x86_64 = "06189e82d407d2f3193b9a22d2b6a289a271677142b993af2cee0c2120e12111",
                aarch64 = "5c0a088880d83faf098e2716abbc373a5607addf76a7e1b7ebbe206bde4ebd35",
            } },
        },
        windows = {
            deps = { runtime = {"xim:vcruntime"} },
            source = "https://github.com/tealdeer-rs/tealdeer/releases/download/v${version}/tealdeer-windows-${arch}-msvc.exe",
            ["latest"] = { ref = "1.9.1" },
            ["1.9.1"] = { sha256 = {
                x86_64 = "f75a3e4b43e7b03d30bac88eccf928af90b8993cd354fe207aec1c643910736f",
            } },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

local function required_files()
    if tostring(pkginfo.install_file()):lower():match("%.exe$") then
        local crt = assert(pkginfo.dep_install_dir("xim:vcruntime"),
                           "tealdeer: xim:vcruntime payload directory is missing")
        local files = {"tldr.exe"}
        local runtime_files = fs.files(crt .. "/bin")
        assert(#runtime_files > 0, "tealdeer: xim:vcruntime file inventory is empty")
        for _, src in ipairs(runtime_files) do
            assert(os.isfile(src), "tealdeer: runtime provider file is missing: " .. src)
            local name = assert(src:gsub("\\", "/"):match("([^/]+)$"))
            files[#files + 1] = name
        end
        return files, runtime_files
    end
    return {"tldr"}
end

function installed()
    return payload.present(required_files())
end

function install()
    local files, runtime_files = required_files()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    fs.mkdir_p(dir)
    os.mv(pkginfo.install_file(), dir .. "/" .. files[1])
    if files[1] == "tldr.exe" then
        for i, src in ipairs(runtime_files) do
            os.cp(src, dir .. "/" .. files[i + 1])
        end
    else
        system.exec(string.format('chmod +x "%s/tldr"', dir))
    end
    return payload.require(files)
end

function config()
    xvm.add("tldr", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("tldr")
    return true
end
