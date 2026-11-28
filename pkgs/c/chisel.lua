-- Official v1.12.0 assets verified against the upstream checksum manifest and
-- GitHub asset digests. Linux amd64/arm64 are static ELF; Darwin is Mach-O.
-- Windows ships rootless ZIPs (including ARM64), not the POSIX bare gzip files.
package = {
    spec = "2",
    name = "chisel",
    description = "Fast TCP/UDP tunnel over HTTP, secured via SSH",
    homepage = "https://github.com/jpillora/chisel",
    repo = "https://github.com/jpillora/chisel",
    docs = "https://github.com/jpillora/chisel#readme",
    authors = { "jpillora" },
    licenses = { "MIT" },
    type = "package",
    archs = { "x86_64", "aarch64" },
    status = "stable",
    categories = { "network", "tools" },
    keywords = { "chisel", "tunnel", "tcp", "http", "ssh" },
    programs = { "chisel" },
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/jpillora/chisel/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/jpillora/chisel/releases/download/${tag}/chisel_${version}_linux_amd64.gz",
                            aarch64 = "https://github.com/jpillora/chisel/releases/download/${tag}/chisel_${version}_linux_arm64.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/jpillora/chisel/releases/download/${tag}/chisel_${version}_darwin_amd64.gz",
                            aarch64 = "https://github.com/jpillora/chisel/releases/download/${tag}/chisel_${version}_darwin_arm64.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/jpillora/chisel/releases/download/${tag}/chisel_${version}_windows_amd64.zip",
                            aarch64 = "https://github.com/jpillora/chisel/releases/download/${tag}/chisel_${version}_windows_arm64.zip",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/jpillora/chisel/releases/download/v${version}/chisel_${version}_linux_${arch_alias}.gz",
            ["latest"] = { ref = "1.12.0" },
            ["1.12.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "f3f180f1d93aa72cce4e6386f98cc06569a0146fbd65eb4423cf83e6434bcfe6",
                    aarch64 = "2ec6152cd2c74fe0146d4d79e4e7aa174521368c56e433d55e023a92ea404ec3",
                },
            },
        },
        macosx = {
            source = "https://github.com/jpillora/chisel/releases/download/v${version}/chisel_${version}_darwin_${arch_alias}.gz",
            ["latest"] = { ref = "1.12.0" },
            ["1.12.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "4aeae36c867f11c8e8c3f2b913a0e063ea3c6d29e1c14a52ed2e6eef8cfc4395",
                    aarch64 = "707a4b932eea214765146504a0df246cefc415b4297af65a80dd67cf69ba85a9",
                },
            },
        },
        windows = {
            source = "https://github.com/jpillora/chisel/releases/download/v${version}/chisel_${version}_windows_${arch_alias}.zip",
            ["latest"] = { ref = "1.12.0" },
            ["1.12.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "600a8ad6f03bc7f6d285fd01ab6a3f8a657204adaafa5666ade9451d18df1ebc",
                    aarch64 = "907e1538ab86522fa4b11d7e45192b5f54e74beb88745093f6b2ca5b6e4efbc8",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")
import("xim.pkgindex.shell")

local function required_files()
    local windows = os.getenv("OS") == "Windows_NT"
    return { windows and "chisel.exe" or "chisel" }
end

function installed()
    return payload.present(required_files())
end

function install()
    local archive = tostring(pkginfo.install_file() or ""):gsub("\\", "/")
    local dir = pkginfo.install_dir()
    local files = required_files()
    if archive:match("%.zip$") then
        payload.unpack({ extracted = archive:match("([^/]+)%.zip$") })
    else
        local target = dir .. "/" .. files[1]
        local unpacked = archive:gsub("%.gz$", "")
        os.tryrm(dir)
        fs.mkdir_p(dir)
        if unpacked ~= archive and os.isfile(unpacked) then
            os.mv(unpacked, target)
        elseif archive:match("%.gz$") and os.isfile(archive) then
            -- Bare gzip is not an archive to every xlings client. Its FNAME
            -- is not an output path: explicitly choose the installed filename.
            shell.exec({ "sh", "-c", 'gzip -dc "$1" > "$2"', "_", archive, target })
        else
            error("chisel: gzip payload missing: " .. archive)
        end
        shell.exec({ "chmod", "+x", target })
    end
    payload.require(files)
    return true
end

function config()
    xvm.add("chisel", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("chisel")
    return true
end
