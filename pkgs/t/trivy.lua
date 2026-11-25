-- Trivy - comprehensive and versatile security scanner (aquasecurity/trivy).
--
-- Verified 2026-11-25 against upstream GitHub release v0.76.2 and
-- `trivy_0.76.2_checksums.txt`: every SHA256 below matched both the upstream
-- checksums file and the downloaded release archive bytes:
--   linux/x86_64   trivy_0.76.2_Linux-64bit.tar.gz   (static Go ELF, no .dynamic section)
--   linux/aarch64  trivy_0.76.2_Linux-ARM64.tar.gz   (static Go ELF, no .dynamic section)
--   macosx/x86_64  trivy_0.76.2_macOS-64bit.tar.gz
--   macosx/aarch64 trivy_0.76.2_macOS-ARM64.tar.gz
--   windows/x86_64 trivy_0.76.2_windows-64bit.zip    (PE32+ x86-64, imports kernel32.dll only)
--
-- Note: upstream does not publish a windows/aarch64 binary for v0.76.2, so
-- `xpm.windows` covers `x86_64` only.
--
-- All five archives are flat at root (`trivy`/`trivy.exe`, `LICENSE`,
-- `README.md`, `contrib/*.tpl` with no top-level wrapper directory).
-- `install()` extracts directly from `pkginfo.install_file()` into a clean
-- `install_dir()` so shared `runtimedir` contents from other flat archives
-- cannot leak into trivy's payload.

package = {
    spec = "2",

    name = "trivy",
    description = "Find vulnerabilities, misconfigurations, secrets, SBOM in containers, Kubernetes, code repositories, clouds and more",
    homepage = "https://trivy.dev",
    authors = {"Aqua Security"},
    maintainers = {"https://github.com/aquasecurity/trivy/graphs/contributors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/aquasecurity/trivy",
    docs = "https://trivy.dev/docs/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"security", "scanner", "containers", "devops", "cli"},
    keywords = {"trivy", "security", "vulnerability", "sbom", "misconfiguration", "container", "iac"},

    programs = {"trivy"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/aquasecurity/trivy/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/aquasecurity/trivy/releases/download/${tag}/trivy_${version}_Linux-64bit.tar.gz",
                            aarch64 = "https://github.com/aquasecurity/trivy/releases/download/${tag}/trivy_${version}_Linux-ARM64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/aquasecurity/trivy/releases/download/${tag}/trivy_${version}_macOS-64bit.tar.gz",
                            aarch64 = "https://github.com/aquasecurity/trivy/releases/download/${tag}/trivy_${version}_macOS-ARM64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/aquasecurity/trivy/releases/download/${tag}/trivy_${version}_windows-64bit.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/aquasecurity/trivy/releases/download/v${version}/trivy_${version}_Linux-${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.76.2" },
            ["0.76.2"] = {
                arch_alias = { x86_64 = "64bit", aarch64 = "ARM64" },
                sha256 = {
                    x86_64 = "bc0fc726e017b8927a62b2d3531d7a84ee01769daf5c99ed866dced54089fdbf",
                    aarch64 = "ab9d51f86e6a5fb936f605faff6b593ac51bc378fff4d3e8b9d58358b9c367c3",
                },
            },
        },
        macosx = {
            source = "https://github.com/aquasecurity/trivy/releases/download/v${version}/trivy_${version}_macOS-${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.76.2" },
            ["0.76.2"] = {
                arch_alias = { x86_64 = "64bit", aarch64 = "ARM64" },
                sha256 = {
                    x86_64 = "e08bb9ea449ecf66c6bfb03cbb8697c503ff33d35fc585c9747e3eaeb7ed4c7b",
                    aarch64 = "ae7ea358326960406b703c77b2ac490190797d80b306b5b50c2a27221da0a5b8",
                },
            },
        },
        windows = {
            source = "https://github.com/aquasecurity/trivy/releases/download/v${version}/trivy_${version}_windows-${arch_alias}.zip",
            ["latest"] = { ref = "0.76.2" },
            ["0.76.2"] = {
                arch_alias = { x86_64 = "64bit" },
                sha256 = {
                    x86_64 = "691f737a7e5566a673c3a74dab9160552ec32101e953b659e5c77443d16dddb6",
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

local COMMON_FILES = {
    "LICENSE",
    "README.md",
    "contrib/asff.tpl",
    "contrib/gitlab-codequality.tpl",
    "contrib/gitlab.tpl",
    "contrib/html.tpl",
    "contrib/junit.tpl",
}

local function required_files(exe)
    local files = { exe }
    for _, rel in ipairs(COMMON_FILES) do
        files[#files + 1] = rel
    end
    return files
end

function installed()
    return payload.present(required_files("trivy"))
        or payload.present(required_files("trivy.exe"))
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("trivy: install_file is empty")
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
            error("trivy: archive not found: " .. archive)
        end
        system.exec(string.format([[tar -xzf "%s" -C "%s"]], normalized, dir))
        if os.isfile(dir .. "/trivy") then
            system.exec(string.format([[chmod +x "%s"]], dir .. "/trivy"))
        end
    end

    payload.require(required_files(is_win and "trivy.exe" or "trivy"))
    return true
end

function config()
    xvm.add("trivy", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("trivy")
    return true
end
