package = {
    spec = "2",

    homepage = "https://mesa3d.org",
    name = "mesa",
    description = "Mesa 3D — OpenGL for CPU (llvmpipe), built self-contained for xlings subos",

    authors = {"Mesa contributors"},
    licenses = {"MIT"},
    repo = "https://gitlab.freedesktop.org/mesa/mesa",
    docs = "https://docs.mesa3d.org",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "opengl", "lib"},
    keywords = {"mesa", "opengl", "gl", "egl", "llvmpipe", "graphics"},

    -- What this package is for.
    --
    -- A program that draws needs three things: a loader and a libc
    -- (bootstrap), a way to find its libraries (discovery), and the
    -- environment its subsystems read (configuration). xlings had the first
    -- two. This package plus the declarations in config() supply the rest, so
    -- a GL program installed through xlings renders on a host that has no
    -- graphics stack of its own.
    --
    -- Build details, including why only llvmpipe for now:
    -- https://github.com/xlings-res/mesa
    xpm = {
        linux = {
            -- Ranges, not pins, except where the ABI genuinely is exact.
            --
            -- libllvm is pinned to the patch version because libgallium
            -- references 97 mangled llvm:: symbols carrying an @LLVM_20.1
            -- version tag; a mismatch is a load-time failure, and a range here
            -- would advertise an upgrade path that does not exist.
            --
            -- Everything else is a lower bound. These libraries are ABI-stable
            -- and the consumer only needs them present and not ancient;
            -- pinning would make the whole stack one block, where a libX11
            -- patch bump means editing a dozen recipes.
            -- Bare names, not `xim:`-prefixed. A namespaced dependency can
            -- only resolve from that namespace, so a batch of new packages
            -- depending on each other cannot be installed until all of them
            -- are published — CI registers changed recipes under `local`.
            deps = {
                "libllvm@20.1.7",
                "libglvnd@>=1.7",
                "libdrm@>=2.4",
                "libX11@>=1.8",
                "libxcb@>=1.17",
                "libXext@>=1.3",
                "libXfixes@>=6.0",
                "libXxf86vm@>=1.1",
                "libxshmfence@>=1.3",
                "expat@>=2.6",
                "zlib@>=1.2",
                "gcc-runtime@>=15",
                -- >=2.38 is the measured floor: libgallium's highest required
                -- symbol version is GLIBC_2.38. Writing @2.39 would state a
                -- requirement the payload does not have.
                "glibc@>=2.38",
            },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "25.0.7" },
            ["25.0.7"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/mesa/releases/download/25.0.7/mesa-25.0.7-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/mesa/releases/download/25.0.7/mesa-25.0.7-linux-x86_64.tar.gz",
                },
                sha256 = "17ff8a09973d69ce591351fe7b38cd40896ddf3444908024807be31673ddea4a",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.subos")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("mesa-25.0.7", dir)

    -- The glvnd vendor JSON ships a bare SONAME, which is how it is shipped
    -- upstream: the host's ld.so cache resolves it. There is no such cache in
    -- a subos, and leaving the bare name would let it resolve against the
    -- HOST's libEGL_mesa instead — the exact boundary this package exists to
    -- close, and a failure that looks like success because rendering still
    -- happens, just with someone else's driver.
    local vendor = path.join(dir, "share/glvnd/egl_vendor.d/50_mesa.json")
    if os.isfile(vendor) then
        local text = io.readfile(vendor)
        io.writefile(vendor, text:gsub('"libEGL_mesa%.so%.0"',
                                       '"' .. path.join(dir, "lib/libEGL_mesa.so.0") .. '"'))
    end
    return true
end

function config()
    local dir = pkginfo.install_dir()
    local tag = package.name .. "@" .. pkginfo.version()

    xvm.add(package.name)

    -- The configuration layer. Neither PATH nor RPATH can carry these: the
    -- process that has to see them is the user's own binary, which xlings
    -- never wraps, so a per-shim environment cannot reach it.
    --
    -- type(), not truthiness: import() answers an unknown module with a
    -- permissive proxy whose every key is truthy, so `if subos.env then` is
    -- true on clients that would accept the call and discard it.
    if type(subos.env) == "function" then
        subos.env{ var = "LIBGL_DRIVERS_PATH", op = "set",
                   value = "${pkgdir}/lib/dri", binding = tag }
        subos.env{ var = "__EGL_VENDOR_LIBRARY_DIRS", op = "set",
                   value = "${pkgdir}/share/glvnd/egl_vendor.d", binding = tag }
        subos.env{ var = "XDG_DATA_DIRS", op = "prepend",
                   value = "${pkgdir}/share", binding = tag }
    end
    return true
end

function uninstall()
    -- Nothing for the env declarations: they are provider-scoped and xlings
    -- drops the whole section with the package. A recipe removing them itself
    -- would be a second owner of that state.
    xvm.remove(package.name)
    return true
end
