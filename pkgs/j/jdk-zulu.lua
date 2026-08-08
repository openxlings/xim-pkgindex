package = {
    spec = "2",

    -- base info
    name = "jdk-zulu",
    description = "Azul Zulu Community — a TCK-certified, no-cost build of OpenJDK (LTS)",

    homepage = "https://www.azul.com/downloads/?package=jdk",
    repo = "https://github.com/zulu-openjdk/zulu-openjdk",
    docs = "https://docs.azul.com/core/",
    authors = {"Azul Systems"},
    licenses = {"GPL-2.0-with-classpath-exception"},

    -- xim pkg info
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"language", "jvm", "runtime", "toolchain"},
    keywords = {"java", "jdk", "openjdk", "zulu", "azul", "jvm", "hotspot"},

    programs = {"java", "javac", "jar", "javadoc", "jshell"},
    xvm_enable = true,

    -- Third JDK distribution in the index, same shape as jdk-temurin.lua; only
    -- the parts that genuinely differ from it are spelled out below.
    --
    -- VERSION STRING — Zulu carries TWO version numbers: its own distro version
    -- (zulu25.36.15) and the OpenJDK version it builds (jdk25.0.4). The version
    -- key here is the OpenJDK one, because that is what `java --version` prints
    -- and what a user asking for "JDK 25.0.4" means; the distro version stays
    -- visible in the archive names and in the mirror assets. Consequence worth
    -- knowing: if Azul ever re-releases the same OpenJDK version under a newer
    -- distro version, that is a new archive under an existing key -- add it as a
    -- fresh key rather than rewriting this one's sha256, so an existing install
    -- keeps resolving to the bytes it was pinned to.
    --
    -- SELECTION — packages come from api.azul.com/metadata/v1/zulu/packages with
    -- `java_package_type=jdk`, `javafx_bundled=false`, `release_status=ga`,
    -- `certifications=tck`, `availability_type=CA` (Community, the freely
    -- redistributable line). CRaC and musl builds are filtered out; they are
    -- different products, not architectures.
    --
    -- PROVENANCE — sha256 comes from that same API's per-package detail
    -- endpoint (`sha256_hash`), which is version-pinned, and was re-verified
    -- against the downloaded archives while publishing the CN mirror.
    --
    -- PAYLOAD LAYOUT — uniform and self-describing: the top-level directory is
    -- always the archive name minus its extension (macOS then nests the usual
    -- Contents/Home bundle inside it), so the hook derives it from the archive
    -- instead of hard-coding distro versions.
    --
    -- ARCH / PLATFORM COVERAGE — linux and macosx ship x86_64 + aarch64,
    -- windows ships x86_64 only.
    --
    -- RUNTIME DEPS — declared on linux since 2026-08-08; see the note on the
    -- `deps` table below for the measured closure and for why glibc is NOT in
    -- it. This supersedes the earlier "none" recorded here, which was correct
    -- only while `libXtst` and `libasound` were unpackaged.
    --
    -- Zulu differs from Temurin in one way that matters: its libjli.so,
    -- libsplashscreen.so and libinstrument.so name `libz.so.1`, which Temurin's
    -- do not. libjli is loaded by `bin/java` itself, so `xim:zlib` is a HARD dep
    -- here rather than an optional one — leave it out and `java` fails to start
    -- rather than degrading.
    xpm = {
        linux = {
            -- RUNTIME DEPS — the JDK's own NEEDED closure, measured rather than
            -- guessed. Every external SONAME its .so files name:
            --
            --   libXtst.so.6 libXi.so.6 libXext.so.6 libX11.so.6 libXrender.so.1
            --   libasound.so.2 libfreetype.so libz.so.1
            --
            -- libX11/libXext/libXi arrive transitively through libXtst, so only
            -- the roots are listed. fontconfig is here because the font path
            -- dlopens it -- it is not in any DT_NEEDED, which is exactly why
            -- DT_NEEDED alone is not a sufficient dependency list.
            --
            -- glibc is deliberately ABSENT. Declaring it would make the
            -- predicate-driven elfpatch switch PT_INTERP, and that must not
            -- happen until the closure resolves to us first: our loader has no
            -- host fallback (its baked ld.so.cache path exists nowhere), so
            -- switching early takes AWT down. Measured in 2026.8.8.1:
            -- `UnsatisfiedLinkError: libawt_xawt.so: libX11.so.6`.
            deps = {
                "xim:libXtst", "xim:libXrender", "xim:alsa-lib",
                "xim:freetype", "xim:fontconfig", "xim:zlib",
            },
            ["latest"] = { ref = "25.0.4" },
            ["25.0.4"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://cdn.azul.com/zulu/bin/zulu25.36.15-ca-jdk25.0.4-linux_x64.tar.gz",
                        CN = "https://gitcode.com/xlings-res/jdk-zulu/releases/download/25.0.4/zulu25.36.15-ca-jdk25.0.4-linux_x64.tar.gz",
                    },
                    sha256 = "e476f5c98952cb365ca77a814dbe3c74341e71ae76d1a87d1c0a69c7d2b1b2d0",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://cdn.azul.com/zulu/bin/zulu25.36.15-ca-jdk25.0.4-linux_aarch64.tar.gz",
                        CN = "https://gitcode.com/xlings-res/jdk-zulu/releases/download/25.0.4/zulu25.36.15-ca-jdk25.0.4-linux_aarch64.tar.gz",
                    },
                    sha256 = "ae04e25b16116ddd0f72cb387742d5122bb29c4b94f0fed08ff2bccc395f9daa",
                },
            },
            ["21.0.12"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://cdn.azul.com/zulu/bin/zulu21.52.15-ca-jdk21.0.12-linux_x64.tar.gz",
                        CN = "https://gitcode.com/xlings-res/jdk-zulu/releases/download/21.0.12/zulu21.52.15-ca-jdk21.0.12-linux_x64.tar.gz",
                    },
                    sha256 = "b1a9df12e798770d1b2db43b402a80f1e6080cff6d5d1d1fbe5c768fb4225f6a",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://cdn.azul.com/zulu/bin/zulu21.52.15-ca-jdk21.0.12-linux_aarch64.tar.gz",
                        CN = "https://gitcode.com/xlings-res/jdk-zulu/releases/download/21.0.12/zulu21.52.15-ca-jdk21.0.12-linux_aarch64.tar.gz",
                    },
                    sha256 = "dc7ed9ab7dfd33f2ddb1cd8311d3b00738497961a420533d81088051eac3f195",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "25.0.4" },
            ["25.0.4"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://cdn.azul.com/zulu/bin/zulu25.36.15-ca-jdk25.0.4-macosx_x64.tar.gz",
                        CN = "https://gitcode.com/xlings-res/jdk-zulu/releases/download/25.0.4/zulu25.36.15-ca-jdk25.0.4-macosx_x64.tar.gz",
                    },
                    sha256 = "63273c6b9e2d9b250a0009ffdaa6d9f27af6ba98772516c391276106fb9f2820",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://cdn.azul.com/zulu/bin/zulu25.36.15-ca-jdk25.0.4-macosx_aarch64.tar.gz",
                        CN = "https://gitcode.com/xlings-res/jdk-zulu/releases/download/25.0.4/zulu25.36.15-ca-jdk25.0.4-macosx_aarch64.tar.gz",
                    },
                    sha256 = "c422f22713510992c764a7d577ae4f5add223529ab356993f38f8df2d4b247bd",
                },
            },
            ["21.0.12"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://cdn.azul.com/zulu/bin/zulu21.52.15-ca-jdk21.0.12-macosx_x64.tar.gz",
                        CN = "https://gitcode.com/xlings-res/jdk-zulu/releases/download/21.0.12/zulu21.52.15-ca-jdk21.0.12-macosx_x64.tar.gz",
                    },
                    sha256 = "14e05cb1299c27cd26d3c5c6815723f63018df548dc7278c810767607902b4f4",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://cdn.azul.com/zulu/bin/zulu21.52.15-ca-jdk21.0.12-macosx_aarch64.tar.gz",
                        CN = "https://gitcode.com/xlings-res/jdk-zulu/releases/download/21.0.12/zulu21.52.15-ca-jdk21.0.12-macosx_aarch64.tar.gz",
                    },
                    sha256 = "84d38c4bf04f73d585bd319b949758d00abde50149a9522c2d9deef46b9a3ec6",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "25.0.4" },
            ["25.0.4"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://cdn.azul.com/zulu/bin/zulu25.36.15-ca-jdk25.0.4-win_x64.zip",
                        CN = "https://gitcode.com/xlings-res/jdk-zulu/releases/download/25.0.4/zulu25.36.15-ca-jdk25.0.4-win_x64.zip",
                    },
                    sha256 = "a91265f0f0fb40155befe8f1cae7d1a0ae2ab4b7760f52733160d206637b50d1",
                },
            },
            ["21.0.12"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://cdn.azul.com/zulu/bin/zulu21.52.15-ca-jdk21.0.12-win_x64.zip",
                        CN = "https://gitcode.com/xlings-res/jdk-zulu/releases/download/21.0.12/zulu21.52.15-ca-jdk21.0.12-win_x64.zip",
                    },
                    sha256 = "3c06e6693fd6fa725b985e66798a6a8293c75f52b793490754ad3c54d3d8b5a6",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")
import("xim.libxpkg.elfpatch")

local PROGRAMS = { "java", "javac", "jar", "javadoc", "jshell" }
local FLAVOR = "zulu"

local function flavor_version()
    return pkginfo.version() .. "-" .. FLAVOR
end

-- Zulu's payload directory is always the archive name minus its extension:
--
--   linux    zulu25.36.15-ca-jdk25.0.4-linux_x64/bin/java
--   macosx   zulu25.36.15-ca-jdk25.0.4-macosx_x64/Contents/Home/bin/java
--   windows  zulu25.36.15-ca-jdk25.0.4-win_x64/bin/java.exe
--
-- That name carries the distro version (25.36.15) and the arch, neither of which
-- this hook can derive from the version key -- and os.arch() is not bound in
-- hooks anyway (see node.lua). So take it from the archive itself:
-- `pkginfo.install_file()` is the downloaded archive path (verified on the
-- current C++ xim runtime), which keeps this hook correct across future Zulu
-- builds without a hard-coded distro-version table.
local function payload_dir()
    local file = pkginfo.install_file() or ""
    local base = file:match("[^/\\]+$") or ""
    base = base:gsub("%.tar%.gz$", "")
    base = base:gsub("%.zip$", "")
    if base == "" then return nil end
    if os.host() == "macosx" then
        -- Same signed .jdk bundle shape as Temurin/Corretto: take the inner
        -- Contents/Home so install_dir() is JAVA_HOME on every platform.
        return path.join(base, "Contents", "Home")
    end
    return base
end

function install()
    -- Idempotent across xim engines, and never report success without a real
    -- launcher in place -- see jdk-temurin.lua for the full rationale.
    local exe = os.host() == "windows" and "java.exe" or "java"
    local staged = path.join(pkginfo.install_dir(), "bin", exe)
    if os.isfile(staged) then return true end

    local payload = payload_dir()
    if payload and os.isdir(payload) then
        os.tryrm(pkginfo.install_dir())
        os.mv(payload, pkginfo.install_dir())
    end

    if not os.isfile(staged) then
        log.error("jdk-zulu: no java launcher at %s (payload dir: %s)",
                  staged, tostring(payload))
        return false
    end

    -- RPATH only, deliberately no loader.
    --
    -- The JDK's own .so files carry RPATH=$ORIGIN and nothing else, so
    -- libXtst / libasound / freetype / fontconfig resolve through the HOST's
    -- ld.so.cache. Measured with `LD_DEBUG=libs` on a headless Toolkit + font +
    -- audio run: 15 of the 27 objects loaded came from /lib/x86_64-linux-gnu.
    -- A `System.loadLibrary` probe reports LOAD_OK for all of them, so "it
    -- loaded" does not mean "it loaded ours" -- read `calling init:` or
    -- /proc/self/maps instead.
    --
    -- Writing our libdirs into the JDK's RUNPATH is the step that has to come
    -- BEFORE any interpreter switch: our loader has no host fallback, so the
    -- moment PT_INTERP points at us, anything still resolving from the host
    -- becomes unreachable. Doing it in the other order is what took AWT down in
    -- 2026.8.8.1.
    --
    -- elfpatch's predicate-driven path keys off a dep exporting
    -- `runtime.loader` (i.e. glibc) and would switch PT_INTERP too, which is
    -- exactly what must not happen yet -- hence the explicit rpath-only
    -- override, the form the elfpatch docs prescribe for this case.
    if os.host() == "linux" then
        local libpaths = elfpatch.closure_lib_paths()
        if libpaths and #libpaths > 0 then
            elfpatch.set({ rpath = libpaths })
            log.info("jdk-zulu: RUNPATH will be set to %d dep libdir(s); "
                     .. "PT_INTERP left alone on purpose", #libpaths)
        else
            -- Do not fall through quietly: an empty closure means the deps did
            -- not export libdirs, and the JDK would keep resolving from the
            -- host while this install reported success.
            log.warn("jdk-zulu: dependency closure produced no libdirs; the "
                     .. "JDK will keep resolving X11/ALSA/font libs from the "
                     .. "host. Not fatal today, but it blocks the loader switch.")
        end
    end

    return true
end

function config()
    -- install_dir() is the JDK home on every platform (see payload_dir).
    local java_home = pkginfo.install_dir()
    local bindir = path.join(java_home, "bin")

    -- Binding-group root: `type = "group"` because the node names no artifact,
    -- so it never becomes an orphan shim (openxlings/xlings#452).
    local binding = "jdk-zulu@" .. pkginfo.version()
    xvm.add("jdk-zulu", { type = "group" })

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

    log.info("jdk-zulu: JAVA_HOME = %s", java_home)
    log.info("jdk-zulu: java/javac/jar/javadoc/jshell registered as %s; other JDK tools live in %s",
             flavor_version(), bindir)

    return true
end

function uninstall()
    -- Version-scoped: another installed version, or another JDK distribution
    -- sharing these names, must keep its own nodes.
    for _, prog in ipairs(PROGRAMS) do
        xvm.remove(prog, flavor_version())
    end
    xvm.remove("jdk-zulu", pkginfo.version())
    return true
end
