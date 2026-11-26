-- pkl - A configuration as code language with rich validation and tooling (apple/pkl).
--
-- Platform and architecture coverage (verified against apple/pkl 0.33.1):
--   linux    x86_64, aarch64   pkl-linux-{amd64,aarch64}   (dynamic ELF; DT_NEEDED: libz.so.1, libpthread.so.0, libdl.so.2, librt.so.1, libc.so.6[, ld-linux-aarch64.so.1])
--   macosx   aarch64           pkl-macos-aarch64           (Mach-O 64-bit arm64; upstream dropped macos-amd64 in 0.33.0)
--   windows  x86_64            pkl-windows-amd64.exe       (PE32+ console x86-64; imports VCRUNTIME140.dll & VCRUNTIME140_1.dll -> app-local xim:vcruntime)
--
-- Every asset is a standalone single-file GraalVM Native Image executable with a
-- distinct filename (no archive container and no materialize basename collision),
-- verified against GitHub release asset digests and hashed locally (SHA-256).
--
-- Linking:
--   linux/x86_64, linux/aarch64: dynamically linked GraalVM Native Image ELFs
--     needing glibc + zlib (`libz.so.1`, `libpthread.so.0`, `libdl.so.2`,
--     `librt.so.1`, `libc.so.6`, plus `ld-linux-aarch64.so.1` on aarch64).
--     Declares `xim:glibc@>=2.39` and `xim:zlib` runtime dependencies so
--     xlings elfpatch stamps PT_INTERP and RPATH to the subos closure.
--   windows/x86_64: PE32+ importing `VCRUNTIME140.dll`, `VCRUNTIME140_1.dll`,
--     UCRT API-set DLLs, and Windows system DLLs; declares `xim:vcruntime` and
--     copies CRT DLLs app-local beside `pkl.exe` in `install()`.

package = {
    spec = "2",

    name = "pkl",
    description = "A configuration as code language with rich validation and tooling",
    homepage = "https://pkl-lang.org",
    authors = {"Apple Inc."},
    maintainers = {"https://github.com/apple/pkl/graphs/contributors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/apple/pkl",
    docs = "https://pkl-lang.org/main/current/index.html",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"config", "language", "cli", "tools"},
    keywords = {"pkl", "configuration", "config", "validation", "json", "yaml"},

    programs = {"pkl"},
    xvm_enable = true,
    ci = { mirror = true },

    extensions = {
        autoupdate = {
            source = "https://github.com/apple/pkl/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/apple/pkl/releases/download/${tag}/pkl-linux-amd64",
                            aarch64 = "https://github.com/apple/pkl/releases/download/${tag}/pkl-linux-aarch64",
                        },
                        macosx = {
                            aarch64 = "https://github.com/apple/pkl/releases/download/${tag}/pkl-macos-aarch64",
                        },
                        windows = {
                            x86_64 = "https://github.com/apple/pkl/releases/download/${tag}/pkl-windows-amd64.exe",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            deps = {
                runtime = { "xim:glibc@>=2.39", "xim:zlib" },
            },
            source = "https://github.com/apple/pkl/releases/download/${version}/pkl-linux-${arch_alias}",
            ["latest"] = { ref = "0.33.1" },
            ["0.33.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "aarch64" },
                sha256 = {
                    x86_64 = "acbca9bb4f31139d09e295d03c9fb25f77edf5a74af4e772b56b32dc6dc17c44",
                    aarch64 = "4a752096dab13d7432e1f0a4f1219833df95e1e36ce0b8d424b0edb2cd5436f9",
                },
            },
        },
        macosx = {
            -- Upstream dropped pkl-macos-amd64 starting in 0.33.0.
            source = "https://github.com/apple/pkl/releases/download/${version}/pkl-macos-${arch_alias}",
            ["latest"] = { ref = "0.33.1" },
            ["0.33.1"] = {
                arch_alias = { aarch64 = "aarch64" },
                sha256 = {
                    aarch64 = "6f93ddf6524a5771bd4b6ebde11010c6dfee8e3a8906ffebaa8f52f8a0ba16b7",
                },
            },
        },
        windows = {
            -- Upstream publishes only pkl-windows-amd64.exe (no windows-arm64 asset).
            deps = {
                runtime = { "xim:vcruntime" },
            },
            source = "https://github.com/apple/pkl/releases/download/${version}/pkl-windows-${arch_alias}.exe",
            ["latest"] = { ref = "0.33.1" },
            ["0.33.1"] = {
                arch_alias = { x86_64 = "amd64" },
                sha256 = {
                    x86_64 = "b1da686befc4ce4d92fe81bd2892e7457a505328313380010c4791c7f68d7432",
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
    return os.isfile(dir .. "/pkl") or os.isfile(dir .. "/pkl.exe")
end

function install()
    local src = pkginfo.install_file()
    local dir = pkginfo.install_dir()
    local is_win = _is_windows_payload(src)
    local target = dir .. (is_win and "/pkl.exe" or "/pkl")

    if not os.isfile(src) then
        error("pkl: downloaded binary not found at " .. tostring(src))
    end

    os.tryrm(dir)
    fs.mkdir_p(dir)
    os.mv(src, target)

    if is_win then
        if not pkginfo.dep_install_dir then
            error("pkl: xim:vcruntime runtime dep lookup is unavailable")
        end
        local crt = assert(pkginfo.dep_install_dir("xim:vcruntime"),
                           "pkl: xim:vcruntime payload directory is missing")
        local copied = 0
        for _, dll in ipairs(fs.files(crt .. "/bin") or {}) do
            os.cp(dll, dir)
            copied = copied + 1
        end
        if copied == 0 then
            error("pkl: no CRT DLLs found in " .. crt .. "/bin")
        end
    else
        system.exec(string.format([[chmod +x "%s"]], target))
    end

    if not os.isfile(target) then
        error("pkl: executable missing after install at " .. target)
    end
    return true
end

function config()
    xvm.add("pkl", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("pkl")
    return true
end
