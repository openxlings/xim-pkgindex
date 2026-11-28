-- crane - CLI tool for managing container images and OCI registries (google/go-containerregistry).
--
-- Verified 2026-11-26 against upstream GitHub release v0.22.1
-- (`google/go-containerregistry`). Every SHA256 below matches upstream
-- `checksums.txt` and locally downloaded archives:
--   * linux   x86_64, aarch64   `go-containerregistry_Linux_{x86_64,arm64}.tar.gz`
--                               (flat archive: `crane`, `gcrane`, `krane`, `LICENSE`, `README.md`;
--                               all three binaries are statically linked Go ELFs with no
--                               dynamic section or external libc dependency via `readelf -d` / `ldd`).
--   * macosx  x86_64, aarch64   `go-containerregistry_Darwin_{x86_64,arm64}.tar.gz`
--   * windows x86_64, aarch64   `go-containerregistry_Windows_{x86_64,arm64}.tar.gz`
--                               (flat `.tar.gz` archive containing `crane.exe`, `gcrane.exe`,
--                               `krane.exe`, `LICENSE`, `README.md`; all three PE32+ binaries
--                               import only `kernel32.dll`, no VCRUNTIME DLL dependency).

package = {
    spec = "2",

    name = "crane",
    description = "CLI tool for interacting with remote container images and OCI registries",
    homepage = "https://github.com/google/go-containerregistry/tree/main/cmd/crane",
    authors = {"Google LLC and contributors"},
    maintainers = {"google/go-containerregistry"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/google/go-containerregistry",
    docs = "https://github.com/google/go-containerregistry/blob/main/cmd/crane/README.md",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"container", "docker", "oci", "cli", "tools"},
    keywords = {"crane", "gcrane", "krane", "oci", "container", "registry", "docker"},

    programs = {"crane"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/google/go-containerregistry/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/google/go-containerregistry/releases/download/${tag}/go-containerregistry_Linux_x86_64.tar.gz",
                            aarch64 = "https://github.com/google/go-containerregistry/releases/download/${tag}/go-containerregistry_Linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/google/go-containerregistry/releases/download/${tag}/go-containerregistry_Darwin_x86_64.tar.gz",
                            aarch64 = "https://github.com/google/go-containerregistry/releases/download/${tag}/go-containerregistry_Darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/google/go-containerregistry/releases/download/${tag}/go-containerregistry_Windows_x86_64.tar.gz",
                            aarch64 = "https://github.com/google/go-containerregistry/releases/download/${tag}/go-containerregistry_Windows_arm64.tar.gz",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/google/go-containerregistry/releases/download/v${version}/go-containerregistry_Linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.22.1" },
            ["0.22.1"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "0ab7a1d6932a213aed964ce97666c3077fe691c8606413674a8b3e0b9ec4cda0",
                    aarch64 = "898c0cff975f898a33e8c4580bdafb0e7c02c7faa33374e946762f97c4ab7110",
                },
            },
        },
        macosx = {
            source = "https://github.com/google/go-containerregistry/releases/download/v${version}/go-containerregistry_Darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.22.1" },
            ["0.22.1"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "6fedd06a648c11335f0e8b9547e4783002c30e9336047fec292942cd518bb799",
                    aarch64 = "2231fc8df8806d20d680ff1225db44e095a55dd6ac1ae8eced4faf4b278b78fb",
                },
            },
        },
        windows = {
            source = "https://github.com/google/go-containerregistry/releases/download/v${version}/go-containerregistry_Windows_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.22.1" },
            ["0.22.1"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "0e073ea8192c3b8442ec8aaf44d53c1050a09084669fae3a6ceb0f2026cf8b21",
                    aarch64 = "bec68b29b18d3f0fb1938739e241006960168c748166d0370111bdc730979584",
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

local function payload_files(ext)
    return { "crane" .. ext, "gcrane" .. ext, "krane" .. ext, "LICENSE" }
end

function installed()
    return payload.present(payload_files(""))
        or payload.present(payload_files(".exe"))
end

function install()
    local archive = tostring(pkginfo.install_file())
    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("_Windows_") ~= nil or os.getenv("OS") == "Windows_NT"
    local ext = is_win and ".exe" or ""

    os.tryrm(dir)

    if os.isfile(archive) then
        -- Extract flat .tar.gz directly into install_dir so files never mix
        -- with other flat archives in the shared runtimedir. On Windows,
        -- System32\tar.exe (bsdtar) handles .tar.gz natively; libs/payload.lua
        -- only dispatches .zip.
        fs.mkdir_p(dir)
        if is_win then
            local sysroot = winpath.native(os.getenv("SystemRoot") or "C:\\Windows"):gsub("\\+$", "")
            local systar = sysroot .. "\\System32\\tar.exe"
            -- exec-quoting-ok: the first token is the system's tar.exe, which cmd.exe must see unquoted
            system.exec(string.format('%s -xf "%s" -C "%s"', systar, winpath.native(archive), winpath.native(dir)))
        else
            system.exec(string.format('tar -xf "%s" -C "%s"', archive, dir))
        end
    elseif os.isfile(parent .. "/crane" .. ext) then
        fs.mkdir_p(dir)
        for _, f in ipairs({ "crane" .. ext, "gcrane" .. ext, "krane" .. ext, "LICENSE", "README.md" }) do
            if os.isfile(parent .. "/" .. f) then
                os.mv(parent .. "/" .. f, dir .. "/" .. f)
            end
        end
    else
        error("crane: archive not found at " .. archive)
    end

    if not is_win then
        for _, bin in ipairs({ "crane", "gcrane", "krane" }) do
            if os.isfile(dir .. "/" .. bin) then
                system.exec(string.format('chmod +x "%s"', dir .. "/" .. bin))
            end
        end
    end

    payload.require(payload_files(ext))
    return true
end

function config()
    local bindir = pkginfo.install_dir()
    local binding = "crane@" .. pkginfo.version()
    xvm.add("crane", { bindir = bindir })
    xvm.add("gcrane", { bindir = bindir, binding = binding })
    xvm.add("krane", { bindir = bindir, binding = binding })
    return true
end

function uninstall()
    xvm.remove("krane")
    xvm.remove("gcrane")
    xvm.remove("crane")
    return true
end
