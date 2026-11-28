-- Dagger - Automation engine to build, test and ship any codebase.
--
-- Verified 2026-11-26 against upstream GitHub release v0.21.12 (dagger/dagger):
--   linux    x86_64, aarch64   dagger_v<ver>_linux_{amd64,arm64}.tar.gz
--   macosx   x86_64, aarch64   dagger_v<ver>_darwin_{amd64,arm64}.tar.gz
--   windows  x86_64, aarch64   dagger_v<ver>_windows_{amd64,arm64}.zip
--
-- Upstream also publishes linux_armv7, which is outside xlings' archs matrix.
-- Every archive is flat at root containing `LICENSE` and a single executable
-- (`dagger` on POSIX, `dagger.exe` on Windows). All six SHA-256 digests match
-- upstream `checksums.txt` and locally downloaded archives.
--
-- Both Linux ELF binaries are statically linked Go executables (`readelf -d`:
-- no dynamic section; `ldd`: not a dynamic executable), so no runtime library
-- deps are required. Both Windows PE32+ executables (`0x8664`, `0xaa64`) import
-- only `kernel32.dll` (no VCRUNTIME DLL dependency). Offline `dagger version`
-- exits 0 in ~18ms, `dagger --help` exits 0, and `dagger "/?"` exits 1 in ~1s
-- (`Error: unknown command or file "/?" for "dagger"`) without blocking to
-- start an engine.

package = {
    spec = "2",

    name = "dagger",
    description = "Automation engine to build, test and ship any codebase",
    homepage = "https://dagger.io",
    authors = {"Dagger"},
    maintainers = {"https://github.com/dagger/dagger/graphs/contributors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/dagger/dagger",
    docs = "https://docs.dagger.io",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"ci", "cd", "containers", "devops", "cli", "tools"},
    keywords = {"dagger", "ci", "cd", "containers", "buildkit", "pipeline", "devops"},

    programs = {"dagger"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/dagger/dagger/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/dagger/dagger/releases/download/${tag}/dagger_v${version}_linux_amd64.tar.gz",
                            aarch64 = "https://github.com/dagger/dagger/releases/download/${tag}/dagger_v${version}_linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/dagger/dagger/releases/download/${tag}/dagger_v${version}_darwin_amd64.tar.gz",
                            aarch64 = "https://github.com/dagger/dagger/releases/download/${tag}/dagger_v${version}_darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/dagger/dagger/releases/download/${tag}/dagger_v${version}_windows_amd64.zip",
                            aarch64 = "https://github.com/dagger/dagger/releases/download/${tag}/dagger_v${version}_windows_arm64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/dagger/dagger/releases/download/v${version}/dagger_v${version}_linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.21.12" },
            ["0.21.12"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "1c8a2949b461c488506e5e668d6e3a0ff3b90ad588fb151f9a8fe77845bc9d7f",
                    aarch64 = "922a6644d91f1e0db6d86bd3ffd6d4ffe9624c1b776d780198dbd5f4fcb2cf9f",
                },
            },
        },
        macosx = {
            source = "https://github.com/dagger/dagger/releases/download/v${version}/dagger_v${version}_darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.21.12" },
            ["0.21.12"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "bfe036218d3ce8d19b3d46e2c8124e3dd6fc7a7b6c7c1c991c2e249f5bbdee16",
                    aarch64 = "61617d1843006466f516c4858f919819082957a7d136c878ae9ffddd193e0d59",
                },
            },
        },
        windows = {
            source = "https://github.com/dagger/dagger/releases/download/v${version}/dagger_v${version}_windows_${arch_alias}.zip",
            ["latest"] = { ref = "0.21.12" },
            ["0.21.12"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "990ef9cd7050ae1a911f5dc7d4a2a6e511dd665f63935b4d0c2678ba539513c8",
                    aarch64 = "49529c0eab434ea46c2ca8321cfd9686b26ac3abc19ced995141866fdecb7cab",
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
    return payload.present({ "dagger" })
        or payload.present({ "dagger.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("dagger: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("%.zip$") ~= nil
        or normalized:match("_windows_") ~= nil
        or os.getenv("OS") == "Windows_NT"
    local exe = is_win and "dagger.exe" or "dagger"

    os.tryrm(dir)

    -- Upstream archives are flat (no top-level wrapper directory). Extract
    -- directly into install_dir so unrelated files in the shared download
    -- directory cannot leak into this payload.
    if is_win then
        if os.isfile(archive) then
            payload.unpack{}
        elseif os.isfile(parent .. "/" .. exe) then
            fs.mkdir_p(dir)
            os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
        else
            error("dagger: neither archive (" .. archive .. ") nor extracted binary exists")
        end
    else
        fs.mkdir_p(dir)
        if os.isfile(archive) then
            system.exec(string.format('tar -xzf "%s" -C "%s"', normalized, dir))
        elseif os.isfile(parent .. "/" .. exe) then
            os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
        else
            error("dagger: neither archive (" .. archive .. ") nor extracted binary exists")
        end
        if os.isfile(dir .. "/" .. exe) then
            system.exec(string.format('chmod +x "%s"', dir .. "/" .. exe))
        end
    end

    payload.require({ exe })
    return true
end

function config()
    xvm.add("dagger", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("dagger")
    return true
end
