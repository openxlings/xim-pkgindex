package = {
    spec = "2",

    homepage = "https://icu.unicode.org/",
    name = "icu",
    description = "International Components for Unicode: Unicode and globalization support libraries",

    authors = {"Unicode, Inc. and others"},
    licenses = {"MIT"},
    repo = "https://github.com/unicode-org/icu",
    docs = "https://unicode-org.github.io/icu-docs/apidoc/released/icu4c/",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"i18n", "lib"},
    keywords = {"icu", "unicode", "i18n", "l10n", "lib"},

    xpm = {
        linux = {
            -- libicui18n/io/tu/uc all carry DT_NEEDED libstdc++.so.6 and
            -- libgcc_s.so.1 (ICU's public API is C, its implementation is
            -- C++). Both sonames are provided by xim:gcc-runtime, confirmed
            -- by extracting its published payload.
            deps = { "xim:glibc", "xim:gcc-runtime" },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "78.3" },
            ["78.3"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/icu/releases/download/78.3/icu-78.3-linux-x86_64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/icu/releases/download/78.3/icu-78.3-linux-x86_64.tar.gz",
                    },
                    sha256 = "e780998a0542c2830028e600abdb8e4d3ff90772e65a18cab0d4dfdcee750f77",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/icu/releases/download/78.3/icu-78.3-linux-aarch64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/icu/releases/download/78.3/icu-78.3-linux-aarch64.tar.gz",
                    },
                    sha256 = "cdb8f3dc6c73292b2fd10f94a594190b35af0d018f053931a42df3f7357f711f",
                },
            },
        },
    },
}

-- Relocatable payload repacked from the conda-forge icu package (78.3,
-- linux-64 and linux-aarch64 builds), built against a glibc 2.17 baseline.
--
-- conda-forge publishes several build strings per architecture at this
-- version: one generic build plus per-Python-ABI rebuilds (build strings
-- prefixed py310/py311/py312/py313). All of them report the same runtime
-- `depends` (libgcc, libstdcxx, glibc -- no Python), so the per-ABI builds
-- appear to be triggered by the feedstock's build matrix rather than an
-- actual Python link; regardless, this recipe pins the plain, non-suffixed
-- build explicitly (h54a6638_2 on linux-64, h7ac5ae9_2 on linux-aarch64,
-- both build number 2, the newest non-Python build on each architecture)
-- rather than trusting "most recently uploaded", which on this package
-- resolves to a Python-tagged artifact instead.
--
-- Payload contents: lib/*.so* for all six ICU libraries (data, i18n, io,
-- test, tu, uc; no static archives, no lib/cmake, no lib/icu/<ver>/ build
-- scaffolding), include/unicode/ (a flat, package-owned namespace -- no
-- other recipe in this index ships an include/unicode/, so config() uses
-- declare_headers rather than the _tree variant), lib/pkgconfig/*.pc
-- (icu-uc, icu-i18n, icu-io), licenses/, and PROVENANCE.md.
--
-- No bin/: this payload is scoped to the libraries. conda-forge's icu also
-- ships bin/ tools (genrb, icuinfo, pkgdata, ...); they are intentionally
-- left out here, along with their own icu-config script (which embeds the
-- build-machine prefix as executable shell, not just data).
--
-- RPATH, measured with readelf -d: every lib/*.so* already carried
-- RPATH=$ORIGIN. Reapplied explicitly with patchelf --force-rpath (DT_RPATH,
-- not DT_RUNPATH).
--
-- .pc files carry the conda-forge build machine's placeholder-padded
-- prefix; rewritten here to `prefix=/usr` with ${prefix}-relative
-- libdir/includedir. Each .pc also defines a `pkglibdir` variable pointing
-- at lib/icu/78.3 (ICU's per-version data-loading convention), a directory
-- this payload does not ship; sysroot.relocate_pkgconfig drops any custom
-- variable whose resolved value does not exist in the payload, so this is
-- handled at install time rather than by hand here.
--
-- PLACEHOLDER AUDIT: no lib/*.so* or include/ file embeds the build-prefix
-- placeholder pattern (checked with grep over the whole assembled payload;
-- ICU's own headers use the English word "placeholder" in prose about
-- MessageFormat syntax, which is not the conda padding pattern and was
-- confirmed by inspection, not filtered blindly).

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.sysroot")
import("xim.pkgindex.selfcontain")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("icu-" .. pkginfo.version(), dir)

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
