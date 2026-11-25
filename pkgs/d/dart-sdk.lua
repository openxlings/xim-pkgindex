-- Dart SDK: libraries, command-line tools, and compilers for the Dart language.
--
-- Platforms and official Dart stable channel archives:
--   linux    x86_64, aarch64   dartsdk-linux-{x64,arm64}-release.zip + xim:glibc@>=2.39
--   macosx   x86_64, aarch64   dartsdk-macos-{x64,arm64}-release.zip
--   windows  x86_64, aarch64   dartsdk-windows-{x64,arm64}-release.zip
--
-- Linux ELF inspection (3.14.1, readelf -d):
--   x86_64:  INTERP /lib64/ld-linux-x86-64.so.2
--            NEEDED libdl.so.2, libpthread.so.0, libm.so.6, libc.so.6,
--                   ld-linux-x86-64.so.2 (plus librt.so.1, libresolv.so.2 on *_asan/msan/tsan)
--   aarch64: INTERP /lib/ld-linux-aarch64.so.1
--            NEEDED libm.so.6, libc.so.6 (plus libresolv.so.2 on *_asan/msan/tsan)
--   All DT_NEEDED sonames belong to xim:glibc (no libstdc++ or libgcc_s dependency),
--   so Linux declares `deps = { runtime = { "xim:glibc@>=2.39" } }` for full
--   RPATH/INTERP closure.
--
-- Windows PE inspection (3.14.1 x86_64):
--   dart.exe, dartaotruntime.exe, dartvm.exe, utils/gen_snapshot.exe, and
--   utils/wasm-opt.exe statically link the MSVC CRT and import only Windows OS
--   system DLLs (KERNEL32, ntdll, ADVAPI32, WS2_32, ole32, OLEAUT32, SHELL32,
--   SHLWAPI, IPHLPAPI, PSAPI, RPCRT4, bcrypt, CRYPT32, dbghelp,
--   api-ms-win-core-path-l1-1-0), so no `xim:vcruntime` runtime dep is needed.
--
-- Autoupdate note:
--   dart-lang/sdk on GitHub publishes no GitHub Releases and carries 89+ pages
--   of tags (exceeding xpkgindex-update's 50-request per-package budget), while
--   Google's authoritative release pointer (`.../stable/release/latest/VERSION`)
--   is JSON rather than a supported GitHub or Sparkle XML feed. Kept manual
--   like `flutter.lua` until JSON manifests are supported.

package = {
    spec = "2",

    name = "dart-sdk",
    description = "The Dart SDK - libraries, command-line tools, and compilers for the Dart programming language",
    homepage = "https://dart.dev",
    authors = {"The Dart Team"},
    maintainers = {"https://github.com/dart-lang/sdk"},
    licenses = {"BSD-3-Clause"},
    repo = "https://github.com/dart-lang/sdk",
    docs = "https://dart.dev/guides",
    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"sdk", "language", "compiler", "tools"},
    keywords = {"dart", "dart-sdk", "sdk", "language", "compiler", "aot"},

    programs = {"dart"},
    xvm_enable = true,

    xpm = {
        linux = {
            deps = {
                runtime = { "xim:glibc@>=2.39" },
            },
            source = "https://storage.googleapis.com/dart-archive/channels/stable/release/${version}/sdk/dartsdk-linux-${arch_alias}-release.zip",
            ["latest"] = { ref = "3.14.1" },
            ["3.14.1"] = {
                arch_alias = { x86_64 = "x64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "759bed01e0aeb50e1a0b0a19474ba5c80c6087ce1d37b3214e475c81a44430e8",
                    aarch64 = "c6e5581d478ac43ecf7d7028798b1bd10aef509f5e351184c755ec7eeeb1bea9",
                },
            },
        },
        macosx = {
            source = "https://storage.googleapis.com/dart-archive/channels/stable/release/${version}/sdk/dartsdk-macos-${arch_alias}-release.zip",
            ["latest"] = { ref = "3.14.1" },
            ["3.14.1"] = {
                arch_alias = { x86_64 = "x64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "3d440c968d4c1bb21c6d57eb1e3e364cea687899daef46b7cc99f07d328caaae",
                    aarch64 = "b670699f921bf307c3f2754b56349863ee9b2878661bcd446b50b90296e11311",
                },
            },
        },
        windows = {
            source = "https://storage.googleapis.com/dart-archive/channels/stable/release/${version}/sdk/dartsdk-windows-${arch_alias}-release.zip",
            ["latest"] = { ref = "3.14.1" },
            ["3.14.1"] = {
                arch_alias = { x86_64 = "x64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "fb2550f71e3408f2a69ff6ee29573f341991a927f8bc9ad0601dd3c9b19945c8",
                    aarch64 = "aca7650ed190f87446930893fa84442d90b5039d0b7e06e21318ed0cf7ddaddb",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

local REQUIRED_POSIX = {
    "bin/dart",
    "bin/dartaotruntime",
    "bin/snapshots/dartdev_aot.dart.snapshot",
    "version",
}

local REQUIRED_WINDOWS = {
    "bin/dart.exe",
    "bin/dartaotruntime.exe",
    "bin/snapshots/dartdev_aot.dart.snapshot",
    "version",
}

local POSIX_EXECUTABLES = {
    "bin/dart",
    "bin/dartaotruntime",
    "bin/dartaotruntime_asan",
    "bin/dartaotruntime_msan",
    "bin/dartaotruntime_tsan",
    "bin/dartcliruntime",
    "bin/dartcliruntime_asan",
    "bin/dartcliruntime_msan",
    "bin/dartcliruntime_tsan",
    "bin/dartvm",
    "bin/utils/gen_snapshot",
    "bin/utils/wasm-opt",
}

function installed()
    return payload.present(REQUIRED_POSIX) or payload.present(REQUIRED_WINDOWS)
end

function install()
    payload.unpack{ extracted = "dart-sdk", strip = 1 }

    local dir = pkginfo.install_dir()
    if os.isfile(dir .. "/bin/dart.exe") then
        payload.require(REQUIRED_WINDOWS)
    else
        for _, rel in ipairs(POSIX_EXECUTABLES) do
            local p = dir .. "/" .. rel
            if os.isfile(p) then
                system.exec(string.format('chmod +x "%s"', p))
            end
        end
        payload.require(REQUIRED_POSIX)
    end
    return true
end

function config()
    local bindir = pkginfo.install_dir() .. "/bin"
    xvm.add("dart-sdk", { type = "group" })
    xvm.add("dart", { bindir = bindir, binding = "dart-sdk@" .. pkginfo.version() })
    return true
end

function uninstall()
    xvm.remove("dart")
    xvm.remove("dart-sdk")
    return true
end
