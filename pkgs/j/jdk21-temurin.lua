package = {
    spec = "2",

    -- base info
    name = "jdk21-temurin",
    description = "Eclipse Temurin JDK 21 — a production-ready binary build of OpenJDK (LTS)",

    homepage = "https://adoptium.net",
    repo = "https://github.com/adoptium/temurin21-binaries",
    docs = "https://adoptium.net/docs",
    authors = {"Eclipse Adoptium"},
    licenses = {"GPL-2.0-with-classpath-exception"},

    -- xim pkg info
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"language", "jvm", "runtime", "toolchain"},
    keywords = {"java", "jdk", "openjdk", "temurin", "jdk21", "jvm", "hotspot"},

    programs = {"java", "javac", "jar", "javadoc", "jshell"},
    xvm_enable = true,

    -- WHY A DEDICATED PACKAGE (`jdk21-temurin`)
    --
    -- `jdk-temurin` tracks the current latest feature line (JDK 25), whereas
    -- Java 21 is a widely pinned LTS line. Giving JDK 21 its own package name
    -- lets users install `jdk21-temurin` alongside `jdk-temurin` (or pin it in
    -- project toolchains) without conflicting over `latest`.
    --
    -- VERSION STRING — the canonical version key carries the OpenJDK build
    -- number (JEP 322: `$FEATURE.$INTERIM.$UPDATE+$BUILD` or four-part security
    -- patch `$FEATURE.$INTERIM.$UPDATE.$PATCH+$BUILD`), matching the upstream
    -- tag `jdk-21.0.13.1+2` and the Adoptium API release name. Because
    -- `java --version` prints only `openjdk 21.0.13.1` on its first line (the
    -- `+2` shows up in `Temurin-21.0.13.1+2 (build 21.0.13.1+2-LTS)`), every
    -- platform also declares `["21.0.13.1"] = { ref = "21.0.13.1+2" }` so both
    -- `xlings install jdk21-temurin@21.0.13.1` and `@21.0.13.1+2` resolve to
    -- the same resource.
    --
    -- PROVENANCE — Temurin (Eclipse Adoptium) 21.0.13.1+2, released 2026-11-18.
    -- Per-arch sha256 fetched from the Adoptium API
    -- (api.adoptium.net/v3/assets/latest/21/hotspot?image_type=jdk) and
    -- GitHub `.sha256.txt` sidecars, and re-verified byte-for-byte against the
    -- Tsinghua TUNA mirror (`mirrors.tuna.tsinghua.edu.cn/Adoptium/21/jdk/`).
    --
    -- CN MIRROR — every xpm URL is a {GLOBAL, CN} pair. GLOBAL is the Adoptium
    -- GitHub release; CN is TUNA's official Adoptium 21 mirror. Note that TUNA
    -- only keeps the newest JDK 21 release under `/Adoptium/21/jdk/<arch>/<os>/`
    -- and its archive path uses `${version:base}_${version:build}` without
    -- literal `${version}` or `${tag}`, so `extensions.autoupdate.resources`
    -- declares `GLOBAL` (`required = true`) only.
    --
    -- ARCH COVERAGE — Temurin 21.0.13.1+2 ships linux + macosx on
    -- x86_64/aarch64 and windows on x86_64 (no 21.0.13.1+2 windows-aarch64
    -- archive), so the windows entry has a single arch.
    --
    -- RUNTIME DEPS — deliberately NONE, for the same reason documented in
    -- `jdk-temurin.lua`: the only hard external DT_NEEDED set is glibc,
    -- libstdc++/libgcc_s are linked statically, and AWT/sound libs remain
    -- dynamically loaded off the host until `libXtst` / `libasound` exist in
    -- the index.
    extensions = {
        autoupdate = {
            source = "https://github.com/adoptium/temurin21-binaries/releases",
            tag = "jdk-${version}",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-${version}/OpenJDK21U-jdk_x64_linux_hotspot_${version:base}_${version:build}.tar.gz",
                            aarch64 = "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-${version}/OpenJDK21U-jdk_aarch64_linux_hotspot_${version:base}_${version:build}.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-${version}/OpenJDK21U-jdk_x64_mac_hotspot_${version:base}_${version:build}.tar.gz",
                            aarch64 = "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-${version}/OpenJDK21U-jdk_aarch64_mac_hotspot_${version:base}_${version:build}.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-${version}/OpenJDK21U-jdk_x64_windows_hotspot_${version:base}_${version:build}.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            ["latest"] = { ref = "21.0.13.1+2" },
            ["21.0.13.1"] = { ref = "21.0.13.1+2" },
            ["21.0.13.1+2"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.13.1%2B2/OpenJDK21U-jdk_x64_linux_hotspot_21.0.13.1_2.tar.gz",
                        CN = "https://mirrors.tuna.tsinghua.edu.cn/Adoptium/21/jdk/x64/linux/OpenJDK21U-jdk_x64_linux_hotspot_21.0.13.1_2.tar.gz",
                    },
                    sha256 = "bb8a93f9ae6e7a693b2b721e85dbeff26ae1a77447985a8d7afcdd9c7cf6222e",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.13.1%2B2/OpenJDK21U-jdk_aarch64_linux_hotspot_21.0.13.1_2.tar.gz",
                        CN = "https://mirrors.tuna.tsinghua.edu.cn/Adoptium/21/jdk/aarch64/linux/OpenJDK21U-jdk_aarch64_linux_hotspot_21.0.13.1_2.tar.gz",
                    },
                    sha256 = "8c72816a6b308842d5ed1f13e5826b69c567da4784f7238d7e800efa71fe54b1",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "21.0.13.1+2" },
            ["21.0.13.1"] = { ref = "21.0.13.1+2" },
            ["21.0.13.1+2"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.13.1%2B2/OpenJDK21U-jdk_x64_mac_hotspot_21.0.13.1_2.tar.gz",
                        CN = "https://mirrors.tuna.tsinghua.edu.cn/Adoptium/21/jdk/x64/mac/OpenJDK21U-jdk_x64_mac_hotspot_21.0.13.1_2.tar.gz",
                    },
                    sha256 = "1b5eff1741bb83d32e2e19aade71452bb42e40f047c01d3e178d438304c9a26d",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.13.1%2B2/OpenJDK21U-jdk_aarch64_mac_hotspot_21.0.13.1_2.tar.gz",
                        CN = "https://mirrors.tuna.tsinghua.edu.cn/Adoptium/21/jdk/aarch64/mac/OpenJDK21U-jdk_aarch64_mac_hotspot_21.0.13.1_2.tar.gz",
                    },
                    sha256 = "48067f2b7c958ed104a9d8a5749be7d25220b0a356b4d2d1bcfaab3e16ad0b14",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "21.0.13.1+2" },
            ["21.0.13.1"] = { ref = "21.0.13.1+2" },
            ["21.0.13.1+2"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.13.1%2B2/OpenJDK21U-jdk_x64_windows_hotspot_21.0.13.1_2.zip",
                        CN = "https://mirrors.tuna.tsinghua.edu.cn/Adoptium/21/jdk/x64/windows/OpenJDK21U-jdk_x64_windows_hotspot_21.0.13.1_2.zip",
                    },
                    sha256 = "bbebea1469996b276683c9299c227b294f85c847039c82633218186a4ad4fbf2",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

-- Every Temurin archive expands to a top-level `jdk-<version>/`, but what
-- sits under it is NOT uniform: linux and windows put the runtime right
-- there (`jdk-21.0.13.1+2/bin/java`), while macOS ships a signed .jdk bundle
-- and buries it one level down:
--
--   linux/windows  jdk-21.0.13.1+2/bin/java
--   macosx         jdk-21.0.13.1+2/Contents/Home/bin/java
--                  jdk-21.0.13.1+2/Contents/_CodeSignature/...
--
-- Moving the bundle root into install_dir on macOS would leave every shim
-- (and JAVA_HOME) pointing at a directory with no `bin/`, so the macOS
-- payload is the inner `Contents/Home`. After this, install_dir() IS
-- JAVA_HOME on all three platforms and the rest of the recipe is
-- arch/os-agnostic.
local function payload_dir()
    local root = "jdk-" .. pkginfo.version()
    if os.host() == "macosx" then
        return path.join(root, "Contents", "Home")
    end
    return root
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
        log.error("jdk21-temurin: no java launcher at %s (payload dir: %s)", staged, payload)
        return false
    end
    return true
end

-- Shared launcher names, and the flavor-tagged version they register under.
local PROGRAMS = { "java", "javac", "jar", "javadoc", "jshell" }
local FLAVOR = "temurin"

local function flavor_version()
    return pkginfo.version() .. "-" .. FLAVOR
end

function config()
    -- install_dir() is the JDK home on every platform (see payload_dir).
    local java_home = pkginfo.install_dir()
    local bindir = path.join(java_home, "bin")

    local binding = "jdk21-temurin@" .. pkginfo.version()
    xvm.add("jdk21-temurin", { type = "group" })

    local env = { JAVA_HOME = java_home }

    for _, prog in ipairs(PROGRAMS) do
        xvm.add(prog, {
            bindir = bindir,
            version = flavor_version(),
            binding = binding,
            envs = env,
        })
    end

    log.info("jdk21-temurin: JAVA_HOME = %s", java_home)
    log.info("jdk21-temurin: java/javac/jar/javadoc/jshell registered as %s; other JDK tools live in %s",
             flavor_version(), bindir)

    return true
end

function uninstall()
    -- Both removals are version-scoped: another installed JDK version (or, for
    -- the shared names, another JDK distribution) must keep its nodes.
    for _, prog in ipairs(PROGRAMS) do
        xvm.remove(prog, flavor_version())
    end
    xvm.remove("jdk21-temurin", pkginfo.version())
    return true
end
