-- oras - OCI registry client for managing content like artifacts, images, and packages (oras-project/oras).
--
-- Platform and architecture coverage (verified against oras-project/oras v1.4.0):
--   linux    x86_64, aarch64   oras_<ver>_linux_{amd64,arm64}.tar.gz   (static Go ELF, no .dynamic section)
--   macosx   x86_64, aarch64   oras_<ver>_darwin_{amd64,arm64}.tar.gz  (Mach-O 64-bit executable)
--   windows  x86_64, aarch64   oras_<ver>_windows_{amd64,arm64}.zip    (PE32+ console executable, imports kernel32.dll only)
--
-- All upstream archives are flat at root (`oras` / `oras.exe` and `LICENSE`)
-- with no top-level wrapper directory. Every SHA256 below was verified against
-- upstream `oras_1.4.0_checksums.txt` and locally downloaded release archives.

package = {
    spec = "2",

    name = "oras",
    description = "OCI registry client for managing content like artifacts, images, and packages",
    homepage = "https://oras.land",
    authors = {"ORAS Authors"},
    maintainers = {"oras-project"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/oras-project/oras",
    docs = "https://oras.land/docs/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"container", "oci", "registry", "cli", "tools"},
    keywords = {"oras", "oci", "registry", "artifact", "container", "supply-chain"},

    programs = {"oras"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/oras-project/oras/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/oras-project/oras/releases/download/${tag}/oras_${version}_linux_amd64.tar.gz",
                            aarch64 = "https://github.com/oras-project/oras/releases/download/${tag}/oras_${version}_linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/oras-project/oras/releases/download/${tag}/oras_${version}_darwin_amd64.tar.gz",
                            aarch64 = "https://github.com/oras-project/oras/releases/download/${tag}/oras_${version}_darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/oras-project/oras/releases/download/${tag}/oras_${version}_windows_amd64.zip",
                            aarch64 = "https://github.com/oras-project/oras/releases/download/${tag}/oras_${version}_windows_arm64.zip",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/oras-project/oras/releases/download/v${version}/oras_${version}_linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.4.0" },
            ["1.4.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "d8e1dce2fd8ce996f1d901845b688eb0cf505a6082897606f053825bb47935d1",
                    aarch64 = "0791fc200831563e498638d30e8ee8aac20ad1da2610760120fe3f770e12a8a4",
                },
            },
        },
        macosx = {
            source = "https://github.com/oras-project/oras/releases/download/v${version}/oras_${version}_darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.4.0" },
            ["1.4.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "17d5c1b435023fe86c3a36bfbf048ac352c61484350c5250ce31131f104a2802",
                    aarch64 = "0a7f499bb28793a97bd0939de8654607e753ff6082fd72697a700868b9cdab53",
                },
            },
        },
        windows = {
            source = "https://github.com/oras-project/oras/releases/download/v${version}/oras_${version}_windows_${arch_alias}.zip",
            ["latest"] = { ref = "1.4.0" },
            ["1.4.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "c70d25e3463a161a5aeeddd9fe5ef882c811dde8115ab0883c0b87d3f0c50832",
                    aarch64 = "6603fe6f0dc27cb127b069f9cd2a55bd6a00c10e34e2288055e74fb60ee24cb8",
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

local function payload_files(ext)
    return { "oras" .. ext, "LICENSE" }
end

local function move_pre_extracted(parent, dir, exe)
    os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
    if os.isfile(parent .. "/LICENSE") then
        os.mv(parent .. "/LICENSE", dir .. "/LICENSE")
    end
end

function installed()
    return payload.present(payload_files(""))
        or payload.present(payload_files(".exe"))
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("oras: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("%.zip$") ~= nil or os.getenv("OS") == "Windows_NT"
    local ext = is_win and ".exe" or ""
    local exe = "oras" .. ext

    os.tryrm(dir)
    fs.mkdir_p(dir)

    -- Upstream archives are flat (no enclosing directory). Extract directly into
    -- install_dir so files from unrelated packages in the shared download
    -- directory never mix with this payload.
    if is_win then
        if os.isfile(archive) then
            payload.unpack{}
        elseif os.isfile(parent .. "/" .. exe) then
            move_pre_extracted(parent, dir, exe)
        else
            error("oras: neither archive (" .. archive .. ") nor extracted binary exists")
        end
    else
        if os.isfile(archive) then
            system.exec(string.format([[tar -xzf "%s" -C "%s"]], normalized, dir))
        elseif os.isfile(parent .. "/" .. exe) then
            move_pre_extracted(parent, dir, exe)
        else
            error("oras: neither archive (" .. archive .. ") nor extracted binary exists")
        end
        if os.isfile(dir .. "/" .. exe) then
            system.exec(string.format([[chmod +x "%s"]], dir .. "/" .. exe))
        end
    end

    payload.require(payload_files(ext))
    return true
end

function config()
    xvm.add("oras", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("oras")
    return true
end
