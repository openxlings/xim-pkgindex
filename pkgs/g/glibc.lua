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
    archs = {"x86_64"},
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
                runtime = {
                    loader = "lib64/ld-linux-x86-64.so.2",
                    abi    = "linux-x86_64-glibc",
                    -- libdirs not declared → falls back to {lib64, lib} convention
                },
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
            -- behind it, so overwriting an asset reaches exactly the audience
            -- a new version reaches -- and adds a failure the new version
            -- does not: a client whose cached index still carries the old
            -- hash pulls the new bytes and fails the integrity check.
            -- Whoever is already on a bad payload needs
            -- `xlings install glibc@<new>`; that is a release note, not a
            -- version-numbering decision.
            --
            -- Backward compatibility is what makes the move safe in the other
            -- direction: glibc runs older binaries on newer libc, never the
            -- reverse, so every 2.39-built payload in the index runs
            -- unchanged under 2.44.
            ["latest"] = { ref = "2.44" },
            ["2.39"] = "XLINGS_RES",
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
            -- nothing wrong. Entries here are append-only for that reason.
            ["2.44"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/glibc/releases/download/2.44/glibc-2.44-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/glibc/releases/download/2.44/glibc-2.44-linux-x86_64.tar.gz",
                },
                sha256 = "0105292fd6b49f74fbf51f93af973b78a9fc18225cb1c757c720e90de3120182",
            },
            -- 2.44.2 IS WITHDRAWN AGAIN, AND THIS TIME NOT FOR A DAY.
            --
            -- The artifact is good and stays published (xlings-res/glibc tag
            -- 2.44.2, sha256 ed4bf048...). What cannot hold is offering it
            -- under a version no existing consumer can bind to.
            --
            -- The binding is the payload DIRECTORY NAME, so a consumer that
            -- has `glibc@2.44` compiled in needs `xim-x-glibc/2.44` on disk.
            -- Publishing 2.44.2 as `latest` means that directory never
            -- appears, and the consumer refuses:
            --
            --   error: selected RuntimeBinding glibc@2.44 requires payload
            --          '<home>/.../xpkgs/xim-x-glibc/2.44', but it is not
            --          installed
            --
            -- THREE places hold that constant, and they update on three
            -- different schedules:
            --
            --   1. xlings itself            -- fixed in 2026.8.27.2, which
            --                                  takes the value from THIS file
            --   2. CI bootstrap pins        -- a workflow literal; moved by
            --                                  hand, whenever someone notices
            --   3. mcpp's VENDORED xlings   -- measured on the release runner:
            --                                  "vendored xlings 2026.8.10.1 is
            --                                  older than the pinned
            --                                  2026.8.17.2"
            --
            -- (1) was the fix. (2) and (3) are copies of the same constant in
            -- places that cannot all be moved at once, and there is no release
            -- ordering that reaches them together -- which is the argument
            -- that the binding should not carry a packaging revision AT ALL.
            --
            -- The structural answer, and the reason this is withdrawn rather
            -- than juggled: 2.44.2 and 2.44 are the SAME ABI. The revision is
            -- our packaging, not glibc's. So the index key may carry it (for
            -- ordering and sha) while the payload directory and the binding
            -- stay `glibc@2.44` -- an install_as/abi concept that makes a
            -- revision invisible to every consumer, old and new. That is
            -- openxlings/xlings' call to make; this entry comes back when it
            -- exists, or when nothing pins the name any more.
            --
            -- Cost meanwhile: 2.44 is the artifact that reads the HOST's
            -- /etc/ld.so.preload (mcpp-community/mcpp#484). That breaks only
            -- on hosts that have such a file -- rare. What was breaking
            -- instead was every clean environment, every release build and
            -- the aarch64 CI: universal.
        },
    },
}

import("xim.libxpkg.log")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.libxpkg.elfpatch")
import("xim.pkgindex.sysroot")

-- libnss modules
local glibc_libs = {
    "crt1.o", "crti.o", "crtn.o", -- crt
    "ld-linux-x86-64.so.2", -- dynamic linker/loader
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
    __relocate()

    __check_nss_coverage()

    return true
end

function config()
    xvm.add("glibc")

    local glibc_root_binding = "glibc@" .. pkginfo.version()
    local glibc_version = __version_key()
    local glibc_bindir = path.join(pkginfo.install_dir(), "bin")
    local glibc_libdir = path.join(pkginfo.install_dir(), "lib64")

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

    local libdir = path.join(pkginfo.install_dir(), "lib64")
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
function __relocate()
    -- TWO markers, because the build pipeline changed and the tarballs did not
    -- change with it.
    --
    -- Releases up to and including 2.44 were configured with the build
    -- machine's own path -- `/home/xlings/.xlings_data/.../fromsource-x-glibc/
    -- <ver>` -- which leaked the builder's disk layout into every artifact.
    -- AD-11 replaced it with an explicitly reserved placeholder
    -- (.agents/tools/graphics/build-glibc.sh).
    --
    -- Both have to be handled here, and for a while both will be: an already
    -- published tarball still carries the old one, and the next build will
    -- carry the new one. Dropping the old marker the day the pipeline changes
    -- would leave every existing release unrelocated, with nothing to say so.
    local markers = {
        "fromsource-x-" .. package.name .. "/" .. pkginfo.version(),
        "/nonexistent/xlings-use-rpath-not-default-search",
    }

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
        return
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
end