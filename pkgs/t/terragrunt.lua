-- Terragrunt - Flexible orchestration for infrastructure as code (OpenTofu / Terraform).
--
-- Verified 2026-11-26 against upstream GitHub release v1.2.3 (gruntwork-io/terragrunt):
--   linux    x86_64, aarch64   terragrunt_linux_{amd64,arm64}.tar.gz
--   macosx   x86_64, aarch64   terragrunt_darwin_{amd64,arm64}.tar.gz
--   windows  x86_64            terragrunt_windows_amd64.exe.zip (no windows_arm64 asset upstream)
--
-- Every archive contains a single arch-suffixed executable (`terragrunt_<os>_<arch>[.exe]`),
-- which `install()` normalizes to `terragrunt` (or `terragrunt.exe` on Windows).
-- All five SHA-256 digests match upstream `SHA256SUMS` and locally downloaded archives.
--
-- Both Linux ELF binaries are statically linked Go executables (`readelf -d`:
-- no dynamic section; `ldd`: not a dynamic executable), so no runtime library
-- deps are required. The Windows PE32+ executable imports only `kernel32.dll`.

package = {
    spec = "2",

    name = "terragrunt",
    description = "Flexible orchestration for infrastructure as code (OpenTofu / Terraform)",
    homepage = "https://terragrunt.gruntwork.io",
    authors = {"Gruntwork"},
    maintainers = {"https://github.com/gruntwork-io/terragrunt/graphs/contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/gruntwork-io/terragrunt",
    docs = "https://terragrunt.gruntwork.io/docs/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"devops", "iac", "cloud", "cli", "tools"},
    keywords = {"terragrunt", "terraform", "opentofu", "iac", "infrastructure", "devops"},

    programs = {"terragrunt"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/gruntwork-io/terragrunt/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/gruntwork-io/terragrunt/releases/download/${tag}/terragrunt_linux_amd64.tar.gz",
                            aarch64 = "https://github.com/gruntwork-io/terragrunt/releases/download/${tag}/terragrunt_linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/gruntwork-io/terragrunt/releases/download/${tag}/terragrunt_darwin_amd64.tar.gz",
                            aarch64 = "https://github.com/gruntwork-io/terragrunt/releases/download/${tag}/terragrunt_darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/gruntwork-io/terragrunt/releases/download/${tag}/terragrunt_windows_amd64.exe.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/gruntwork-io/terragrunt/releases/download/v${version}/terragrunt_linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.2.3" },
            ["1.2.3"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "f975736bb03ad3b0242df920a213656510e6294e507782453da01045c00bef41",
                    aarch64 = "9080e4c36871f6222034179bdc6d6b22cd26b964dbfd9bccc47e10221bdcde8d",
                },
            },
        },
        macosx = {
            source = "https://github.com/gruntwork-io/terragrunt/releases/download/v${version}/terragrunt_darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.2.3" },
            ["1.2.3"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "e6d6770d33ece6cc3681e237d4ff3f6a92e5de35179679ac30cc80cb8fd7e339",
                    aarch64 = "1bf085e1f02497dbbd0a84b53f9e9da4e2f5674a79620455abfd2d93bd33d90c",
                },
            },
        },
        windows = {
            source = "https://github.com/gruntwork-io/terragrunt/releases/download/v${version}/terragrunt_windows_${arch_alias}.exe.zip",
            ["latest"] = { ref = "1.2.3" },
            ["1.2.3"] = {
                arch_alias = { x86_64 = "amd64" },
                sha256 = {
                    x86_64 = "8f753e3bc94d4938aa2bd587b3ff14e18ecab7c6e75a64b10c0b03f5f0dc5e24",
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

local function _normalize_binary(dir, exe, is_win)
    if os.isfile(dir .. "/" .. exe) then
        return true
    end
    local candidates = is_win
        and { "terragrunt_windows_amd64.exe" }
        or {
            "terragrunt_linux_amd64",
            "terragrunt_linux_arm64",
            "terragrunt_darwin_amd64",
            "terragrunt_darwin_arm64",
        }
    for _, name in ipairs(candidates) do
        local p = dir .. "/" .. name
        if os.isfile(p) then
            os.mv(p, dir .. "/" .. exe)
            return true
        end
    end
    return false
end

function installed()
    return payload.present({ "terragrunt" })
        or payload.present({ "terragrunt.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("terragrunt: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local is_win = normalized:match("%.zip$") ~= nil
        or normalized:match("_windows_") ~= nil
        or os.getenv("OS") == "Windows_NT"
    local exe = is_win and "terragrunt.exe" or "terragrunt"

    os.tryrm(dir)
    fs.mkdir_p(dir)

    if is_win then
        payload.unpack{}
    else
        system.exec(string.format('tar -xzf "%s" -C "%s"', normalized, dir))
    end

    if not _normalize_binary(dir, exe, is_win) then
        error("terragrunt: extracted binary not found in " .. dir)
    end

    if not is_win and os.isfile(dir .. "/" .. exe) then
        system.exec(string.format('chmod +x "%s"', dir .. "/" .. exe))
    end

    payload.require({ exe })
    return true
end

function config()
    xvm.add("terragrunt", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("terragrunt")
    return true
end
