-- Traefik - modern HTTP reverse proxy and load balancer (traefik/traefik).
--
-- Platform and architecture coverage (verified 2026-11-26 against v3.8.0):
--   linux    x86_64, aarch64   traefik_v<ver>_linux_<arch>.tar.gz   (static Go ELF, no .dynamic section)
--   macosx   x86_64, aarch64   traefik_v<ver>_darwin_<arch>.tar.gz
--   windows  x86_64, aarch64   traefik_v<ver>_windows_<arch>.zip   (PE32+ CUI, imports kernel32.dll only)
--
-- Every upstream archive is flat at root (`traefik` / `traefik.exe`, `CHANGELOG.md`, `LICENSE.md`),
-- verified against upstream `traefik_v3.8.0_checksums.txt` (SHA-256) and hashed locally.
-- `install()` extracts directly from `pkginfo.install_file()` into a clean `install_dir()`
-- so shared `runtimedir` contents from other flat archives cannot leak into traefik's payload.

package = {
    spec = "2",

    name = "traefik",
    description = "The Cloud Native Application Proxy",
    homepage = "https://traefik.io",
    authors = {"Traefik Labs"},
    maintainers = {"https://github.com/traefik/traefik/graphs/contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/traefik/traefik",
    docs = "https://doc.traefik.io/traefik/",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"web", "proxy", "server", "http", "cloud"},
    keywords = {"traefik", "reverse-proxy", "load-balancer", "http", "tls", "ingress", "proxy"},

    programs = {"traefik"},
    xvm_enable = true,
    ci = { mirror = true },

    extensions = {
        autoupdate = {
            source = "https://github.com/traefik/traefik/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/traefik/traefik/releases/download/${tag}/traefik_v${version}_linux_amd64.tar.gz",
                            aarch64 = "https://github.com/traefik/traefik/releases/download/${tag}/traefik_v${version}_linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/traefik/traefik/releases/download/${tag}/traefik_v${version}_darwin_amd64.tar.gz",
                            aarch64 = "https://github.com/traefik/traefik/releases/download/${tag}/traefik_v${version}_darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/traefik/traefik/releases/download/${tag}/traefik_v${version}_windows_amd64.zip",
                            aarch64 = "https://github.com/traefik/traefik/releases/download/${tag}/traefik_v${version}_windows_arm64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    -- Upstream builds with CGO_ENABLED=0; Linux binaries are static Go ELF executables
    -- with zero external shared-library dependencies.
    xpm = {
        linux = {
            source = "https://github.com/traefik/traefik/releases/download/v${version}/traefik_v${version}_linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "3.8.0" },
            ["3.8.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "266f4b02a3c9d16880c6d913053c6358df8163e296b6f0899ed4544d0a742bd6",
                    aarch64 = "3c85f6f40ef10eddcdcce6f5416b2ba9a818ddcd900b1f9e4955b7bbb744a9fc",
                },
            },
        },
        macosx = {
            source = "https://github.com/traefik/traefik/releases/download/v${version}/traefik_v${version}_darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "3.8.0" },
            ["3.8.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "2d29524cf056c9f280a42598c4295ed689d4973f26b9b6895e6dc60617ba13c8",
                    aarch64 = "503742119bf499a8a7964b9f178bab3d6c5d5526ca7251b59fd469290b1c2744",
                },
            },
        },
        windows = {
            source = "https://github.com/traefik/traefik/releases/download/v${version}/traefik_v${version}_windows_${arch_alias}.zip",
            ["latest"] = { ref = "3.8.0" },
            ["3.8.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "bcbd077402cf4a1fbc638c594252a8881e6839fc37e11240d691d61c458025af",
                    aarch64 = "778375847ae9df5e6f876ae0f4c314f40a77b8cf795f006e806483e4c3781415",
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
    "CHANGELOG.md",
    "LICENSE.md",
}

local function required_files(exe)
    local files = { exe }
    for _, rel in ipairs(COMMON_FILES) do
        files[#files + 1] = rel
    end
    return files
end

function installed()
    return payload.present(required_files("traefik"))
        or payload.present(required_files("traefik.exe"))
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("traefik: install_file is empty")
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
            error("traefik: archive not found: " .. archive)
        end
        system.exec(string.format([[tar -xzf "%s" -C "%s"]], normalized, dir))
        if os.isfile(dir .. "/traefik") then
            system.exec(string.format([[chmod +x "%s"]], dir .. "/traefik"))
        end
    end

    payload.require(required_files(is_win and "traefik.exe" or "traefik"))
    return true
end

function config()
    xvm.add("traefik", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("traefik")
    return true
end
