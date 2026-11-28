-- Lefthook - Fast and powerful Git hooks manager (evilmartians/lefthook).
--
-- Verified 2026-11-26 against upstream GitHub release v2.2.3 and
-- `lefthook_checksums.txt`: every SHA256 below matched both the upstream
-- checksums file and the downloaded release bytes:
--   linux/x86_64    lefthook_2.2.3_Linux_x86_64.gz     (gzip-compressed static Go ELF, no .dynamic section)
--   linux/aarch64   lefthook_2.2.3_Linux_arm64.gz      (gzip-compressed static Go ELF, no .dynamic section)
--   macosx/x86_64   lefthook_2.2.3_MacOS_x86_64.gz     (gzip-compressed Mach-O 64-bit x86_64)
--   macosx/aarch64  lefthook_2.2.3_MacOS_arm64.gz      (gzip-compressed Mach-O 64-bit arm64)
--   windows/x86_64  lefthook_2.2.3_Windows_x86_64.exe  (PE32+ console x86-64, imports kernel32.dll only)
--   windows/aarch64 lefthook_2.2.3_Windows_arm64.exe   (PE32+ console ARM64, imports kernel32.dll only)
--
-- POSIX assets are single-file `.gz` compressed binaries (not `.tar.gz`), and
-- Windows assets are raw `.exe` binaries so Windows installation needs no
-- external decompressor.

package = {
    spec = "2",

    name = "lefthook",
    description = "Fast and powerful Git hooks manager for any type of project",
    homepage = "https://lefthook.dev/",
    authors = {"Evil Martians"},
    maintainers = {"evilmartians"},
    licenses = {"MIT"},
    repo = "https://github.com/evilmartians/lefthook",
    docs = "https://lefthook.dev/configuration/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"git", "hooks", "cli", "devtools", "tools"},
    keywords = {"lefthook", "git", "git-hooks", "pre-commit", "lint", "cli", "go"},

    programs = {"lefthook"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/evilmartians/lefthook/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/evilmartians/lefthook/releases/download/${tag}/lefthook_${version}_Linux_x86_64.gz",
                            aarch64 = "https://github.com/evilmartians/lefthook/releases/download/${tag}/lefthook_${version}_Linux_arm64.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/evilmartians/lefthook/releases/download/${tag}/lefthook_${version}_MacOS_x86_64.gz",
                            aarch64 = "https://github.com/evilmartians/lefthook/releases/download/${tag}/lefthook_${version}_MacOS_arm64.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/evilmartians/lefthook/releases/download/${tag}/lefthook_${version}_Windows_x86_64.exe",
                            aarch64 = "https://github.com/evilmartians/lefthook/releases/download/${tag}/lefthook_${version}_Windows_arm64.exe",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/evilmartians/lefthook/releases/download/v${version}/lefthook_${version}_Linux_${arch_alias}.gz",
            ["latest"] = { ref = "2.2.3" },
            ["2.2.3"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "f25a53b1991c2727aa2819fdd7a4b9798fc0c210d1e1a92f035be8f346cec9fb",
                    aarch64 = "7e80cf4b1c42ecc420759d6c1071f0092462e113ea1ac153d1d11d3a77b3ce61",
                },
            },
        },
        macosx = {
            source = "https://github.com/evilmartians/lefthook/releases/download/v${version}/lefthook_${version}_MacOS_${arch_alias}.gz",
            ["latest"] = { ref = "2.2.3" },
            ["2.2.3"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "a5fbf2fd32ba0d170aac41659b30cf7c25d597eb513dda96f044021dda78b6e8",
                    aarch64 = "ac57c55fa405c11afe9be7a733ab7d9e81ae5afa71e3588105b7d7aa3c7025ae",
                },
            },
        },
        windows = {
            source = "https://github.com/evilmartians/lefthook/releases/download/v${version}/lefthook_${version}_Windows_${arch_alias}.exe",
            ["latest"] = { ref = "2.2.3" },
            ["2.2.3"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "1d74cdecc4028d32c0240fde53cd874b83cf6a64ab03c02f56b6b74e7feaa9ae",
                    aarch64 = "f1d8d741abbe67e20da5d3afa316016e7f2fbc74cc5c383de0cf6838b86a42ec",
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
    return payload.present({ "lefthook" }) or payload.present({ "lefthook.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("lefthook: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local is_win = normalized:lower():match("%.exe$") ~= nil
    local exe = is_win and "lefthook.exe" or "lefthook"
    local target = dir .. "/" .. exe

    os.tryrm(dir)
    fs.mkdir_p(dir)

    if is_win then
        if not os.isfile(archive) then
            error("lefthook: executable not found: " .. archive)
        end
        os.mv(archive, target)
    else
        local unpacked = normalized:gsub("%.gz$", "")
        if unpacked ~= normalized and os.isfile(unpacked) then
            os.mv(unpacked, target)
        elseif normalized:match("%.gz$") and os.isfile(archive) then
            system.exec(string.format([[sh -c 'gzip -dc "$1" > "$2"' _ "%s" "%s"]], normalized, target))
        elseif os.isfile(archive) then
            os.mv(archive, target)
        else
            error("lefthook: archive not found: " .. archive)
        end
        if os.isfile(target) then
            system.exec(string.format([[chmod +x "%s"]], target))
        end
    end

    payload.require({ exe })
    return true
end

function config()
    xvm.add("lefthook", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("lefthook")
    return true
end
