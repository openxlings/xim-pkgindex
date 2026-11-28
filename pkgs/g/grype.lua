-- Grype - vulnerability scanner for container images, filesystems, and SBOMs (anchore/grype).
--
-- Verified 2026-11-26 against upstream GitHub release v0.122.1 and
-- `grype_0.122.1_checksums.txt`: every SHA256 below matched both the upstream
-- checksums file and the downloaded release archive bytes:
--   linux/x86_64   grype_0.122.1_linux_amd64.tar.gz   (static Go ELF, no .dynamic section)
--   linux/aarch64  grype_0.122.1_linux_arm64.tar.gz   (static Go ELF, no .dynamic section)
--   macosx/x86_64  grype_0.122.1_darwin_amd64.tar.gz
--   macosx/aarch64 grype_0.122.1_darwin_arm64.tar.gz
--   windows/x86_64 grype_0.122.1_windows_amd64.zip    (PE32+ x86-64, imports kernel32.dll only)
--
-- Note: upstream does not publish a windows/aarch64 binary for v0.122.1, so
-- `xpm.windows` covers `x86_64` only.
--
-- All five archives are flat at root (`grype`/`grype.exe`, `CHANGELOG.md`,
-- `LICENSE`, `README.md` with no top-level wrapper directory).
-- `install()` extracts directly from `pkginfo.install_file()` into a clean
-- `install_dir()` so shared `runtimedir` contents from other flat archives
-- cannot leak into grype's payload.

package = {
    spec = "2",

    name = "grype",
    description = "A vulnerability scanner for container images and filesystems",
    homepage = "https://github.com/anchore/grype",
    authors = {"Anchore"},
    maintainers = {"https://github.com/anchore/grype/graphs/contributors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/anchore/grype",
    docs = "https://github.com/anchore/grype#readme",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"security", "scanner", "containers", "sbom", "cli"},
    keywords = {"grype", "vulnerability", "scanner", "sbom", "cve", "containers", "security"},

    programs = {"grype"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/anchore/grype/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/anchore/grype/releases/download/${tag}/grype_${version}_linux_amd64.tar.gz",
                            aarch64 = "https://github.com/anchore/grype/releases/download/${tag}/grype_${version}_linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/anchore/grype/releases/download/${tag}/grype_${version}_darwin_amd64.tar.gz",
                            aarch64 = "https://github.com/anchore/grype/releases/download/${tag}/grype_${version}_darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/anchore/grype/releases/download/${tag}/grype_${version}_windows_amd64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/anchore/grype/releases/download/v${version}/grype_${version}_linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.122.1" },
            ["0.122.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "f1ba7e2917ee1395618de20a98da0aa7c0fb1788927797651047c50502a37538",
                    aarch64 = "819e5be3d9516432fedb7b6b56df7306c3a16607606dfc05826eefbb00e471da",
                },
            },
        },
        macosx = {
            source = "https://github.com/anchore/grype/releases/download/v${version}/grype_${version}_darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.122.1" },
            ["0.122.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "8063aef11b52e6da342068aa6980e92f40b28849eff990c8375a0a8e6b6dfbc5",
                    aarch64 = "8bbb3c01695d1e954875cf9f7403c5d3cdb652caf763867955fad520e3cd6c00",
                },
            },
        },
        windows = {
            source = "https://github.com/anchore/grype/releases/download/v${version}/grype_${version}_windows_${arch_alias}.zip",
            ["latest"] = { ref = "0.122.1" },
            ["0.122.1"] = {
                arch_alias = { x86_64 = "amd64" },
                sha256 = {
                    x86_64 = "24e19d6378782d2da343b80c632e342bcdd3bd1bf44e415a0ff81cf85ce1043a",
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
    return payload.present(required_files("grype"))
        or payload.present(required_files("grype.exe"))
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("grype: install_file is empty")
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
            error("grype: archive not found: " .. archive)
        end
        system.exec(string.format([[tar -xzf "%s" -C "%s"]], normalized, dir))
        if os.isfile(dir .. "/grype") then
            system.exec(string.format([[chmod +x "%s"]], dir .. "/grype"))
        end
    end

    payload.require(required_files(is_win and "grype.exe" or "grype"))
    return true
end

function config()
    xvm.add("grype", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("grype")
    return true
end
