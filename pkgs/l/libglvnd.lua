package = {
    spec = "2",

    homepage = "https://gitlab.freedesktop.org/glvnd/libglvnd",
    name = "libglvnd",
    description = "The GL Vendor-Neutral Dispatch library",

    authors = {"NVIDIA Corporation", "libglvnd contributors"},
    licenses = {"MIT"},
    repo = "https://gitlab.freedesktop.org/glvnd/libglvnd",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "lib"},
    keywords = {"libglvnd", "graphics", "gl"},

    xpm = {
        linux = {
            -- Separated shape, not the array-plus-`build` mixed one: every
            -- client before libxpkg 0.0.52 takes the array branch on a mixed
            -- table and drops `build` silently. See tests/test_deps_shape.py.
            deps = {
                runtime = { "xim:libX11@>=1.8", "xim:libXext@>=1.3", "xim:glibc" },
                -- config() rewrites libGLX.so.0's RPATH so glvnd's vendor
                -- dlopen can reach the vendor directory. patchelf is the only
                -- way to do that to an already-built payload.
                build = { "xim:patchelf@0.18.0" },
            },
            -- elfpatch reads this from each dependency and writes the consumer's
            -- RPATH, which is what makes the stack resolve without anyone
            -- setting LD_LIBRARY_PATH. Same mechanism `gcc-runtime` uses.
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "1.7.0.1" },
            -- Same upstream artifact as 1.7.0, new version key.
            --
            -- The GLX vendor wiring lives in config(), and config() only runs
            -- when the package installs. A home that already has 1.7.0 would
            -- keep a libGLX.so.0 that cannot reach any vendor, with nothing to
            -- say so -- the fix would ship and those users would never get it.
            -- A new key under the same artifact makes every consumer's `>=1.7`
            -- lower bound pull it, so the hook re-runs. The fontconfig
            -- 2.15.0.1 pattern; the payload bytes and sha256 are unchanged.
            ["1.7.0.1"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/libglvnd/releases/download/1.7.0/libglvnd-1.7.0-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/libglvnd/releases/download/1.7.0/libglvnd-1.7.0-linux-x86_64.tar.gz",
                },
                sha256 = "07366016ef25ec20436df65bf94f0dee758d41ec34d0723056690d5c899bf8c8",
            },
            ["1.7.0"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/libglvnd/releases/download/1.7.0/libglvnd-1.7.0-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/libglvnd/releases/download/1.7.0/libglvnd-1.7.0-linux-x86_64.tar.gz",
                },
                sha256 = "07366016ef25ec20436df65bf94f0dee758d41ec34d0723056690d5c899bf8c8",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")
import("xim.libxpkg.fs")
import("xim.pkgindex.sysroot")
import("xim.pkgindex.selfcontain")
import("xim.pkgindex.graphics")

-- Give libGLX.so.0 a search path that reaches the GLX vendor libraries.
--
-- glvnd builds `libGLX_<vendor>.so.0` and dlopens it BY NAME -- there is no
-- GLX equivalent of `egl_vendor.d`, no directory variable, nothing but the
-- SONAME (measured: this payload's libGLX.so.0 contains `libGLX_%s.so.0` and
-- `__GLX_VENDOR_LIBRARY_NAME`, which selects a NAME, never a path). glibc
-- serves that dlopen from the CALLING object's own search path, and the
-- calling object is this file. So the reachability has to live here.
--
-- It used to live on the CONSUMER instead, via DT_RPATH searched transitively
-- up the load chain -- which works, and which every probe in
-- `.agents/tools/graphics/` bought with `-Wl,--disable-new-dtags`. Real build
-- systems emit DT_RUNPATH (the default), DT_RUNPATH is not transitive, and
-- the whole thing collapses: openxlings/xlings#525, where mcpp's imgui
-- template got `GLX: No GLXFBConfigs returned` on a host whose own glxinfo
-- was fine. A contract no consumer can be expected to honour is not a
-- contract.
--
-- `$ORIGIN`, so the entry survives a home that moves and serves every subos
-- in the home. DT_RPATH (--force-rpath) rather than DT_RUNPATH: it is also
-- searched for the vendor's OWN dependencies, which is what the interposers
-- in nvidia-gl-host-link rely on.
--
-- APPEND. selfcontain.seal() already stamped this payload's closure onto the
-- library in install(); replacing that is how a payload loses its own libs.
function __wire_glx_vendor_search_path()
    local dispatch = path.join(pkginfo.install_dir(), "lib", "libGLX.so.0")
    if not os.isfile(dispatch) then
        log.warn("no lib/libGLX.so.0 in this payload; GLX vendor lookup is "
                 .. "left as upstream shipped it")
        return false
    end

    -- The directory the vendors get wired into. Created here so the RPATH
    -- entry names something that exists even before `graphics` populates it;
    -- ld.so skips a missing directory silently, and "silently" is the whole
    -- problem being fixed.
    fs.mkdir_p(path.join(pkginfo.install_dir(), graphics.GLX_VENDOR_SUBDIR))

    local want = "$ORIGIN/glx-vendor"
    -- --print-rpath prints DT_RUNPATH too, so this reads whatever tag is
    -- actually there.
    local current = os.iorun(string.format(
        [[patchelf --print-rpath "%s"]], dispatch))
    current = current and current:gsub("%s+$", "") or ""

    if current:find(want, 1, true) then return true end
    local merged = (current ~= "") and (current .. ":" .. want) or want
    os.exec(string.format([[patchelf --force-rpath --set-rpath %q %q]],
                          merged, dispatch))

    -- Assert the result, do not assume it. patchelf may be absent, and a
    -- skipped rewrite here is indistinguishable from a working one until a GL
    -- program fails two layers away with a message about FBConfigs.
    local after = os.iorun(string.format(
        [[patchelf --print-rpath "%s"]], dispatch))
    if not (after and after:find(want, 1, true)) then
        log.error("failed to add %s to libGLX.so.0's RPATH (patchelf missing "
                  .. "or refused). GLX programs would find no vendor and "
                  .. "render on llvmpipe.", want)
        return false
    end
    log.info("GLX vendor search path: %s", want)
    return true
end

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("libglvnd-1.7.0", dir)

    -- Stamp this payload's own dependency closure onto its libraries, so
    -- they resolve from our payloads and not from the host's ld.so.cache.
    selfcontain.seal(pkginfo.install_dir())
    return true
end

function config()
    local binding = package.name .. "@" .. pkginfo.version()

    xvm.add(package.name)

    -- Before declare_libs: that publishes `lib/` into the subos, and the
    -- vendor directory must already exist as a directory when it does rather
    -- than appearing underneath it afterwards.
    if not __wire_glx_vendor_search_path() then return false end

    sysroot.declare_libs(pkginfo.install_dir(), "lib", binding, pkginfo.version())

    -- Headers into the subos sysroot, so a compiler in this subos can build
    -- against this package, not only run it. Declared rather than copied, so
    -- xlings removes them with the package.
    --
    -- _tree, not declare_headers: eight packages in this stack contribute to
    -- one `X11/`, and declaring that directory places it as a single asset --
    -- rename(2) over the sysroot's copy, so the last install wins and the
    -- other seven vanish. See libs/sysroot.lua for why neither of the
    -- non-recursive helpers can express a shared namespace.
    if not sysroot.declare_headers_tree(pkginfo.install_dir(), "include",
                                        "usr/include", binding) then
        sysroot.install_headers_tree(
            path.join(pkginfo.install_dir(), "include"),
            path.join(system.subos_sysrootdir(), "usr", "include"))
    end
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
