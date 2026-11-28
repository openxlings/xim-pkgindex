-- dive - A tool for exploring each layer in a docker image.
--
-- Platform and architecture coverage (verified against wagoodman/dive v0.13.1):
--   linux    x86_64, aarch64   dive_<ver>_linux_<arch>.tar.gz   (static Go ELF, no .dynamic section)
--   macosx   x86_64, aarch64   dive_<ver>_darwin_<arch>.tar.gz  (official Mach-O binary)
--   windows  x86_64, aarch64   dive_<ver>_windows_<arch>.zip    (official PE32+ binary, imports kernel32.dll only)
--
-- Upstream also publishes linux_ppc64le, which is outside xlings' archs matrix.
-- All upstream archives are flat at root (`dive` / `dive.exe`, `CHANGELOG.md`, `LICENSE`,
-- `README.md`) with no top-level wrapper directory. Every SHA256 below was verified against
-- both upstream `dive_0.13.1_checksums.txt` and downloaded release archives.

package = {
    spec = "2",

    name = "dive",
    description = "A tool for exploring each layer in a docker image",
    homepage = "https://github.com/wagoodman/dive",
    authors = {"Alex Goodman"},
    maintainers = {"wagoodman"},
    licenses = {"MIT"},
    repo = "https://github.com/wagoodman/dive",
    docs = "https://github.com/wagoodman/dive",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"docker", "containers", "cli", "tui", "tools"},
    keywords = {"dive", "docker", "container", "image", "layers", "cli", "tui", "go"},

    programs = {"dive"},
    xvm_enable = true,
    ci = { mirror = true },

    extensions = {
        autoupdate = {
            source = "https://github.com/wagoodman/dive/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/wagoodman/dive/releases/download/${tag}/dive_${version}_linux_amd64.tar.gz",
                            aarch64 = "https://github.com/wagoodman/dive/releases/download/${tag}/dive_${version}_linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/wagoodman/dive/releases/download/${tag}/dive_${version}_darwin_amd64.tar.gz",
                            aarch64 = "https://github.com/wagoodman/dive/releases/download/${tag}/dive_${version}_darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/wagoodman/dive/releases/download/${tag}/dive_${version}_windows_amd64.zip",
                            aarch64 = "https://github.com/wagoodman/dive/releases/download/${tag}/dive_${version}_windows_arm64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/wagoodman/dive/releases/download/v${version}/dive_${version}_linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.13.1" },
            ["0.13.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "0970549eb4a306f8825a84145a2534153badb4d7dcf3febd1967c706367c3d0e",
                    aarch64 = "2fcd2cf20f634ccdb41efac44048b204bfc867c115641f37a7420693ed480a18",
                },
            },
        },
        macosx = {
            source = "https://github.com/wagoodman/dive/releases/download/v${version}/dive_${version}_darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.13.1" },
            ["0.13.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "04e4c1bac21be3aef99799cf0e470149a072ea4786be50718aa846cd13746523",
                    aarch64 = "38b7fa95a13e7f4d0b3060c875fe7427c2a0613ecff674bb45156eb34bca0b09",
                },
            },
        },
        windows = {
            source = "https://github.com/wagoodman/dive/releases/download/v${version}/dive_${version}_windows_${arch_alias}.zip",
            ["latest"] = { ref = "0.13.1" },
            ["0.13.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "3e764ff28c7b89f4da679deac80483249fbbae3a1d512c103d54609eec09086a",
                    aarch64 = "de298f2edeffeac3e4c715eb516eab8075b50a7c8fce28194f730f2a384d4dc9",
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
    return payload.present({ "dive" }) or payload.present({ "dive.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("dive: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("%.zip$") ~= nil
    local exe = is_win and "dive.exe" or "dive"

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
            error("dive: neither archive (" .. archive .. ") nor extracted binary exists")
        end
    else
        if os.isfile(archive) then
            system.exec(string.format([[tar -xzf "%s" -C "%s"]], normalized, dir))
        elseif os.isfile(parent .. "/" .. exe) then
            os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
        else
            error("dive: neither archive (" .. archive .. ") nor extracted binary exists")
        end
        if os.isfile(dir .. "/" .. exe) then
            system.exec(string.format([[chmod +x "%s"]], dir .. "/" .. exe))
        end
    end

    payload.require({ exe })
    return true
end

function config()
    xvm.add("dive", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("dive")
    return true
end
