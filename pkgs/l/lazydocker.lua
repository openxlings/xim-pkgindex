-- lazydocker - The lazier way to manage everything docker (jesseduffield/lazydocker).
--
-- Platform and architecture coverage (verified against jesseduffield/lazydocker v0.25.2):
--   linux    x86_64, aarch64   lazydocker_<ver>_Linux_<arch>.tar.gz   (static Go ELF, no .dynamic section)
--   macosx   x86_64, aarch64   lazydocker_<ver>_Darwin_<arch>.tar.gz  (official Mach-O 64-bit binary)
--   windows  x86_64, aarch64   lazydocker_<ver>_Windows_<arch>.zip    (official PE32+ console binary, imports kernel32.dll only)
--
-- Upstream also publishes armv6/armv7/x86 assets, which are outside xlings' archs matrix.
-- All upstream archives are flat at root (`lazydocker` / `lazydocker.exe`, `LICENSE`, `README.md`)
-- with no top-level wrapper directory. Every SHA256 below was verified against both upstream
-- `checksums.txt` and locally downloaded release archives.

package = {
    spec = "2",

    name = "lazydocker",
    description = "The lazier way to manage everything docker",
    homepage = "https://github.com/jesseduffield/lazydocker",
    authors = {"Jesse Duffield"},
    maintainers = {"Jesse Duffield"},
    licenses = {"MIT"},
    repo = "https://github.com/jesseduffield/lazydocker",
    docs = "https://github.com/jesseduffield/lazydocker#readme",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"docker", "containers", "tui", "cli", "tools"},
    keywords = {"lazydocker", "docker", "containers", "compose", "tui", "cli", "go"},

    programs = {"lazydocker"},
    xvm_enable = true,
    ci = { mirror = true },

    extensions = {
        autoupdate = {
            source = "https://github.com/jesseduffield/lazydocker/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/jesseduffield/lazydocker/releases/download/${tag}/lazydocker_${version}_Linux_x86_64.tar.gz",
                            aarch64 = "https://github.com/jesseduffield/lazydocker/releases/download/${tag}/lazydocker_${version}_Linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/jesseduffield/lazydocker/releases/download/${tag}/lazydocker_${version}_Darwin_x86_64.tar.gz",
                            aarch64 = "https://github.com/jesseduffield/lazydocker/releases/download/${tag}/lazydocker_${version}_Darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/jesseduffield/lazydocker/releases/download/${tag}/lazydocker_${version}_Windows_x86_64.zip",
                            aarch64 = "https://github.com/jesseduffield/lazydocker/releases/download/${tag}/lazydocker_${version}_Windows_arm64.zip",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/jesseduffield/lazydocker/releases/download/v${version}/lazydocker_${version}_Linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.25.2" },
            ["0.25.2"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "0d9dbfc26068b218e7ed84b104748cadc6e3cf733c0afd35465306fb39b9523c",
                    aarch64 = "005c38b685aaa557e7d646d83a3dadb5024340eeed8c6a2e1949eee6f530de23",
                },
            },
        },
        macosx = {
            source = "https://github.com/jesseduffield/lazydocker/releases/download/v${version}/lazydocker_${version}_Darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.25.2" },
            ["0.25.2"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "af70b6e234089aa24924db25fc201d17f224e76d334e743e4595d30cf83a013b",
                    aarch64 = "4a54d7b4abdf255b2bce9806641eac5568d5b7fbc820c1b5d3f9e34ea1367d60",
                },
            },
        },
        windows = {
            source = "https://github.com/jesseduffield/lazydocker/releases/download/v${version}/lazydocker_${version}_Windows_${arch_alias}.zip",
            ["latest"] = { ref = "0.25.2" },
            ["0.25.2"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "facae8869c1bf144468191c563002162273a2c2761f052659170530cae3fa8a9",
                    aarch64 = "25a4f4708b7f73a0aeadde13c8d7a172baa5a1ebabccb062765c28ae93029903",
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
    return payload.present({ "lazydocker" }) or payload.present({ "lazydocker.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("lazydocker: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("%.zip$") ~= nil
    local exe = is_win and "lazydocker.exe" or "lazydocker"

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
            error("lazydocker: neither archive (" .. archive .. ") nor extracted binary exists")
        end
    else
        if os.isfile(archive) then
            system.exec(string.format([[tar -xzf "%s" -C "%s"]], normalized, dir))
        elseif os.isfile(parent .. "/" .. exe) then
            os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
        else
            error("lazydocker: neither archive (" .. archive .. ") nor extracted binary exists")
        end
        if os.isfile(dir .. "/" .. exe) then
            system.exec(string.format([[chmod +x "%s"]], dir .. "/" .. exe))
        end
    end

    payload.require({ exe })
    return true
end

function config()
    xvm.add("lazydocker", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("lazydocker")
    return true
end
