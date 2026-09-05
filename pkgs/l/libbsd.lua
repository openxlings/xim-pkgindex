package = {
    spec = "2",

    homepage = "https://libbsd.freedesktop.org",
    name = "libbsd",
    description = "Utility functions from BSD systems",

    authors = {"Guillem Jover and contributors"},
    licenses = {"BSD-2-Clause", "BSD-3-Clause", "ISC", "MIT", "Beerware", "public-domain"},
    repo = "https://gitlab.freedesktop.org/libbsd/libbsd",

    type = "package",
    -- x86_64 only: the subos harness this package is built with
    -- (.agents/tools/graphics/build-in-subos.sh, subos "gfxbuild") is x86_64-only
    -- on this machine, and libbsd is not on conda-forge, so there is no repack
    -- fallback the way libmd.lua uses for its aarch64 build. Deferred, not
    -- refused.
    archs = {"x86_64"},
    status = "stable",
    categories = {"lib"},
    keywords = {"libbsd", "bsd", "err", "setproctitle", "strlcpy", "queue", "lib"},

    xpm = {
        linux = {
            deps = { "xim:glibc", "xim:libmd@>=1.2.0" },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "0.12.2" },
            ["0.12.2"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/libbsd/releases/download/0.12.2/libbsd-0.12.2-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/libbsd/releases/download/0.12.2/libbsd-0.12.2-linux-x86_64.tar.gz",
                },
                sha256 = "9c34584a71dee86497b817a6711e8a5d7a69bdaa2117d8294545c4260e28ae1c",
            },
        },
    },
}

-- Built from source (0.12.2, https://libbsd.freedesktop.org/releases/) inside
-- the "gfxbuild" subos with build-in-subos.sh --system autotools --deps libmd,
-- the same harness libxcb.lua uses. build-in-subos.sh's own checks passed
-- clean: "all 5 resolved input path(s) are ours" (config.log, no host include
-- or library search path) and "no host references" (no RPATH/RUNPATH/DT_NEEDED
-- naming a path, no /usr/(lib|include|share)/ in a .pc/.la/*-config).
--
-- BUILD PATCH: .agents/tools/graphics/patches/
-- libbsd-0.12.2-self-overlay-cppflags-priority.patch. libbsd compiles its own
-- sources against its own not-yet-installed include/bsd/ headers by adding
-- that directory to AM_CPPFLAGS as -isystem, ahead of the real system headers,
-- so a bare `#include <stdio.h>`/`<string.h>`/`<sys/cdefs.h>` inside libbsd's
-- OWN .c files picks up its own compat additions. That only works when nothing
-- else on the compiler command line supplies a competing -I for the same
-- names -- and build-in-subos.sh always exports
-- CPPFLAGS="-I<subos>/usr/include ..." so a DEPENDENCY's headers can be found.
-- Measured (both gcc and clang honor this): every -I directory is searched,
-- in order, before every -isystem directory, regardless of which one is
-- earlier on the command line. So the subos's real glibc <stdio.h> won the
-- lookup, libbsd's own overlay of itself was never reached, and
-- FPARSELN_UNESCALL, S_ISTXT, _PW_BUF_LEN and their neighbors -- all declared
-- only in include/bsd/*.h -- came back "undeclared" compiling fparseln.c,
-- setmode.c, pwcache.c and others. The patch changes libbsd's own
-- src/Makefile.in to add that directory as -I instead of -isystem, which
-- restores the priority libbsd's own build depends on without touching the
-- installed payload's public interface: libbsd-overlay.pc still hands
-- consumers -isystem ${includedir}/bsd, unchanged.
--
-- HEADERS: include/bsd/*.h (plus include/bsd/sys/ and include/bsd/netinet/)
-- is the only directory `make install` writes into includedir, verified by
-- reading include/Makefile.am's nobase_include_HEADERS and by inspecting the
-- installed DESTDIR tree. Nothing lands directly under includedir itself --
-- "overlay" is a CONSUMPTION mode (libbsd-overlay.pc hands out
-- `-isystem ${includedir}/bsd -DLIBBSD_OVERLAY` so a bare `#include <err.h>`
-- resolves through bsd/err.h's own #include_next), not a second physical
-- header tree. bsd/ is therefore a namespace this package alone owns, the
-- same shape as libmd's flat top-level headers, so config() below uses
-- declare_headers (one node for the whole bsd/ directory) rather than the
-- _tree variant libxcb.lua needs for the X11/ directory eight packages share.
--
-- EXCLUDED FROM THE PAYLOAD:
--   * lib/libbsd-ctor.a and lib/pkgconfig/libbsd-ctor.pc. libbsd-ctor is an
--     automake plain archive (`lib_LIBRARIES`, not `lib_LTLIBRARIES`), so
--     --disable-static does not stop it from being built and installed; it
--     provides constructor-based init for programs that link -lbsd-ctor
--     directly (mainly setproctitle's argv/environ relocation). Out of scope
--     for this payload, the same call libmd.lua makes for libmd.a: this index
--     does not ship static archives from these builds. Its .pc is dropped
--     with it -- shipping libbsd-ctor.pc without libbsd-ctor.a would advertise
--     a library that is not there.
--   * share/man/. Neither libmd.lua nor libxcb.lua ships man pages; matched
--     here for consistency, since nothing in this index reads them.
--
-- lib/libbsd.so: upstream's own `make install` does NOT write a plain symlink
-- here. libbsd_la_LIBADD names -lmd (src/Makefile.am), and libtool's answer to
-- "make sure a consumer linking only -lbsd still gets -lmd" is a GNU ld
-- linker script instead of a symlink:
--
--     /* GNU ld script
--      * The MD5 functions are provided by the libmd library. */
--     OUTPUT_FORMAT(elf64-x86-64)
--     GROUP(/usr/lib/libbsd.so.0.12.2 AS_NEEDED(-lmd))
--
-- with this build's own --prefix=/usr baked in as a literal path. That is a
-- host-shaped reference build-in-subos.sh's payload check cannot see: the
-- check's .pc/.la/*-config filter does not match a bare "libbsd.so" filename,
-- and the RPATH/DT_NEEDED passes both skip it because `is_elf` is false for a
-- text file. Measured directly: `gcc -L<install_dir>/lib -lbsd` against the
-- unmodified harness output fails with
-- "/usr/bin/ld: cannot find /usr/lib/libbsd.so.0.12.2: No such file or
-- directory" -- every consumer's build would break, on every machine, since
-- nothing here is ever installed under literal /usr/lib. Replaced with a
-- plain relative symlink (libbsd.so -> libbsd.so.0.12.2) before packaging,
-- the same shape libmd.so and every libxcb-*.so in this index already use.
-- Nothing is lost: libbsd.so.0.12.2's own DT_NEEDED already lists libmd.so.0,
-- so the runtime edge exists without the ld script. Measured, both with and
-- without an explicit -lmd on the consumer's own link line, against the
-- corrected tree: link and run both succeed.
--
-- .pc FILES: prefix=/usr, libdir=/usr/lib (a literal path, not
-- ${prefix}-relative -- this harness's autotools branch always configures
-- --libdir=/usr/lib, and the already-published libxcb payload's .pc files
-- carry the identical literal libdir=/usr/lib; sysroot.relocate_pkgconfig
-- resolves either spelling to the same installed path, so this is the
-- harness's normal output, not a defect), includedir=${prefix}/include.
-- libbsd-ctor.pc is dropped along with libbsd-ctor.a, above.
--
-- RPATH / DT_NEEDED, measured with readelf -d on lib/libbsd.so.0.12.2:
-- NEEDED libmd.so.0, NEEDED libc.so.6, SONAME libbsd.so.0,
-- RUNPATH $ORIGIN. No other NEEDED entry and no RPATH.
--
-- LICENSES: derived from COPYING (Debian copyright-format 1.0), not assumed.
-- Every "License:" short name maps onto one of the six recorded above:
-- BSD-2-clause / BSD-2-clause-NetBSD / BSD-2-clause-author /
-- BSD-2-clause-verbatim -> BSD-2-Clause; BSD-3-clause / BSD-3-clause-Regents /
-- BSD-3-clause-author / BSD-3-clause-John-Birrell -> BSD-3-Clause (the
-- variation is only in whose name sits in the no-endorsement clause);
-- ISC / ISC-Original -> ISC; Expat -> MIT (Expat is Debian's and SPDX's name
-- for the plain MIT license text); Beerware and public-domain, verbatim.
-- One block (man/setproctitle.3bsd, License: BSD-5-clause-Peter-Wemm) is left
-- OUT of this set: its five numbered conditions -- FreeBSD-inclusion-only use,
-- an author disclaimer, free modification -- match no SPDX identifier,
-- BSD-4-Clause included, because that text requires an advertising
-- acknowledgment clause this one does not carry. BSD-4-Clause is deliberately
-- not in the list above even though it is sometimes assumed for this project:
-- a whole-tree grep of 0.12.2's COPYING and sources for
-- "4-clause"/"advertising" finds nothing, and the project's own ChangeLog
-- records why -- "This gets rid of the last BSD-4-clause licensed file in the
-- project" -- so 0.12.2 ships none. The full COPYING text, covering every
-- block including the unmapped one, is shipped verbatim at
-- licenses/libbsd/COPYING; the six-entry list above is a summary of it, not a
-- replacement for it.
--
-- PLACEHOLDER AUDIT: no shipped file embeds a build-machine or subos path
-- (checked with grep over the whole assembled payload, after the libbsd.so
-- fix above).

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.sysroot")
import("xim.pkgindex.selfcontain")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("libbsd-" .. pkginfo.version(), dir)

    selfcontain.seal(dir)

    sysroot.relocate_pkgconfig(dir, "lib/pkgconfig")
    return true
end

function config()
    local dir = pkginfo.install_dir()
    local binding = package.name .. "@" .. pkginfo.version()

    xvm.add(package.name, { type = "group" })

    sysroot.declare_libs(dir, "lib", binding, pkginfo.version())
    sysroot.declare_headers(dir, "include", "usr/include", binding)
    sysroot.declare_pkgconfig(dir, "lib/pkgconfig", binding)

    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
