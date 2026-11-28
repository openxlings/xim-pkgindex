-- Official Apache-2.0-only RTK OSS binaries, not the engine/proxy distribution.
-- Linux uses upstream musl builds with no DT_NEEDED or interpreter.
-- Windows imports VCRUNTIME140.dll: copy the declared runtime beside rtk.exe.
-- Optional proxy commands use tools explicitly selected by the user;
-- installation never runs rtk init or enables hooks or telemetry.
package = {
    spec = "2",
    name = "rtk",
    description = "Token-efficient command output filters, Apache-2.0-only RTK OSS build",
    homepage = "https://github.com/rtk-ai/rtk",
    licenses = {"Apache-2.0"},
    repo = "https://github.com/rtk-ai/rtk",
    docs = "https://github.com/rtk-ai/rtk/blob/v1.2.1/README.md",
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"tools", "development"},
    keywords = {"rtk", "tokens", "cli", "filters", "llm"},
    programs = {"rtk"},
    xvm_enable = true,
    ci = { mirror = true },
    xpm = {
        linux = {
            source = "https://github.com/rtk-ai/rtk/releases/download/v${version}/rtk-oss-${arch}-unknown-linux-musl.tar.gz",
            ["latest"] = { ref = "1.2.1" },
            ["1.2.1"] = { sha256 = {
                x86_64 = "44aa460c4827d206d11405c652832c9f7082edccfbc3a9f15a69a851e8a9e8b4",
                aarch64 = "b01860ae2d3f44e0f7fc4431a95dd66b29b4bd87ec7f5e60aff13681b05db5dd",
            } },
        },
        macosx = {
            source = "https://github.com/rtk-ai/rtk/releases/download/v${version}/rtk-oss-${arch}-apple-darwin.tar.gz",
            ["latest"] = { ref = "1.2.1" },
            ["1.2.1"] = { sha256 = {
                x86_64 = "5e39ee8c4613c798f8d62868d4851bacca5aefcc134301052841e458ed71c797",
                aarch64 = "5a37e5e8e016b559597024900e7b21cff7a0015aa189ac6ac80d461cbb4be65b",
            } },
        },
        windows = {
            deps = { runtime = { "xim:vcruntime" } },
            source = "https://github.com/rtk-ai/rtk/releases/download/v${version}/rtk-oss-${arch}-pc-windows-msvc.zip",
            ["latest"] = { ref = "1.2.1" },
            -- This upstream OSS release does not provide Windows ARM64.
            ["1.2.1"] = { sha256 = {
                x86_64 = "43124168ec0733b50f7e9e1f1b994ced9b0693b9e92281428f64990c308bf1c8",
            } },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

local function required_files(exe)
    if exe == "rtk.exe" then return { exe, "LICENSE", "vcruntime140.dll" } end
    return { exe, "LICENSE" }
end

function installed()
    return payload.present(required_files("rtk"))
        or payload.present(required_files("rtk.exe"))
end

function install()
    local archive = tostring(pkginfo.install_file()):gsub("\\", "/")
    local dir = pkginfo.install_dir()
    if archive:match("%.zip$") then
        payload.unpack{}
        local crt = pkginfo.dep_install_dir("xim:vcruntime")
        os.cp(crt .. "/bin/vcruntime140.dll", dir .. "/vcruntime140.dll")
        payload.require(required_files("rtk.exe"))
    else
        -- Move only this tarball's files, never the shared extraction tree.
        local parent = archive:match("^(.*)/[^/]+$") or "."
        fs.mkdir_p(dir)
        for _, file in ipairs(required_files("rtk")) do
            os.mv(parent .. "/" .. file, dir .. "/" .. file)
        end
        payload.require(required_files("rtk"))
    end
    return true
end

function config()
    xvm.add("rtk", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("rtk")
    return true
end
