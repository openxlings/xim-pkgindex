-- oha — HTTP load generator with real-time TUI, inspired by rakyll/hey (hatoo/oha).
--
-- Distribution: upstream publishes raw single-file binaries on GitHub Releases
-- (no archive container). All 5 supported asset basenames are distinct across
-- platforms and architectures.
--
-- Verified against hatoo/oha release v1.17.0 (SHA-256 matched GitHub release
-- digests and downloaded bytes):
--   linux/x86_64    oha-linux-amd64        (ELF64 static-pie, readelf -d: no DT_NEEDED, ldd: statically linked)
--   linux/aarch64   oha-linux-arm64        (ELF64 static, readelf -d: no dynamic section, ldd: not a dynamic executable)
--   macosx/x86_64   oha-macos-amd64        (Mach-O 64-bit x86_64)
--   macosx/aarch64  oha-macos-arm64        (Mach-O 64-bit arm64)
--   windows/x86_64  oha-windows-amd64.exe  (PE32+ x86_64 console, imports VCRUNTIME140.dll -> xim:vcruntime)
--
-- Upstream v1.17.0 publishes no windows/arm64 binary, so windows covers x86_64 only.
-- Windows x86_64 copies app-local CRT DLLs from xim:vcruntime beside oha.exe.

package = {
    spec = "2",

    name = "oha",
    description = "HTTP load generator with real-time TUI, inspired by rakyll/hey",
    homepage = "https://github.com/hatoo/oha",
    authors = {"hatoo"},
    maintainers = {"https://github.com/hatoo/oha/graphs/contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/hatoo/oha",
    docs = "https://github.com/hatoo/oha#readme",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"http", "benchmark", "cli", "tools"},
    keywords = {"oha", "http", "load-testing", "benchmark", "tui", "rust"},

    programs = {"oha"},
    xvm_enable = true,

    -- Verified upstream release assets; no CN mirror has been verified.
    extensions = {
        autoupdate = {
            source = "https://github.com/hatoo/oha/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/hatoo/oha/releases/download/${tag}/oha-linux-amd64",
                            aarch64 = "https://github.com/hatoo/oha/releases/download/${tag}/oha-linux-arm64",
                        },
                        macosx = {
                            x86_64 = "https://github.com/hatoo/oha/releases/download/${tag}/oha-macos-amd64",
                            aarch64 = "https://github.com/hatoo/oha/releases/download/${tag}/oha-macos-arm64",
                        },
                        windows = {
                            x86_64 = "https://github.com/hatoo/oha/releases/download/${tag}/oha-windows-amd64.exe",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/hatoo/oha/releases/download/v${version}/oha-linux-${arch_alias}",
            ["latest"] = { ref = "1.17.0" },
            ["1.17.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "85c6eb98066b8c8bd513b2dd96fafd8f9863249ea653606bae1ca2e3a75c43d2",
                    aarch64 = "0b360c858f6277a5fca691d38adbd2dbc8c344d049ddf1a12fee8a762351ea24",
                },
            },
        },
        macosx = {
            source = "https://github.com/hatoo/oha/releases/download/v${version}/oha-macos-${arch_alias}",
            ["latest"] = { ref = "1.17.0" },
            ["1.17.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "c372c87b3273d60aeeb0516f026672bdbcf234638e06ce43a752142c54651ca3",
                    aarch64 = "2c58f2bac11ae23a12f6188a6723fd1882fa82f73d9874c2141eb78c222752c7",
                },
            },
        },
        windows = {
            deps = {
                runtime = { "xim:vcruntime" },
            },
            source = "https://github.com/hatoo/oha/releases/download/v${version}/oha-windows-${arch_alias}.exe",
            ["latest"] = { ref = "1.17.0" },
            ["1.17.0"] = {
                arch_alias = { x86_64 = "amd64" },
                sha256 = {
                    x86_64 = "3971644690672523c5d998874bef397cbc5d800cb1ba7164882eb7fe8f6027ac",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

local function _is_windows_payload(file)
    return tostring(file):lower():match("%.exe$") ~= nil
end

function installed()
    local dir = pkginfo.install_dir()
    return os.isfile(dir .. "/oha") or os.isfile(dir .. "/oha.exe")
end

function install()
    local src = pkginfo.install_file()
    local dir = pkginfo.install_dir()
    local is_win = _is_windows_payload(src)
    local target = dir .. (is_win and "/oha.exe" or "/oha")

    os.tryrm(dir)
    fs.mkdir_p(dir)
    os.mv(src, target)

    if is_win then
        if not pkginfo.dep_install_dir then
            error("oha: xim:vcruntime runtime dep lookup is unavailable")
        end
        local crt = assert(pkginfo.dep_install_dir("xim:vcruntime"),
                           "oha: xim:vcruntime payload directory is missing")
        local copied = 0
        for _, dll in ipairs(fs.files(crt .. "/bin") or {}) do
            os.cp(dll, dir)
            copied = copied + 1
        end
        if copied == 0 then
            error("oha: no CRT DLLs found in " .. crt .. "/bin")
        end
    else
        system.exec(string.format([[chmod +x "%s"]], target))
    end

    if not os.isfile(target) then
        error("oha: executable missing after install at " .. target)
    end
    return true
end

function config()
    xvm.add("oha", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("oha")
    return true
end
