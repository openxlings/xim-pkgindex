package = {
    spec = "1",
    homepage = "https://www.freedesktop.org/wiki/Software/fontconfig/",
    name = "fontconfig",
    description = "Library for configuring and customizing font access",
    maintainers = {"The Fontconfig Developers"},
    licenses = {"MIT"},
    repo = "https://gitlab.freedesktop.org/fontconfig/fontconfig",
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "font", "library"},
    keywords = {"fontconfig", "font", "lib"},
    xvm_enable = true,
    xpm = {
        linux = {
            -- `xim:`-qualified, not bare. A bare name resolves fine while only
            -- one index provides it -- and CI registers every CHANGED recipe a
            -- second time under `local:`, so the moment expat is touched in the
            -- same PR the bare name becomes ambiguous and fontconfig's install
            -- fails with a candidate list. That is a property of the PR, not of
            -- the recipe, so it stays latent until some unrelated change hits
            -- both packages at once.
            deps = { "xim:freetype@2.13.2", "xim:expat@2.6.2", "xim:glibc" },
            ["latest"] = { ref = "2.15.0.1" },
            -- 2.15.0.1 ships the SAME artifact as 2.15.0 — same url, same
            -- sha256 — under a new version key, and exists for one reason:
            -- payloads installed in the 2.15.0 era predate selfcontain.seal,
            -- so they carry no RUNPATH and their NEEDED freetype/expat
            -- resolve from the HOST's ld.so cache. Nothing ever re-runs
            -- install() on an already-installed version — "already
            -- installed" is a success, not a refresh — so the only way to
            -- get a SEALED payload onto a machine holding an unsealed one is
            -- a new version key. `latest` points here, so any fresh install
            -- gets the sealed vintage; a consumer that NEEDS the sealed
            -- payload pins this key EXACTLY (`xim:fontconfig@2.15.0.1`) —
            -- exact and not a range, because semver rejects a fourth
            -- component ("trailing content after 3 components is invalid"),
            -- so no range constraint can ever select a 4-component key, and
            -- `>=2.15.0` would select the unsealed 2.15.0. An exact pin also
            -- pierces pin-to-active on a machine holding an old active
            -- 2.15.0.
            ["2.15.0.1"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/fontconfig/releases/download/2.15.0/fontconfig-2.15.0-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/fontconfig/releases/download/2.15.0/fontconfig-2.15.0-linux-x86_64.tar.gz",
                },
                sha256 = "dfe6869d6b615414deb0c818a195a9f2b8cb8ad10789376dfa6ce9c2a1e3135f",
            },
            ["2.15.0"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/fontconfig/releases/download/2.15.0/fontconfig-2.15.0-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/fontconfig/releases/download/2.15.0/fontconfig-2.15.0-linux-x86_64.tar.gz",
                },
                sha256 = "dfe6869d6b615414deb0c818a195a9f2b8cb8ad10789376dfa6ce9c2a1e3135f",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.sysroot")
import("xim.pkgindex.selfcontain")

local libs = { "libfontconfig.so", "libfontconfig.so.1" }

function install()
    -- The version KEY and the artifact can differ: 2.15.0.1 downloads the
    -- 2.15.0 archive (deliberately — see the xpm note), so a directory name
    -- derived from pkginfo.version() would not exist, os.mv would silently
    -- do nothing, and seal's payload assertion would abort the install.
    -- Derive the extracted directory from the archive name instead; keep the
    -- version-derived name as the fallback for clients without
    -- install_file() (type() probe: import() proxies make truthiness lie).
    local srcdir = pkginfo.name() .. "-" .. pkginfo.version() .. "-linux-x86_64"
    if type(pkginfo.install_file) == "function" then
        local file = pkginfo.install_file() or ""
        local base = (file:match("[^/\\]+$") or ""):gsub("%.tar%.gz$", "")
        if base ~= "" and os.isdir(base) then srcdir = base end
    end
    os.tryrm(pkginfo.install_dir())
    os.mv(srcdir, pkginfo.install_dir())

    -- Stamp this payload's own dependency closure onto its libraries, so
    -- they resolve from our payloads and not from the host's ld.so.cache.
    selfcontain.seal(pkginfo.install_dir())

    -- The .pc files in this payload say `libdir=${prefix}/lib/x86_64-linux-gnu`
    -- -- a Debian-family build host -- against a payload with a flat lib/.
    -- Rewriting `prefix=` alone (what this recipe did) leaves pkg-config
    -- emitting -L for a directory that does not exist. It still links, because
    -- the subos lib search path covers it, and then the consumer that stamped
    -- its RPATH from `pkg-config --variable=libdir` dies at startup.
    sysroot.relocate_pkgconfig(pkginfo.install_dir(), "lib/pkgconfig")

    return true
end

function config()
    local idir = pkginfo.install_dir()
    local libdir = path.join(idir, "lib")
    local binding = package.name .. "@" .. pkginfo.version()
    xvm.add(package.name)
    for _, lib in ipairs(libs) do
        if os.isfile(path.join(libdir, lib)) then
            xvm.add(lib, { type = "lib", bindir = libdir, filename = lib, alias = lib, binding = binding })
        end
    end
    local sysroot = system.subos_sysrootdir()
    local sys_inc = path.join(sysroot, "usr/include")
    os.mkdir(sys_inc)
    system.exec(string.format("sh -c 'cp -a %s/include/* %s/ 2>/dev/null || true'", idir, sys_inc))
    local sys_pc = path.join(sysroot, "usr/lib/pkgconfig")
    os.mkdir(sys_pc)
    -- The payload's .pc files were already pointed at the payload in
    -- install(); copying them verbatim is what keeps that the only answer.
    system.exec(string.format(
        "sh -c 'for pc in %s/lib/pkgconfig/*.pc; do [ -f \"$pc\" ] && cp -f \"$pc\" %s/; done'",
        idir, sys_pc
    ))
    return true
end

function uninstall()
    xvm.remove(package.name)
    for _, lib in ipairs(libs) do xvm.remove(lib) end
    local sysroot = system.subos_sysrootdir()
    system.exec(string.format("sh -c 'rm -rf %s/usr/include/fontconfig; rm -f %s/usr/lib/pkgconfig/fontconfig.pc'", sysroot, sysroot))
    return true
end
