-- Official v0.6.0 archives are flat and contain only bore (bore.exe on Windows).
-- Linux uses static musl builds. Windows x64 imports VCRUNTIME140.dll, supplied
-- app-locally by xim:vcruntime. Upstream publishes no Windows ARM64 archive.
package = {
    spec = "2",
    name = "bore",
    description = "A simple, self-hosted TCP tunnel for exposing local ports",
    homepage = "https://github.com/ekzhang/bore",
    authors = {"Eric Zhang"},
    licenses = {"MIT"},
    repo = "https://github.com/ekzhang/bore",
    docs = "https://github.com/ekzhang/bore#detailed-usage",
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"tools", "network"},
    keywords = {"bore", "tcp", "tunnel", "proxy"},
    programs = {"bore"},
    xvm_enable = true,
    ci = { mirror = true },
    extensions = {
        autoupdate = {
            source = "https://github.com/ekzhang/bore/releases",
            resources = {
                GLOBAL = { url = {
                    linux = {
                        x86_64 = "https://github.com/ekzhang/bore/releases/download/${tag}/bore-${tag}-x86_64-unknown-linux-musl.tar.gz",
                        aarch64 = "https://github.com/ekzhang/bore/releases/download/${tag}/bore-${tag}-aarch64-unknown-linux-musl.tar.gz",
                    },
                    macosx = {
                        x86_64 = "https://github.com/ekzhang/bore/releases/download/${tag}/bore-${tag}-x86_64-apple-darwin.tar.gz",
                        aarch64 = "https://github.com/ekzhang/bore/releases/download/${tag}/bore-${tag}-aarch64-apple-darwin.tar.gz",
                    },
                    windows = {
                        x86_64 = "https://github.com/ekzhang/bore/releases/download/${tag}/bore-${tag}-x86_64-pc-windows-msvc.zip",
                    },
                } },
            },
        },
    },
    xpm = {
        linux = {
            source = "https://github.com/ekzhang/bore/releases/download/v${version}/bore-v${version}-${arch}-unknown-linux-musl.tar.gz",
            ["latest"] = { ref = "0.6.0" },
            ["0.6.0"] = { sha256 = {
                x86_64 = "e484d1e3acba77169b773f31a5bfb34192d4b660f44a094a658a2522cd2270f7",
                aarch64 = "ffc4515f3617420b243758cf36ed6a63208d7dba76b2ec3e90d1f476a9742951",
            } },
        },
        macosx = {
            source = "https://github.com/ekzhang/bore/releases/download/v${version}/bore-v${version}-${arch}-apple-darwin.tar.gz",
            ["latest"] = { ref = "0.6.0" },
            ["0.6.0"] = { sha256 = {
                x86_64 = "206db723a382bbc18d2893fc8472868e0b5f41de35975269aab7891ecc8659cc",
                aarch64 = "65f43a67b90874700538bdb6064c5e92276e64dfba24f5cd72ef24a035eec3bc",
            } },
        },
        windows = {
            deps = { runtime = {"xim:vcruntime"} },
            source = "https://github.com/ekzhang/bore/releases/download/v${version}/bore-v${version}-${arch}-pc-windows-msvc.zip",
            ["latest"] = { ref = "0.6.0" },
            ["0.6.0"] = { sha256 = {
                x86_64 = "01709c64fe2787cdc9a21d7030b0f08ad72dff0c36b7ecb72f4f667a55a34b4f",
            } },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")
import("xim.pkgindex.shell")

local function required_files()
    if tostring(pkginfo.install_file()):lower():match("%.zip$") then
        local crt = assert(pkginfo.dep_install_dir("xim:vcruntime"),
                           "bore: xim:vcruntime payload directory is missing")
        local files = {"bore.exe"}
        local runtime_files = fs.files(crt .. "/bin")
        assert(#runtime_files > 0, "bore: xim:vcruntime file inventory is empty")
        for _, src in ipairs(runtime_files) do
            assert(os.isfile(src), "bore: runtime provider file is missing: " .. src)
            files[#files + 1] = assert(src:gsub("\\", "/"):match("([^/]+)$"))
        end
        return files, runtime_files
    end
    return {"bore"}
end

function installed()
    return payload.present(required_files())
end

function install()
    local files, runtime_files = required_files()
    local dir = pkginfo.install_dir()
    if runtime_files then
        payload.unpack{}
        for i, src in ipairs(runtime_files) do
            os.cp(src, dir .. "/" .. files[i + 1])
        end
    else
        -- Flat archives must not inherit files from the shared runtime directory.
        os.tryrm(dir)
        fs.mkdir_p(dir)
        shell.exec({"tar", "-xzf", pkginfo.install_file(), "-C", dir})
        shell.exec({"chmod", "+x", dir .. "/bore"})
    end
    return payload.require(files)
end

function config()
    xvm.add("bore", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("bore")
    return true
end
