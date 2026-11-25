-- Buf - CLI for working with Protocol Buffers.
--
-- Verified 2026-11-25 against upstream bufbuild/buf release v1.75.0:
--   * Every SHA256 below was verified against upstream sha256.txt and the
--     downloaded archives.
--   * All six archives (Linux x86_64/aarch64, Darwin x86_64/arm64, Windows
--     x86_64/arm64) unpack under a single `buf/` directory containing
--     `bin/buf[.exe]`, `bin/protoc-gen-buf-lint[.exe]`,
--     `bin/protoc-gen-buf-breaking[.exe]`, and `LICENSE`.
--   * Linux ELF binaries on both x86_64 and aarch64 are statically linked Go
--     executables (no dynamic section, no external libc dependency).
--   * Windows PE binaries on both x86_64 and arm64 import only kernel32.dll
--     (no MSVC runtime dependency).
package = {
    spec = "2",

    name = "buf",
    description = "The best way of working with Protocol Buffers",
    homepage = "https://buf.build",
    authors = {"Buf Technologies, Inc."},
    maintainers = {"https://github.com/bufbuild/buf/graphs/contributors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/bufbuild/buf",
    docs = "https://buf.build/docs/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"protobuf", "grpc", "cli", "tools"},
    keywords = {"buf", "protobuf", "proto", "grpc", "linter", "codegen"},

    programs = {"buf"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/bufbuild/buf/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/bufbuild/buf/releases/download/${tag}/buf-Linux-x86_64.tar.gz",
                            aarch64 = "https://github.com/bufbuild/buf/releases/download/${tag}/buf-Linux-aarch64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/bufbuild/buf/releases/download/${tag}/buf-Darwin-x86_64.tar.gz",
                            aarch64 = "https://github.com/bufbuild/buf/releases/download/${tag}/buf-Darwin-arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/bufbuild/buf/releases/download/${tag}/buf-Windows-x86_64.zip",
                            aarch64 = "https://github.com/bufbuild/buf/releases/download/${tag}/buf-Windows-arm64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/bufbuild/buf/releases/download/v${version}/buf-Linux-${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.75.0" },
            ["1.75.0"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "aarch64" },
                sha256 = {
                    x86_64 = "7168a06e29bd5eb8d1530848f242264f7a86b9b8af3b2e811570fbea0c929a30",
                    aarch64 = "0fe2cf43cff973e27a09219e611d98101cb22b0fee398f10f2be2256dd7f892e",
                },
            },
        },
        macosx = {
            source = "https://github.com/bufbuild/buf/releases/download/v${version}/buf-Darwin-${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.75.0" },
            ["1.75.0"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "d04292081e76c19c613d2411b2d0b3619d6d49d54ce6cbcf9e12f72edce0532b",
                    aarch64 = "5478531c4645c5b80866e87d76d73f0e8bf5a35644b12c92cbdcc408e7c8b9d3",
                },
            },
        },
        windows = {
            source = "https://github.com/bufbuild/buf/releases/download/v${version}/buf-Windows-${arch_alias}.zip",
            ["latest"] = { ref = "1.75.0" },
            ["1.75.0"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "3d580339622823a2ea48ec1f0a401b8c5686144ef51f88d19ce17af7c54588fc",
                    aarch64 = "925e977a031c6ff389cfac21c0363f0c0d3d6b0e81a5d6cf17691694bc68857b",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

local function expected_files(ext)
    return {
        "bin/buf" .. ext,
        "bin/protoc-gen-buf-lint" .. ext,
        "bin/protoc-gen-buf-breaking" .. ext,
        "LICENSE",
    }
end

function installed()
    return payload.present(expected_files(""))
        or payload.present(expected_files(".exe"))
end

function install()
    local archive = tostring(pkginfo.install_file())
    local is_win = archive:gsub("\\", "/"):match("%.zip$") ~= nil

    payload.unpack{ extracted = "buf", strip = 1 }
    payload.require(expected_files(is_win and ".exe" or ""))
    return true
end

function config()
    local bindir = pkginfo.install_dir() .. "/bin"
    local root = "buf@" .. pkginfo.version()
    xvm.add("buf", { bindir = bindir })
    xvm.add("protoc-gen-buf-lint", { bindir = bindir, binding = root })
    xvm.add("protoc-gen-buf-breaking", { bindir = bindir, binding = root })
    return true
end

function uninstall()
    xvm.remove("protoc-gen-buf-breaking")
    xvm.remove("protoc-gen-buf-lint")
    xvm.remove("buf")
    return true
end
