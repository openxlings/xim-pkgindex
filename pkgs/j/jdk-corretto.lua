package = {
    spec = "2",

    -- base info
    name = "jdk-corretto",
    description = "Amazon Corretto — a no-cost, production-ready distribution of OpenJDK (LTS)",

    homepage = "https://aws.amazon.com/corretto/",
    repo = "https://github.com/corretto/corretto-25",
    docs = "https://docs.aws.amazon.com/corretto/",
    authors = {"Amazon Web Services"},
    licenses = {"GPL-2.0-with-classpath-exception"},

    -- xim pkg info
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"language", "jvm", "runtime", "toolchain"},
    keywords = {"java", "jdk", "openjdk", "corretto", "amazon", "aws", "jvm", "hotspot"},

    programs = {"java", "javac", "jar", "javadoc", "jshell"},
    xvm_enable = true,

    -- Second JDK distribution in the index, same shape as jdk-temurin.lua; only
    -- the parts that genuinely differ from it are spelled out below.
    --
    -- VERSION STRING — Corretto versions are five-part,
    -- `<feature>.<interim>.<update>.<build>.<revision>` (25.0.4.7.1 = OpenJDK
    -- 25.0.4+7, Corretto revision 1), so the version key is NOT what
    -- `java --version` prints (`openjdk 25.0.4`). Both spellings are accepted:
    -- `["25.0.4"] = { ref = "25.0.4.7.1" }` on every platform, same reason as
    -- jdk-temurin's `25.0.4` alias.
    --
    -- PROVENANCE — Corretto publishes no per-file checksum sidecar (the
    -- `.sha256` URL next to the archive is 403), but every GitHub release body
    -- in corretto/corretto-<feature> carries a version-pinned MD5/SHA256 table
    -- per artifact. The hashes below come from those tables (25.0.4.7.1 and
    -- 21.0.12.8.1) and were re-verified against the downloaded archives while
    -- publishing the CN mirror.
    --
    -- PAYLOAD LAYOUT — the one genuinely awkward part: each platform names its
    -- top-level directory from a different slice of the version, and none of
    -- them is the version key itself (see payload_candidates below).
    --
    -- ARCH / PLATFORM COVERAGE — linux and macosx ship x86_64 + aarch64,
    -- windows ships x86_64 only. Alpine (musl) tarballs exist upstream and are
    -- deliberately not wired up here; that needs the same real-machine elfpatch
    -- work jdk-temurin defers.
    --
    -- RUNTIME DEPS — none, for the reason recorded in jdk-temurin.lua: the only
    -- hard external dependency of a HotSpot JDK tree is glibc, libstdc++/libgcc
    -- are linked statically, and the X11/alsa/freetype users are the AWT/sound
    -- libs a headless JVM never loads.
    xpm = {
        linux = {
            ["latest"] = { ref = "25.0.4.7.1" },
            ["25.0.4"] = { ref = "25.0.4.7.1" },
            ["21.0.12"] = { ref = "21.0.12.8.1" },
            ["25.0.4.7.1"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://corretto.aws/downloads/resources/25.0.4.7.1/amazon-corretto-25.0.4.7.1-linux-x64.tar.gz",
                        CN = "https://gitcode.com/xlings-res/jdk-corretto/releases/download/25.0.4.7.1/amazon-corretto-25.0.4.7.1-linux-x64.tar.gz",
                    },
                    sha256 = "1d03a3bd5091728492d92f0ef341aca7d8885ece9a150119558f3e3d62b58745",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://corretto.aws/downloads/resources/25.0.4.7.1/amazon-corretto-25.0.4.7.1-linux-aarch64.tar.gz",
                        CN = "https://gitcode.com/xlings-res/jdk-corretto/releases/download/25.0.4.7.1/amazon-corretto-25.0.4.7.1-linux-aarch64.tar.gz",
                    },
                    sha256 = "90a07c1c693ac9333a8a6ec79432f0d13c0564fec6617b0222d43f86858f65b8",
                },
            },
            ["21.0.12.8.1"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://corretto.aws/downloads/resources/21.0.12.8.1/amazon-corretto-21.0.12.8.1-linux-x64.tar.gz",
                        CN = "https://gitcode.com/xlings-res/jdk-corretto/releases/download/21.0.12.8.1/amazon-corretto-21.0.12.8.1-linux-x64.tar.gz",
                    },
                    sha256 = "75faed442d38a89c27f920e45ab24f9f71ff8ca6b732bfea90cdb500decd3c6b",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://corretto.aws/downloads/resources/21.0.12.8.1/amazon-corretto-21.0.12.8.1-linux-aarch64.tar.gz",
                        CN = "https://gitcode.com/xlings-res/jdk-corretto/releases/download/21.0.12.8.1/amazon-corretto-21.0.12.8.1-linux-aarch64.tar.gz",
                    },
                    sha256 = "fd94500b0d3d7e6e040a9dc1b34cbe25046454e5e3047b68c1842fa6894e9bbc",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "25.0.4.7.1" },
            ["25.0.4"] = { ref = "25.0.4.7.1" },
            ["21.0.12"] = { ref = "21.0.12.8.1" },
            ["25.0.4.7.1"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://corretto.aws/downloads/resources/25.0.4.7.1/amazon-corretto-25.0.4.7.1-macosx-x64.tar.gz",
                        CN = "https://gitcode.com/xlings-res/jdk-corretto/releases/download/25.0.4.7.1/amazon-corretto-25.0.4.7.1-macosx-x64.tar.gz",
                    },
                    sha256 = "840b857016f2ab1a60a2aa5a68584b1da55f4ab953c1e2a207bde0a5114f683d",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://corretto.aws/downloads/resources/25.0.4.7.1/amazon-corretto-25.0.4.7.1-macosx-aarch64.tar.gz",
                        CN = "https://gitcode.com/xlings-res/jdk-corretto/releases/download/25.0.4.7.1/amazon-corretto-25.0.4.7.1-macosx-aarch64.tar.gz",
                    },
                    sha256 = "41e185be6b230cff4e9c85d33f9b092274a32e42113087f26d3b2e4f7909ab78",
                },
            },
            ["21.0.12.8.1"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://corretto.aws/downloads/resources/21.0.12.8.1/amazon-corretto-21.0.12.8.1-macosx-x64.tar.gz",
                        CN = "https://gitcode.com/xlings-res/jdk-corretto/releases/download/21.0.12.8.1/amazon-corretto-21.0.12.8.1-macosx-x64.tar.gz",
                    },
                    sha256 = "a018ae6221babf065f770479b1bf0ab0d23bea78ed18f236c40bb5d4736612ff",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://corretto.aws/downloads/resources/21.0.12.8.1/amazon-corretto-21.0.12.8.1-macosx-aarch64.tar.gz",
                        CN = "https://gitcode.com/xlings-res/jdk-corretto/releases/download/21.0.12.8.1/amazon-corretto-21.0.12.8.1-macosx-aarch64.tar.gz",
                    },
                    sha256 = "cb230d7ac82784a4438663cdaf91d0d04037a9b4fb99ea41e138d88ce1224ab7",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "25.0.4.7.1" },
            ["25.0.4"] = { ref = "25.0.4.7.1" },
            ["21.0.12"] = { ref = "21.0.12.8.1" },
            ["25.0.4.7.1"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://corretto.aws/downloads/resources/25.0.4.7.1/amazon-corretto-25.0.4.7.1-windows-x64-jdk.zip",
                        CN = "https://gitcode.com/xlings-res/jdk-corretto/releases/download/25.0.4.7.1/amazon-corretto-25.0.4.7.1-windows-x64-jdk.zip",
                    },
                    sha256 = "3e9126f1af6ecdcae0104e5adfe21b15de0b406319c9b5bba4dacd6bfc0bfc9d",
                },
            },
            ["21.0.12.8.1"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://corretto.aws/downloads/resources/21.0.12.8.1/amazon-corretto-21.0.12.8.1-windows-x64-jdk.zip",
                        CN = "https://gitcode.com/xlings-res/jdk-corretto/releases/download/21.0.12.8.1/amazon-corretto-21.0.12.8.1-windows-x64-jdk.zip",
                    },
                    sha256 = "de9ad88fb2575a1aff4715b192014ba31edd6e411d243371f377cff0560e34bc",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

local PROGRAMS = { "java", "javac", "jar", "javadoc", "jshell" }
local FLAVOR = "corretto"

local function flavor_version()
    return pkginfo.version() .. "-" .. FLAVOR
end

-- The downloaded archive's own name minus its extension. `pkginfo.install_file()`
-- is the archive path (verified on the current C++ xim runtime), and for
-- Corretto's linux tarballs that stem IS the extracted top-level directory --
-- including the arch token this hook cannot otherwise learn, since os.arch() is
-- not bound in hooks and _RUNTIME.arch is empty (see node.lua).
local function archive_stem()
    local file = pkginfo.install_file() or ""
    local base = file:match("[^/\\]+$") or ""
    base = base:gsub("%.tar%.gz$", "")
    base = base:gsub("%.zip$", "")
    return base
end

-- Every platform names its payload directory from a different slice of the
-- five-part version, and none of them is the version key itself:
--
--   linux    amazon-corretto-25.0.4.7.1-linux-x64/bin/java   (full version + arch)
--   macosx   amazon-corretto-25.jdk/Contents/Home/bin/java   (feature only, .jdk bundle)
--   windows  jdk25.0.4_7/bin/java.exe                        (java version + build)
--
-- macOS is the same signed-bundle shape as Temurin, so the payload is again the
-- inner Contents/Home and install_dir() ends up being JAVA_HOME everywhere.
local function payload_candidates()
    local version = pkginfo.version()
    local host = os.host()

    if host == "macosx" then
        local feature = version:match("^(%d+)")
        return { path.join("amazon-corretto-" .. (feature or version) .. ".jdk",
                           "Contents", "Home") }
    end

    if host == "windows" then
        local java_version, build = version:match("^(%d+%.%d+%.%d+)%.(%d+)")
        if java_version then
            return { "jdk" .. java_version .. "_" .. build }
        end
        return { "jdk" .. version }
    end

    -- linux: the archive stem is exact; the arch spellings are a fallback for an
    -- engine that hands the hook no archive path.
    local candidates = {}
    local stem = archive_stem()
    if stem ~= "" then table.insert(candidates, stem) end
    for _, token in ipairs({ "x64", "aarch64" }) do
        table.insert(candidates, "amazon-corretto-" .. version .. "-linux-" .. token)
    end
    return candidates
end

function install()
    -- Idempotent across xim engines, and never report success without a real
    -- launcher in place -- see jdk-temurin.lua for the full rationale.
    local exe = os.host() == "windows" and "java.exe" or "java"
    local staged = path.join(pkginfo.install_dir(), "bin", exe)
    if os.isfile(staged) then return true end

    local candidates = payload_candidates()
    for _, payload in ipairs(candidates) do
        if os.isdir(payload) then
            os.tryrm(pkginfo.install_dir())
            os.mv(payload, pkginfo.install_dir())
            break
        end
    end

    if not os.isfile(staged) then
        log.error("jdk-corretto: no java launcher at %s (tried: %s)",
                  staged, table.concat(candidates, ", "))
        return false
    end
    return true
end

function config()
    -- install_dir() is the JDK home on every platform (see payload_candidates).
    local java_home = pkginfo.install_dir()
    local bindir = path.join(java_home, "bin")

    -- Binding-group root: `type = "group"` because the node names no artifact,
    -- so it never becomes an orphan shim (openxlings/xlings#452).
    local binding = "jdk-corretto@" .. pkginfo.version()
    xvm.add("jdk-corretto", { type = "group" })

    -- `java`/`javac`/... are shared with every other JDK distribution, and xvm
    -- refuses a second package claiming an exact (name, version) pair -- with
    -- the plain version, installing this package would make jdk-temurin
    -- uninstallable and vice versa. Flavor-scope them, as musl-gcc.lua does for
    -- `gcc`. JAVA_HOME rides on the shims because maven/gradle/IDEs locate a JDK
    -- through it rather than PATH; it does not leak into the user's shell.
    local env = { JAVA_HOME = java_home }
    for _, prog in ipairs(PROGRAMS) do
        xvm.add(prog, {
            bindir = bindir,
            version = flavor_version(),
            binding = binding,
            envs = env,
        })
    end

    log.info("jdk-corretto: JAVA_HOME = %s", java_home)
    log.info("jdk-corretto: java/javac/jar/javadoc/jshell registered as %s; other JDK tools live in %s",
             flavor_version(), bindir)

    return true
end

function uninstall()
    -- Version-scoped: another installed version, or another JDK distribution
    -- sharing these names, must keep its own nodes.
    for _, prog in ipairs(PROGRAMS) do
        xvm.remove(prog, flavor_version())
    end
    xvm.remove("jdk-corretto", pkginfo.version())
    return true
end
