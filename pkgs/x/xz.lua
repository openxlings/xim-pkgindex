package = {
    spec = "2",

    homepage = "https://tukaani.org/xz/",
    name = "xz",
    description = "liblzma compression library and the xz/lzma command-line tools",

    authors = {"Lasse Collin and contributors"},
    licenses = {"0BSD", "LGPL-2.1-or-later"},
    repo = "https://github.com/tukaani-project/xz",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"compression", "lib"},
    keywords = {"xz", "lzma", "liblzma", "compression", "lib"},

    programs = {"xz", "xzcat", "unxz", "lzma", "unlzma", "lzcat", "lzmainfo", "lzmadec", "xzdec"},
    xvm_enable = true,

    xpm = {
        linux = {
            deps = { "xim:glibc" },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "5.8.3" },
            ["5.8.3"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/xz/releases/download/5.8.3/xz-5.8.3-linux-x86_64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/xz/releases/download/5.8.3/xz-5.8.3-linux-x86_64.tar.gz",
                    },
                    sha256 = "1f4bf20c0d489610bb05ae08dbfacc458e107a320a1e415790e31d9517bad660",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/xz/releases/download/5.8.3/xz-5.8.3-linux-aarch64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/xz/releases/download/5.8.3/xz-5.8.3-linux-aarch64.tar.gz",
                    },
                    sha256 = "0648cf1147206d84d1c83f1c09e5e27684fc8b0d6ad5ed15b663bfaa90446fa9",
                },
            },
        },
    },
}

-- Relocatable payload repacked from three sibling outputs of the split
-- conda-forge xz feedstock -- liblzma (the shared library), liblzma-devel
-- (headers + .pc + the unversioned .so symlink), and xz-tools (the xz/lzma
-- command-line tools) -- all at 5.8.3, linux-64 and linux-aarch64, fetched
-- into one prefix and packed as one payload. Built against a glibc 2.17
-- baseline. `licenses` is the union recorded in PROVENANCE.md: liblzma and
-- liblzma-devel are 0BSD; xz-tools is "0BSD AND LGPL-2.1-or-later" (a few
-- of the CLI tools' getopt/gettext scaffolding is LGPL).
--
-- Payload contents: lib/*.so* (no static archives), include/ (lzma.h plus
-- the lzma/ subdirectory -- a flat, package-owned namespace, so config()
-- uses declare_headers rather than the _tree variant), lib/pkgconfig/
-- liblzma.pc, bin/ (all nine liblzma-devel/xz-tools executables and
-- aliases), licenses/, and PROVENANCE.md.
--
-- RPATH, measured with readelf -d: lib/liblzma.so.5 already carried
-- RPATH=$ORIGIN/. and every bin/ executable already carried
-- RPATH=$ORIGIN/../lib. Reapplied explicitly with patchelf --force-rpath
-- (DT_RPATH, not DT_RUNPATH -- see pkgs/z/zstd.lua's comment for why that
-- distinction matters for a dlopen'd or caller-patched object).
--
-- .pc file carries the conda-forge build machine's placeholder-padded
-- prefix, with exec_prefix/libdir/includedir each repeating the same
-- absolute path rather than referencing ${prefix}; rewritten here to
-- `prefix=/usr` with ${prefix}-relative libdir/includedir.
--
-- PLACEHOLDER AUDIT: bin/xz and bin/lzmainfo each embed one occurrence of
-- the build-machine prefix, as gettext's compiled-in LOCALEDIR default
-- (`<build-prefix>/share/locale`, used by bindtextdomain()). This payload
-- ships no share/locale, so the effect is identical to a real --prefix=/usr
-- install missing its locale tree: messages fall back to the untranslated
-- (English) strings baked into the binary. Not rewritten -- it is a single
-- self-contained string, not concatenated with other data the way
-- xcb-util-cursor's icon-theme path is, but rewriting an ELF string still
-- risks corrupting the string table for no functional gain here.

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.sysroot")
import("xim.pkgindex.selfcontain")

local programs = {"xz", "xzcat", "unxz", "lzma", "unlzma", "lzcat", "lzmainfo", "lzmadec", "xzdec"}

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("xz-" .. pkginfo.version(), dir)

    -- Stamp this payload's own dependency closure (glibc) onto both
    -- lib/*.so* and bin/*; see pkgs/z/zstd.lua for why bin/ must be
    -- named explicitly here rather than relying on the {"lib","lib64"}
    -- default.
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
    -- other eight names bind to it, exactly as nasm.lua's ndisasm and
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
