-- step - Smallstep CLI, a zero trust swiss army knife for working with X.509,
-- OAuth, JWT, OATH OTP, SSH certificates, and more (smallstep/cli).
--
-- Verified 2026-11-26 against upstream smallstep/cli release v0.31.0:
--   * Every SHA256 below matched upstream checksums.txt, GitHub release asset
--     digests, and locally downloaded archives.
--   * All six archives unpack under a single `step_0.31.0/` directory
--     containing `bin/step` (or `bin/step.exe` on Windows), `LICENSE`,
--     `README.md`, and `autocomplete/`.
--   * linux/x86_64    step_linux_0.31.0_amd64.tar.gz    (ELF64 static, readelf -d: no dynamic section, ldd: not dynamic)
--   * linux/aarch64   step_linux_0.31.0_arm64.tar.gz    (ELF64 static, readelf -d: no dynamic section)
--   * macosx/x86_64   step_darwin_0.31.0_amd64.tar.gz   (Mach-O 64-bit x86_64)
--   * macosx/aarch64  step_darwin_0.31.0_arm64.tar.gz   (Mach-O 64-bit arm64)
--   * windows/x86_64  step_windows_0.31.0_amd64.zip     (PE32+ console x86-64, imports kernel32.dll only)
--   * windows/aarch64 step_windows_0.31.0_arm64.zip     (PE32+ console ARM64, imports kernel32.dll only)

package = {
    spec = "2",

    name = "step",
    description = "A zero trust swiss army knife for working with X509, OAuth, JWT, OATH OTP, etc.",
    homepage = "https://smallstep.com/cli",
    authors = {"Smallstep"},
    maintainers = {"https://github.com/smallstep/cli/graphs/contributors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/smallstep/cli",
    docs = "https://smallstep.com/docs/step-cli/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"security", "tls", "crypto", "cli", "tools"},
    keywords = {"step", "smallstep", "x509", "tls", "certificates", "jwt", "oauth", "ssh", "cli"},

    programs = {"step"},
    xvm_enable = true,

    -- Verified upstream release assets; no CN mirror has been verified.
    extensions = {
        autoupdate = {
            source = "https://github.com/smallstep/cli/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/smallstep/cli/releases/download/${tag}/step_linux_${version}_amd64.tar.gz",
                            aarch64 = "https://github.com/smallstep/cli/releases/download/${tag}/step_linux_${version}_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/smallstep/cli/releases/download/${tag}/step_darwin_${version}_amd64.tar.gz",
                            aarch64 = "https://github.com/smallstep/cli/releases/download/${tag}/step_darwin_${version}_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/smallstep/cli/releases/download/${tag}/step_windows_${version}_amd64.zip",
                            aarch64 = "https://github.com/smallstep/cli/releases/download/${tag}/step_windows_${version}_arm64.zip",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/smallstep/cli/releases/download/v${version}/step_linux_${version}_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.31.0" },
            ["0.31.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "a7e13726efa8782f3d5459174dacf602ab3514b9431f2d42a6a75950b7685e5f",
                    aarch64 = "9937964c7d47de47a511cd775bd07101b8ee9854db210abd402c69093f0a6fd4",
                },
            },
        },
        macosx = {
            source = "https://github.com/smallstep/cli/releases/download/v${version}/step_darwin_${version}_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.31.0" },
            ["0.31.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "4b928a936e9d2ff3bfa6f7638003a9e46c702a27cf515169c6e5996ade8cd23e",
                    aarch64 = "91963c7c1ef6654dda61ff2f99cff2b8e95efce198d8c7b3532a00a8f253bf41",
                },
            },
        },
        windows = {
            source = "https://github.com/smallstep/cli/releases/download/v${version}/step_windows_${version}_${arch_alias}.zip",
            ["latest"] = { ref = "0.31.0" },
            ["0.31.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "3b8dc1245fb1dffe3b57bf10cac9b3da9808ed42f7274f869085e1086214d0f4",
                    aarch64 = "f5be7139b78db9d051274c029cc3aefa7d87c16d4867a430eddfebdc8689d922",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

local function expected_files(ext)
    return {
        "bin/step" .. ext,
        "LICENSE",
    }
end

function installed()
    return payload.present(expected_files(""))
        or payload.present(expected_files(".exe"))
end

function install()
    local archive = tostring(pkginfo.install_file())
    local is_win = archive:gsub("\\", "/"):match("%.zip$") ~= nil

    payload.unpack{
        extracted = "step_" .. pkginfo.version(),
        strip = 1,
    }
    payload.require(expected_files(is_win and ".exe" or ""))
    return true
end

function config()
    xvm.add("step", { bindir = pkginfo.install_dir() .. "/bin" })
    return true
end

function uninstall()
    xvm.remove("step")
    return true
end
