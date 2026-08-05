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
            exports = {
                runtime = {
                    loader = "lib64/ld-linux-x86-64.so.2",
                    abi    = "linux-x86_64-glibc",
                    -- libdirs not declared → falls back to {lib64, lib} convention
                },
            },
            -- `latest` stays 2.39, deliberately.
            --
            -- glibc is backward compatible and not forward compatible: a
            -- binary built against 2.39 runs on 2.44, and one built against
            -- 2.44 does not run on 2.39. Every payload in the index today was
            -- built against 2.39, so 2.39 is the version that runs all of
            -- them. Moving `latest` to 2.44 would be safe for the same reason
            -- — but it would also silently change which glibc every existing
            -- home resolves to, and that is a decision to make deliberately
            -- rather than as a side effect of adding a version.
            --
            -- What 2.44 is FOR is the other direction: a newer runtime hosts
            -- MORE prebuilt binaries. Anything built elsewhere against a
            -- glibc up to 2.44 — a vendor's binary, a distro's, the host's
            -- NVIDIA userspace that nvidia-gl-host-link links to — loads under
            -- it and does not under 2.39. Ask for it with `xlings install
            -- glibc@2.44` or `xlings subos new <name> --runtime glibc@2.44`.
            ["latest"] = { ref = "2.39" },
            ["2.39"] = "XLINGS_RES",
            -- Built from source, not XLINGS_RES: the sha256 is checked, which
            -- an XLINGS_RES entry cannot do. Build recipe and the reason its
            -- prefix looks the way it does:
            -- .agents/tools/graphics/build-glibc.sh
            ["2.44"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/glibc/releases/download/2.44/glibc-2.44-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/glibc/releases/download/2.44/glibc-2.44-linux-x86_64.tar.gz",
                },
                sha256 = "0105292fd6b49f74fbf51f93af973b78a9fc18225cb1c757c720e90de3120182",
            },
        },
    },
}

import("xim.libxpkg.log")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
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
    -- change from first-claimant-keeps-it to last-one-wins. Measured before
    -- doing it: of glibc's 130 top-level entries exactly one, `scsi`, is
    -- also shipped by another package in the index (linux-headers). Every
    -- other name is glibc's alone.
    --
    -- That one entry was already decided by install order, just invisibly:
    -- install_headers skipped it if linux-headers got there first, and
    -- linux-headers (declared since #425) overwrote it if it came second.
    -- With both declared it is still order-dependent, but now *recorded* —
    -- two packages claiming one path becomes state doctor can see rather
    -- than a silent race.
    if sysroot.declare_headers(pkginfo.install_dir(), "include",
                               "usr/include", binding) then
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

function __relocate()

    local relocate_files = {
        "lib/libc.so",
        "lib/libm.so",
        "lib/libm.a",

        "bin/ldd",
        "bin/tzselect",
        "bin/xtrace",
        "bin/sotruss",
    }

--[[
  Prebuilt tarball contains absolute paths from build machine (e.g. /home/xlings/.xlings_data/...).
  Must replace ANY path ending with fromsource-x-glibc/VERSION/lib, not just current install path.
]]

    local fromsource_glibc = "fromsource-x-" .. package.name
    local version_escaped = pkginfo.version():gsub("%.", "%%.")
    -- Match any absolute path ending with fromsource-x-glibc/VERSION/lib (build path varies by machine)
    local path_pattern = "([^%s)]+)/" .. fromsource_glibc:gsub("-", "%%-") .. "/" .. version_escaped .. "/lib"

    local base = pkginfo.install_dir()
    log.info("relocate glibc paths (pattern: */%s/%s/lib) -> .", fromsource_glibc, pkginfo.version())

    for _, f in ipairs(relocate_files) do
        local abs_f = path.join(base, f)
        if os.isfile(abs_f) then
            log.info("relocate file: " .. f)
            local content = io.readfile(abs_f)
            local new_content, count = content:gsub(path_pattern, ".")
            if count > 0 then
                io.writefile(abs_f, new_content)
            end
        end
    end
end