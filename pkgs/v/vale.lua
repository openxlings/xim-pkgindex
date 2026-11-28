-- vale - A markup-aware linter for prose built with speed and extensibility in mind.
--
-- Platform and architecture coverage (verified against vale-cli/vale v3.28.1;
-- note errata-ai/vale redirects to vale-cli/vale):
--   linux    x86_64, aarch64   vale_<ver>_Linux_<64-bit|arm64>.tar.gz   (static Go ELF, no .dynamic section)
--   macosx   x86_64, aarch64   vale_<ver>_macOS_<64-bit|arm64>.tar.gz   (official Mach-O binary)
--   windows  x86_64, aarch64   vale_<ver>_Windows_<64-bit|arm64>.zip    (official PE32+ binary, imports kernel32.dll only)
--
-- Upstream also publishes vale_<ver>_wasm.tar.gz, which is outside xlings' archs matrix.
-- All upstream archives are flat at root (`vale` / `vale.exe`, `LICENSE`, `README.md`)
-- with no top-level wrapper directory. Every SHA256 below was verified against both
-- upstream `vale_3.28.1_checksums.txt` and downloaded release archives.

package = {
    spec = "2",

    name = "vale",
    description = "A markup-aware linter for prose built with speed and extensibility in mind",
    homepage = "https://vale.sh",
    authors = {"Joseph Kato"},
    maintainers = {"vale-cli"},
    licenses = {"MIT"},
    repo = "https://github.com/vale-cli/vale",
    docs = "https://docs.vale.sh",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"linter", "prose", "markdown", "docs", "cli", "tools"},
    keywords = {"vale", "linter", "prose", "markdown", "asciidoc", "rst", "style", "go"},

    programs = {"vale"},
    xvm_enable = true,
    ci = { mirror = true },

    extensions = {
        autoupdate = {
            source = "https://github.com/vale-cli/vale/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/vale-cli/vale/releases/download/${tag}/vale_${version}_Linux_64-bit.tar.gz",
                            aarch64 = "https://github.com/vale-cli/vale/releases/download/${tag}/vale_${version}_Linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/vale-cli/vale/releases/download/${tag}/vale_${version}_macOS_64-bit.tar.gz",
                            aarch64 = "https://github.com/vale-cli/vale/releases/download/${tag}/vale_${version}_macOS_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/vale-cli/vale/releases/download/${tag}/vale_${version}_Windows_64-bit.zip",
                            aarch64 = "https://github.com/vale-cli/vale/releases/download/${tag}/vale_${version}_Windows_arm64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/vale-cli/vale/releases/download/v${version}/vale_${version}_Linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "3.29.0" },
            ["3.28.1"] = {
                arch_alias = { x86_64 = "64-bit", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "068954ad869ebec24b8dec6ebcd1cbb1fd5f5a83e966a35baedfae8b2cdc093a",
                    aarch64 = "af0ca36ec6133ba20093295591e43ed2823b2632520d1f3811293aa4cbe758f2",
                },
            },
            ["3.29.0"] = {
                x86_64 = {
                    url = "https://github.com/vale-cli/vale/releases/download/v3.29.0/vale_3.29.0_Linux_64-bit.tar.gz",
                    sha256 = "00356ae1bacd1160aa415664f3ed0d34ce9ef5319c61d31123a97366ea1a2f64",
                },
                aarch64 = {
                    url = "https://github.com/vale-cli/vale/releases/download/v3.29.0/vale_3.29.0_Linux_arm64.tar.gz",
                    sha256 = "ffff63b3aaf97ca3c7e0a0c5226a8ddf7c21f21f1695e40461b0037d2189ba74",
                },
            },
        },
        macosx = {
            source = "https://github.com/vale-cli/vale/releases/download/v${version}/vale_${version}_macOS_${arch_alias}.tar.gz",
            ["latest"] = { ref = "3.29.0" },
            ["3.28.1"] = {
                arch_alias = { x86_64 = "64-bit", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "4a59f52678b4e6bd55846fb6c22371ed531a274a614ea8e4d51a365c365b563e",
                    aarch64 = "b5362c16d2c95db9d773078b957f5bd59cef27d05dac34c5248a93fed130e9f1",
                },
            },
            ["3.29.0"] = {
                x86_64 = {
                    url = "https://github.com/vale-cli/vale/releases/download/v3.29.0/vale_3.29.0_macOS_64-bit.tar.gz",
                    sha256 = "5c983d634074ea0a7a9b40e6450dff1035f2b406a3f79b130ec4cddd8ff14675",
                },
                aarch64 = {
                    url = "https://github.com/vale-cli/vale/releases/download/v3.29.0/vale_3.29.0_macOS_arm64.tar.gz",
                    sha256 = "62b0eb911aa9255ad4520afa5284d0b8a27f11eea5ffe40390a1eaaca9baab73",
                },
            },
        },
        windows = {
            source = "https://github.com/vale-cli/vale/releases/download/v${version}/vale_${version}_Windows_${arch_alias}.zip",
            ["latest"] = { ref = "3.29.0" },
            ["3.28.1"] = {
                arch_alias = { x86_64 = "64-bit", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "5ad37282f16f3903bb2ec89a7b7b9e718ef838577ffc1657f892a0068cd9b0f3",
                    aarch64 = "8ac31442594dc3c6774ac6d7b5996a9c16629f1c2a93e255e54907c2cd851a87",
                },
            },
            ["3.29.0"] = {
                x86_64 = {
                    url = "https://github.com/vale-cli/vale/releases/download/v3.29.0/vale_3.29.0_Windows_64-bit.zip",
                    sha256 = "5977efcb833248b69c870759c74d368cdaf8845103ac59b986cad1467affc1a0",
                },
                aarch64 = {
                    url = "https://github.com/vale-cli/vale/releases/download/v3.29.0/vale_3.29.0_Windows_arm64.zip",
                    sha256 = "139641ed5ef31b6a4b05b93570aa1be4246e64816c55fe20724abd07821d2c7c",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")
import("xim.pkgindex.shell")

function installed()
    return payload.present({ "vale" }) or payload.present({ "vale.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("vale: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("%.zip$") ~= nil
    local exe = is_win and "vale.exe" or "vale"

    os.tryrm(dir)
    fs.mkdir_p(dir)

    -- Upstream archives are flat (no top-level wrapper directory). Extract
    -- directly from the archive into install_dir so files from unrelated flat
    -- packages in the shared download directory cannot leak into this payload.
    if is_win then
        if os.isfile(archive) then
            payload.unpack{}
        elseif os.isfile(parent .. "/" .. exe) then
            os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
        else
            error("vale: neither archive (" .. archive .. ") nor extracted binary exists")
        end
    else
        if os.isfile(archive) then
            shell.exec({ "tar", "-xzf", normalized, "-C", dir })
        elseif os.isfile(parent .. "/" .. exe) then
            os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
        else
            error("vale: neither archive (" .. archive .. ") nor extracted binary exists")
        end
        if os.isfile(dir .. "/" .. exe) then
            shell.exec({ "chmod", "+x", dir .. "/" .. exe })
        end
    end

    payload.require({ exe })
    return true
end

function config()
    xvm.add("vale", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("vale")
    return true
end
