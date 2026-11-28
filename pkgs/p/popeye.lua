-- Popeye - Kubernetes cluster resource sanitizer (derailed/popeye).
--
-- Verified 2026-11-26 against upstream GitHub release v0.22.1 and
-- `checksums.sha256`: every SHA-256 below matched the upstream checksums file
-- and downloaded archive bytes:
--   linux/x86_64    popeye_linux_amd64.tar.gz    (static Go ELF, no .dynamic section)
--   linux/aarch64   popeye_linux_arm64.tar.gz    (static Go ELF, no .dynamic section)
--   macosx/x86_64   popeye_darwin_amd64.tar.gz   (Mach-O 64-bit x86_64)
--   macosx/aarch64  popeye_darwin_arm64.tar.gz   (Mach-O 64-bit arm64)
--   windows/x86_64  popeye_windows_amd64.tar.gz  (PE32+ x86-64 CUI, imports kernel32.dll only)
--   windows/aarch64 popeye_windows_arm64.tar.gz  (PE32+ ARM64 CUI, imports kernel32.dll only)
--
-- Upstream also publishes FreeBSD, ppc64le, s390x, and distro packages
-- (.apk/.deb/.rpm), which are outside `archs`. All six supported archives are
-- flat `.tar.gz` at root (`popeye` / `popeye.exe`, `LICENSE`, `README.md` with
-- no top-level wrapper directory). `install()` extracts directly from
-- `pkginfo.install_file()` into a clean `pkginfo.install_dir()` so shared
-- `runtimedir` contents from other flat archives cannot leak into this payload.

package = {
    spec = "2",

    name = "popeye",
    description = "Kubernetes cluster resource sanitizer",
    homepage = "https://popeyecli.io",
    maintainers = {"derailed"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/derailed/popeye",
    docs = "https://popeyecli.io",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"kubernetes", "k8s", "cli", "tools"},
    keywords = {"popeye", "kubernetes", "k8s", "linter", "sanitizer", "cli", "go"},

    programs = {"popeye"},
    xvm_enable = true,

    -- Verified upstream release assets; no CN mirror has been verified.
    extensions = {
        autoupdate = {
            source = "https://github.com/derailed/popeye/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/derailed/popeye/releases/download/${tag}/popeye_linux_amd64.tar.gz",
                            aarch64 = "https://github.com/derailed/popeye/releases/download/${tag}/popeye_linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/derailed/popeye/releases/download/${tag}/popeye_darwin_amd64.tar.gz",
                            aarch64 = "https://github.com/derailed/popeye/releases/download/${tag}/popeye_darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/derailed/popeye/releases/download/${tag}/popeye_windows_amd64.tar.gz",
                            aarch64 = "https://github.com/derailed/popeye/releases/download/${tag}/popeye_windows_arm64.tar.gz",
                        },
                    },
                },
            },
        },
    },

    -- Upstream builds static Go binaries; Linux ELFs have no dynamic section and
    -- Windows PE executables import only kernel32.dll, so no runtime deps are needed.
    xpm = {
        linux = {
            source = "https://github.com/derailed/popeye/releases/download/v${version}/popeye_linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.22.1" },
            ["0.22.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "d58a3c0ba45805d452c32628320eecdcb5172fd5f42c82e12aeecc7a17eb930b",
                    aarch64 = "5188b0b521966113580f0fef7769173af6303061dee10df247536f9bb55fe988",
                },
            },
        },
        macosx = {
            source = "https://github.com/derailed/popeye/releases/download/v${version}/popeye_darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.22.1" },
            ["0.22.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "3dafce865dd778e2501ccbfd53fcbeecfc3244a43d4d1b02446064e39ac58d4e",
                    aarch64 = "71dc8b8dc7d7cad60f9c377d4bb22a0ef5bac189c617951ebc20343f83a6704d",
                },
            },
        },
        windows = {
            source = "https://github.com/derailed/popeye/releases/download/v${version}/popeye_windows_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.22.1" },
            ["0.22.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "fa5c155d65313e93985bdb7ed1a79fb0e310b7868848dfaf381ea081f349dacc",
                    aarch64 = "91aee5c13655f6fa509e79a87963ec0a81dd23486bb54a4845b3d0db33dabfb0",
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
import("xim.pkgindex.winpath")

local function required_files(exe)
    return { exe, "LICENSE", "README.md" }
end

function installed()
    return payload.present(required_files("popeye"))
        or payload.present(required_files("popeye.exe"))
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("popeye: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("_windows_") ~= nil
        or normalized:match("^[A-Za-z]:/") ~= nil
        or os.getenv("OS") == "Windows_NT"
    local exe = is_win and "popeye.exe" or "popeye"

    os.tryrm(dir)
    fs.mkdir_p(dir)

    if os.isfile(archive) then
        if is_win then
            -- libs/payload.lua only dispatches .zip; Windows ships flat .tar.gz,
            -- so invoke Windows built-in bsdtar (System32\tar.exe) explicitly.
            local sysroot = winpath.native(os.getenv("SystemRoot") or "C:\\Windows"):gsub("\\+$", "")
            local systar = sysroot .. "\\System32\\tar.exe"
            -- exec-quoting-ok: the first token is the system's tar.exe, which cmd.exe must see unquoted
            system.exec(string.format('%s -xf "%s" -C "%s"',
                                      systar, winpath.native(archive), winpath.native(dir)))
        else
            -- Extract flat .tar.gz directly into install_dir so files never mix
            -- with other flat archives in the shared runtimedir.
            system.exec(string.format('tar -xzf "%s" -C "%s"', normalized, dir))
            system.exec(string.format('chmod +x "%s"', dir .. "/popeye"))
        end
    elseif os.isfile(parent .. "/" .. exe) then
        for _, f in ipairs(required_files(exe)) do
            if os.isfile(parent .. "/" .. f) then
                os.mv(parent .. "/" .. f, dir .. "/" .. f)
            end
        end
        if not is_win then
            system.exec(string.format('chmod +x "%s"', dir .. "/popeye"))
        end
    else
        error("popeye: archive not found at " .. archive)
    end

    payload.require(required_files(exe))
    return true
end

function config()
    xvm.add("popeye", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("popeye")
    return true
end
