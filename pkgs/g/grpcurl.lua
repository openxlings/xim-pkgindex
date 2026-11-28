-- grpcurl — Like cURL, but for gRPC: command-line tool for interacting with gRPC servers.
--
-- Verified against fullstorydev/grpcurl release v1.9.4 (SHA-256 verified against
-- upstream `grpcurl_1.9.4_checksums.txt`):
--   linux/x86_64    grpcurl_1.9.4_linux_x86_64.tar.gz   (static Go ELF, no .dynamic section)
--   linux/aarch64   grpcurl_1.9.4_linux_arm64.tar.gz    (static Go ELF, no .dynamic section)
--   macosx/x86_64   grpcurl_1.9.4_osx_x86_64.tar.gz
--   macosx/aarch64  grpcurl_1.9.4_osx_arm64.tar.gz
--   windows/x86_64  grpcurl_1.9.4_windows_x86_64.zip    (PE32+, imports only kernel32.dll)
--   windows/aarch64 grpcurl_1.9.4_windows_arm64.zip     (PE32+ ARM64, imports only kernel32.dll)
--
-- Every upstream archive is flat at root (`grpcurl` / `grpcurl.exe` and `LICENSE`).

package = {
    spec = "2",

    name = "grpcurl",
    description = "Like cURL, but for gRPC: A command-line tool for interacting with gRPC servers",
    homepage = "https://github.com/fullstorydev/grpcurl",
    authors = {"Joshua Humphries", "FullStory, Inc."},
    maintainers = {"fullstorydev"},
    licenses = {"MIT"},
    repo = "https://github.com/fullstorydev/grpcurl",
    docs = "https://github.com/fullstorydev/grpcurl#readme",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"grpc", "network", "cli", "tools"},
    keywords = {"grpcurl", "grpc", "curl", "protobuf", "cli", "rpc"},

    programs = {"grpcurl"},
    xvm_enable = true,

    -- Verified upstream release assets; no CN mirror has been verified.
    extensions = {
        autoupdate = {
            source = "https://github.com/fullstorydev/grpcurl/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/fullstorydev/grpcurl/releases/download/${tag}/grpcurl_${version}_linux_x86_64.tar.gz",
                            aarch64 = "https://github.com/fullstorydev/grpcurl/releases/download/${tag}/grpcurl_${version}_linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/fullstorydev/grpcurl/releases/download/${tag}/grpcurl_${version}_osx_x86_64.tar.gz",
                            aarch64 = "https://github.com/fullstorydev/grpcurl/releases/download/${tag}/grpcurl_${version}_osx_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/fullstorydev/grpcurl/releases/download/${tag}/grpcurl_${version}_windows_x86_64.zip",
                            aarch64 = "https://github.com/fullstorydev/grpcurl/releases/download/${tag}/grpcurl_${version}_windows_arm64.zip",
                        },
                    },
                },
            },
        },
    },

    -- Upstream builds static Go binaries; Linux ELFs have no dynamic section and
    -- Windows PEs import only kernel32.dll, so no runtime deps are needed.
    xpm = {
        linux = {
            source = "https://github.com/fullstorydev/grpcurl/releases/download/v${version}/grpcurl_${version}_linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.9.4" },
            ["1.9.4"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "97e13d58d2733a0e62cd2571d1d5f0c02823f0d25282f08bddedf1ad9c5d1736",
                    aarch64 = "ad66227d90631da5428b4a5ccf28d63846f0f15649d8b2367df044a59edbb617",
                },
            },
        },
        macosx = {
            source = "https://github.com/fullstorydev/grpcurl/releases/download/v${version}/grpcurl_${version}_osx_${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.9.4" },
            ["1.9.4"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "0c1b24a82097862027af6abe88f362db73e4846859a3ceda2dd466e4dc971a06",
                    aarch64 = "e0df111350acf8ee38f453f4e97e0474cfe1a987ee0c368ebe5383e6a4bccf25",
                },
            },
        },
        windows = {
            source = "https://github.com/fullstorydev/grpcurl/releases/download/v${version}/grpcurl_${version}_windows_${arch_alias}.zip",
            ["latest"] = { ref = "1.9.4" },
            ["1.9.4"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "412dbe98dc6f3fddfbdc15db061768495d3b4c6ee24de998c83c36f79857680d",
                    aarch64 = "f42f6646bc259989cc8e8b7ecb3b987456ea24dd103361bcabb61534f2c77189",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

local function is_windows_archive()
    local archive = tostring(pkginfo.install_file() or ""):gsub("\\", "/")
    return archive:match("%.zip$") ~= nil or archive:match("windows") ~= nil
end

function installed()
    return payload.present({ "grpcurl", "LICENSE" })
        or payload.present({ "grpcurl.exe", "LICENSE" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = is_windows_archive()
    local exe = is_win and "grpcurl.exe" or "grpcurl"

    os.tryrm(dir)

    if os.isfile(parent .. "/" .. exe) then
        fs.mkdir_p(dir)
        for _, f in ipairs({ exe, "LICENSE" }) do
            if os.isfile(parent .. "/" .. f) then
                os.mv(parent .. "/" .. f, dir .. "/" .. f)
            end
        end
    elseif normalized:match("%.zip$") then
        payload.unpack{}
    else
        error(string.format("grpcurl: extracted binary (%s) not found in %s", exe, parent))
    end

    if not is_win then
        system.exec(string.format('chmod +x "%s"', dir .. "/" .. exe))
    end

    payload.require({ exe, "LICENSE" })
    return true
end

function config()
    xvm.add("grpcurl", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("grpcurl")
    return true
end
