package = {
    spec = "2",

    name = "perl",
    description = "Perl — a complete, relocatable Perl 5 interpreter with the full core module set",

    homepage = "https://www.perl.org",
    maintainers = {"Perl 5 Porters"},
    licenses = {"Artistic-1.0-Perl OR GPL-1.0-or-later"},
    repo = "https://github.com/Perl/perl5",
    docs = "https://perldoc.perl.org",

    -- xim pkg info
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"language", "interpreter", "scripting", "toolchain"},
    keywords = {"perl", "perl5", "interpreter", "script", "configure"},

    programs = {"perl", "perldoc"},
    xvm_enable = true,

    -- WHY THIS PACKAGE EXISTS
    --
    -- Several source builds in the ecosystem are driven by Perl scripts —
    -- OpenSSL's `./config`/`Configure` most prominently. Those builds do not
    -- need "a perl binary on PATH", they need a perl whose CORE MODULES are
    -- present: `Configure` opens with `use FindBin;`, and a distro perl that
    -- was split into sub-packages (or a trimmed container image) has the
    -- binary but not FindBin.pm. The failure then surfaces deep inside a
    -- third-party build with a message nobody can act on
    -- (mcpplibs/mcpp-index#140). A recipe can only declare its way out of that
    -- by depending on a perl it brought itself — hence `xim:perl`.
    --
    -- So "complete" is the requirement, not a nicety: every asset here ships
    -- the full core lib tree (FindBin, Config, File::Path, POSIX, ExtUtils::*,
    -- Digest::*, …), not a minimal interpreter.
    --
    -- PROVENANCE — two build paths, one version (perl 5.44.0 everywhere).
    --
    --   linux x86_64 / aarch64 — built from the upstream CPAN source tarball
    --     (perl-5.44.0.tar.gz) inside Alpine 3.22 as a FULLY STATIC musl
    --     binary: `Configure -Uusedl -Duserelocatableinc -Aldflags=-static`.
    --       * `-Uusedl` removes DynaLoader, so every core XS extension is
    --         linked INTO the perl binary. That is what makes `-static`
    --         usable at all — a static perl that still expected to dlopen
    --         its own .so files would load nothing.
    --       * `-Duserelocatableinc` stores @INC relative to the binary, so
    --         the unpacked tree works from any install prefix.
    --       * static musl means no glibc floor and no NSS caveat: the same
    --         archive runs on Alpine, CentOS 7, and Fedora 44 alike. This is
    --         the case that motivated the package, and it is the one platform
    --         where a distro perl cannot be relied on.
    --       TRADE-OFF: with no DynaLoader, this perl cannot load XS modules
    --       built after the fact — `cpan Some::XS::Module` will not work.
    --       Pure-perl modules are fine, and every core module is built in.
    --       That is the deliberate cost of a single portable binary; anyone
    --       who needs a CPAN-extensible perl wants their distro's.
    --
    --   macosx x86_64 / arm64 — repacked from skaji/relocatable-perl 5.44.0.0
    --     (the same perl version), byte-identical payload, only the archive's
    --     top-level directory is renamed to the xlings-res convention.
    --     macOS cannot be served the linux treatment: Apple does not support
    --     statically linking libSystem, so a "static macOS binary" does not
    --     exist. relocatable-perl is the portable-and-complete build for that
    --     platform, and it keeps DynaLoader (so macOS has no XS limitation).
    --
    --   windows — not shipped. The Windows answer is Strawberry Perl, which
    --     is a ~250MB toolchain distribution rather than an interpreter, and
    --     nothing in the index needs it yet.
    --
    -- RESOURCE SHAPE — `url = "XLINGS_RES"` + per-arch sha256, the mcpp.lua /
    -- nasm.lua idiom, NOT the bare `source = "xlings-res"` form (mcpp#232):
    -- deployed xlings engines don't parse a `source` key, so that form
    -- resolves to no URL at all — nothing gets downloaded, the install hook
    -- no-ops, and the package lands "installed" but empty with dangling shims.
    -- The placeholder resolves at runtime to
    -- `{res-server}/perl/releases/download/5.44.0/perl-5.44.0-<os>-<arch>.tar.gz`
    -- with GLOBAL(github)→CN(gitcode) fallback.
    --
    -- Note the macosx arch spelling split, which is xlings's and not ours:
    -- the ASSET name uses the raw host token (`arm64` on Apple, `aarch64` on
    -- linux), while the sha256 table is keyed by the NORMALIZED arch
    -- (`aarch64` on both). See installer.cppm detect_arch_() vs
    -- normalize_arch().
    xpm = {
        linux = {
            ["latest"] = { ref = "5.44.0" },
            ["5.44.0"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "b9e884be3df92028df0d023b482f033440ade29c5b9e715313d971b1542eff72",
                    aarch64 = "31b49b6b581b10d7d519ca358205cf4343c0ce1436ab443e421fd44be5ca4a9d",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "5.44.0" },
            ["5.44.0"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "c6b62e520fd9d4f733d6426d4adf0058675bb79bd9c36a77d9ae7909798436d7",
                    aarch64 = "2daae82c24f114eb708cee183bf1fe1ba86e1acc33c897dad55268dd221472f4",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    -- Every asset — both build paths, all four os/arch pairs — expands to the
    -- SAME top-level directory `perl-<ver>/`, so this hook needs no arch
    -- knowledge. (Deliberate: `os.arch()` is the normalized token and would
    -- not match a directory named after the raw one on macOS.)
    --
    -- Idempotent across xim engines (mcpp#232): some stage the extracted
    -- payload into install_dir() before/without the hook, others leave it in
    -- the hook CWD for us to move. Never wipe install_dir before a
    -- replacement payload is confirmed, and never report success unless the
    -- interpreter is actually in place — `return true` over an empty dir gets
    -- stamped as installed and leaves dangling xvm shims behind.
    local staged = path.join(pkginfo.install_dir(), "bin", "perl")
    if os.isfile(staged) then return true end

    local payload = "perl-" .. pkginfo.version()
    if os.isdir(payload) then
        os.tryrm(pkginfo.install_dir())
        os.mv(payload, pkginfo.install_dir())
    end
    return os.isfile(staged)
end

function config()
    local bindir = path.join(pkginfo.install_dir(), "bin")

    -- Only `perl` and `perldoc` get shims. The tree also carries prove,
    -- shasum, json_pp, ptar, splain and friends — generic names that would
    -- shadow the host's own tools for every user who installs perl for one
    -- build script. They stay reachable through <install>/bin.
    --
    -- `cpan` is deliberately NOT registered: on linux this perl has no
    -- DynaLoader (see the provenance note), so cpan would install XS modules
    -- that can never be loaded. A shim that only half-works is worse than no
    -- shim.
    xvm.add("perl", { bindir = bindir })
    xvm.add("perldoc", { bindir = bindir, binding = "perl@" .. pkginfo.version() })
    return true
end

function uninstall()
    xvm.remove("perl")
    xvm.remove("perldoc")
    return true
end
