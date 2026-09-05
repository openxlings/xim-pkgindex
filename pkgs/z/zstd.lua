package = {
    spec = "2",

    homepage = "https://facebook.github.io/zstd/",
    name = "zstd",
    description = "Zstandard fast lossless compression algorithm: shared library and command-line tools",

    authors = {"Meta Platforms, Inc. and affiliates"},
    licenses = {"BSD-3-Clause"},
    repo = "https://github.com/facebook/zstd",
    docs = "https://facebook.github.io/zstd/zstd_manual.html",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"compression", "lib"},
    keywords = {"zstd", "zstandard", "compression", "lib"},

    programs = {"zstd", "zstdcat", "unzstd", "zstdmt", "zstdgrep", "zstdless"},
    xvm_enable = true,

    xpm = {
        linux = {
            -- bin/zstd links libz.so.1 in addition to this payload's own
            -- libzstd.so.1: measured with readelf -d, zstd's gzip-compatible
            -- mode pulls in zlib. libzstd.so.1 itself needs only libc/
            -- libpthread. xim:zlib provides libz.so.1 (pkgs/z/zlib.lua).
            deps = { "xim:glibc", "xim:zlib" },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "1.5.7" },
            ["1.5.7"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/zstd/releases/download/1.5.7/zstd-1.5.7-linux-x86_64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/zstd/releases/download/1.5.7/zstd-1.5.7-linux-x86_64.tar.gz",
                    },
                    sha256 = "d51a7bfb791b86ac5af90d215c208039156fb478047942491a7975fb3f56eeb1",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/zstd/releases/download/1.5.7/zstd-1.5.7-linux-aarch64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/zstd/releases/download/1.5.7/zstd-1.5.7-linux-aarch64.tar.gz",
                    },
                    sha256 = "a17b62173a2426c1665c546771888b65aac7198de1771742777f2ef7f7531172",
                },
            },
        },
    },
}

-- Relocatable payload repacked from the conda-forge zstd package (1.5.7,
-- linux-64 and linux-aarch64 builds), built against a glibc 2.17 baseline.
-- Payload contents: lib/*.so* (no static archives, no lib/cmake), include/
-- (zstd.h, zstd_errors.h, zdict.h -- a flat, package-owned namespace, so
-- config() uses declare_headers rather than the _tree variant), lib/
-- pkgconfig/*.pc, bin/ (zstd and its five aliases/companions: zstdcat,
-- unzstd, zstdmt are $ORIGIN-relative symlinks to zstd; zstdgrep/zstdless
-- are POSIX shell scripts that call zstd/zstdcat by bare name, so they need
-- no relocation of their own), licenses/, and PROVENANCE.md.
--
-- RPATH, measured with readelf -d on the shipped objects: lib/libzstd.so.1
-- already carried RPATH=$ORIGIN and bin/zstd already carried
-- RPATH=$ORIGIN/../lib -- the conda-forge build already assumes a payload
-- with lib/ and bin/ siblings. Reapplied explicitly here with
-- patchelf --force-rpath so the shipped tag is DT_RPATH (not DT_RUNPATH):
-- a DT_RUNPATH on a dlopen'd object switches OFF the caller's inherited
-- RPATH for THAT object's own dependencies, which is exactly what would
-- otherwise cut bin/zstd off from a caller-provided glibc/zlib closure.
--
-- .pc file carries the conda-forge build machine's placeholder-padded
-- prefix; rewritten here to `prefix=/usr` with ${prefix}-relative
-- libdir/includedir, the shape sysroot.relocate_pkgconfig expects.
--
-- PLACEHOLDER AUDIT: bin/zstd and its ELF siblings carry no embedded
-- build-prefix string (checked with `strings`/grep over the whole
-- assembled payload). The only other packages in this repack batch where
-- one turned up are xz (gettext LOCALEDIR) and xcb-util-cursor (a
-- fallback icon-theme path); see those recipes' comments.

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.sysroot")
import("xim.pkgindex.selfcontain")

local programs = {"zstd", "zstdcat", "unzstd", "zstdmt", "zstdgrep", "zstdless"}

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("zstd-" .. pkginfo.version(), dir)

    -- Stamp this payload's own dependency closure (glibc, zlib) onto both
    -- lib/*.so* and bin/*: the default libdirs list is {"lib","lib64"},
    -- which would leave bin/zstd's RPATH untouched and its libz.so.1 need
    -- resolving from the host instead of xim:zlib.
    selfcontain.seal(dir, { "lib", "bin" })

    sysroot.relocate_pkgconfig(dir, "lib/pkgconfig")
    return true
end

function config()
    local dir = pkginfo.install_dir()
    local bindir = path.join(dir, "bin")
    local binding = package.name .. "@" .. pkginfo.version()

    -- The anchor entry (named after the package itself) carries no
    -- `binding`: a node cannot bind to itself (xvm-self-binding). The
    -- other five names bind to it, exactly as nasm.lua's ndisasm and
    -- perl.lua's perldoc bind to their package's own entry.
    for _, prog in ipairs(programs) do
        if os.isfile(path.join(bindir, prog)) then
            if prog == package.name then
                xvm.add(prog, { bindir = bindir })
            else
                xvm.add(prog, { bindir = bindir, binding = binding })
            end
        end
    end

    sysroot.declare_libs(dir, "lib", binding, pkginfo.version())
    sysroot.declare_headers(dir, "include", "usr/include", binding)
    sysroot.declare_pkgconfig(dir, "lib/pkgconfig", binding)

    return true
end

function uninstall()
    for _, prog in ipairs(programs) do
        xvm.remove(prog)
    end
    return true
end
