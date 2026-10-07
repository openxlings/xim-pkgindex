-- Linux ARM64 metadata requires xlings 2026.10.8.1 or newer, whose
-- catalog and hook loaders expose the process architecture consistently.
-- Older x86_64 clients retain their existing layout.
local recipe_arch = (os.arch and os.arch()) or "x86_64"
local runtime_metadata = {
    x86_64 = { loader = "lib64/ld-linux-x86-64.so.2",
               abi = "linux-x86_64-glibc", libdirs = { "lib64" } },
    aarch64 = { loader = "lib/ld-linux-aarch64.so.1",
               abi = "linux-aarch64-glibc", libdirs = { "lib" } },
}
local runtime_export = runtime_metadata[recipe_arch == "arm64" and "aarch64" or recipe_arch]
    or runtime_metadata.x86_64

package = {
    spec = "1",

    homepage = "https://www.gnu.org/software/libc",
    -- base info
    name = "glibc",
    description = "The GNU C Library",

    authors = {"GNU"},
    licenses = {"GPL"},
    repo = "https://sourceware.org/git/?p=glibc.git;a=summary",
    docs = "https://www.gnu.org/doc/doc.html",

    -- xim pkg info
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable", -- dev, stable, deprecated
    categories = {"libc", "gnu"},
    keywords = {"libc", "gnu"},

    -- xvm: xlings version management
    xvm_enable = true,

    -- Only `ldd` is a CLI shim. The .so / .a files are libs registered
    -- via `xvm.add(name, { type = "lib", ... })` in config() below — they
    -- live in glibc's xvm version DB, not in subos/default/bin, so they
    -- don't belong in `programs` (which is the CLI-shim audit list).
    programs = { "ldd" },

    xpm = {
        linux = {
            -- Declare the dynamic linker we ship so consumers don't have
            -- to hardcode `path.join(glibc_dir, "lib64", "ld-linux-x86-64.so.2")`
            -- in their own install hooks. xlings predicate-driven elfpatch
            -- (regenerated post 2026-05-02 design) reads this and patches
            -- consumer ELFs automatically. `abi` is the disambiguation tag
            -- when a subos hosts both glibc and musl xpkgs.
            --
            -- WHAT DECLARING THIS COSTS THE CONSUMER, because it is not
            -- obvious and it is not reversible at runtime: our ld.so resolves
            -- nothing through ld.so.cache. On a multiarch distro essentially
            -- every system library lives in /usr/lib/<triple> and is reachable
            -- ONLY through that cache, so a payload whose PT_INTERP points
            -- here has no host fallback at all.
            --
            -- That is the intended end state, and as of 2.44r1 it is true for
            -- the reason stated rather than by accident. The published 2.44
            -- gets there the wrong way: its cache path is
            -- `/home/xlings/.xlings_data/.../etc/ld.so.cache`, the BUILD
            -- MACHINE, which no user has -- so the cache misses because the
            -- file is absent, and reading that as "we do not use the cache"
            -- confuses a stale artifact for a design. 2.44r1 carries the
            -- reserved prefix and ships no cache at all.
            --
            -- Either way the declaration is all-or-nothing. A consumer's closure
            -- must cover every library it will ever load, dlopen'd ones
            -- included. Reasoning "the missing ones are optional, so behaviour
            -- degrades no further than today" is false: today they resolve off
            -- the host, afterwards they resolve nowhere. Measured on
            -- jdk-temurin, where it is the difference between a working AWT and
            -- UnsatisfiedLinkError; see that recipe.
            exports = {
                runtime = runtime_export,
            },
            -- `latest` is 2.44 (as 2.44.2 — same upstream release, our
            -- revision 1; see that entry) — and from now on it TRACKS the
            -- highest glibc of any distribution we support, as a standing
            -- policy rather than a per-version judgement call. Decided 2026-08-09
            -- (ecosystem-closure design, §C5/§C1):
            --
            -- The target form is X-complete — loader, libc and libraries all
            -- ours — with exactly one permanent exception: host closed-source
            -- hardware libraries, carried in via the `*-host-link` sentinels
            -- (nvidia-gl-host-link, libcuda-host-link, ...). Those libraries
            -- are compiled against the HOST's glibc and need its symbols, so
            -- as long as the exception exists, host-built objects can appear
            -- in our closures — which makes `our_glibc >= host_glibc` a
            -- PERMANENT constraint, not a transition-period one. A `latest`
            -- pinned below the newest supported distro's glibc is therefore
            -- a guaranteed failure, not a conservative default:
            -- mcpp-community/mcpp#392 is exactly the old 2.39 floor meeting a
            -- 2.43 host, and it recurs with every new distro release.
            --
            -- Existing subos are NOT affected by this bump: the runtime is
            -- bound in each subos's subos_info, and the resolver's
            -- pin-to-active keeps an already-activated 2.39 pinned. `latest`
            -- decides only version-less explicit installs and NEW subos.
            --
            -- The same sentence is why a bad artifact cannot be recalled by
            -- republishing it. InstallState (xlings src/core/xim/
            -- install_state.cppm) answers from the payload directory and the
            -- ledger; no caller consults the remote sha256. A machine holding
            -- `xim-x-glibc/2.44` never downloads that url again whatever is
            -- behind it, so overwriting an asset reaches nobody who already
            -- has the payload -- and adds a failure of its own: a client whose
            -- cached index still carries the old hash pulls the new bytes and
            -- fails the integrity check.
            --
            -- What does reach them is `revision` on the version entry
            -- (docs/V2/xpackage-spec.md): a client that implements it records
            -- the revision it installed and reinstalls, stating why, when the
            -- recipe's differs. The rebuilt payload goes under a NEW asset
            -- name with its own sha256, the old asset stays published as it
            -- is, and the version key does not move. A client that predates
            -- revision installs the new asset on a fresh install and keeps
            -- the payload it already has.
            --
            -- Backward compatibility is what makes the move safe in the other
            -- direction: glibc runs older binaries on newer libc, never the
            -- reverse, so every 2.39-built payload in the index runs
            -- unchanged under 2.44.
            ["latest"] = { ref = "2.44.3" },
            ["2.39"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/glibc/releases/download/2.39/glibc-2.39-linux-x86_64.tar.gz",
                        CN = "https://gitcode.com/xlings-res/glibc/releases/download/2.39/glibc-2.39-linux-x86_64.tar.gz",
                    },
                    sha256 = "d5d476e099bd048d0b0d74adce1d86da00dcc79d67325040ef92e52f8408557f",
                },
            },
            -- Built from source, not XLINGS_RES: the sha256 is checked, which
            -- an XLINGS_RES entry cannot do. Build recipe and the reason its
            -- prefix looks the way it does:
            -- .agents/tools/graphics/build-glibc.sh
            --
            -- 2.44 IS LEFT IN PLACE, AND IT IS NOT THE ONE TO INSTALL.
            --
            -- Its asset predates two decisions that were made about it and
            -- never reached it. `strings` on the published loader shows
            -- neither the reserved prefix (AD-11, one day younger than this
            -- tarball) nor the preload change below; it still carries
            -- `/home/xlings/.xlings_data/...`, the build machine.
            --
            -- Nothing about it is edited rather than superseded, because a
            -- published sha256 is a promise to whoever already read it: a
            -- client holding a cached index still has THIS hash, and swapping
            -- the bytes behind the same version breaks the one party that did
            -- nothing wrong. So a published url and its sha256 are immutable:
            -- no entry is removed, and no asset is replaced. What an entry
            -- installs changes only by a higher `revision`, which points the
            -- entry at a NEW asset under the same version key (2.44.3 below)
            -- and leaves the old asset published for cached indexes.
            ["2.44"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/glibc/releases/download/2.44/glibc-2.44-linux-x86_64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/glibc/releases/download/2.44/glibc-2.44-linux-x86_64.tar.gz",
                    },
                    sha256 = "0105292fd6b49f74fbf51f93af973b78a9fc18225cb1c757c720e90de3120182",
                },
            },
            -- 2.44.2 IS BACK, AND IT IS `latest`.
            --
            -- It was withdrawn three times. Not because the artifact was bad
            -- -- it was always good -- but because the BINDING IS THE PAYLOAD
            -- DIRECTORY NAME, and consumers held that name as a compiled-in
            -- constant. A consumer with `glibc@2.44` baked in needs
            -- `xim-x-glibc/2.44` on disk; publishing a higher version means
            -- range dependencies (36 of them, `glibc@>=2.38/2.39`) resolve
            -- through select_best -- MAXIMUM satisfying, which does not
            -- consult `latest` -- install the higher one, and the consumer
            -- refuses:
            --
            --   error: selected RuntimeBinding glibc@2.44 requires payload
            --          '<home>/.../xpkgs/xim-x-glibc/2.44', but it is not
            --          installed
            --
            -- What changed is that every consumer now takes the binding from
            -- THIS FILE instead of from a constant, so both questions asked of
            -- this table give the same answer again. Measured across four
            -- client versions against exactly this state:
            --
            --   v2026.8.8.1   [constant]     declares 2.39    installs 2.44.2
            --   v2026.8.10.1  [constant]     declares 2.44    installs 2.44.2
            --   2026.8.27.4   [reads index]  declares 2.44.2  installs 2.44.2
            --   2026.8.27.5   [index + D1]   declares 2.44.2  installs 2.44.2
            --
            -- The two that mismatch are gone: openxlings/xlings#574 moved all
            -- seven CI bootstrap pins off them, and mcpp-community/mcpp#520
            -- moved mcpp's bundled xlings to 2026.8.27.5.
            --
            -- ⚠️ MOVING `latest` WITH THE ENTRY IS NOT OPTIONAL. Adding 2.44.2
            -- while leaving `latest` at 2.44 is strictly worse than not adding
            -- it: select_best would install 2.44.2 while every binding still
            -- said 2.44. `latest` and "the highest entry" are two different
            -- questions, and they must not disagree for a runtime package.
            --
            -- Why it is worth doing at all -- `strings` on the two loaders:
            --
            --                             2.44        2.44.2
            --   XLINGS_LD_PRELOAD_FILE    absent      present
            --   build-machine paths       8           0
            --   preload path              /etc/ld.so.preload   /nonexistent/...
            --
            -- 2.44 reads the HOST's /etc/ld.so.preload (mcpp-community/mcpp#484)
            -- and still carries the machine it was built on. Every user is on
            -- it today. That is what this restores.
            --
            -- 2.44 stays in the table, append-only: subos created against it
            -- keep resolving, and on 2026.8.27.5 the declaration outranks
            -- `latest`, so they are not dragged forward.
            ["2.44.2"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/glibc/releases/download/2.44.2/glibc-2.44.2-linux-x86_64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/glibc/releases/download/2.44.2/glibc-2.44.2-linux-x86_64.tar.gz",
                    },
                    sha256 = "ed4bf048b8ed2b65433e0dd655f93133da4a9bd458276cfa986b7cccde835d08",
                },
            },
            -- 2.44.3: THE LOADER'S OWN DIRECTORY IS ITS DEFAULT DIRECTORY.
            --
            -- Same upstream 2.44, same prefix, plus
            -- .agents/tools/graphics/patches/glibc-2.44-default-dir-follows-loader.patch.
            -- The reserved prefix above cut the host's libraries off, as meant,
            -- and cut glibc's OWN libraries off with them, which nobody meant:
            -- a system glibc reaches libresolv.so.2 through slibdir, a default
            -- directory that serves every object whatever its RUNPATH says. Ours
            -- had no such directory, so a prebuilt module carrying its own
            -- DT_RUNPATH (sharp's libvips, openxlings/xlings#605) could not find
            -- a glibc library sitting beside the libc it was already using --
            -- and no RPATH on the program could help, because an object with a
            -- DT_RUNPATH is searched on that alone.
            --
            -- `strings` shows no difference from 2.44.2 (the prefix is still
            -- compiled in; only the first default-directory entry is replaced
            -- at run time), so the difference is asserted as behaviour in
            -- build-glibc.sh: a RUNPATH-only program starts and resolves
            -- libresolv from the loader's directory, and the host-only libz.so.1
            -- stays unreachable.
            --
            -- Moving `latest` with it for the reason given at 2.44.2. Existing
            -- subos and already-patched payloads keep the glibc they were bound
            -- to; new subos and new installs get this one.
            --
            -- REVISION 1: THE PAYLOAD REACHES ITS OWN LOCALE AND GCONV DATA
            -- (openxlings/xlings#621).
            --
            -- Revision 0 compiled every data path of libc under the dead
            -- reserved prefix, so nothing in lib/locale, lib/gconv,
            -- share/locale or share/zoneinfo could be found, and it shipped no
            -- compiled locale at all. Measured under LANG=C.UTF-8:
            -- setlocale(LC_ALL, "C.UTF-8") returned NULL, and
            -- iconv_open("GBK", "UTF-8") failed beside 255 gconv modules.
            --
            -- Revision 1 is the same upstream 2.44 and the same two patches,
            -- configured with that prefix padded to 255 bytes, so install()
            -- can write the install directory over it inside the binaries
            -- (__relocate) and then compile C.utf8 with the payload's own
            -- localedef (__generate_c_utf8). The top-level directory of the
            -- archive is now its own stem, so the payload root is found
            -- without a directory search.
            --
            -- Same version key, new asset. Revision 0 --
            -- releases/download/2.44.3/glibc-2.44.3-linux-x86_64.tar.gz,
            -- sha256 b84de544a8c8b3e1e7a1103c829b393a37bc865f6720e391ec05f8ef69672845
            -- -- stays published unchanged, so a client with a cached index
            -- still gets the bytes its hash names. A fresh install gets
            -- revision 1 on every client, because the recipe does the
            -- relocation itself; a machine that already holds 2.44.3 gets it
            -- only from a client that implements revision, which reinstalls
            -- the payload and says why.
            ["2.44.3"] = {
                revision = 1,
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/glibc/releases/download/2.44.3-r1/glibc-2.44.3-r1-linux-x86_64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/glibc/releases/download/2.44.3-r1/glibc-2.44.3-r1-linux-x86_64.tar.gz",
                    },
                    sha256 = "5a02e37f735fdf6121babfd7616342b79b2440985d909bc42d711c48d0cb3623",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/glibc/releases/download/2.44.3-r1/glibc-2.44.3-r1-linux-aarch64.tar.gz",
                        CN = "https://gitcode.com/xlings-res/glibc/releases/download/2.44.3-r1/glibc-2.44.3-r1-linux-aarch64.tar.gz",
                    },
                    sha256 = "25dbdec6bc40784f138028e2c7418f7522b2b96f4ef81be2e60d8b77f0944c66",
                },
            },
        },
    },
}

import("xim.libxpkg.log")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.libxpkg.elfpatch")
import("xim.pkgindex.sysroot")

-- The prefix libc is configured with (.agents/tools/graphics/build-glibc.sh).
-- RESERVED_PREFIX is AD-11's dead path; payloads up to 2.44.3 revision 0 carry
-- it as it is. From 2.44.3 revision 1 on it is padded with one path component
-- to 255 bytes, so that the install directory fits in its place inside the
-- binaries. The build script spells the same string; __relocate finds out
-- which one a payload carries by reading it.
local RESERVED_PREFIX = "/nonexistent/xlings-use-rpath-not-default-search"
local PADDING_HEAD = RESERVED_PREFIX .. "/padding-to-255-bytes-for-install-time-relocation"
local PADDED_PREFIX = PADDING_HEAD .. string.rep("_", 255 - #PADDING_HEAD)

-- Hook paths follow the downloaded payload; they do not depend on the
-- client's optional architecture API.
local function runtime_layout()
    local file = pkginfo.install_file()
    if file:find("linux-aarch64", 1, true) then
        return "lib", "ld-linux-aarch64.so.1"
    end
    return "lib64", "ld-linux-x86-64.so.2"
end

-- libnss modules
local glibc_libs = {
    "crt1.o", "crti.o", "crtn.o", -- crt
    -- The architecture-specific loader is registered in config().
    "libc.a", "libc.so", "libc.so.6", "libc_nonshared.a", -- C library
    "libdl.a", "libdl.so.2", -- dynamic loading
    -- `libm-<version>.a` is version-named and is added in config() rather than
    -- listed here: writing `libm-2.39.a` made this list true of exactly one
    -- glibc, and installing any other version registered a file that is not
    -- there.
    "libm.a", "libmvec.a", "libm.so", "libm.so.6", "libmvec.so.1", -- math
    "libpthread.so.0", "libpthread.a", -- pthread
    "librt.so.1", -- realtime
    "libresolv.so", "libresolv.so.2", -- resolver
    -- libnss modules
    "libnss_compat.so",
    "libnss_compat.so.2",
    "libnss_dns.so.2",
    "libnss_files.so.2",
    "libnss_hesiod.so",
    "libnss_hesiod.so.2",
    "libnss_db.so",
    "libnss_db.so.2",
    -- 
    "libnsl.so.1",

    -- rust-lld: error: cannot open Scrt1.o: No such file or directory
    -- rust-lld: error: unable to find library -lutil
    -- rust-lld: error: unable to find library -lrt
    "Scrt1.o",
    "libutil.a", "libutil.so.1",
    -- librt.so.1 is already listed above with the realtime group; a
    -- second entry makes config() call xvm.add for the same name and
    -- version twice.
    "librt.a",
}

function install()
    -- Hook executors reload recipes without the catalog LoaderContext.
    -- Their top-level os.arch() is unbound even in a current client. Check
    -- the catalog's resolved exports, passed into the hook at invocation,
    -- rather than that executor's fallback metadata.
    if pkginfo.install_file():find("linux-aarch64", 1, true) then
        local exports = _RUNTIME and _RUNTIME.self_exports
        local expected_loader = path.join(pkginfo.install_dir(),
            "lib", "ld-linux-aarch64.so.1")
        if not exports or exports.abi ~= "linux-aarch64-glibc"
           or exports.loader ~= expected_loader then
            log.error("glibc aarch64 requires xlings >= 2026.10.8.1; "
                .. "the catalog must resolve the aarch64 runtime loader and ABI")
            return false
        end
    end

    -- The payload root, without assuming what the tarball called it.
    --
    -- This used to be `install_file() minus .tar.gz`, which is true of the
    -- 2.39 asset and of nothing else by construction — 2.44's tar holds
    -- `glibc-2.44/`, not `glibc-2.44-linux-x86_64/`. The mismatch does not
    -- raise: os.mv fails, install() returns true, and the install directory is
    -- left holding the download cache. What you get is a glibc package with no
    -- loader in it, reported as a successful install.
    local glibcdir = pkginfo.install_file():replace(".tar.gz", "")
    if not os.isdir(glibcdir) then
        -- Identified by CONTENT, not by name. The extraction directory is
        -- shared and holds more than this archive, so "the only directory" is
        -- not a usable rule either; what makes a directory glibc's payload is
        -- that it contains glibc.
        local base = path.directory(glibcdir)
        local found = nil
        local f = io.popen(string.format([[ls -1 "%s" 2>/dev/null]], base))
        if f then
            for line in f:lines() do
                local d = line:gsub("[\r\n]+$", "")
                if d ~= "" then
                    local cand = path.join(base, d)
                    if os.isdir(cand)
                       and (os.isfile(path.join(cand, "lib", "libc.so.6"))
                         or os.isfile(path.join(cand, "lib64", "libc.so.6"))) then
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
                .. "directory contains lib/libc.so.6", base))
        end
        glibcdir = found
    end

    os.tryrm(pkginfo.install_dir())
    os.mv(glibcdir, pkginfo.install_dir())

    log.info("Relocating glibc files(path) ...")
    if __relocate() then
        __generate_c_utf8()
    else
        -- A payload configured before the padded prefix: its binaries name a
        -- 48-byte prefix that no install path fits in, so libc cannot be
        -- pointed at this directory and a compiled locale would never be read.
        log.info("this glibc payload predates install-time relocation: its "
                 .. "locale, gconv and zoneinfo paths stay unreachable "
                 .. "(openxlings/xlings#621); 2.44.3 revision 1 has them")
    end

    __check_nss_coverage()

    return true
end

function config()
    xvm.add("glibc")

    local glibc_root_binding = "glibc@" .. pkginfo.version()
    local glibc_version = __version_key()
    local glibc_bindir = path.join(pkginfo.install_dir(), "bin")
    local libname, loader_name = runtime_layout()
    local glibc_libdir = path.join(pkginfo.install_dir(), libname)

    xvm.add(loader_name, {
        type = "lib", version = glibc_version, bindir = glibc_libdir,
        filename = loader_name, alias = loader_name, binding = glibc_root_binding,
    })

    log.debug("1 - config glibc tool...")
    local bin_config = {
        version = glibc_version,
        bindir = glibc_bindir,
        binding = glibc_root_binding,
        envs = {
            --["LD_LIBRARY_PATH"] = glibc_libdir,
            --["LD_RUN_PATH"] = glibc_libdir,
        }
    }

    xvm.add("ldd", bin_config)

-- lib
    log.debug("2 - config glibc libs...")
    local lib_config = {
        version = glibc_version,
        type = "lib",
        bindir = glibc_libdir,
        binding = glibc_root_binding,
    }

    -- The version-named archive, whatever this release calls it.
    local libs = {}
    for _, l in ipairs(glibc_libs) do table.insert(libs, l) end
    table.insert(libs, "libm-" .. pkginfo.version() .. ".a")

    for _, lib in ipairs(libs) do
        -- Guarded, the way zlib's registration is. A name that is not in this
        -- release's payload should be skipped, not registered as a lib whose
        -- source file does not exist — glibc's own file set changes between
        -- versions and the list above cannot be right for all of them.
        if os.isfile(path.join(glibc_libdir, lib)) then
            lib_config.filename = lib -- target file name
            lib_config.alias = lib -- source file name
            xvm.add(lib, lib_config)
        end
    end

    log.debug("3 - glibc config header files...")

    __config_header(glibc_root_binding)

    return true
end

function uninstall()
    local glibc_version = __version_key()
    local _, loader_name = runtime_layout()
    xvm.remove(loader_name, glibc_version)
    for _, lib in ipairs(glibc_libs) do
        xvm.remove(lib, glibc_version)
    end
    xvm.remove("libm-" .. pkginfo.version() .. ".a", glibc_version)
    xvm.remove("ldd", glibc_version)
    xvm.remove("glibc")
    return true
end

-- private

-- Does the NSS module set we ship cover what this host's nsswitch.conf asks for?
--
-- glibc does not link its name-service backends; it dlopens `libnss_<mod>.so.2`
-- at the moment of the first lookup, and the module MUST come from the same
-- glibc as the caller. So a process that switched to our loader stops using the
-- host's modules and starts using ours — for `getpwnam`, `getaddrinfo`, group
-- lookups, everything.
--
-- We ship compat, db, dns, files and hesiod. A host configured with systemd's
-- (`systemd`, `resolve`, `myhostname`, `mymachines`), Avahi's (`mdns4_minimal`)
-- or NIS's modules names backends we do not have.
--
-- Warn, do not fail. On an ordinary machine the user is in /etc/passwd and
-- `files` answers, so the missing modules never get consulted and the install
-- is fine; failing here would break the common case to report the rare one.
-- The rare one is real though — LDAP, NIS or systemd-homed users are resolved
-- by exactly the modules we lack, and the failure mode is not an error but an
-- empty answer: `getpwuid` returns nothing and the caller reports something
-- else entirely (a missing home directory, a numeric username, a failed
-- lookup). `xlings doctor` has a cell for the other half of this — whether
-- getpwuid actually resolves in a home that has already switched.
function __check_nss_coverage()
    local conf = "/etc/nsswitch.conf"
    if not os.isfile(conf) then
        -- Not a pass. Say which one it is, or "no warnings" reads as "checked".
        log.debug("no %s on this host; NSS coverage not compared", conf)
        return
    end

    local content = io.readfile(conf)
    if not content or content == "" then
        log.debug("%s is empty or unreadable; NSS coverage not compared", conf)
        return
    end

    local libname = runtime_layout()
    local libdir = path.join(pkginfo.install_dir(), libname)
    local seen, missing = {}, {}
    for line in content:gmatch("[^\r\n]+") do
        -- Comments off first, then the `db: mod [STATUS=action] mod` shape.
        -- The bracketed reactions are control flow, not modules; leaving them
        -- in would report `NOTFOUND` and `UNAVAIL` as missing backends.
        local body = line:gsub("#.*", "")
        local _, rest = body:match("^%s*([%w_]+)%s*:%s*(.*)$")
        if rest then
            rest = rest:gsub("%[.-%]", " ")
            for mod in rest:gmatch("[%w_%-]+") do
                if not seen[mod] then
                    seen[mod] = true
                    if not os.isfile(path.join(libdir, "libnss_" .. mod .. ".so.2")) then
                        table.insert(missing, mod)
                    end
                end
            end
        end
    end

    if #missing == 0 then
        log.info("NSS: every backend named in %s is present in this payload", conf)
        return
    end

    log.warn("NSS: %s names backend(s) this glibc does not ship: %s. "
             .. "Programs that switch to this loader will not consult them — "
             .. "harmless if your users resolve via `files`, but users defined "
             .. "only by those backends will silently not be found.",
             conf, table.concat(missing, ", "))
end

-- The version key this package's entries are stored under.
--
-- xlings keys a version by namespace for every repo but the primary one, so
-- `local:glibc` stores `local:glibc-2.39` while `xim:glibc` stores a bare
-- `glibc-2.39`. Removing by the bare key is unambiguous only while ONE of
-- them exists: with both installed, removal fails with
--
--     bare removal version 'glibc-2.39' matches 2 stored versions
--
-- and uninstall leaves every registered lib behind. That state was
-- unreachable while the index shipped one glibc; adding 2.44 made it
-- ordinary.
--
-- The namespace is not exposed to a hook, but the store directory is:
-- `<data>/xpkgs/<ns>-x-glibc/<version>`. Deriving it from install_dir() keeps
-- this to the recipe rather than waiting on a libxpkg field.
function __version_key()
    local store = path.filename(path.directory(pkginfo.install_dir()))
    local ns = store:match("^(.-)%-x%-")
    local bare = "glibc-" .. pkginfo.version()
    if ns and ns ~= "" and ns ~= "xim" then return ns .. ":" .. bare end
    return bare
end

function __config_header(binding)
    -- Declared where the client supports it, so the 130 top-level entries
    -- follow `xlings use` and are removed with the release instead of
    -- outliving it. No stamp on that path: a declaration is idempotent by
    -- construction, and unlike a stamp it survives a sysroot wipe, because
    -- it is state xlings owns rather than a file in the tree being wiped.
    --
    -- glibc is the case declare_headers warns about — it scatters into
    -- `usr/include`, the most shared namespace there is, and the semantics
    -- change from first-claimant-keeps-it to last-one-wins. Measured: of
    -- glibc's 129 top-level entries exactly one, `scsi`, is also shipped by
    -- another package in the index (linux-headers). Every other name is
    -- glibc's alone.
    --
    -- `scsi` is therefore declared per FILE, and linux-headers does the same
    -- in the same release. Directory granularity cannot express what that
    -- one name needs: the two payloads are DISJOINT — glibc ships scsi.h,
    -- scsi_ioctl.h and sg.h, linux-headers ships six others — and a
    -- distribution's /usr/include/scsi is the union. Declaring the directory
    -- makes it one link, so whoever installed last won it whole.
    --
    -- This comment used to say that was acceptable because it had become
    -- "state doctor can see". It had not: nothing reported it, and measured
    -- on a real installation the link belonged to linux-headers, so
    -- `<scsi/sg.h>` was simply ABSENT from a subos with glibc installed and
    -- declaring it. Recorded and unread is the same as unrecorded.
    if sysroot.declare_headers(pkginfo.install_dir(), "include",
                               "usr/include", binding,
                               { merge = { "scsi" } }) then
        return
    end

    local include_dir = path.join(pkginfo.install_dir(), "include")

    -- Legacy path, byte-for-byte what it did before, for a client with no
    -- `xvm.files`. Do not "clean up" the stamp here: config() runs on every
    -- dependent xpkg install (anything listing glibc@<ver> in deps), so
    -- without it every install of xim:gcc / fromsource:* re-cp's the whole
    -- include tree. Same fix shape as linux-headers (commit 3718532).
    local subos_sysrootdir = system.subos_sysrootdir()
    local sysroot_usrdir = path.join(subos_sysrootdir, "usr")
    if not os.isdir(sysroot_usrdir) then os.mkdir(sysroot_usrdir) end

    local stamp = path.join(sysroot_usrdir, ".glibc-" .. pkginfo.version() .. ".stamp")
    if os.isfile(stamp) then
        log.debug("glibc headers already in subos rootfs (stamp present), skipping copy.")
        return
    end

    log.info("Linking glibc headers into subos sysroot ...")
    sysroot.install_headers(include_dir, path.join(sysroot_usrdir, "include"))
    io.writefile(stamp, pkginfo.version())
end

-- The tarball is a prebuilt, so it carries the absolute paths of the machine
-- that built it -- and that machine used the `.xlings_data` home layout xlings
-- abandoned long ago, so the paths cannot exist anywhere. Both the 2.39 and the
-- 2.44 payloads are affected; it is the build pipeline's `--prefix`, not a
-- stale artifact (see AD-4/AD-11 in xlings/.agents/docs/
-- 2026-08-06-subos-architecture-proposal.md).
--
-- This used to be done here, by hand, and it did not work:
--
--   * it named six files, and the payload has build paths in five, of which
--     the one that mattered most (`bin/ldd`'s TEXTDOMAINDIR) was on the list
--     and still went unprocessed because the pattern's tail was anchored at
--     `/lib`;
--   * the pattern `([^%s)]+)/<marker>/lib` matched leftward through quotes and
--     variable names, so `RTLDLIST="` was swallowed with the path and the ldd
--     we ship does not survive `bash -n`;
--   * and it reported success on having written anything, so neither failure
--     produced any output at all.
--
-- libxpkg 0.0.51 does it properly, for every recipe that downloads a prebuilt:
-- enumerate the payload, anchor on a whole absolute path token, and assert
-- afterwards that no build path survived and every rewritten script still
-- parses.
--
-- That covers TEXT files only, by design. The paths libc uses to find its own
-- data are C strings inside ELF files, and __relocate_binaries below rewrites
-- those. Returns true when the payload carried the padded prefix, i.e. when
-- libc now points at this directory.
function __relocate()
    -- THREE markers, because the build pipeline changed twice and the tarballs
    -- did not change with it.
    --
    -- Releases up to and including 2.44 were configured with the build
    -- machine's own path -- `/home/xlings/.xlings_data/.../fromsource-x-glibc/
    -- <ver>` -- which leaked the builder's disk layout into every artifact.
    -- AD-11 replaced it with an explicitly reserved placeholder, and 2.44.3
    -- revision 1 padded that placeholder to 255 bytes
    -- (.agents/tools/graphics/build-glibc.sh).
    --
    -- All three have to be handled here, and for a while all three will be:
    -- an already published tarball keeps the marker it was built with.
    -- Dropping an old marker the day the pipeline changes would leave every
    -- existing release unrelocated, with nothing to say so.
    --
    -- ORDER MATTERS between the first two. RESERVED_PREFIX is the leading part
    -- of PADDED_PREFIX, so rewriting it first would turn `<padded>/lib` into
    -- `<install>/padding-to-255-bytes-.../lib`, a path that does not exist and
    -- that no later marker matches.
    local markers = {
        PADDED_PREFIX,
        RESERVED_PREFIX,
        "fromsource-x-" .. package.name .. "/" .. pkginfo.version(),
    }

    -- Binaries first, and by the recipe itself, so the relocation does not
    -- depend on the client: every client that installs revision 1 gets a libc
    -- that finds its locale and gconv data.
    local dir = pkginfo.install_dir()
    local relocatable = __relocate_binaries(dir, PADDED_PREFIX) > 0

    -- type(), not truthiness: an unknown field on a module proxy is truthy on
    -- every client, so `if elfpatch.relocate_build_paths then` would be true
    -- even where the function does not exist. This repo has fallen into that
    -- twice (subos.env, xim.pkgindex.sysroot).
    if type(elfpatch.relocate_build_paths) == "function" then
        -- One call each. A marker that is not present rewrites nothing and
        -- asserts nothing remains, which is the correct outcome for a payload
        -- built by the other pipeline -- not an error.
        for _, marker in ipairs(markers) do
            elfpatch.relocate_build_paths{ marker = marker }
        end
        if relocatable then __assert_no_reserved_prefix(dir, true) end
        return relocatable
    end

    -- Older client. Do the ONE substitution that is both needed and safe here,
    -- and say plainly what is left undone.
    --
    -- Only the linker scripts. In those the path is preceded by `( ` or a
    -- space, so the greedy match has nothing to swallow, and they are what a
    -- compiler in this subos actually reads. The `bin/` scripts are left
    -- ALONE: the old code's output for them was not "imperfect", it was a file
    -- bash cannot parse, and an `ldd` that still names a nonexistent directory
    -- is strictly better than an `ldd` that does not run.
    -- Legacy path only ever saw the legacy marker, and the placeholder prefix
    -- needs no leftward match at all -- it is already an absolute path token
    -- with nothing before it. A client this old will simply not relocate a
    -- payload from the new pipeline, and says so below.
    local version_escaped = pkginfo.version():gsub("%.", "%%.")
    local path_pattern = "([^%s)]+)/"
        .. ("fromsource-x-" .. package.name):gsub("-", "%%-")
        .. "/" .. version_escaped .. "/lib"

    local base = pkginfo.install_dir()
    local rewritten = 0
    for _, f in ipairs({ "lib/libc.so", "lib/libm.so", "lib/libm.a" }) do
        local abs_f = path.join(base, f)
        if os.isfile(abs_f) then
            local content = io.readfile(abs_f)
            local new_content, count = content:gsub(path_pattern, ".")
            if count > 0 then
                io.writefile(abs_f, new_content)
                rewritten = rewritten + 1
            end
        end
    end

    log.warn("this xlings is too old to relocate glibc's build paths "
             .. "(libxpkg 0.0.51 added elfpatch.relocate_build_paths); "
             .. "rewrote %d linker script(s), and bin/ldd, bin/tzselect, "
             .. "bin/xtrace and bin/sotruss keep the build machine's paths. "
             .. "Run `xlings self update` and reinstall glibc to fix them.",
             rewritten)

    -- The text files are this client's gap and are reported above; the
    -- binaries are this recipe's own work, and are asserted all the same.
    if relocatable then __assert_no_reserved_prefix(dir, false) end
    return relocatable
end

-- ── binary relocation ─────────────────────────────────────────────────
--
-- libc finds its own data through paths compiled in as C strings: lib/locale
-- (and its locale-archive), lib/gconv (and gconv-modules.cache), share/locale,
-- share/zoneinfo, etc/localtime, libexec/getconf; the loader names its
-- ld.so.cache, ld.so.preload and default directory the same way. A text
-- rewrite cannot change them, because a string that changes length moves
-- every offset behind it.
--
-- So each occurrence of the 255-byte placeholder is overwritten in place by
-- the install directory followed by `/` up to 255 bytes:
-- `<install>//////lib/locale` names the same directory as
-- `<install>/lib/locale`. Nothing changes length -- not the file, not any
-- string in it (a search list holding the placeholder several times included),
-- and not the lengths glibc compiled in beside its strings. That last part is
-- why the padding is `/` and not NUL, conda's choice: sizeof, a strlen the
-- compiler folded on the constant, and ld.so's table of directory lengths all
-- keep the build-time length, and after NUL padding they read past the end of
-- the path. Measured with NUL padding: each setlocale opened ~2200 paths in
-- the host's root directory (the padding read as empty locale directories),
-- sysconf reported two 32-bit programming environments as supported, and
-- `locale -a` and localedef misread their own directories.
--
-- The placeholder must be at least as long as the install directory, which is
-- what the padding to 255 bytes is for; a longer install directory is refused
-- by name rather than truncated.
--
-- The loader's ld.so.cache and ld.so.preload then name <install>/etc: paths
-- inside this payload, which ships neither, instead of dead ones. The host's
-- /etc is still never read, and XLINGS_LD_PRELOAD_FILE still overrides the
-- preload path.
--
-- Here and not in libxpkg, whose relocate_build_paths is text-only by design:
-- glibc is the one payload that needs it. It becomes a libxpkg helper when a
-- second package does.

-- Characters that end a path token -- the set relocate_build_paths uses, NUL
-- included, because in a binary a C string starts after one.
local PATH_DELIMS = {
    ["\0"] = true, [" "] = true, ["\t"] = true, ["\n"] = true, ["\r"] = true,
    ['"'] = true, ["'"] = true, ["`"] = true, ["("] = true, [")"] = true,
    ["{"] = true, ["}"] = true, ["["] = true, ["]"] = true, ["="] = true,
    [","] = true, [";"] = true, [":"] = true, ["<"] = true, [">"] = true,
    ["|"] = true, ["&"] = true, ["*"] = true,
}

function __sh_quote(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

-- Every regular file of the payload. Symlinks are not followed and not
-- listed: rewriting through one would write outside the payload, and the
-- file it names is listed on its own.
function __payload_files(dir)
    local files = {}
    local f = io.popen("find " .. __sh_quote(dir) .. " -type f 2>/dev/null")
    if not f then raise("cannot enumerate the files of " .. dir) end
    for line in f:lines() do files[#files + 1] = line end
    f:close()
    return files
end

function __read_file(file)
    local f = io.open(file, "rb")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content
end

-- The test libxpkg's relocate_build_paths uses: a NUL in the first 8 KiB.
function __is_binary(content)
    return content:sub(1, 8192):find("\0", 1, true) ~= nil
end

-- `content` with every occurrence of `from` replaced by `to`, which must have
-- the same length. Returns the new content and the number of occurrences.
function __replace_same_length(content, from, to)
    if #to ~= #from then
        error(string.format("replacement is %d bytes, the placeholder %d", #to, #from))
    end
    local out, pos, count = {}, 1, 0
    while true do
        local s, e = content:find(from, pos, true)
        if not s then break end
        out[#out + 1] = content:sub(pos, s - 1)
        out[#out + 1] = to
        pos = e + 1
        count = count + 1
    end
    out[#out + 1] = content:sub(pos)
    return table.concat(out), count
end

-- Replace `file` with `content` through a temporary file in the same
-- directory and a rename: a process running the old file keeps its inode,
-- and an interrupted write leaves the original in place. `cp -p` gives the
-- temporary file the original's mode, and opening it for writing truncates
-- it without changing that mode.
function __replace_file(file, content)
    local tmp = file .. ".xlings-relocate"
    os.remove(tmp)
    local ok = os.execute("cp -p " .. __sh_quote(file) .. " " .. __sh_quote(tmp))
    if ok ~= true and ok ~= 0 then
        os.remove(tmp)
        raise("cannot copy " .. file .. " for relocation")
    end
    local f = io.open(tmp, "wb")
    local written = f and f:write(content)
    local closed = f and f:close()
    if not (written and closed) then
        os.remove(tmp)
        raise("cannot write the relocated copy of " .. file)
    end
    local renamed, err = os.rename(tmp, file)
    if not renamed then
        os.remove(tmp)
        raise("cannot replace " .. file .. ": " .. tostring(err))
    end
end

-- Overwrite `placeholder` with `dir`, `/`-padded to the same length, in every
-- binary file of the payload that holds it. Returns the number of files
-- rewritten; 0 means the payload predates the padded prefix, which is not an
-- error.
function __relocate_binaries(dir, placeholder)
    local to = dir:gsub("/+$", "")
    -- Absolute, and not the root: padding "" with `/` would name the host's
    -- own /lib/locale, /lib/gconv and /etc.
    if to:sub(1, 1) ~= "/" then
        raise(string.format("cannot relocate glibc to '%s': not an absolute "
                            .. "directory below /", dir))
    end
    local targets = {}
    for _, file in ipairs(__payload_files(dir)) do
        local content = __read_file(file)
        if content and __is_binary(content) then
            if content:find(placeholder, 1, true) then
                targets[#targets + 1] = file
            elseif content:find(PADDING_HEAD, 1, true) then
                -- Padded, but not to the string spelled above: the build
                -- script and this recipe disagree, and relocating by either
                -- spelling would leave the other half behind.
                raise(string.format(
                    "%s carries a padded prefix other than the %d-byte one this "
                    .. "recipe relocates; .agents/tools/graphics/build-glibc.sh and "
                    .. "pkgs/g/glibc.lua must spell the same PREFIX", file, #placeholder))
            end
        end
    end
    if #targets == 0 then return 0 end

    -- Checked before anything is written, so a refused install leaves the
    -- payload as it was extracted.
    if #to > #placeholder then
        raise(string.format(
            "glibc can be installed only under a directory of at most %d bytes: its "
            .. "binaries hold the install directory in the space of a %d-byte "
            .. "placeholder, and '%s' is %d bytes. Install it under a shorter home.",
            #placeholder, #placeholder, to, #to))
    end

    local replacement = to .. string.rep("/", #placeholder - #to)
    local occurrences = 0
    for _, file in ipairs(targets) do
        local content = __read_file(file)
        local new, n = __replace_same_length(content, placeholder, replacement)
        if #new ~= #content then
            raise("relocation changed the size of " .. file .. "; not written")
        end
        __replace_file(file, new)
        occurrences = occurrences + n
    end
    log.info("relocated %d occurrence(s) in %d binary file(s) -> %s",
             occurrences, #targets, to)
    return #targets
end

-- No file may still name the reserved prefix as an absolute path (R4). The
-- padded prefix begins with it, so this also catches a padded occurrence left
-- behind, and it catches what the padding exists to rule out: a path compiled
-- in with the 48-byte prefix alone, which no install directory fits. Text
-- files are included when the client relocated them.
function __assert_no_reserved_prefix(dir, include_text)
    local left = {}
    for _, file in ipairs(__payload_files(dir)) do
        local content = __read_file(file)
        if content and (include_text or __is_binary(content)) then
            local pos = 1
            while true do
                local s, e = content:find(RESERVED_PREFIX, pos, true)
                if not s then break end
                if s == 1 or PATH_DELIMS[content:sub(s - 1, s - 1)] then
                    left[#left + 1] = file:sub(#dir + 2)
                    break
                end
                pos = e + 1
            end
        end
    end
    if #left > 0 then
        raise(string.format(
            "%d file(s) still name %s after relocation, so this payload cannot "
            .. "find its own data: %s",
            #left, RESERVED_PREFIX, table.concat(left, ", ")))
    end
end

-- Output and success of a command, stderr included.
function __run(cmd)
    local p = io.popen(cmd .. " 2>&1")
    if not p then return "", false end
    local out = p:read("*a") or ""
    local ok = p:close()
    return out, ok == true or ok == 0
end

-- ── the C.UTF-8 locale ─────────────────────────────────────────────────
--
-- The payload ships localedef and its sources (share/i18n) but no compiled
-- locale, and C.UTF-8 is the one locale a program may reasonably expect of any
-- glibc. It is compiled here, by the payload's own localedef running on the
-- payload's own loader, from the payload's own sources -- never copied from
-- the host, whose locale files belong to the host's glibc and whose format is
-- not guaranteed to match this one. --no-archive writes a directory, which
-- the relocated libc finds at lib/locale/C.utf8 without a locale-archive.
--
-- Then the result is asserted as behaviour, through the payload's own
-- programs: `locale charmap` under LC_ALL=C.UTF-8 must say UTF-8 (setlocale
-- succeeded), and iconv must convert UTF-8 to GBK through lib/gconv. The
-- environment variables that would redirect either lookup are removed, so a
-- pass means the relocated paths were used.
function __generate_c_utf8()
    local dir = pkginfo.install_dir()
    local libname, loader_name = runtime_layout()
    local libdir = path.join(dir, libname)
    local localedir = path.join(dir, "lib", "locale")
    local target = path.join(localedir, "C.utf8")
    -- A payload program on the payload's loader, with `env` assignments first.
    local function run(env, program, args)
        return __run("env -u LD_PRELOAD -u LOCPATH -u GCONV_PATH " .. env .. " "
            .. __sh_quote(path.join(libdir, loader_name))
            .. " --library-path " .. __sh_quote(libdir) .. " "
            .. __sh_quote(path.join(dir, "bin", program)) .. " " .. args)
    end

    os.tryrm(target)
    os.mkdir(localedir)
    -- localedef exits 1 when it wrote the locale with warnings, so the verdict
    -- is the file it produced, not its status. The UTF-8 charmap is read from
    -- share/i18n/charmaps, where the build ships it uncompressed as well, so
    -- that localedef does not need a host gzip.
    local out = run("I18NPATH=" .. __sh_quote(path.join(dir, "share", "i18n")),
                    "localedef", "--no-archive -i C -f UTF-8 " .. __sh_quote(target))
    if not os.isfile(path.join(target, "LC_CTYPE")) then
        raise("the payload's localedef did not produce lib/locale/C.utf8:\n" .. out)
    end

    local charmap = run("LC_ALL=C.UTF-8", "locale", "charmap")
    if charmap:gsub("%s+$", "") ~= "UTF-8" then
        raise("lib/locale/C.utf8 was compiled but setlocale(LC_ALL, \"C.UTF-8\") "
              .. "does not load it: `locale charmap` says " .. charmap)
    end

    -- U+4E2D is E4 B8 AD in UTF-8 and D6 D0 in GBK. The probe files live in
    -- the payload directory, the one place this hook is sure it may write.
    local input = path.join(dir, ".xlings-iconv-probe.in")
    local output = path.join(dir, ".xlings-iconv-probe.out")
    local f = io.open(input, "wb")
    if f then f:write("\228\184\173"); f:close() end
    local iconv_out = run("", "iconv", "-f UTF-8 -t GBK " .. __sh_quote(input)
                                       .. " -o " .. __sh_quote(output))
    local gbk = __read_file(output)
    os.remove(input)
    os.remove(output)
    if gbk ~= "\214\208" then
        raise("iconv from UTF-8 to GBK does not work through this payload's "
              .. "lib/gconv: " .. iconv_out)
    end

    log.info("compiled lib/locale/C.utf8; setlocale(C.UTF-8) and UTF-8 -> GBK "
             .. "work from this payload")
end