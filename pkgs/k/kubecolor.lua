-- kubecolor — Colorize your kubectl output.
--
-- Verified 2026-11-26 against upstream GitHub release v0.9.0 (kubecolor/kubecolor)
-- and `checksums.txt`: every SHA256 below matched both the upstream checksums
-- file and the downloaded release archive bytes:
--   linux/x86_64    kubecolor_0.9.0_linux_amd64.tar.gz    (static Go ELF, no .dynamic section)
--   linux/aarch64   kubecolor_0.9.0_linux_arm64.tar.gz    (static Go ELF, no .dynamic section)
--   macosx/x86_64   kubecolor_0.9.0_darwin_amd64.tar.gz   (Mach-O 64-bit x86_64)
--   macosx/aarch64  kubecolor_0.9.0_darwin_arm64.tar.gz   (Mach-O 64-bit arm64)
--   windows/x86_64  kubecolor_0.9.0_windows_amd64.zip     (PE32+ console x86-64, imports kernel32.dll only)
--   windows/aarch64 kubecolor_0.9.0_windows_arm64.zip     (PE32+ console ARM64, imports kernel32.dll only)
--
-- Every archive is flat at root containing `LICENSE`, `README.md`, and
-- `kubecolor` (or `kubecolor.exe` on Windows). `install()` extracts directly
-- into `pkginfo.install_dir()` so unrelated files in the shared download
-- directory cannot leak into this payload.

package = {
    spec = "2",

    name = "kubecolor",
    description = "Colorize your kubectl output",
    homepage = "https://kubecolor.github.io/",
    maintainers = {"https://github.com/kubecolor/kubecolor/graphs/contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/kubecolor/kubecolor",
    docs = "https://kubecolor.github.io/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"kubernetes", "k8s", "cli", "tools"},
    keywords = {"kubecolor", "kubectl", "kubernetes", "k8s", "color", "cli"},

    programs = {"kubecolor"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/kubecolor/kubecolor/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/kubecolor/kubecolor/releases/download/${tag}/kubecolor_${version}_linux_amd64.tar.gz",
                            aarch64 = "https://github.com/kubecolor/kubecolor/releases/download/${tag}/kubecolor_${version}_linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/kubecolor/kubecolor/releases/download/${tag}/kubecolor_${version}_darwin_amd64.tar.gz",
                            aarch64 = "https://github.com/kubecolor/kubecolor/releases/download/${tag}/kubecolor_${version}_darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/kubecolor/kubecolor/releases/download/${tag}/kubecolor_${version}_windows_amd64.zip",
                            aarch64 = "https://github.com/kubecolor/kubecolor/releases/download/${tag}/kubecolor_${version}_windows_arm64.zip",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            deps = { runtime = { "xim:kubectl" } },
            source = "https://github.com/kubecolor/kubecolor/releases/download/v${version}/kubecolor_${version}_linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.9.0" },
            ["0.9.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "286ef7abc25a1c7b136761b32303b64838929bee83a2ed12e74c67531d7221f2",
                    aarch64 = "78a3d101436dc99b506bb0233d45d008eac8b94635ae641b1154e4ed31101c83",
                },
            },
        },
        macosx = {
            deps = { runtime = { "xim:kubectl" } },
            source = "https://github.com/kubecolor/kubecolor/releases/download/v${version}/kubecolor_${version}_darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.9.0" },
            ["0.9.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "7e72064b0346761589b7ecc230710fc22707ca775b7a177ae27e87f0295db957",
                    aarch64 = "8eeb8297a54eeca266bc29fbe0d10ffcef8a7185e4c4400295696405db75ae6a",
                },
            },
        },
        windows = {
            deps = { runtime = { "xim:kubectl" } },
            source = "https://github.com/kubecolor/kubecolor/releases/download/v${version}/kubecolor_${version}_windows_${arch_alias}.zip",
            ["latest"] = { ref = "0.9.0" },
            ["0.9.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "0a357d019d8cd070617bea75a678baa16063a7c0f646d0a436f11bcdda6fa0e4",
                    aarch64 = "cb6a2b5107987bac5abe6bd7e9fdce2d5e4a52325fddee05f87dcd54ee7b3576",
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
    return payload.present({ "kubecolor" })
        or payload.present({ "kubecolor.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("kubecolor: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("%.zip$") ~= nil
        or normalized:match("_windows_") ~= nil
        or os.getenv("OS") == "Windows_NT"
    local exe = is_win and "kubecolor.exe" or "kubecolor"

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
            error("kubecolor: neither archive (" .. archive .. ") nor extracted binary exists")
        end
    else
        fs.mkdir_p(dir)
        if os.isfile(archive) then
            system.exec(string.format('tar -xzf "%s" -C "%s"', normalized, dir))
        elseif os.isfile(parent .. "/" .. exe) then
            os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
        else
            error("kubecolor: neither archive (" .. archive .. ") nor extracted binary exists")
        end
        if os.isfile(dir .. "/" .. exe) then
            system.exec(string.format('chmod +x "%s"', dir .. "/" .. exe))
        end
    end

    payload.require({ exe })
    return true
end

function config()
    xvm.add("kubecolor", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("kubecolor")
    return true
end
