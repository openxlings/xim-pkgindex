-- actionlint - Static checker for GitHub Actions workflow files.
--
-- Platform and architecture coverage (verified against rhysd/actionlint v1.7.12):
--   linux    x86_64, aarch64   actionlint_<ver>_linux_<arch>.tar.gz   (static Go ELF, no .dynamic section)
--   macosx   x86_64, aarch64   actionlint_<ver>_darwin_<arch>.tar.gz  (official Mach-O binary)
--   windows  x86_64, aarch64   actionlint_<ver>_windows_<arch>.zip    (official PE binary, imports kernel32.dll only)
--
-- All upstream archives are flat at root (`actionlint` / `actionlint.exe`,
-- `LICENSE.txt`, `README.md`, `docs/*`, `man/actionlint.1`) with no top-level
-- wrapper directory. Every SHA256 below was verified against upstream
-- `actionlint_1.7.12_checksums.txt` and downloaded release archives.

package = {
    spec = "2",

    name = "actionlint",
    description = "Static checker for GitHub Actions workflow files",
    homepage = "https://rhysd.github.io/actionlint/",
    authors = {"rhysd"},
    maintainers = {"rhysd"},
    licenses = {"MIT"},
    repo = "https://github.com/rhysd/actionlint",
    docs = "https://github.com/rhysd/actionlint/tree/main/docs",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"ci", "github", "lint", "cli", "tools"},
    keywords = {"actionlint", "github-actions", "workflow", "yaml", "linter", "ci", "go"},

    programs = {"actionlint"},
    xvm_enable = true,
    ci = { mirror = true },

    extensions = {
        autoupdate = {
            source = "https://github.com/rhysd/actionlint/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/rhysd/actionlint/releases/download/${tag}/actionlint_${version}_linux_amd64.tar.gz",
                            aarch64 = "https://github.com/rhysd/actionlint/releases/download/${tag}/actionlint_${version}_linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/rhysd/actionlint/releases/download/${tag}/actionlint_${version}_darwin_amd64.tar.gz",
                            aarch64 = "https://github.com/rhysd/actionlint/releases/download/${tag}/actionlint_${version}_darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/rhysd/actionlint/releases/download/${tag}/actionlint_${version}_windows_amd64.zip",
                            aarch64 = "https://github.com/rhysd/actionlint/releases/download/${tag}/actionlint_${version}_windows_arm64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/rhysd/actionlint/releases/download/v${version}/actionlint_${version}_linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.7.12" },
            ["1.7.12"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8",
                    aarch64 = "325e971b6ba9bfa504672e29be93c24981eeb1c07576d730e9f7c8805afff0c6",
                },
            },
        },
        macosx = {
            source = "https://github.com/rhysd/actionlint/releases/download/v${version}/actionlint_${version}_darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.7.12" },
            ["1.7.12"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "5b44c3bc2255115c9b69e30efc0fecdf498fdb63c5d58e17084fd5f16324c644",
                    aarch64 = "aba9ced2dee8d27fecca3dc7feb1a7f9a52caefa1eb46f3271ea66b6e0e6953f",
                },
            },
        },
        windows = {
            source = "https://github.com/rhysd/actionlint/releases/download/v${version}/actionlint_${version}_windows_${arch_alias}.zip",
            ["latest"] = { ref = "1.7.12" },
            ["1.7.12"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "6e7241b51e6817ea6a047693d8e6fed13b31819c9a0dd6c5a726e1592d22f6e9",
                    aarch64 = "cadcf7ea4efe3a68728893813643cebe1185e5b1d4be5b96245f65c9a4d5ea41",
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

function installed()
    return payload.present({ "actionlint" }) or payload.present({ "actionlint.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("actionlint: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("%.zip$") ~= nil
    local exe = is_win and "actionlint.exe" or "actionlint"

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
            error("actionlint: neither archive (" .. archive .. ") nor extracted binary exists")
        end
    else
        if os.isfile(archive) then
            system.exec(string.format([[tar -xzf "%s" -C "%s"]], normalized, dir))
        elseif os.isfile(parent .. "/" .. exe) then
            os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
        else
            error("actionlint: neither archive (" .. archive .. ") nor extracted binary exists")
        end
        if os.isfile(dir .. "/" .. exe) then
            system.exec(string.format([[chmod +x "%s"]], dir .. "/" .. exe))
        end
    end

    payload.require({ exe })
    return true
end

function config()
    xvm.add("actionlint", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("actionlint")
    return true
end
