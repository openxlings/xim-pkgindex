-- age - Simple, modern and secure file encryption tool.
--
-- Verified 2026-11-26 against upstream FiloSottile/age release v1.3.2.
-- Every SHA256 below matches both GitHub release asset digests and locally
-- downloaded archives:
--   * linux   x86_64, aarch64   `.tar.gz` (`age/` top-level directory); all
--                               seven binaries (`age`, `age-keygen`,
--                               `age-inspect`, `age-plugin-batchpass`,
--                               `age-plugin-pq`, `age-plugin-tag`,
--                               `age-plugin-tagpq`) are statically linked Go
--                               ELFs with no dynamic section or external libc
--                               dependency (`readelf -d`, `ldd`).
--   * macosx  x86_64, aarch64   `.tar.gz` (`age/` top-level directory).
--   * windows x86_64, aarch64   `.zip` (`age/` top-level directory); all
--                               seven PE32+ executables import only
--                               `kernel32.dll` (no VCRUNTIME DLL dependency).

package = {
    spec = "2",

    name = "age",
    description = "A simple, modern and secure encryption tool with small explicit keys, no config options, and UNIX-style composability",
    homepage = "https://age-encryption.org",
    authors = {"Filippo Valsorda", "age Authors"},
    maintainers = {"FiloSottile"},
    licenses = {"BSD-3-Clause"},
    repo = "https://github.com/FiloSottile/age",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"security", "crypto", "cli", "tools"},
    keywords = {"age", "age-keygen", "age-inspect", "encryption", "cryptography", "cli"},

    programs = {
        "age",
        "age-keygen",
        "age-inspect",
        "age-plugin-batchpass",
        "age-plugin-pq",
        "age-plugin-tag",
        "age-plugin-tagpq",
    },
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/FiloSottile/age/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/FiloSottile/age/releases/download/${tag}/age-v${version}-linux-amd64.tar.gz",
                            aarch64 = "https://github.com/FiloSottile/age/releases/download/${tag}/age-v${version}-linux-arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/FiloSottile/age/releases/download/${tag}/age-v${version}-darwin-amd64.tar.gz",
                            aarch64 = "https://github.com/FiloSottile/age/releases/download/${tag}/age-v${version}-darwin-arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/FiloSottile/age/releases/download/${tag}/age-v${version}-windows-amd64.zip",
                            aarch64 = "https://github.com/FiloSottile/age/releases/download/${tag}/age-v${version}-windows-arm64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/FiloSottile/age/releases/download/v${version}/age-v${version}-linux-${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.3.2" },
            ["1.3.2"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "cbe24006683f8eb669266162894b9a522a1af52f2665fbc63a4bb032ed26ac10",
                    aarch64 = "6b8dc4333c53a5a57c9e5834e3a48f92605d7154014cd07269ff3327db5d37f4",
                },
            },
        },
        macosx = {
            source = "https://github.com/FiloSottile/age/releases/download/v${version}/age-v${version}-darwin-${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.3.2" },
            ["1.3.2"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "1d1e4bc66e1427edad7739ae7616157de0e79db8b6d2a1497d7d9925fb06a539",
                    aarch64 = "e2020b073c44f692685a24d6abc378817eb81ffaaf49fd0531ef8565f767f2f5",
                },
            },
        },
        windows = {
            source = "https://github.com/FiloSottile/age/releases/download/v${version}/age-v${version}-windows-${arch_alias}.zip",
            ["latest"] = { ref = "1.3.2" },
            ["1.3.2"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "f48d8f8f9ebe903ab5027ed067652f2cc1db94bc206976430133b905dcd8e8c7",
                    aarch64 = "fae351336c8d5f30f93cc3ccdec16d1ed7851d68cdd6656d41955cc31a447c9d",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

local SIBLINGS = {
    "age-keygen",
    "age-inspect",
    "age-plugin-batchpass",
    "age-plugin-pq",
    "age-plugin-tag",
    "age-plugin-tagpq",
}

local function expected_files(ext)
    local list = { "age" .. ext }
    for _, name in ipairs(SIBLINGS) do
        list[#list + 1] = name .. ext
    end
    list[#list + 1] = "LICENSE"
    return list
end

function installed()
    return payload.present(expected_files(""))
        or payload.present(expected_files(".exe"))
end

function install()
    local archive = tostring(pkginfo.install_file())
    local normalized = archive:gsub("\\", "/")
    local is_win = normalized:match("%-windows%-") ~= nil or os.getenv("OS") == "Windows_NT"

    payload.unpack{
        extracted = "age",
        strip = 1,
    }

    payload.require(expected_files(is_win and ".exe" or ""))
    return true
end

function config()
    local bindir = pkginfo.install_dir()
    local binding = "age@" .. pkginfo.version()
    xvm.add("age", { bindir = bindir })
    for _, name in ipairs(SIBLINGS) do
        xvm.add(name, { bindir = bindir, binding = binding })
    end
    return true
end

function uninstall()
    for i = #SIBLINGS, 1, -1 do
        xvm.remove(SIBLINGS[i])
    end
    xvm.remove("age")
    return true
end
