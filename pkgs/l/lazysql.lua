-- lazysql - A cross-platform TUI database management tool written in Go (jorgerojas26/lazysql).
--
-- Platform and architecture coverage (verified against jorgerojas26/lazysql v0.7.0):
--   linux    x86_64, aarch64   lazysql_Linux_<arch>.tar.gz   (static Go ELF, no .dynamic section)
--   macosx   x86_64, aarch64   lazysql_Darwin_<arch>.tar.gz  (official Mach-O 64-bit binary)
--   windows  x86_64, aarch64   lazysql_Windows_<arch>.zip    (official PE32+ console binary, imports kernel32.dll only)
--
-- Upstream also publishes i386 assets, which are outside xlings' archs matrix.
-- Upstream release asset filenames are unversioned under releases/download/v<version>/.
-- All upstream archives are flat at root (`lazysql` / `lazysql.exe`, `LICENSE.txt`, `README.md`)
-- with no top-level wrapper directory. Every SHA256 below was verified against both upstream
-- `lazysql_0.7.0_checksums.txt` and locally downloaded release archives.

package = {
    spec = "2",

    name = "lazysql",
    description = "A cross-platform TUI database management tool written in Go",
    homepage = "https://github.com/jorgerojas26/lazysql",
    authors = {"Jorge Rojas"},
    maintainers = {"Jorge Rojas"},
    licenses = {"MIT"},
    repo = "https://github.com/jorgerojas26/lazysql",
    docs = "https://github.com/jorgerojas26/lazysql#readme",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"database", "sql", "tui", "cli", "tools"},
    keywords = {"lazysql", "sql", "database", "postgres", "mysql", "sqlite", "tui", "go"},

    programs = {"lazysql"},
    xvm_enable = true,
    ci = { mirror = true },

    extensions = {
        autoupdate = {
            source = "https://github.com/jorgerojas26/lazysql/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/jorgerojas26/lazysql/releases/download/${tag}/lazysql_Linux_x86_64.tar.gz",
                            aarch64 = "https://github.com/jorgerojas26/lazysql/releases/download/${tag}/lazysql_Linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/jorgerojas26/lazysql/releases/download/${tag}/lazysql_Darwin_x86_64.tar.gz",
                            aarch64 = "https://github.com/jorgerojas26/lazysql/releases/download/${tag}/lazysql_Darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/jorgerojas26/lazysql/releases/download/${tag}/lazysql_Windows_x86_64.zip",
                            aarch64 = "https://github.com/jorgerojas26/lazysql/releases/download/${tag}/lazysql_Windows_arm64.zip",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/jorgerojas26/lazysql/releases/download/v${version}/lazysql_Linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.7.0" },
            ["0.7.0"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "ebc3edeb848c7e557f88177cf6b2ca7e492ef158e2aa1dce18eb137d1d0726fc",
                    aarch64 = "2157e58f107bd9c250ad4d106e31d3f3484cfd93280b1c59f25a2dd0965e9128",
                },
            },
        },
        macosx = {
            source = "https://github.com/jorgerojas26/lazysql/releases/download/v${version}/lazysql_Darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.7.0" },
            ["0.7.0"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "9a070da390bc024ee9da14435ef3801ef7fd25c6387458fea9a3d0f549ad46b4",
                    aarch64 = "b6e6ac70d67f737cb8cf8e88a076e697f0b171518adc31d9c88f4e06856c81a1",
                },
            },
        },
        windows = {
            source = "https://github.com/jorgerojas26/lazysql/releases/download/v${version}/lazysql_Windows_${arch_alias}.zip",
            ["latest"] = { ref = "0.7.0" },
            ["0.7.0"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "f005142f0f9b4a6ee8f8752df7ef349bd5541f991d162934b242a56a487bf363",
                    aarch64 = "b6635f499d5847c07c4c0d7ff7c44bc7911167ccb8770623b0a8be0927a34c21",
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
    return payload.present({ "lazysql" }) or payload.present({ "lazysql.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("lazysql: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("%.zip$") ~= nil
    local exe = is_win and "lazysql.exe" or "lazysql"

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
            error("lazysql: neither archive (" .. archive .. ") nor extracted binary exists")
        end
    else
        if os.isfile(archive) then
            system.exec(string.format([[tar -xzf "%s" -C "%s"]], normalized, dir))
        elseif os.isfile(parent .. "/" .. exe) then
            os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
        else
            error("lazysql: neither archive (" .. archive .. ") nor extracted binary exists")
        end
        if os.isfile(dir .. "/" .. exe) then
            system.exec(string.format([[chmod +x "%s"]], dir .. "/" .. exe))
        end
    end

    payload.require({ exe })
    return true
end

function config()
    xvm.add("lazysql", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("lazysql")
    return true
end
