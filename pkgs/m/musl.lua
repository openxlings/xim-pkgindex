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
-- package.
--
-- Where its files go. The subos's `lib/` and `usr/include` belong to its
-- system C library (glibc); a plain `cc` links what is there. musl takes
-- no name in either:
--
--   lib/ld-musl-<arch>.so.1  its loader, the one name only musl has: the
--                            interpreter a musl program names, and what a
--                            root's /lib serves (luban:tiny-musl)
--   usr/lib/musl/            every file a musl link reads: crt1.o, crti.o,
--                            crtn.o, Scrt1.o, rcrt1.o, libc.so, libc.a and
--                            the stub archives (the payload's lib/)
--   usr/include/musl/        its headers (the payload's include/)
--
-- A musl build names the two directories (`-B`/`-L usr/lib/musl`,
-- `-isystem usr/include/musl`); nothing reaches them by default. Installing
-- musl, or `xlings use musl`, therefore never changes what `cc` links:
-- glibc keeps crt1.o, libc.so and the rest.
--
-- Versions: 1.2.5 is the one in the field — Alpine 3.20/3.21/3.22 ship
-- it, so it is what "a musl binary" is overwhelmingly built against —
-- and 1.2.6 is upstream's current release. `latest` is 1.2.5 for the
-- same reason glibc's is 2.39 rather than 2.44: musl is backward
-- compatible, so the older runtime is the one that runs both, and
-- moving the default is a decision to make on purpose rather than as a
-- side effect of adding a version. Ask for the newer one explicitly.
--
-- x86_64 and aarch64. The aarch64 payload is built natively on an arm
-- runner by tools/res/build.sh musl (Alpine, relocatable: the loader link is
-- relative and under the prefix), whose checks RUN the loader and a program
-- linked against it -- the reason this was once x86_64 only.
--
-- Payload comes from .agents/tools/build-musl.sh, which exists because
-- two musl defaults are wrong for a relocatable payload: `--syslibdir`
-- puts the `ld-musl-*.so.1` loader symlink in /lib rather than under
-- --prefix (so a default build ships no loader at all), and that symlink
-- is absolute into the build prefix. See the script for the rest.

-- Linux ARM64 metadata requires xlings 2026.10.8.1 or newer, whose catalog
-- loader exposes the process architecture (as glibc.lua reads it).
local recipe_arch = (os.arch and os.arch())
if recipe_arch ~= "aarch64" and recipe_arch ~= "arm64" and recipe_arch ~= "x86_64" then
    recipe_arch = (type(is_arch) == "function" and is_arch("aarch64")) and "aarch64" or "x86_64"
end
if recipe_arch == "arm64" then recipe_arch = "aarch64" end
local MUSL_LOADER = "ld-musl-" .. recipe_arch .. ".so.1"

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
    archs = {"x86_64", "aarch64"},
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
            -- patchelf removes the build machine's RPATH from libc.so (install()).
            deps = { build = { "xim:patchelf@0.18.0" } },
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
                    loader = "lib/" .. MUSL_LOADER,
                    abi    = "linux-" .. recipe_arch .. "-musl",
                },
            },
            ["latest"] = { ref = "1.2.5" },
            -- Explicit urls rather than XLINGS_RES: an XLINGS_RES entry
            -- carries no checksum, and a libc payload is the last thing
            -- that should install unverified. Same reasoning as glibc 2.44.
            ["1.2.6"] = {
                -- 1: libc.so (the loader) no longer names the build
                -- machine's musl-gcc lib/ as its RPATH (install()).
                -- 2: the link files leave lib/ for usr/lib/musl (config()).
                revision = 2,
                url = {
                    GLOBAL = "https://github.com/xlings-res/musl/releases/download/1.2.6/musl-1.2.6-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/musl/releases/download/1.2.6/musl-1.2.6-linux-x86_64.tar.gz",
                },
                sha256 = "44f6b63ddd6fcb3e668d76fe336cf91e42d4aa1c538bd228b09a298065284c49",
            },
            ["1.2.5"] = {
                -- 1: libc.so (the loader) no longer names the build
                -- machine's musl-gcc lib/ as its RPATH (install()).
                -- 2: the link files leave lib/ for usr/lib/musl (config()).
                revision = 2,
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/musl/releases/download/1.2.5/musl-1.2.5-linux-x86_64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/musl/releases/download/1.2.5/musl-1.2.5-linux-x86_64.tar.gz",
                    },
                    sha256 = "b48e958059906a4e5eef9b222d68e6e17a13c5640973d815bac6c2c66ba70d9a",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/musl/releases/download/1.2.5/musl-1.2.5-linux-aarch64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/musl/releases/download/1.2.5/musl-1.2.5-linux-aarch64.tar.gz",
                    },
                    sha256 = "615c40618263604ceba1d239dd023d431237cecf0b918871630addc22dab23fd",
                },
            },
        },
    },
}

-- 1.2.6 was published for x86_64 only: an aarch64 reader refuses it rather
-- than install x86 bytes.
if recipe_arch == "aarch64" then
    package.xpm.linux["1.2.6"] = nil
end

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
    -- The loader this payload has (ld-musl-<arch>.so.1), read from it: a
    -- hook does not always see the catalog's architecture.
    local loader = nil
    for _, name in ipairs({"ld-musl-x86_64.so.1", "ld-musl-aarch64.so.1"}) do
        local p = path.join(pkginfo.install_dir(), "lib", name)
        if os.isfile(p) then loader = p end
    end
    if not loader then
        raise("musl payload has no lib/ld-musl-<arch>.so.1 after install")
    end

    -- The published libc.so carries an RPATH into the machine that built it
    -- (musl-gcc's lib/). It is the loader: nothing it could search for is
    -- there, and a root's closure check rightly refuses a payload whose ELF
    -- names a path outside it. Removed here; asserted, not assumed.
    local pe = "patchelf"
    local bd = nil
    if pkginfo.build_dep then
        bd = try { function() return pkginfo.build_dep("xim:patchelf") end }
    end
    if bd and bd.bin and os.isfile(path.join(bd.bin, "patchelf")) then
        pe = path.join(bd.bin, "patchelf")
    end
    local libc = path.join(pkginfo.install_dir(), "lib", "libc.so")
    os.exec(string.format([["%s" --remove-rpath "%s"]], pe, libc))
    local left = os.iorun(string.format([[%s --print-rpath "%s"]], pe, libc))
    if left and left:gsub("%s+", "") ~= "" then
        raise("libc.so still names an RPATH after patchelf: " .. left)
    end

    return true
end

-- ── what goes into the subos's lib/ ────────────────────────────────────
--
-- The loader only. Its name is musl's alone, so it registers into the
-- shared `lib/` like any lib, under `<version>-musl` (the idiom of
-- jdk-temurin's `25.0.4+7-temurin` and musl-gcc's `16.1.0-musl`) and bound
-- to the release, so `xlings use musl` moves it.
local LOADERS = { "ld-musl-x86_64.so.1", "ld-musl-aarch64.so.1" }

-- ── what revision 1 registered there, and no release does now ──────────
--
-- The link-time files, eleven of them under glibc's own names. Bound to
-- `musl@<version>`, they went active with that group on `xlings install
-- musl`, and from then on `cc` linked musl's crt1.o and libc.so against
-- glibc's headers:
--
--     undefined reference to `__isoc23_strtol'
--
-- They live in `usr/lib/musl` now. config() removes these nodes where the
-- home still has them (a scope configured at revision 1), and uninstall()
-- with the release.
local LINK_LIBS = {
    -- glibc registers these names too
    "Scrt1.o", "crt1.o", "crti.o", "crtn.o",
    "libc.a", "libc.so", "libdl.a", "libm.a",
    "libpthread.a", "librt.a", "libutil.a",
    -- musl's own
    "rcrt1.o", "libcrypt.a", "libresolv.a", "libxnet.a",
}

local FLAVOR = "musl"

local function flavor_version()
    return pkginfo.version() .. "-" .. FLAVOR
end

function config()
    -- Root of this release's binding group, so `xlings use musl 1.2.5`
    -- switches everything bound to it in one step.
    --
    -- `type = "group"` because the node names no artifact: there is no
    -- `bin/musl` to exec. Left as the default `program` kind it becomes
    -- a shim that can only ever fail — verified here before the fix, as
    -- `subos/default/bin/musl -> ../../../bin/xlings`, exactly the
    -- orphan `self doctor` reports (openxlings/xlings#452). Same idiom
    -- as gcc.lua / rust.lua / jdk-temurin.lua.
    local binding = "musl@" .. pkginfo.version()
    xvm.add("musl", { type = "group" })

    __remove_registered(LINK_LIBS, __stored_version())

    local musl_libdir = path.join(pkginfo.install_dir(), "lib")
    for _, loader in ipairs(LOADERS) do
        -- Only the loader this payload has (one per architecture).
        if os.isfile(path.join(musl_libdir, loader)) then
            xvm.add(loader, {
                version = flavor_version(),
                type = "lib",
                bindir = musl_libdir,
                filename = loader, -- target file name
                alias = loader, -- source file name
                binding = binding,
            })
        end
    end

    __declare_dir("lib", "usr/lib/musl", binding)
    __declare_dir("include", "usr/include/musl", binding)

    log.info("musl: link files in usr/lib/musl, headers in usr/include/musl "
             .. "(glibc keeps lib/ and usr/include)")

    return true
end

function uninstall()
    -- Version-scoped on purpose: any other installed musl release must
    -- survive this. The declared usr/lib/musl and usr/include/musl
    -- entries go with the release.
    local v = __stored_version()
    for _, set in ipairs({ LOADERS, LINK_LIBS }) do
        for _, lib in ipairs(set) do
            xvm.remove(lib, v)
        end
    end
    xvm.remove("musl", pkginfo.version())
    return true
end

-- Removes each of NAMES at KEY where this home has it registered. In
-- config() a client refuses the removal of a version it does not know,
-- and most scopes never held the revision-1 nodes.
function __remove_registered(names, key)
    for _, name in ipairs(names) do
        if xvm.has(name, key) then
            xvm.remove(name, key)
        end
    end
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

function __declare_dir(src_rel, dst_rel, binding)
    -- The payload's SRC_REL, entry by entry, at DST_REL in the subos.
    -- Declared where the client supports it, so the entries follow
    -- `xlings use` and are removed with the release instead of outliving
    -- it.
    --
    -- Never into the shared `lib/` or `usr/include` themselves: musl's
    -- crt1.o, libc.so, stdio.h and features.h carry the names of glibc's,
    -- with other contents, and whichever lands second silently wins for
    -- every compile and link in the subos. So they go to their own
    -- directory and a musl build points at it explicitly (`-B`/`-L`,
    -- `-isystem`, or the toolchain's own sysroot) rather than inheriting
    -- it by accident.
    local src_dir = path.join(pkginfo.install_dir(), src_rel)
    if not os.isdir(src_dir) then
        return
    end

    if sysroot.declare_headers(pkginfo.install_dir(), src_rel, dst_rel, binding) then
        return
    end

    -- Legacy path for a client with no `xvm.files`. The stamp matters
    -- for the same reason it does in glibc.lua: config() runs on every
    -- dependent install, and without it each one re-links the tree.
    local dst_dir = path.join(system.subos_sysrootdir(), dst_rel)
    local stamp = path.join(dst_dir, ".musl-" .. pkginfo.version() .. ".stamp")
    if os.isfile(stamp) then
        log.debug("musl %s already in the subos (stamp present), skipping.", dst_rel)
        return
    end

    log.info("Linking musl %s into the subos (%s) ...", src_rel, dst_rel)
    sysroot.install_headers(src_dir, dst_dir)
    io.writefile(stamp, pkginfo.version())
end
