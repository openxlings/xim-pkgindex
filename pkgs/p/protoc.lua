-- Protocol Buffers compiler (`protoc`) and well-known `.proto` includes.
--
-- Platforms and upstream release assets (protocolbuffers/protobuf v36.2):
--   linux    x86_64, aarch64   protoc-<ver>-linux-{x86_64,aarch_64}.zip
--   macosx   x86_64, aarch64   protoc-<ver>-osx-{x86_64,aarch_64}.zip
--   windows  x86_64            protoc-<ver>-win64.zip
--
-- All upstream archives are flat `.zip` files containing `bin/protoc[.exe]`,
-- `include/google/protobuf/*.proto`, and `readme.txt` with no top-level
-- directory wrapper. Both `bin/` and `include/` are preserved side-by-side
-- inside `pkginfo.install_dir()` so `protoc` resolves well-known types
-- (`google/protobuf/timestamp.proto`, etc.) via `../include` automatically.
--
-- Binary inspection (v36.2):
--   * Linux x86_64 & aarch64: statically linked ELF executables with no
--     PT_INTERP and no dynamic section / DT_NEEDED entries (no xim:glibc or
--     xim:gcc-runtime runtime dep needed).
--   * Windows win64: PE32+ x86-64 executable importing only OS system DLLs
--     (`ADVAPI32.dll`, `dbghelp.dll`, `KERNEL32.dll`, `msvcrt.dll`), so no
--     `xim:vcruntime` runtime dep is needed. Upstream publishes no Windows
--     ARM64 release asset.
--
-- All SHA256 digests match the GitHub release asset digests and locally
-- computed hashes on the downloaded v36.2 archives.

package = {
    spec = "2",

    name = "protoc",
    description = "Protocol Buffers compiler (protoc) and well-known .proto definitions",
    homepage = "https://protobuf.dev",
    authors = {"Google Inc."},
    maintainers = {"https://github.com/protocolbuffers/protobuf"},
    licenses = {"BSD-3-Clause"},
    repo = "https://github.com/protocolbuffers/protobuf",
    docs = "https://protobuf.dev/reference/protobuf/",
    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"compiler", "protobuf", "serialization", "tools"},
    keywords = {"protoc", "protobuf", "protocol-buffers", "grpc", "idl", "compiler"},

    programs = {"protoc"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/protocolbuffers/protobuf/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/protocolbuffers/protobuf/releases/download/${tag}/protoc-${version}-linux-x86_64.zip",
                            aarch64 = "https://github.com/protocolbuffers/protobuf/releases/download/${tag}/protoc-${version}-linux-aarch_64.zip",
                        },
                        macosx = {
                            x86_64 = "https://github.com/protocolbuffers/protobuf/releases/download/${tag}/protoc-${version}-osx-x86_64.zip",
                            aarch64 = "https://github.com/protocolbuffers/protobuf/releases/download/${tag}/protoc-${version}-osx-aarch_64.zip",
                        },
                        windows = {
                            x86_64 = "https://github.com/protocolbuffers/protobuf/releases/download/${tag}/protoc-${version}-win64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            ["latest"] = { ref = "36.2" },
            ["36.2"] = {
                x86_64 = {
                    url = "https://github.com/protocolbuffers/protobuf/releases/download/v36.2/protoc-36.2-linux-x86_64.zip",
                    sha256 = "121f6c7afe1d4d0e3ea6aab9432038599250134cbf4474cb1167d2c7decd4278",
                },
                aarch64 = {
                    url = "https://github.com/protocolbuffers/protobuf/releases/download/v36.2/protoc-36.2-linux-aarch_64.zip",
                    sha256 = "8b8f18bd2b30346efbc698dd5a73dd7c805f3ef8380f6dfc95c768f3f1852f6a",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "36.2" },
            ["36.2"] = {
                x86_64 = {
                    url = "https://github.com/protocolbuffers/protobuf/releases/download/v36.2/protoc-36.2-osx-x86_64.zip",
                    sha256 = "228cc7add4616cc14ca5e80dee83209d44449a7aee95a914ae748fa374efb078",
                },
                aarch64 = {
                    url = "https://github.com/protocolbuffers/protobuf/releases/download/v36.2/protoc-36.2-osx-aarch_64.zip",
                    sha256 = "9cd98a532c5c5e0c4161314de0225de27e4c8a323917b6ea7b1b714d3ae23466",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "36.2" },
            ["36.2"] = {
                x86_64 = {
                    url = "https://github.com/protocolbuffers/protobuf/releases/download/v36.2/protoc-36.2-win64.zip",
                    sha256 = "f0c128dc0d8492eceece83bb459a4c0e316764b929ffbf1aa416357fd644edd3",
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

local function is_windows_target(archive, dir)
    local normalized = tostring(archive or ""):gsub("\\", "/")
    if normalized:match("%-win64%.zip$") or normalized:match("%-win32%.zip$") then
        return true
    end
    if os.getenv("OS") == "Windows_NT" then
        return true
    end
    local d = tostring(dir or "")
    return d:match("^[A-Za-z]:") ~= nil or d:find("\\", 1, true) ~= nil
end

function installed()
    return payload.present({ "bin/protoc", "include/google/protobuf/timestamp.proto" })
        or payload.present({ "bin/protoc.exe", "include/google/protobuf/timestamp.proto" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("protoc: install_file is empty")
    end
    local dir = pkginfo.install_dir()
    local is_win = is_windows_target(archive, dir)
    local exe_rel = is_win and "bin/protoc.exe" or "bin/protoc"

    -- Flat archive: extract directly from install_file() into install_dir() so
    -- bin/ and include/ never mix with other flat archives in runtimedir.
    os.tryrm(dir)
    fs.mkdir_p(dir)

    if is_win then
        local sysroot = winpath.native(os.getenv("SystemRoot") or "C:\\Windows"):gsub("\\+$", "")
        local systar = sysroot .. "\\System32\\tar.exe"
        -- exec-quoting-ok: the first token is the system's tar.exe, which cmd.exe must see unquoted
        system.exec(string.format('%s -xf "%s" -C "%s"',
                                  systar, winpath.native(archive), winpath.native(dir)))
    elseif os.isfile(archive) then
        system.exec(string.format('unzip -q -o "%s" -d "%s"', archive, dir))
    else
        error("protoc: archive not found at " .. archive)
    end

    if not is_win and os.isfile(dir .. "/" .. exe_rel) then
        system.exec(string.format('chmod +x "%s"', dir .. "/" .. exe_rel))
    end

    payload.require({ exe_rel, "include/google/protobuf/timestamp.proto" })
    return true
end

function config()
    xvm.add("protoc", { bindir = pkginfo.install_dir() .. "/bin" })
    return true
end

function uninstall()
    xvm.remove("protoc")
    return true
end
