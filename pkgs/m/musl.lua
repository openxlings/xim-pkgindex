-- musl libc — the runtime, as a peer of glibc.lua.
--
-- The index already had musl *toolchains* (musl-gcc.lua,
-- x86_64-linux-musl-gcc.lua, aarch64-linux-musl-gcc.lua) but no musl
-- runtime you could install on its own. glibc.lua's own comment names
-- the gap: it tags its loader export `abi = "linux-x86_64-glibc"`
-- because that is "the disambiguation tag when a subos hosts both glibc
-- and musl xpkgs" — a subos that could not, until now, host the musl
-- one.
--
-- What it is for — the gap, measured in a subos sandbox on a glibc host:
--
--   $ musl-gcc -o h h.c && ./h
--   cannot execute: required file not found     # INTERP is the canonical
--                                               # /lib/ld-musl-x86_64.so.1,
--                                               # which a glibc host has not got
--   $ <musl>/lib/ld-musl-x86_64.so.1 ./h
--   hello from musl                             # runs under this payload
--   $ musl-gcc -Wl,--dynamic-linker=<musl>/lib/ld-musl-x86_64.so.1 -o h2 h.c
--   $ ./h2
--   hello from musl                             # or link straight at it
--
-- So: running a musl-linked prebuilt (an Alpine-built binary, or a
-- vendor's `-musl` asset) on a glibc host, without root and without
-- touching /lib; giving a musl-targeting build a runtime inside the
-- subos; `xlings subos new <name> --runtime musl@1.2.6`.
--
-- It does NOT replace a musl toolchain: musl-gcc.lua carries its own
-- musl sysroot (including its own loader) and does not read this
-- package. The two coexist — verified in one subos, `gcc` still building
-- and running glibc binaries while these libs were registered.
--
-- Versions: 1.2.5 is the one in the field — Alpine 3.20/3.21/3.22 ship
-- it, so it is what "a musl binary" is overwhelmingly built against —
-- and 1.2.6 is upstream's current release. `latest` is 1.2.5 for the
-- same reason glibc's is 2.39 rather than 2.44: musl is backward
-- compatible, so the older runtime is the one that runs both, and
-- moving the default is a decision to make on purpose rather than as a
-- side effect of adding a version. Ask for the newer one explicitly.
--
-- x86_64 only, matching glibc.lua. Cross-building the aarch64 payload is
-- easy (musl takes CROSS_COMPILE and the index ships
-- aarch64-linux-musl-gcc), but the build script's checks actually RUN
-- the loader and link a program against it, and none of that can run
-- here — an aarch64 payload would ship unverified.
--
-- Payload comes from .agents/tools/build-musl.sh, which exists because
-- two musl defaults are wrong for a relocatable payload: `--syslibdir`
-- puts the `ld-musl-*.so.1` loader symlink in /lib rather than under
-- --prefix (so a default build ships no loader at all), and that symlink
-- is absolute into the build prefix. See the script for the rest.

package = {
    spec = "1",

    homepage = "https://musl.libc.org",
    -- base info
    name = "musl",
    description = "musl - a lightweight, fast, simple, free, standards-conformant C library",

    authors = {"Rich Felker", "musl contributors"},
    licenses = {"MIT"},
    repo = "https://git.musl-libc.org/cgit/musl",
    docs = "https://musl.libc.org/doc/1.2.5/manual.html",

    -- xim pkg info
    type = "package",
    archs = {"x86_64"},
    status = "stable", -- dev, stable, deprecated
    categories = {"libc"},
    keywords = {"libc", "musl", "static", "alpine"},

    -- xvm: xlings version management
    xvm_enable = true,

    -- No CLI shims. musl has no `ldd` binary of its own (its "ldd" is the
    -- loader invoked under that name) and its `musl-gcc` wrapper is
    -- deliberately not built — musl-gcc.lua already owns that xvm program
    -- name, and two packages claiming one (name, version) is refused.
    -- The .so / .a / crt files are registered as libs in config().
    programs = {},

    xpm = {
        linux = {
            -- Declare the dynamic linker we ship so consumers don't have
            -- to hardcode a path into their own hooks. xlings
            -- predicate-driven elfpatch reads this and patches consumer
            -- ELFs automatically; `abi` is what keeps it from confusing
            -- this loader with glibc's in a subos holding both.
            --
            -- musl's loader IS libc.so — `lib/ld-musl-x86_64.so.1` is a
            -- relative symlink to it, which is why libdirs falls through
            -- to the {lib64, lib} convention and finds everything.
            exports = {
                runtime = {
                    loader = "lib/ld-musl-x86_64.so.1",
                    abi    = "linux-x86_64-musl",
                },
            },
            ["latest"] = { ref = "1.2.5" },
            -- Explicit urls rather than XLINGS_RES: an XLINGS_RES entry
            -- carries no checksum, and a libc payload is the last thing
            -- that should install unverified. Same reasoning as glibc 2.44.
            ["1.2.6"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/musl/releases/download/1.2.6/musl-1.2.6-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/musl/releases/download/1.2.6/musl-1.2.6-linux-x86_64.tar.gz",
                },
                sha256 = "44f6b63ddd6fcb3e668d76fe336cf91e42d4aa1c538bd228b09a298065284c49",
            },
            ["1.2.5"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/musl/releases/download/1.2.5/musl-1.2.5-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/musl/releases/download/1.2.5/musl-1.2.5-linux-x86_64.tar.gz",
                },
                sha256 = "b48e958059906a4e5eef9b222d68e6e17a13c5640973d815bac6c2c66ba70d9a",
            },
        },
    },
}

import("xim.libxpkg.log")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.sysroot")

function install()
    -- The payload root, identified by CONTENT rather than by name.
    --
    -- glibc.lua learned this the hard way: deriving the directory from
    -- `install_file() minus .tar.gz` was true of exactly one asset, and
    -- when it stopped being true os.mv failed, install() returned true
    -- anyway, and what shipped was a libc package with no loader in it,
    -- reported as a successful install. The extraction directory is
    -- shared, so "the only directory" is not a usable rule either.
    local musldir = pkginfo.install_file():replace(".tar.gz", "")
    if not os.isdir(musldir) then
        local base = path.directory(musldir)
        local found = nil
        local f = io.popen(string.format([[ls -1 "%s" 2>/dev/null]], base))
        if f then
            for line in f:lines() do
                local d = line:gsub("[\r\n]+$", "")
                if d ~= "" then
                    local cand = path.join(base, d)
                    if os.isdir(cand) and os.isfile(path.join(cand, "lib", "libc.so")) then
                        found = cand
                        break
                    end
                end
            end
            f:close()
        end
        if not found then
            raise(string.format(
                "cannot find the payload root under '%s': no extracted "
                .. "directory contains lib/libc.so", base))
        end
        musldir = found
    end

    os.tryrm(pkginfo.install_dir())
    os.mv(musldir, pkginfo.install_dir())

    -- Never report success without the one file the package exists for.
    -- A `return true` here gets stamped as installed and leaves every
    -- consumer elfpatched onto a loader that is not there.
    local loader = path.join(pkginfo.install_dir(), "lib", "ld-musl-x86_64.so.1")
    if not os.isfile(loader) then
        raise("musl payload has no lib/ld-musl-x86_64.so.1 after install")
    end

    return true
end

-- ── the eleven names glibc.lua also registers ──────────────────────────
--
-- These are NOT musl's to own. glibc is the subos's system C library and
-- registers every one of them into the shared `lib/` directory; musl
-- ships a file under the same name, with incompatible contents. The
-- overlap was computed against glibc.lua's `glibc_libs` list and this
-- payload's actual `lib/`, not eyeballed.
--
-- Registered under the plain version, they become two-owner names —
-- measured on a real install, not theorised:
--
--     crt1.o  = {"active": "glibc-2.39",
--                "installed": ["glibc-2.39", "musl-1.2.5"]}
--
-- and one `xvm use` landing on the musl side repoints the subos's
-- `crt1.o` at musl's, which silently breaks every glibc C link in that
-- subos.
--
-- So they register as `<version>-musl`, the same idiom jdk-temurin.lua
-- uses for `java`/`javac` (`25.0.4+7-temurin`) and musl-gcc.lua uses to
-- share `gcc` with gcc.lua (`16.1.0-musl`). `xlings use crt1.o
-- 1.2.5-musl` then names one libc unambiguously, and the whole set
-- switches together through the binding root below.
local SHARED_LIBS = {
    "Scrt1.o", "crt1.o", "crti.o", "crtn.o",
    "libc.a", "libc.so", "libdl.a", "libm.a",
    "libpthread.a", "librt.a", "libutil.a",
}

-- ── names only musl ships ──────────────────────────────────────────────
--
-- No collision today, but they take the same flavor-tagged version so
-- the whole set moves as one under `xlings use musl`, and so a second
-- musl-ish libc arriving later meets the same convention rather than a
-- plain number that happens to be free.
--
-- `libm.a`/`libpthread.a`/`librt.a`/`libdl.a`/`libcrypt.a`/`libutil.a`/
-- `libxnet.a`/`libresolv.a` are all 8-byte empty archives: musl puts
-- everything in libc and keeps these so a `-lm`/`-lpthread` on someone's
-- link line resolves instead of erroring.
local MUSL_ONLY_LIBS = {
    "ld-musl-x86_64.so.1", "rcrt1.o",
    "libcrypt.a", "libresolv.a", "libxnet.a",
}

local FLAVOR = "musl"

local function flavor_version()
    return pkginfo.version() .. "-" .. FLAVOR
end

function config()
    -- Root of this release's binding group, so `xlings use musl 1.2.5`
    -- switches every lib bound to it in one step.
    --
    -- `type = "group"` because the node names no artifact: there is no
    -- `bin/musl` to exec. Left as the default `program` kind it becomes
    -- a shim that can only ever fail — verified here before the fix, as
    -- `subos/default/bin/musl -> ../../../bin/xlings`, exactly the
    -- orphan `self doctor` reports (openxlings/xlings#452). Same idiom
    -- as gcc.lua / rust.lua / jdk-temurin.lua.
    local binding = "musl@" .. pkginfo.version()
    xvm.add("musl", { type = "group" })

    local musl_libdir = path.join(pkginfo.install_dir(), "lib")
    local lib_config = {
        version = flavor_version(),
        type = "lib",
        bindir = musl_libdir,
        binding = binding,
    }

    log.debug("1 - config musl libs (%s)...", flavor_version())
    for _, set in ipairs({ SHARED_LIBS, MUSL_ONLY_LIBS }) do
        for _, lib in ipairs(set) do
            -- Guarded the way glibc's registration is: a name absent
            -- from this release's payload is skipped rather than
            -- registered as a lib whose source file does not exist.
            if os.isfile(path.join(musl_libdir, lib)) then
                lib_config.filename = lib -- target file name
                lib_config.alias = lib -- source file name
                xvm.add(lib, lib_config)
            end
        end
    end

    log.debug("2 - musl config header files...")
    __config_header(binding)

    log.info("musl: libs registered as %s (glibc keeps the plain names)",
             flavor_version())

    return true
end

function uninstall()
    -- Version-scoped on purpose: glibc's registration of the same eleven
    -- names, and any other installed musl release, must survive this.
    local v = __stored_version()
    for _, set in ipairs({ SHARED_LIBS, MUSL_ONLY_LIBS }) do
        for _, lib in ipairs(set) do
            xvm.remove(lib, v)
        end
    end
    xvm.remove("musl", pkginfo.version())
    return true
end

-- The key the lib nodes are actually STORED under.
--
-- `xvm.add` prefixes the index namespace itself: registering
-- `version = "1.2.5-musl"` stores a bare `1.2.5-musl` from the primary
-- `xim` namespace but `local:1.2.5-musl` from any other. `xvm.remove`
-- does NOT prefix — hand it the bare key from a secondary namespace and
-- it matches nothing.
--
-- Measured after `xlings remove local:musl`: the package root was gone
-- and every lib node was still there —
--
--     crt1.o = {"active": "glibc-2.39",
--               "installed": ["glibc-2.39", "local:1.2.5-musl"]}
--
-- i.e. uninstall left musl owning eleven of glibc's names, which is the
-- exact state the flavor tag exists to keep switchable-but-clean. It
-- passes CI because posix-test.sh's post-uninstall check looks for
-- leftover *shims* in `bin/`, and lib nodes make none.
--
-- `xim:musl` was symmetric all along, so this only ever bit secondary
-- namespaces — which is every local test and every CI run.
--
-- Same shape as glibc.lua's `__version_key()`. The namespace is not
-- exposed to a hook, but the store directory is:
-- `<data>/xpkgs/<ns>-x-musl/<version>`.
function __stored_version()
    local store = path.filename(path.directory(pkginfo.install_dir()))
    local ns = store:match("^(.-)%-x%-")
    local bare = flavor_version()
    if ns and ns ~= "" and ns ~= "xim" then return ns .. ":" .. bare end
    return bare
end

-- private

function __config_header(binding)
    -- Declared where the client supports it, so the entries follow
    -- `xlings use` and are removed with the release instead of outliving
    -- it.
    --
    -- Unlike glibc, musl's headers are NOT safe to scatter into a shared
    -- `usr/include` next to another libc's: the two disagree on the
    -- contents of stdio.h, features.h and everything reachable from
    -- them, and whichever lands second silently wins for every compile
    -- in the subos. So they go to their own directory and a musl build
    -- points at it explicitly (`-isystem`, or the toolchain's own
    -- sysroot) rather than inheriting it by accident.
    local include_dir = path.join(pkginfo.install_dir(), "include")
    if not os.isdir(include_dir) then
        return
    end

    if sysroot.declare_headers(pkginfo.install_dir(), "include",
                               "usr/include/musl", binding) then
        return
    end

    -- Legacy path for a client with no `xvm.files`. The stamp matters
    -- for the same reason it does in glibc.lua: config() runs on every
    -- dependent install, and without it each one re-copies the tree.
    local subos_sysrootdir = system.subos_sysrootdir()
    local sysroot_usrdir = path.join(subos_sysrootdir, "usr")
    if not os.isdir(sysroot_usrdir) then os.mkdir(sysroot_usrdir) end

    local stamp = path.join(sysroot_usrdir, ".musl-" .. pkginfo.version() .. ".stamp")
    if os.isfile(stamp) then
        log.debug("musl headers already in subos rootfs (stamp present), skipping copy.")
        return
    end

    log.info("Linking musl headers into subos sysroot (usr/include/musl) ...")
    sysroot.install_headers(include_dir, path.join(sysroot_usrdir, "include", "musl"))
    io.writefile(stamp, pkginfo.version())
end
