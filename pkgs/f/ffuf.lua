-- ffuf - Fast web fuzzer written in Go (ffuf/ffuf).
--
-- Verified 2026-11-26 against upstream GitHub release v2.3.0 and
-- `ffuf_2.3.0_checksums.txt`: every SHA-256 below matched the upstream
-- checksums file, GitHub release asset digests, and downloaded archive bytes:
--   linux/x86_64    ffuf_2.3.0_linux_amd64.tar.gz    (static Go ELF, no .dynamic section)
--   linux/aarch64   ffuf_2.3.0_linux_arm64.tar.gz    (static Go ELF, no .dynamic section)
--   macosx/x86_64   ffuf_2.3.0_macOS_amd64.tar.gz
--   macosx/aarch64  ffuf_2.3.0_macOS_arm64.tar.gz
--   windows/x86_64  ffuf_2.3.0_windows_amd64.zip     (PE32+ x86-64 CUI, imports kernel32.dll only)
--   windows/aarch64 ffuf_2.3.0_windows_arm64.zip     (PE32+ ARM64 CUI, imports kernel32.dll only)
--
-- Upstream also publishes 32-bit x86, ARMv6, FreeBSD, and OpenBSD builds, which
-- are outside `archs`. All six supported archives are flat at root (`ffuf` /
-- `ffuf.exe`, `CHANGELOG.md`, `LICENSE`, `README.md` with no wrapper directory).
-- `install()` extracts directly from `pkginfo.install_file()` into a clean
-- `pkginfo.install_dir()` so shared `runtimedir` contents from other flat
-- archives cannot leak into ffuf's payload.

package = {
    spec = "2",

    name = "ffuf",
    description = "Fast web fuzzer written in Go",
    homepage = "https://github.com/ffuf/ffuf",
    authors = {"Joona Hoikkala"},
    maintainers = {"https://github.com/ffuf/ffuf/graphs/contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/ffuf/ffuf",
    docs = "https://github.com/ffuf/ffuf#readme",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"http", "security", "cli", "tools"},
    keywords = {"ffuf", "fuzz", "fuzzer", "http", "web", "security", "cli", "go"},

    programs = {"ffuf"},
    xvm_enable = true,

    -- Verified upstream release assets; no CN mirror has been verified.
    extensions = {
        autoupdate = {
            source = "https://github.com/ffuf/ffuf/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/ffuf/ffuf/releases/download/${tag}/ffuf_${version}_linux_amd64.tar.gz",
                            aarch64 = "https://github.com/ffuf/ffuf/releases/download/${tag}/ffuf_${version}_linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/ffuf/ffuf/releases/download/${tag}/ffuf_${version}_macOS_amd64.tar.gz",
                            aarch64 = "https://github.com/ffuf/ffuf/releases/download/${tag}/ffuf_${version}_macOS_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/ffuf/ffuf/releases/download/${tag}/ffuf_${version}_windows_amd64.zip",
                            aarch64 = "https://github.com/ffuf/ffuf/releases/download/${tag}/ffuf_${version}_windows_arm64.zip",
                        },
                    },
                },
            },
        },
    },

    -- Upstream builds static Go binaries; Linux ELFs have no dynamic section and
    -- Windows PE executables import only kernel32.dll, so no runtime deps are needed.
    xpm = {
        linux = {
            source = "https://github.com/ffuf/ffuf/releases/download/v${version}/ffuf_${version}_linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "2.3.0" },
            ["2.3.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "b2a3c725fcb9da175159682f54d6e9149f2905b00d84d155e7efc5d599975ceb",
                    aarch64 = "e2d712615d53da797ee929006e41f2df5a7960a5353133db9c150ddaa22ae4e8",
                },
            },
        },
        macosx = {
            source = "https://github.com/ffuf/ffuf/releases/download/v${version}/ffuf_${version}_macOS_${arch_alias}.tar.gz",
            ["latest"] = { ref = "2.3.0" },
            ["2.3.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "c1d1a0320b299d2c7f3a62163b336fe861954ea865bab13b9e80f128eb985997",
                    aarch64 = "891e6358f7c72c951ce6fcef82a3736e91b34034e95edbd305505c9d31cfff13",
                },
            },
        },
        windows = {
            source = "https://github.com/ffuf/ffuf/releases/download/v${version}/ffuf_${version}_windows_${arch_alias}.zip",
            ["latest"] = { ref = "2.3.0" },
            ["2.3.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "091c8a22d0c7fbe07d343b3ae2c213dbd37b38a8a2ed40631fcd3128ea1764fb",
                    aarch64 = "8b119b5ba25c8ac0a8c029fbf62f9e92ed3ec80d4ecb8275703892c8574ce15c",
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

local function required_files(exe)
    return { exe, "CHANGELOG.md", "LICENSE", "README.md" }
end

function installed()
    return payload.present(required_files("ffuf"))
        or payload.present(required_files("ffuf.exe"))
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("ffuf: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local is_win = normalized:match("%.zip$") ~= nil

    os.tryrm(dir)
    fs.mkdir_p(dir)

    if is_win then
        payload.unpack{}
    else
        if not os.isfile(archive) then
            error("ffuf: archive not found: " .. archive)
        end
        system.exec(string.format([[tar -xzf "%s" -C "%s"]], normalized, dir))
        if os.isfile(dir .. "/ffuf") then
            system.exec(string.format([[chmod +x "%s"]], dir .. "/ffuf"))
        end
    end

    payload.require(required_files(is_win and "ffuf.exe" or "ffuf"))
    return true
end

function config()
    xvm.add("ffuf", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("ffuf")
    return true
end
