package = {
    spec = "2",

    -- base info
    name = "jdk8-temurin",
    description = "Eclipse Temurin JDK 8 — a production-ready binary build of OpenJDK (LTS)",

    homepage = "https://adoptium.net",
    repo = "https://github.com/adoptium/temurin8-binaries",
    docs = "https://adoptium.net/docs",
    authors = {"Eclipse Adoptium"},
    licenses = {"GPL-2.0-with-classpath-exception"},

    -- xim pkg info
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"language", "jvm", "runtime", "toolchain"},
    keywords = {"java", "jdk", "jdk8", "openjdk", "temurin", "jvm", "hotspot"},

    programs = {"java", "javac", "jar", "javadoc"},
    xvm_enable = true,

    -- WHY A SEPARATE PACKAGE FROM `jdk-temurin`
    --
    -- `jdk-temurin` tracks the modern OpenJDK feature stream (JDK 25, JEP 322
    -- version grammar, `jshell`, Apple Silicon macOS builds). Temurin 8 uses
    -- the legacy `8u<update>-b<build>` release tag / `8u<update>b<build>`
    -- filename scheme, predates `jshell` (introduced in JDK 9), and ships no
    -- `macosx aarch64` binary. Keeping `jdk8-temurin` separate lets users
    -- install JDK 8 cleanly alongside JDK 25 without conflating two different
    -- toolchains and platform matrices.
    --
    -- VERSION STRING & ALIASES — Canonical key `"8.0.512+9"` matches the
    -- Adoptium API semver for GA release `jdk8u512-b09` (2026-11-04). Note that
    -- `jdk8u514-b01` (2026-11-19) has Linux tarballs on GitHub but no Windows
    -- GA assets yet, so `8.0.512+9` is the latest cross-platform GA release.
    -- Two aliases are provided on every declared platform:
    --   * `["8.0.512"] = { ref = "8.0.512+9" }`  (plain dotted version)
    --   * `["8u512b09"] = { ref = "8.0.512+9" }` (Adoptium update/build tag)
    --
    -- WHY `extensions.autoupdate` IS OMITTED — `xpkgindex-update` (`manifest.py`)
    -- supports only a single `${version}` / `${version:dash}` /
    -- `${version:underscore}` slot in `tag`, and `expand()` only provides
    -- `${version}`, `${version:base}`, `${version:build}`, `${version:compact}`,
    -- and `${tag}`. It cannot map between tag `jdk8u512-b09`, version key
    -- `8.0.512+9`, and asset suffix `8u512b09`. Updates stay manual.
    --
    -- ARCH / PLATFORM COVERAGE — Covers `linux` (`x86_64`, `aarch64`) and
    -- `windows` (`x86_64`). `xpm.macosx` is deliberately omitted: Adoptium
    -- Temurin 8 ships no `macosx aarch64` (Apple Silicon) build (`x86_64` only),
    -- while CI `macos-latest` runs on `arm64` and `.github/scripts/posix-test.sh`
    -- invokes `xlings install` whenever `xpm.macosx` is present without
    -- checking per-platform architecture availability, causing
    -- `E_UNSUPPORTED_TARGET: has no macosx-aarch64 artifact`.
    -- `archs = {"x86_64", "aarch64"}` is the union across declared platforms.
    --
    -- PROVENANCE — Every URL and SHA256 is verified against the upstream
    -- GitHub release `.sha256.txt` sidecars and the Adoptium API for
    -- `jdk8u512-b09`.
    --
    -- CN MIRROR — TUNA (`mirrors.tuna.tsinghua.edu.cn/Adoptium/8/jdk/`) mirrors
    -- only the latest GA archive per OS/arch: `x64/linux` has already rotated
    -- to `8u514b01` (so `linux.x86_64` declares GLOBAL only), while
    -- `aarch64/linux` and `x64/windows` still serve the byte-identical
    -- `8u512b09` files (SHA256 verified against upstream).
    -- `ci.mirror` is omitted because CN institutional mirror legs are declared.
    --
    -- RUNTIME DEPS — deliberately NONE, for the same reason documented in
    -- `pkgs/j/jdk-temurin.lua`: HotSpot links libstdc++/libgcc statically, the
    -- only hard external dependency is glibc, and switching PT_INTERP without
    -- host AWT/sound deps (`libXtst`, `libasound`) would break AWT.

    xpm = {
        linux = {
            ["latest"] = { ref = "8.0.512+9" },
            ["8.0.512"] = { ref = "8.0.512+9" },
            ["8u512b09"] = { ref = "8.0.512+9" },
            ["8.0.512+9"] = {
                x86_64 = {
                    url = "https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u512-b09/OpenJDK8U-jdk_x64_linux_hotspot_8u512b09.tar.gz",
                    sha256 = "fb3bfa869012419b562bb4235d0d83ec4f8c1dda62ae432ba20c6c3a7e43f7e4",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u512-b09/OpenJDK8U-jdk_aarch64_linux_hotspot_8u512b09.tar.gz",
                        CN = "https://mirrors.tuna.tsinghua.edu.cn/Adoptium/8/jdk/aarch64/linux/OpenJDK8U-jdk_aarch64_linux_hotspot_8u512b09.tar.gz",
                    },
                    sha256 = "01263df22c4553f63146bbae807e70cd4628dd0d9ec7582f01cb2453f7c69aaa",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "8.0.512+9" },
            ["8.0.512"] = { ref = "8.0.512+9" },
            ["8u512b09"] = { ref = "8.0.512+9" },
            ["8.0.512+9"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u512-b09/OpenJDK8U-jdk_x64_windows_hotspot_8u512b09.zip",
                        CN = "https://mirrors.tuna.tsinghua.edu.cn/Adoptium/8/jdk/x64/windows/OpenJDK8U-jdk_x64_windows_hotspot_8u512b09.zip",
                    },
                    sha256 = "20f248ddd600f900cd9b235d50d54cdb27e7b750f140d381176a7612c53663cd",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

-- Convert canonical semver `"8.0.512+9"` to Adoptium's extracted directory
-- name `"jdk8u512-b09"`.
local function archive_root()
    local ver = pkginfo.version()
    local major, update, build = ver:match("^(%d+)%.%d+%.(%d+)%+(%d+)$")
    if major then
        return string.format("jdk%su%s-b%02d", major, update, tonumber(build))
    end
    return "jdk-" .. ver
end

local function payload_dir()
    return archive_root()
end

function install()
    local exe = os.host() == "windows" and "java.exe" or "java"
    local staged = path.join(pkginfo.install_dir(), "bin", exe)
    if os.isfile(staged) then return true end

    local payload = payload_dir()
    if os.isdir(payload) then
        os.tryrm(pkginfo.install_dir())
        os.mv(payload, pkginfo.install_dir())
    end

    if not os.isfile(staged) then
        log.error("jdk8-temurin: no java launcher at %s (payload dir: %s)", staged, payload)
        return false
    end
    return true
end

local PROGRAMS = { "java", "javac", "jar", "javadoc" }
local FLAVOR = "temurin"

local function flavor_version()
    return pkginfo.version() .. "-" .. FLAVOR
end

function config()
    local java_home = pkginfo.install_dir()
    local bindir = path.join(java_home, "bin")

    local binding = "jdk8-temurin@" .. pkginfo.version()
    xvm.add("jdk8-temurin", { type = "group" })

    local env = { JAVA_HOME = java_home }

    for _, prog in ipairs(PROGRAMS) do
        xvm.add(prog, {
            bindir = bindir,
            version = flavor_version(),
            binding = binding,
            envs = env,
        })
    end

    log.info("jdk8-temurin: JAVA_HOME = %s", java_home)
    log.info("jdk8-temurin: java/javac/jar/javadoc registered as %s; other JDK tools live in %s",
             flavor_version(), bindir)

    return true
end

function uninstall()
    -- Both removals are version-scoped: another installed JDK version (or, for
    -- the shared names, another JDK distribution) must keep its nodes.
    for _, prog in ipairs(PROGRAMS) do
        xvm.remove(prog, flavor_version())
    end
    xvm.remove("jdk8-temurin", pkginfo.version())
    return true
end
