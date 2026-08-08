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
    -- RUNTIME DEPS — declared on linux since 2026-08-09 (D5-1 of the
    -- ecosystem-closure design, §8.2). This supersedes the "none" recorded
    -- here earlier, which was correct only while libXtst and libasound were
    -- unpackaged.
    --
    -- The payload stays FORM H: host PT_INTERP, host glibc, OUR leaf
    -- libraries. That split is not a compromise, it is the measured safety
    -- boundary:
    --
    --   host INTERP + our libX11 / libXtst / freetype ...  ->  works. The
    --       leaves are built against glibc 2.39, the host's glibc is >= 2.39
    --       on every supported distro, and glibc is backward compatible.
    --   host INTERP + our glibc                            ->  segfaults
    --       before main (design §2, combination 2). This is what took #578
    --       down.
    --
    -- So config() writes a RUNPATH that names ONLY the leaf payloads' libdirs
    -- — never glibc's, and never the subos farm dir (`<subos>/lib` holds a
    -- ld.so/libc symlink, i.e. it is a directory through which a second libc
    -- can be reached; writing it into RUNPATH re-creates combination 2 one
    -- symlink later). The full-closure helpers do write those two, which is
    -- why they are not used here; see install()/config().
    --
    -- AUDIO STAYS ON THE HOST, deliberately: libjsound.so is left unpatched,
    -- so its `libasound.so.2` keeps falling back to the host's via the
    -- ld.so cache — that is what keeps the distro's pipewire/pulse bridge
    -- (and its plugin configuration) working. "audio = host service" is the
    -- documented exception: alsa-lib IS declared below (the closure account
    -- must be honest, and the D1 check requires the soname's provider), but
    -- its libdir is NOT written into any RUNPATH.
    --
    -- Zulu differs from Temurin in one way that matters: its libjli.so,
    -- libsplashscreen.so and libinstrument.so name `libz.so.1`, which
    -- Temurin's do not. libjli is loaded by `bin/java` itself, so `xim:zlib`
    -- is a HARD dep here rather than an optional one — leave it out and
    -- `java` fails to start rather than degrading.
    xpm = {
        linux = {
            -- The JDK's measured runtime closure — every external SONAME its
            -- .so files name, each declared DIRECTLY:
            --
            --   libX11.so.6 libXext.so.6 libXi.so.6 libXtst.so.6
            --   libXrender.so.1 libasound.so.2 libfreetype.so libz.so.1
            --
            -- including the ones also reachable transitively: the index's
            -- dep-closure check (D1) rejects the transitive form, and it is
            -- right to — a transitive dep does NOT put its libdir in this
            -- payload's RPATH closure, only direct deps do. (#578 was failed
            -- for exactly libX11/libXext/libXi.)
            --
            -- glibc IS declared (D1 finds libc.so.6 et al. in the payload's
            -- NEEDED), and declaring it is exactly what would trip elfpatch's
            -- predicate-driven auto path into switching PT_INTERP — see the
            -- elfpatch.skip() in install() for why that must not happen and
            -- how it is prevented.
            --
            -- fontconfig floor >= 2.15.0.1: fontconfig is dlopen'd by
            -- libfontmanager (no DT_NEEDED names it), and a fontconfig
            -- payload from the 2.15.0 era predates selfcontain.seal — it
            -- carries no RUNPATH, so ITS OWN freetype/expat resolve from the
            -- host's ld.so cache and the host font stack rides back in
            -- through the side door. 2.15.0.1 is the same artifact re-keyed
            -- to force a sealed install; the floor is what pierces
            -- pin-to-active on a machine holding an old unsealed 2.15.0
            -- (the pin cannot satisfy >= 2.15.0.1, so the resolver installs
            -- the sealed one).
            --
            -- fontconfig and freetype draw the "declares X, but nothing in
            -- the payload names a soname it provides" warning, and both
            -- stay: fontconfig is dlopen'd, and libfontmanager names
            -- `libfreetype.so` (the linker name) rather than the
            -- `libfreetype.so.6` soname the check matches on. Both are
            -- genuinely loaded at runtime — measured with LD_DEBUG — which
            -- is precisely why DT_NEEDED alone is not a sufficient
            -- dependency list.
            deps = {
                "xim:glibc",
                "xim:libX11", "xim:libXext", "xim:libXi",
                "xim:libXtst", "xim:libXrender", "xim:alsa-lib",
                "xim:freetype", "xim:fontconfig@>=2.15.0.1", "xim:zlib",
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

-- D5-1: the leaf payloads whose libdirs go into the RUNPATH written by
-- config(), and nothing else.
--
-- This is the DIRECT NEEDED/dlopen set of the objects patched below —
-- fontconfig (dlopen'd), freetype (libfontmanager NEEDs libfreetype.so),
-- zlib (libjli/libsplashscreen/libinstrument NEED libz.so.1), and the X11
-- five (libawt_xawt/libsplashscreen). Deliberately NOT here:
--
--   * glibc — host INTERP + our libc segfaults before main (#578).
--   * the subos farm dir — it reaches a glibc through symlinks; same hazard.
--   * alsa-lib — audio stays a host service (libjsound is not patched, so
--     libasound.so.2 falls back to the host's and the pipewire bridge
--     keeps working); declared in deps for closure honesty only.
--   * expat / libpng — transitive: a sealed fontconfig resolves its own
--     freetype/expat through its own RUNPATH, and brotli/bz2/png only ever
--     entered the process as the HOST freetype's dependencies. A dir the
--     JDK's own objects never name does not belong in their RUNPATH.
local LEAF_RUNPATH_DEPS = {
    "fontconfig", "freetype", "zlib",
    "libX11", "libXext", "libXi", "libXtst", "libXrender",
}

-- The payload objects that name (via NEEDED or dlopen) a leaf outside this
-- payload. Only these are patched: executables keep their shipped headers
-- untouched, and libjsound.so is deliberately absent (see alsa above).
local LEAF_PATCH_TARGETS = {
    "libfontmanager.so", "libawt.so", "libawt_headless.so", "libawt_xawt.so",
    "libjli.so", "libsplashscreen.so", "libinstrument.so",
}

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
    -- D5-1 SAFETY PREREQUISITE — this line is what makes declaring xim:glibc
    -- survivable, so it comes before anything can fail:
    --
    -- With glibc in deps, elfpatch's predicate ("exactly one runtime dep
    -- exports runtime.loader") fires after install() returns and would both
    -- switch PT_INTERP to our loader AND stamp the FULL dependency closure —
    -- glibc's lib64 plus the subos farm dir — into RUNPATH. Either half is
    -- fatal here: host INTERP + our libc segfaults before main, and our
    -- INTERP without a complete closure is 2026.8.8.1's AWT breakage.
    --
    -- #578 tried to thread this needle with `elfpatch.set({ rpath = ... })`
    -- and shipped the segfault anyway: set()'s `rpath` parameter is not read
    -- by _apply at all — the override path recomputes closure_lib_paths()
    -- itself — so the "rpath-only" override still wrote glibc's libdir.
    -- skip() is the only override that actually turns the auto path off; the
    -- leaf-only RUNPATH is then written by hand in config(), through the
    -- low-level primitive that does take a caller-supplied rpath.
    --
    -- type() probe, not truthiness: a client old enough to lack skip() also
    -- predates the predicate-driven auto path (they shipped together), so on
    -- such a client there is nothing to switch off.
    if os.host() == "linux" and type(elfpatch.skip) == "function" then
        elfpatch.skip()
    end

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
    return true
end

-- Does `dir` directly contain a shared object? os.files/os.exists are nil in
-- the recipe sandbox, so probe with ls, as llvm.lua does.
function __dir_has_so(dir)
    local f = io.popen('ls -1 "' .. dir .. '" 2>/dev/null')
    if not f then return false end
    local found = false
    for line in f:lines() do
        if line:find(".so", 1, true) then found = true end
    end
    f:close()
    return found
end

-- A leaf dep's REAL libdir — the directory that actually holds the .so files,
-- not the conventional name. {lib64, lib} first; when the conventional dir
-- exists but holds no shared object directly, descend one level: freetype
-- ships lib/x86_64-linux-musl/libfreetype.so*, and a RUNPATH entry naming
-- lib/ instead of the triple dir would resolve nothing while looking right.
function __leaf_libdir(name)
    local root = pkginfo.dep_install_dir(name)
    if not root then return nil end
    for _, sub in ipairs({ "lib64", "lib" }) do
        local d = path.join(root, sub)
        if os.isdir(d) then
            if __dir_has_so(d) then return d end
            local f = io.popen('ls -1 "' .. d .. '" 2>/dev/null')
            if f then
                for line in f:lines() do
                    local nested = path.join(d, (line:gsub("[\r\n]+$", "")))
                    if os.isdir(nested) and __dir_has_so(nested) then
                        f:close()
                        return nested
                    end
                end
                f:close()
            end
        end
    end
    return nil
end

-- D5-1 leaf RUNPATH surgery (linux only; called from config()).
--
-- Writes `$ORIGIN:<leaf libdirs>` onto exactly LEAF_PATCH_TARGETS, via the
-- low-level elfpatch.patch_elf_loader_rpath — the one entry point that takes
-- a caller-supplied rpath verbatim (elfpatch.set()'s rpath parameter is
-- ignored by _apply; that is how #578 shipped a full-closure RUNPATH while
-- reading as rpath-only). PT_INTERP is not touched anywhere.
--
-- Idempotent by construction: patchelf --set-rpath REPLACES the whole
-- RUNPATH with the same fixed value on every run, so config() re-running
-- (xlings use, re-config) converges instead of accumulating.
function __leaf_runpath_surgery()
    -- type() probe, not truthiness: import() answers an unknown module with
    -- a permissive proxy whose every key is truthy, so `if elfpatch.x then`
    -- lies on old clients. Degrade loudly but do not fail config: on such a
    -- client the payload simply keeps resolving leaves from the host, which
    -- is exactly yesterday's (working) behaviour.
    if type(elfpatch.patch_elf_loader_rpath) ~= "function" then
        log.warn("jdk-zulu: this xlings cannot write a custom RUNPATH; the "
                 .. "JDK keeps resolving X11/font/zlib from the host. "
                 .. "Run `xlings self update`.")
        return
    end

    local rpath, seen, missing = { "$ORIGIN" }, {}, {}
    for _, dep in ipairs(LEAF_RUNPATH_DEPS) do
        local d = __leaf_libdir(dep)
        if d then
            if not seen[d] then
                seen[d] = true
                table.insert(rpath, d)
            end
        else
            table.insert(missing, dep)
        end
    end
    if #missing > 0 then
        -- Not fatal — form H still resolves those from the host — but never
        -- silent: an incomplete RUNPATH here is precisely the gap that
        -- becomes an outage the day the loader switches (D5-3).
        log.warn("jdk-zulu: no libdir found for dep(s): %s; those sonames "
                 .. "keep resolving from the host",
                 table.concat(missing, ", "))
    end

    local libdir = path.join(pkginfo.install_dir(), "lib")
    local patched, failed = 0, 0
    for _, name in ipairs(LEAF_PATCH_TARGETS) do
        local target = path.join(libdir, name)
        if os.isfile(target) then
            local r = elfpatch.patch_elf_loader_rpath(target, {
                rpath  = rpath,
                -- No shrink: it would keep only entries satisfying a current
                -- DT_NEEDED, dropping exactly the fontconfig dir that only a
                -- later dlopen needs.
                shrink = false,
            })
            -- Count only a REAL patch as one: a missing patchelf returns
            -- {scanned=0, patched=0, failed=0}, and reading that as success
            -- is the never-happened-vs-succeeded conflation this index keeps
            -- paying for.
            if r and (r.patched or 0) > 0 and (r.failed or 0) == 0 then
                patched = patched + 1
            else
                failed = failed + 1
            end
        end
    end
    log.info("jdk-zulu: leaf RUNPATH (%d libdir(s)) written onto %d object(s); "
             .. "PT_INTERP stays the host's", #rpath - 1, patched)
    if failed > 0 then
        log.warn("jdk-zulu: %d object(s) could not be patched; those keep "
                 .. "resolving from the host", failed)
    end
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

    if os.host() == "linux" then
        __leaf_runpath_surgery()
    end

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
