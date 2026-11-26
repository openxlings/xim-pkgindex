-- sops - Simple and flexible tool for managing secrets (getsops/sops).
--
-- Distribution: upstream publishes standalone raw single-file binaries on
-- GitHub Releases (no archive container). xlings skips auto-extract for
-- unarchived binaries and passes the downloaded file via pkginfo.install_file(),
-- which install() moves to `<install_dir>/sops` (or `sops.exe` on Windows).
--
-- Verified against getsops/sops release v3.13.3 (SHA-256 matched
-- sops-v3.13.3.checksums.txt, GitHub release digests, and downloaded bytes):
--   linux/x86_64    sops-v3.13.3.linux.amd64   (ELF64 static, readelf -d: no dynamic section, ldd: not dynamic)
--   linux/aarch64   sops-v3.13.3.linux.arm64   (ELF64 static, readelf -d: no dynamic section, ldd: not dynamic)
--   macosx/x86_64   sops-v3.13.3.darwin.amd64  (Mach-O 64-bit x86_64)
--   macosx/aarch64  sops-v3.13.3.darwin.arm64  (Mach-O 64-bit arm64)
--   windows/x86_64  sops-v3.13.3.amd64.exe     (PE32+ console, imports kernel32.dll only)
--   windows/aarch64 sops-v3.13.3.arm64.exe     (PE32+ console, imports kernel32.dll only)

package = {
    spec = "2",

    name = "sops",
    description = "Simple and flexible tool for managing secrets",
    homepage = "https://getsops.io",
    maintainers = {"https://github.com/getsops/sops/graphs/contributors"},
    licenses = {"MPL-2.0"},
    repo = "https://github.com/getsops/sops",
    docs = "https://getsops.io/docs/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"security", "encryption", "cli", "devops", "tools"},
    keywords = {"sops", "secrets", "encryption", "age", "kms", "pgp", "cli"},

    programs = {"sops"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/getsops/sops/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/getsops/sops/releases/download/${tag}/sops-v${version}.linux.amd64",
                            aarch64 = "https://github.com/getsops/sops/releases/download/${tag}/sops-v${version}.linux.arm64",
                        },
                        macosx = {
                            x86_64 = "https://github.com/getsops/sops/releases/download/${tag}/sops-v${version}.darwin.amd64",
                            aarch64 = "https://github.com/getsops/sops/releases/download/${tag}/sops-v${version}.darwin.arm64",
                        },
                        windows = {
                            x86_64 = "https://github.com/getsops/sops/releases/download/${tag}/sops-v${version}.${arch_alias}.exe",
                            aarch64 = "https://github.com/getsops/sops/releases/download/${tag}/sops-v${version}.${arch_alias}.exe",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/getsops/sops/releases/download/v${version}/sops-v${version}.linux.${arch_alias}",
            ["latest"] = { ref = "3.13.3" },
            ["3.13.3"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "e5bec3346a873ae91d871550f3e698c1aad962aff462a080e40f25fde17fef6b",
                    aarch64 = "53b0abacd38ef1b12a66d6c100956691b9cefce018d91f81e73ddf7438b94d77",
                },
            },
        },
        macosx = {
            source = "https://github.com/getsops/sops/releases/download/v${version}/sops-v${version}.darwin.${arch_alias}",
            ["latest"] = { ref = "3.13.3" },
            ["3.13.3"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "42162d5cef10b74fcf80a045a70e658d7ce6e63d6ea1be6f347e44015714468d",
                    aarch64 = "b97c0d434aab577dc40310e8d22ff9e45eef4c80638ab978daae9b4681c59286",
                },
            },
        },
        windows = {
            source = "https://github.com/getsops/sops/releases/download/v${version}/sops-v${version}.${arch_alias}.exe",
            ["latest"] = { ref = "3.13.3" },
            ["3.13.3"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "a4a9a398858fe8b2ef72d9686d930bf7c5cece9be74ad83ac3b53cfdd70e6b1c",
                    aarch64 = "7f936a0d08edbeba3eb8f50bad1fe71eba83a140a80dfd17051f3bdb4facb08a",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

local function _is_windows_payload(file)
    return tostring(file):lower():match("%.exe$") ~= nil
end

function installed()
    local dir = pkginfo.install_dir()
    return os.isfile(dir .. "/sops") or os.isfile(dir .. "/sops.exe")
end

function install()
    local src = pkginfo.install_file()
    local dir = pkginfo.install_dir()
    local is_win = _is_windows_payload(src)
    local target = dir .. (is_win and "/sops.exe" or "/sops")

    os.tryrm(dir)
    fs.mkdir_p(dir)
    os.mv(src, target)
    if not is_win then
        system.exec(string.format([[chmod +x "%s"]], target))
    end
    if not os.isfile(target) then
        error("sops: executable missing after install at " .. target)
    end
    return true
end

function config()
    xvm.add("sops", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("sops")
    return true
end
