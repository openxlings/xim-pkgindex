-- Syft - CLI tool and library for generating an SBOM from container images and filesystems (anchore/syft).
--
-- Verified 2026-11-26 against upstream GitHub release v1.57.2 and
-- `syft_1.57.2_checksums.txt`: every SHA256 below matched both the upstream
-- checksums file and the downloaded release archive bytes:
--   linux/x86_64    syft_1.57.2_linux_amd64.tar.gz    (static Go ELF, no .dynamic section)
--   linux/aarch64   syft_1.57.2_linux_arm64.tar.gz    (static Go ELF, no .dynamic section)
--   macosx/x86_64   syft_1.57.2_darwin_amd64.tar.gz
--   macosx/aarch64  syft_1.57.2_darwin_arm64.tar.gz
--   windows/x86_64  syft_1.57.2_windows_amd64.zip     (PE32+ x86-64, imports kernel32.dll only)
--   windows/aarch64 syft_1.57.2_windows_arm64.zip     (PE32+ ARM64, imports kernel32.dll only)
--
-- All six archives are flat at root (`syft`/`syft.exe`, `CHANGELOG.md`,
-- `LICENSE`, `README.md` with no top-level wrapper directory).
-- `install()` extracts directly from `pkginfo.install_file()` into a clean
-- `install_dir()` so shared `runtimedir` contents from other flat archives
-- cannot leak into syft's payload.

package = {
    spec = "2",

    name = "syft",
    description = "CLI tool and library for generating a Software Bill of Materials (SBOM) from container images and filesystems",
    homepage = "https://github.com/anchore/syft",
    authors = {"Anchore"},
    maintainers = {"https://github.com/anchore/syft/graphs/contributors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/anchore/syft",
    docs = "https://github.com/anchore/syft#readme",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"security", "sbom", "containers", "devops", "cli"},
    keywords = {"syft", "sbom", "security", "containers", "spdx", "cyclonedx", "anchore"},

    programs = {"syft"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/anchore/syft/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/anchore/syft/releases/download/${tag}/syft_${version}_linux_amd64.tar.gz",
                            aarch64 = "https://github.com/anchore/syft/releases/download/${tag}/syft_${version}_linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/anchore/syft/releases/download/${tag}/syft_${version}_darwin_amd64.tar.gz",
                            aarch64 = "https://github.com/anchore/syft/releases/download/${tag}/syft_${version}_darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/anchore/syft/releases/download/${tag}/syft_${version}_windows_amd64.zip",
                            aarch64 = "https://github.com/anchore/syft/releases/download/${tag}/syft_${version}_windows_arm64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/anchore/syft/releases/download/v${version}/syft_${version}_linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.57.2" },
            ["1.57.2"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "ad92bd3ec1b94a3df01d4d0aec199afa9c42b72e86da436ff5f837914d32706b",
                    aarch64 = "8efe605309c98798e1ee0cffdcf8c05ca26819b4cd44c0b03650f1e963e9bdb6",
                },
            },
        },
        macosx = {
            source = "https://github.com/anchore/syft/releases/download/v${version}/syft_${version}_darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.57.2" },
            ["1.57.2"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "73c6100bc43fbcc1c99aed3428d859c6289c4076be7e296dde7e427324c15908",
                    aarch64 = "38afbcc03a9d9afac2d7572432fd2c435e051e03930582ea90f4710ffb515224",
                },
            },
        },
        windows = {
            source = "https://github.com/anchore/syft/releases/download/v${version}/syft_${version}_windows_${arch_alias}.zip",
            ["latest"] = { ref = "1.57.2" },
            ["1.57.2"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "0a10e03ffd124c304fd7e7491262dba2e5f68eb12378b106d7525146675b2e3a",
                    aarch64 = "7f3cace29c2a7d2478de834aaa42663b8dbf82c9e8abc6a0917b437584ea54e1",
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
    return payload.present(required_files("syft"))
        or payload.present(required_files("syft.exe"))
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("syft: install_file is empty")
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
            error("syft: archive not found: " .. archive)
        end
        system.exec(string.format([[tar -xzf "%s" -C "%s"]], normalized, dir))
        if os.isfile(dir .. "/syft") then
            system.exec(string.format([[chmod +x "%s"]], dir .. "/syft"))
        end
    end

    payload.require(required_files(is_win and "syft.exe" or "syft"))
    return true
end

function config()
    xvm.add("syft", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("syft")
    return true
end
