package = {
    spec = "2",

    -- base info
    name = "jdk-temurin",
    description = "Eclipse Temurin JDK 25 — a production-ready binary build of OpenJDK (LTS)",

    homepage = "https://adoptium.net",
    repo = "https://github.com/adoptium/temurin25-binaries",
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

    -- WHY THE NAME
    --
    -- The flavor is in the package name (`jdk-temurin`) so other
    -- distributions can coexist as jdk-oracle / jdk-microsoft / jdk-zulu
    -- later; the JDK version lives in the version dimension (25.0.4+7), so
    -- future JDK 26/27 land in this same package. This mirrors how apt
    -- (`openjdk-25-jdk`) / dnf (`java-25-openjdk`) / Arch (`jdk25-openjdk`)
    -- all embed the flavor in the name.
    --
    -- VERSION STRING — the canonical version key carries the OpenJDK build
    -- number (JEP 322: `$FEATURE.$INTERIM.$UPDATE+$BUILD`), matching the
    -- upstream tag `jdk-25.0.4+7`, the Adoptium API semver `25.0.4+7.0.LTS`
    -- and what mise/asdf call this build. But `java --version` prints only
    -- `openjdk 25.0.4` on its first line (the `+7` shows up further down, in
    -- `Temurin-25.0.4+7 (build 25.0.4+7-LTS)`), and `java.version` is plain
    -- `25.0.4` -- so users reasonably type what they see. Hence the
    -- `["25.0.4"] = { ref = "25.0.4+7" }` alias on every platform: both
    -- `xlings install jdk-temurin@25.0.4` and `@25.0.4+7` resolve to the same
    -- resource. Future security updates add their own pair (25.0.5 -> ...).
    --
    -- PROVENANCE — Temurin (Eclipse Adoptium) 25.0.4+7, released 2026-07-29.
    -- Per-arch sha256 fetched from the Adoptium API
    -- (api.adoptium.net/v3/assets/release_name/eclipse/jdk-25.0.4%2B7) and
    -- re-verified against the downloaded archives.
    --
    -- RESOURCE SHAPE — Shape B per-arch resource maps, because Adoptium's
    -- release tag and archive filename encode the build number differently:
    --   tag  jdk-25.0.4+7                  (URL-escaped as %2B)
    --   file OpenJDK25U-jdk_..._25.0.4_7.  (build joined with '_')
    -- A URL template cannot express both encodings, so each os/arch URL is
    -- explicit. That also rules out `ci.update` / `ci.mirror`, which both
    -- need a `${version}`-parameterized template; bumps stay manual, one
    -- version block + one `latest`/alias edit per quarterly security update.
    --
    -- CN MIRROR — every URL is a {GLOBAL, CN} pair. GLOBAL is the Adoptium
    -- release itself (no reason to re-host 648MB for the global path); CN is
    -- gitcode.com/xlings-res/jdk-temurin, byte-identical copies of the same
    -- five archives, each with a `.sha256` sidecar. The GitCode release tag
    -- is `25.0.4_7`, not `25.0.4+7`: GitCode's release API decodes `+` in a
    -- path segment back to a space and then 404s, so the mirror reuses the
    -- underscore spelling Adoptium already uses in the archive filenames.
    --
    -- ARCH COVERAGE — Temurin 25 ships linux + macosx on x86_64/aarch64 but
    -- only x86_64 on windows (no windows-aarch64 JDK image for 25), so the
    -- windows entry has a single arch. `archs = {x86_64, aarch64}` is the
    -- union; a windows-aarch64 host fails closed with a clear error, which is
    -- the intended fail-closed behavior.
    --
    -- RUNTIME DEPS — deliberately NONE, and the ELF tree says why: a full
    -- readelf sweep of the linux x86_64 build shows the only hard external
    -- DT_NEEDED set is glibc (libc/libdl/libm/libpthread/librt + the
    -- ld-linux INTERP). There is no libstdc++/libgcc_s anywhere in the tree
    -- (HotSpot links them statically), so this package does NOT need
    -- node.lua's `xim:gcc-runtime`. libX11/libXext/libXi/libXrender/libXtst,
    -- libasound and libfreetype appear only in libawt_xawt / libjsound /
    -- libfontmanager / libsplashscreen, which a headless JVM never dlopens.
    -- `bin/java` already carries RPATH `$ORIGIN:$ORIGIN/../lib`, so the tree
    -- is relocatable as shipped. Alpine / distroless support means an
    -- INTERP rewrite across that tree; that is a separate, real-machine
    -- verified change, not something to declare blind here.
    xpm = {
        linux = {
            ["latest"] = { ref = "25.0.4+7" },
            ["25.0.4"] = { ref = "25.0.4+7" },
            ["25.0.4+7"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.4%2B7/OpenJDK25U-jdk_x64_linux_hotspot_25.0.4_7.tar.gz",
                        CN = "https://gitcode.com/xlings-res/jdk-temurin/releases/download/25.0.4_7/OpenJDK25U-jdk_x64_linux_hotspot_25.0.4_7.tar.gz",
                    },
                    sha256 = "e58fcdcd637b25c03ca84cbbcefc70d11efb8f4b4cbd05decc9f661769d77f94",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.4%2B7/OpenJDK25U-jdk_aarch64_linux_hotspot_25.0.4_7.tar.gz",
                        CN = "https://gitcode.com/xlings-res/jdk-temurin/releases/download/25.0.4_7/OpenJDK25U-jdk_aarch64_linux_hotspot_25.0.4_7.tar.gz",
                    },
                    sha256 = "621f7196f0b682fb557da58bec89bd7dfe5419811fe1c0ba75c9cc8432f084c7",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "25.0.4+7" },
            ["25.0.4"] = { ref = "25.0.4+7" },
            ["25.0.4+7"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.4%2B7/OpenJDK25U-jdk_x64_mac_hotspot_25.0.4_7.tar.gz",
                        CN = "https://gitcode.com/xlings-res/jdk-temurin/releases/download/25.0.4_7/OpenJDK25U-jdk_x64_mac_hotspot_25.0.4_7.tar.gz",
                    },
                    sha256 = "a5ac9c46dad47ac06df35e36d096913195d8da1f3f71918828bcc2cfe33869b7",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.4%2B7/OpenJDK25U-jdk_aarch64_mac_hotspot_25.0.4_7.tar.gz",
                        CN = "https://gitcode.com/xlings-res/jdk-temurin/releases/download/25.0.4_7/OpenJDK25U-jdk_aarch64_mac_hotspot_25.0.4_7.tar.gz",
                    },
                    sha256 = "5a101c54abf5a9f16c0f70d8c38ba99e6567c1ba213378f0bb04497284f051bd",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "25.0.4+7" },
            ["25.0.4"] = { ref = "25.0.4+7" },
            ["25.0.4+7"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.4%2B7/OpenJDK25U-jdk_x64_windows_hotspot_25.0.4_7.zip",
                        CN = "https://gitcode.com/xlings-res/jdk-temurin/releases/download/25.0.4_7/OpenJDK25U-jdk_x64_windows_hotspot_25.0.4_7.zip",
                    },
                    sha256 = "7caab7db43bf4b94a2e6252c699e70d90084f9aa7c943cd3414761fd540937ae",
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
-- there (`jdk-25.0.4+7/bin/java`), while macOS ships a signed .jdk bundle
-- and buries it one level down:
--
--   linux/windows  jdk-25.0.4+7/bin/java
--   macosx         jdk-25.0.4+7/Contents/Home/bin/java
--                  jdk-25.0.4+7/Contents/_CodeSignature/...
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
    -- Idempotent across xim engines (same rationale as perl.lua): some stage
    -- the extracted payload into install_dir() before/without the hook, others
    -- leave it in the hook CWD for us to move. Never wipe install_dir before a
    -- replacement payload is confirmed, and never report success unless the
    -- launcher is actually in place — `return true` over an empty dir gets
    -- stamped as installed and leaves dangling xvm shims behind.
    local exe = os.host() == "windows" and "java.exe" or "java"
    local staged = path.join(pkginfo.install_dir(), "bin", exe)
    if os.isfile(staged) then return true end

    local payload = payload_dir()
    if os.isdir(payload) then
        os.tryrm(pkginfo.install_dir())
        os.mv(payload, pkginfo.install_dir())
    end

    if not os.isfile(staged) then
        log.error("jdk-temurin: no java launcher at %s (payload dir: %s)", staged, payload)
        return false
    end
    return true
end

-- Shared launcher names, and the flavor-tagged version they register under.
--
-- `java`/`javac`/... are NOT owned by Temurin: jdk-zulu, jdk-oracle,
-- jdk-microsoft and friends are all builds of the SAME upstream OpenJDK tag,
-- so a sibling recipe would want to register `java` at the very same
-- "25.0.4+7". xvm refuses that outright -- the second package's whole config
-- batch is rejected:
--
--   field: /nodes/0
--   hint:  another package already owns this exact name and version;
--          uninstall that package first, or install this one at a different
--          version
--   Error: [jdk-<other>] failed: config hook failed
--
-- i.e. with the plain numeric version, installing Temurin would make every
-- other JDK distribution uninstallable, which defeats the whole point of
-- putting the flavor in the package name. So the shared names register as
-- `<version>-temurin`, exactly the idiom musl-gcc.lua uses to share `gcc`
-- with gcc.lua ("16.1.0-musl"). `xlings use java 25.0.4+7-temurin` then names
-- one flavor unambiguously, and the whole set still switches together via the
-- binding root below.
local PROGRAMS = { "java", "javac", "jar", "javadoc", "jshell" }
local FLAVOR = "temurin"

local function flavor_version()
    return pkginfo.version() .. "-" .. FLAVOR
end

function config()
    -- install_dir() is the JDK home on every platform (see payload_dir).
    local java_home = pkginfo.install_dir()
    local bindir = path.join(java_home, "bin")

    -- Root of this release's binding group. The package name already carries
    -- the flavor, so the root keeps the plain version and `xlings use
    -- jdk-temurin 25.0.4+7` switches every program bound to it in one step.
    -- `type = "group"` because the node names no artifact: there is no
    -- `bin/jdk-temurin` to exec, and left as the default `program` kind it
    -- becomes a shim that can only ever fail, which `self doctor` then reports
    -- as an orphan (openxlings/xlings#452). Same idiom as gcc.lua / rust.lua.
    local binding = "jdk-temurin@" .. pkginfo.version()
    xvm.add("jdk-temurin", { type = "group" })

    -- Nearly every JVM-ecosystem tool (maven, gradle, the wrappers, IDE
    -- launchers) locates a JDK through JAVA_HOME rather than PATH, so a JDK
    -- that only registers shims is half-installed. xvm attaches these to the
    -- shim, so they apply to processes started through `java`/`javac`/... and
    -- follow `xlings use` automatically instead of pinning one JDK in a
    -- profile file. Note the boundary: this does NOT export JAVA_HOME into
    -- the user's interactive shell, so a tool invoked outside these shims
    -- still needs its own JAVA_HOME (printed below once at install time).
    local env = { JAVA_HOME = java_home }

    -- Core developer-facing launchers. The tree also carries ~90 more tools
    -- (jlink, jmod, jpackage, keytool, ...); they stay reachable through
    -- <install>/bin and are deliberately NOT registered, so installing the
    -- JDK doesn't shadow unrelated system tools.
    for _, prog in ipairs(PROGRAMS) do
        xvm.add(prog, {
            bindir = bindir,
            version = flavor_version(),
            binding = binding,
            envs = env,
        })
    end

    log.info("jdk-temurin: JAVA_HOME = %s", java_home)
    log.info("jdk-temurin: java/javac/jar/javadoc/jshell registered as %s; other JDK tools live in %s",
             flavor_version(), bindir)

    return true
end

function uninstall()
    -- Both removals are version-scoped: another installed JDK version (or, for
    -- the shared names, another JDK distribution) must keep its nodes.
    for _, prog in ipairs(PROGRAMS) do
        xvm.remove(prog, flavor_version())
    end
    xvm.remove("jdk-temurin", pkginfo.version())
    return true
end
