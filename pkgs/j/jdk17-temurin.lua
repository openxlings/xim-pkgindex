package = {
    spec = "2",

    -- base info
    name = "jdk17-temurin",
    description = "Eclipse Temurin JDK 17 — a production-ready binary build of OpenJDK (LTS)",

    homepage = "https://adoptium.net",
    repo = "https://github.com/adoptium/temurin17-binaries",
    docs = "https://adoptium.net/docs",
    authors = {"Eclipse Adoptium"},
    licenses = {"GPL-2.0-with-classpath-exception"},

    -- xim pkg info
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"language", "jvm", "runtime", "toolchain"},
    keywords = {"java", "jdk", "openjdk", "temurin", "jvm", "hotspot"},

    programs = {"java", "javac", "jar", "javadoc", "jshell"},
    xvm_enable = true,

    -- VERSION STRING — the canonical version key carries the OpenJDK build
    -- number (`$FEATURE.$INTERIM.$UPDATE[.$PATCH]+$BUILD`), matching the
    -- upstream tag `jdk-17.0.21.1+2`. `java --version` prints only
    -- `openjdk 17.0.21.1` on its first line, so `["17.0.21.1"]` is provided
    -- as an alias on every platform: both `xlings install jdk17-temurin@17.0.21.1`
    -- and `@17.0.21.1+2` resolve to the same resource.
    --
    -- PROVENANCE — Temurin (Eclipse Adoptium) 17.0.21.1+2. Per-arch sha256
    -- fetched from the GitHub release `.sha256.txt` sidecars and verified
    -- byte-for-byte against both GitHub upstream and TUNA CN mirror archives.
    --
    -- CN MIRROR — every URL in `xpm` is a verified {GLOBAL, CN} pair where
    -- GLOBAL is the Adoptium GitHub release and CN is TUNA (`mirrors.tuna.tsinghua.edu.cn/Adoptium/17`).
    -- In `extensions.autoupdate`, CN is marked `required = false` because TUNA
    -- syncs periodically after upstream GitHub releases.
    --
    -- ARCH COVERAGE — Temurin 17 ships linux + macosx on x86_64/aarch64 and
    -- x86_64 only on windows.
    --
    -- RUNTIME DEPS — deliberately NONE, for the same reason documented in
    -- `jdk-temurin.lua`: HotSpot links libstdc++/libgcc statically, and switching
    -- PT_INTERP to xlings glibc without full X11/ALSA closure breaks AWT.
    extensions = {
        autoupdate = {
            source = "https://github.com/adoptium/temurin17-binaries/releases",
            tag = "jdk-${version}",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/adoptium/temurin17-binaries/releases/download/jdk-${version}/OpenJDK17U-jdk_x64_linux_hotspot_${version:base}_${version:build}.tar.gz",
                            aarch64 = "https://github.com/adoptium/temurin17-binaries/releases/download/jdk-${version}/OpenJDK17U-jdk_aarch64_linux_hotspot_${version:base}_${version:build}.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/adoptium/temurin17-binaries/releases/download/jdk-${version}/OpenJDK17U-jdk_x64_mac_hotspot_${version:base}_${version:build}.tar.gz",
                            aarch64 = "https://github.com/adoptium/temurin17-binaries/releases/download/jdk-${version}/OpenJDK17U-jdk_aarch64_mac_hotspot_${version:base}_${version:build}.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/adoptium/temurin17-binaries/releases/download/jdk-${version}/OpenJDK17U-jdk_x64_windows_hotspot_${version:base}_${version:build}.zip",
                        },
                    },
                    required = true,
                },
                CN = {
                    url = {
                        linux = {
                            x86_64 = "https://mirrors.tuna.tsinghua.edu.cn/Adoptium/17/jdk/x64/linux/OpenJDK17U-jdk_x64_linux_hotspot_${version:base}_${version:build}.tar.gz",
                            aarch64 = "https://mirrors.tuna.tsinghua.edu.cn/Adoptium/17/jdk/aarch64/linux/OpenJDK17U-jdk_aarch64_linux_hotspot_${version:base}_${version:build}.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://mirrors.tuna.tsinghua.edu.cn/Adoptium/17/jdk/x64/mac/OpenJDK17U-jdk_x64_mac_hotspot_${version:base}_${version:build}.tar.gz",
                            aarch64 = "https://mirrors.tuna.tsinghua.edu.cn/Adoptium/17/jdk/aarch64/mac/OpenJDK17U-jdk_aarch64_mac_hotspot_${version:base}_${version:build}.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://mirrors.tuna.tsinghua.edu.cn/Adoptium/17/jdk/x64/windows/OpenJDK17U-jdk_x64_windows_hotspot_${version:base}_${version:build}.zip",
                        },
                    },
                    required = false,
                },
            },
        },
    },

    xpm = {
        linux = {
            ["latest"] = { ref = "17.0.21.1+2" },
            ["17.0.21.1"] = { ref = "17.0.21.1+2" },
            ["17.0.21.1+2"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.21.1%2B2/OpenJDK17U-jdk_x64_linux_hotspot_17.0.21.1_2.tar.gz",
                        CN = "https://mirrors.tuna.tsinghua.edu.cn/Adoptium/17/jdk/x64/linux/OpenJDK17U-jdk_x64_linux_hotspot_17.0.21.1_2.tar.gz",
                    },
                    sha256 = "0b0ac5eab6db6abaec68c9913bcddb31321e5da411c45073d520d9c125e6f7b4",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.21.1%2B2/OpenJDK17U-jdk_aarch64_linux_hotspot_17.0.21.1_2.tar.gz",
                        CN = "https://mirrors.tuna.tsinghua.edu.cn/Adoptium/17/jdk/aarch64/linux/OpenJDK17U-jdk_aarch64_linux_hotspot_17.0.21.1_2.tar.gz",
                    },
                    sha256 = "1d808f4b558e9de63d8ba3ead21ffc8b9de204894eff3c19d52c1480aa17cc58",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "17.0.21.1+2" },
            ["17.0.21.1"] = { ref = "17.0.21.1+2" },
            ["17.0.21.1+2"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.21.1%2B2/OpenJDK17U-jdk_x64_mac_hotspot_17.0.21.1_2.tar.gz",
                        CN = "https://mirrors.tuna.tsinghua.edu.cn/Adoptium/17/jdk/x64/mac/OpenJDK17U-jdk_x64_mac_hotspot_17.0.21.1_2.tar.gz",
                    },
                    sha256 = "63a1469b52a8063a9f70e539f815093f3a33ef71e6f901b5f43545dbe4e72858",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.21.1%2B2/OpenJDK17U-jdk_aarch64_mac_hotspot_17.0.21.1_2.tar.gz",
                        CN = "https://mirrors.tuna.tsinghua.edu.cn/Adoptium/17/jdk/aarch64/mac/OpenJDK17U-jdk_aarch64_mac_hotspot_17.0.21.1_2.tar.gz",
                    },
                    sha256 = "2a88ccb044a8fb00957be93245da6357c11b55717511509d147cbcc5d93b2109",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "17.0.21.1+2" },
            ["17.0.21.1"] = { ref = "17.0.21.1+2" },
            ["17.0.21.1+2"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.21.1%2B2/OpenJDK17U-jdk_x64_windows_hotspot_17.0.21.1_2.zip",
                        CN = "https://mirrors.tuna.tsinghua.edu.cn/Adoptium/17/jdk/x64/windows/OpenJDK17U-jdk_x64_windows_hotspot_17.0.21.1_2.zip",
                    },
                    sha256 = "eafba0944f777abdc74d5aad16049c9b5a1275b6ce99e2939ba9f7f3e6f08c87",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

-- Every Temurin archive expands to a top-level `jdk-<version>/`:
--   linux/windows  jdk-17.0.21.1+2/bin/java
--   macosx         jdk-17.0.21.1+2/Contents/Home/bin/java
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
        log.error("jdk17-temurin: no java launcher at %s (payload dir: %s)", staged, payload)
        return false
    end
    return true
end

local PROGRAMS = { "java", "javac", "jar", "javadoc", "jshell" }
local FLAVOR = "temurin"

local function flavor_version()
    return pkginfo.version() .. "-" .. FLAVOR
end

function config()
    local java_home = pkginfo.install_dir()
    local bindir = path.join(java_home, "bin")

    local binding = "jdk17-temurin@" .. pkginfo.version()
    xvm.add("jdk17-temurin", { type = "group" })

    local env = { JAVA_HOME = java_home }

    for _, prog in ipairs(PROGRAMS) do
        xvm.add(prog, {
            bindir = bindir,
            version = flavor_version(),
            binding = binding,
            envs = env,
        })
    end

    log.info("jdk17-temurin: JAVA_HOME = %s", java_home)
    log.info("jdk17-temurin: java/javac/jar/javadoc/jshell registered as %s; other JDK tools live in %s",
             flavor_version(), bindir)

    return true
end

function uninstall()
    for _, prog in ipairs(PROGRAMS) do
        xvm.remove(prog, flavor_version())
    end
    xvm.remove("jdk17-temurin", pkginfo.version())
    return true
end
