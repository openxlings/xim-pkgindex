package = {
    spec = "2",

    -- base info
    name = "jdk11-temurin",
    description = "Eclipse Temurin JDK 11 — a production-ready binary build of OpenJDK (LTS)",

    homepage = "https://adoptium.net",
    repo = "https://github.com/adoptium/temurin11-binaries",
    docs = "https://adoptium.net/docs",
    authors = {"Eclipse Adoptium"},
    licenses = {"GPL-2.0-with-classpath-exception"},

    -- xim pkg info
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"language", "jvm", "runtime", "toolchain"},
    keywords = {"java", "jdk", "openjdk", "temurin", "jvm", "hotspot", "jdk11"},

    programs = {"java", "javac", "jar", "javadoc", "jshell"},
    xvm_enable = true,

    -- VERSION STRING — the canonical version key carries the OpenJDK build
    -- number (`11.0.33+10`), matching the upstream tag `jdk-11.0.33+10` and
    -- Adoptium API release name. Because `java -version` prints
    -- `openjdk version "11.0.33"` on its first line and `javac -version` prints
    -- `javac 11.0.33`, the plain alias `["11.0.33"] = { ref = "11.0.33+10" }`
    -- is declared on every platform.
    --
    -- PROVENANCE — Temurin (Eclipse Adoptium) 11.0.33+10, released 2026-11-04
    -- (the latest GA release covering all 5 targets; 11.0.33.1+1 omitted
    -- windows x86_64). Per-arch sha256 values were retrieved from the Adoptium
    -- API and cross-checked against upstream `.sha256.txt` sidecars; the
    -- linux x86_64 archive was downloaded and hashed locally.
    --
    -- MIRRORS — GLOBAL-only: USTC/NJU/GitCode mirrors do not host
    -- temurin11-binaries 11.0.33+10, and TUNA's Adoptium directory retains
    -- only the latest build per OS/arch (already 404 on linux x86_64 and
    -- macosx x86_64/aarch64 for 11.0.33_10).
    --
    -- RUNTIME DEPS — deliberately none (same HotSpot ELF/AWT rationale as
    -- jdk-temurin.lua).
    extensions = {
        autoupdate = {
            source = "https://github.com/adoptium/temurin11-binaries/releases",
            tag = "jdk-${version}",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/adoptium/temurin11-binaries/releases/download/jdk-${version}/OpenJDK11U-jdk_x64_linux_hotspot_${version:base}_${version:build}.tar.gz",
                            aarch64 = "https://github.com/adoptium/temurin11-binaries/releases/download/jdk-${version}/OpenJDK11U-jdk_aarch64_linux_hotspot_${version:base}_${version:build}.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/adoptium/temurin11-binaries/releases/download/jdk-${version}/OpenJDK11U-jdk_x64_mac_hotspot_${version:base}_${version:build}.tar.gz",
                            aarch64 = "https://github.com/adoptium/temurin11-binaries/releases/download/jdk-${version}/OpenJDK11U-jdk_aarch64_mac_hotspot_${version:base}_${version:build}.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/adoptium/temurin11-binaries/releases/download/jdk-${version}/OpenJDK11U-jdk_x64_windows_hotspot_${version:base}_${version:build}.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            ["latest"] = { ref = "11.0.33+10" },
            ["11.0.33"] = { ref = "11.0.33+10" },
            ["11.0.33+10"] = {
                x86_64 = {
                    url = "https://github.com/adoptium/temurin11-binaries/releases/download/jdk-11.0.33%2B10/OpenJDK11U-jdk_x64_linux_hotspot_11.0.33_10.tar.gz",
                    sha256 = "c4b8eaf56c93b95b689ffc08d155df1bcdbbffb666f8f71d21d97aedaea6f0ec",
                },
                aarch64 = {
                    url = "https://github.com/adoptium/temurin11-binaries/releases/download/jdk-11.0.33%2B10/OpenJDK11U-jdk_aarch64_linux_hotspot_11.0.33_10.tar.gz",
                    sha256 = "60b0fb79bb678b6fae3e499c7b0a353e68633ed0ab69d1a6bafe6092ed1e59e4",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "11.0.33+10" },
            ["11.0.33"] = { ref = "11.0.33+10" },
            ["11.0.33+10"] = {
                x86_64 = {
                    url = "https://github.com/adoptium/temurin11-binaries/releases/download/jdk-11.0.33%2B10/OpenJDK11U-jdk_x64_mac_hotspot_11.0.33_10.tar.gz",
                    sha256 = "11e3e9de3ce65ff957aee9b4b76876553e9d328cab9aede47996463625c88887",
                },
                aarch64 = {
                    url = "https://github.com/adoptium/temurin11-binaries/releases/download/jdk-11.0.33%2B10/OpenJDK11U-jdk_aarch64_mac_hotspot_11.0.33_10.tar.gz",
                    sha256 = "6ef5b027206691439b2dcb2fc05adc13cc7f5b6e75a08fce8f75ee188adc7751",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "11.0.33+10" },
            ["11.0.33"] = { ref = "11.0.33+10" },
            ["11.0.33+10"] = {
                x86_64 = {
                    url = "https://github.com/adoptium/temurin11-binaries/releases/download/jdk-11.0.33%2B10/OpenJDK11U-jdk_x64_windows_hotspot_11.0.33_10.zip",
                    sha256 = "cff2e75657c96a718974732b4a7b2c81a245a0b2ea44e6d8ea08cd0248d8fa9d",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

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
        log.error("jdk11-temurin: no java launcher at %s (payload dir: %s)", staged, payload)
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

    local binding = "jdk11-temurin@" .. pkginfo.version()
    xvm.add("jdk11-temurin", { type = "group" })

    local env = { JAVA_HOME = java_home }

    for _, prog in ipairs(PROGRAMS) do
        xvm.add(prog, {
            bindir = bindir,
            version = flavor_version(),
            binding = binding,
            envs = env,
        })
    end

    log.info("jdk11-temurin: JAVA_HOME = %s", java_home)
    log.info("jdk11-temurin: java/javac/jar/javadoc/jshell registered as %s; other JDK tools live in %s",
             flavor_version(), bindir)

    return true
end

function uninstall()
    for _, prog in ipairs(PROGRAMS) do
        xvm.remove(prog, flavor_version())
    end
    xvm.remove("jdk11-temurin", pkginfo.version())
    return true
end
