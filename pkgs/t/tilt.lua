-- Tilt - multi-service dev environment tool for Kubernetes (tilt-dev/tilt).
--
-- Verified 2026-11-26 against upstream GitHub release v0.37.9 (tilt-dev/tilt):
--   linux    x86_64, aarch64   tilt.<ver>.linux-alpine.{x86_64,arm64}.tar.gz  (static musl Go ELF, no .dynamic section)
--   macosx   x86_64, aarch64   tilt.<ver>.mac.{x86_64,arm64}.tar.gz           (Mach-O 64-bit)
--   windows  x86_64            tilt.<ver>.windows.x86_64.zip                  (PE32+ console, imports KERNEL32.dll & msvcrt.dll)
--
-- Upstream also publishes glibc `tilt.<ver>.linux.{x86_64,arm64}.tar.gz`
-- (dynamically linked against libstdc++.so.6, libgcc_s.so.1, libc.so.6);
-- we use the `linux-alpine` builds because they are completely statically
-- linked (`readelf -d`: no dynamic section; `ldd`: not a dynamic executable)
-- and require zero runtime library dependencies. Upstream does not publish a
-- windows/aarch64 binary for v0.37.9, so `xpm.windows` covers `x86_64` only.
--
-- Every archive is flat at root (`tilt` / `tilt.exe`, `LICENSE`, `README.md`).
-- All five SHA-256 digests match upstream `checksums.txt` and locally
-- downloaded archives. `tilt "/?"` exits immediately with status 1
-- (`unknown command "/?" for "tilt"`), so Windows CI program smoke probing
-- will not hang.

package = {
    spec = "2",

    name = "tilt",
    description = "Define your dev environment as code. For microservice apps on Kubernetes.",
    homepage = "https://tilt.dev",
    authors = {"Tilt Dev"},
    maintainers = {"https://github.com/tilt-dev/tilt/graphs/contributors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/tilt-dev/tilt",
    docs = "https://docs.tilt.dev/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"kubernetes", "containers", "devops", "cli", "tools"},
    keywords = {"tilt", "kubernetes", "k8s", "docker", "microservices", "dev", "tiltfile"},

    programs = {"tilt"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/tilt-dev/tilt/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/tilt-dev/tilt/releases/download/${tag}/tilt.${version}.linux-alpine.x86_64.tar.gz",
                            aarch64 = "https://github.com/tilt-dev/tilt/releases/download/${tag}/tilt.${version}.linux-alpine.arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/tilt-dev/tilt/releases/download/${tag}/tilt.${version}.mac.x86_64.tar.gz",
                            aarch64 = "https://github.com/tilt-dev/tilt/releases/download/${tag}/tilt.${version}.mac.arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/tilt-dev/tilt/releases/download/${tag}/tilt.${version}.windows.x86_64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/tilt-dev/tilt/releases/download/v${version}/tilt.${version}.linux-alpine.${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.37.9" },
            ["0.37.9"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "a56e5deb260be3c0a463584e4518e883800b523bc04617328c59bed4e43ce3a5",
                    aarch64 = "75ecb4d838b4094330b7316095cd5173299cd07087a3dde4bec6efbdfad63498",
                },
            },
        },
        macosx = {
            source = "https://github.com/tilt-dev/tilt/releases/download/v${version}/tilt.${version}.mac.${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.37.9" },
            ["0.37.9"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "e8d6a3bddf0118fa1d46e1090608762d07b33cb0dab8578b17bf001979172ced",
                    aarch64 = "b3a3ad44f6c2d92abb49191a2e0dfa16dd1d84a367c97d83074e46af347a0426",
                },
            },
        },
        windows = {
            source = "https://github.com/tilt-dev/tilt/releases/download/v${version}/tilt.${version}.windows.${arch_alias}.zip",
            ["latest"] = { ref = "0.37.9" },
            ["0.37.9"] = {
                arch_alias = { x86_64 = "x86_64" },
                sha256 = {
                    x86_64 = "ca0f6531ad5930da8a12214de22b83e1757d412ed78c86950c0e8ee9d946cca9",
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
    "LICENSE",
    "README.md",
}

local function required_files(exe)
    local files = { exe }
    for _, rel in ipairs(COMMON_FILES) do
        files[#files + 1] = rel
    end
    return files
end

function installed()
    return payload.present(required_files("tilt"))
        or payload.present(required_files("tilt.exe"))
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("tilt: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("%.zip$") ~= nil
        or normalized:match("%.windows%.") ~= nil
        or os.getenv("OS") == "Windows_NT"
    local exe = is_win and "tilt.exe" or "tilt"

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
            for _, rel in ipairs(COMMON_FILES) do
                if os.isfile(parent .. "/" .. rel) then
                    os.mv(parent .. "/" .. rel, dir .. "/" .. rel)
                end
            end
        else
            error("tilt: neither archive (" .. archive .. ") nor extracted binary exists")
        end
    else
        fs.mkdir_p(dir)
        if os.isfile(archive) then
            system.exec(string.format('tar -xzf "%s" -C "%s"', normalized, dir))
        elseif os.isfile(parent .. "/" .. exe) then
            os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
            for _, rel in ipairs(COMMON_FILES) do
                if os.isfile(parent .. "/" .. rel) then
                    os.mv(parent .. "/" .. rel, dir .. "/" .. rel)
                end
            end
        else
            error("tilt: neither archive (" .. archive .. ") nor extracted binary exists")
        end
        if os.isfile(dir .. "/" .. exe) then
            system.exec(string.format('chmod +x "%s"', dir .. "/" .. exe))
        end
    end

    payload.require(required_files(exe))
    return true
end

function config()
    xvm.add("tilt", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("tilt")
    return true
end
