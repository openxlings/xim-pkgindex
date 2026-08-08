package = {
    spec = "2",

    homepage = "https://mesa3d.org",
    name = "mesa",
    description = "Mesa 3D — OpenGL and Vulkan: llvmpipe, radeonsi, iris, nouveau, zink, d3d12, RADV",

    authors = {"Mesa contributors"},
    licenses = {"MIT"},
    repo = "https://gitlab.freedesktop.org/mesa/mesa",
    docs = "https://docs.mesa3d.org",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "opengl", "lib"},
    keywords = {"mesa", "opengl", "vulkan", "gl", "egl", "llvmpipe", "radeonsi", "graphics"},

    -- What this package is for.
    --
    -- A program that draws needs three things: a loader and a libc
    -- (bootstrap), a way to find its libraries (discovery), and the
    -- environment its subsystems read (configuration). xlings had the first
    -- two. This package plus the declarations in config() supply the rest, so
    -- a GL program installed through xlings renders on a host that has no
    -- graphics stack of its own.
    --
    -- Drivers: llvmpipe and softpipe (CPU), radeonsi (AMD), iris (Intel),
    -- nouveau (NVIDIA open kernel module), zink (GL over Vulkan), d3d12 (WSL2 /
    -- Windows via DirectX 12), and RADV for Vulkan on AMD.
    --
    -- iris and d3d12 arrived in 25.0.7.2, and what they cost was five packages
    -- rather than a flag:
    --
    --   iris   -> with_gallium_iris implies with_clc (meson.build:841), so
    --             libclc + LLVMSPIRVLib + clang-cpp (llvm-dev) AND SPIRV-Tools
    --   d3d12  -> dependency('DirectX-Headers') (meson.build:606)
    --
    -- None of them appear in `deps` below, and that is the point: they are
    -- BUILD-time inputs. The payload was checked rather than assumed --
    -- libclang-cpp, libLLVMSPIRVLib, libSPIRV-Tools and libclc appear zero times
    -- in it, and no DT_NEEDED anywhere in the payload names any of them. iris and
    -- d3d12 add exactly one library between them, `libgbm.so.1`, which mesa ships
    -- itself. So the external closure is unchanged from 25.0.7.1.
    --
    -- anv (Intel Vulkan) and NVK are still NOT here: anv wants the same clc
    -- chain plus more, and NVK is Rust and needs bindgen.
    --
    -- Build details, per-flag, and what each one cost:
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
            -- Namespaced. Bare names were tried and are ambiguous once these
            -- packages exist in `xim` and the install test also registers them
            -- under `local`; the resolver refuses to guess between the two.
            deps = {
                "xim:libllvm@20.1.7",
                "xim:libglvnd@>=1.7",
                "xim:libdrm@>=2.4",
                "xim:libX11@>=1.8",
                "xim:libxcb@>=1.17",
                "xim:libXext@>=1.3",
                "xim:libXfixes@>=6.0",
                "xim:libXxf86vm@>=1.1",
                "xim:libxshmfence@>=1.3",
                "xim:expat@>=2.6",
                "xim:zlib@>=1.2",
                -- radeonsi reads the ELF that LLVM's AMDGPU backend emits.
                "xim:elfutils@>=0.19",
                -- The second window-system platform. Not optional once mesa
                -- is built with `-Dplatforms=x11,wayland`: libEGL_mesa gains a
                -- DT_NEEDED on libwayland-client, and a missing dep here does
                -- not fail the install -- it makes glvnd's dlopen of the
                -- vendor fail, which EGL reports as having no vendor at all.
                "xim:wayland@>=1.23",
                "xim:gcc-runtime@>=15",
                -- A floor, and 2.38 is measured: libgallium's highest
                -- required symbol version. It was pinned for one release
                -- because clients before 2026.8.5.2 compared a dep's version
                -- half by string equality and silently dropped glibc's
                -- exports; that is fixed, and this package shipped with the
                -- fix. A floor is also what lets a newer glibc satisfy this —
                -- glibc is backward compatible, so a 2.44 runtime runs this
                -- 2.39-built payload, and a pin would refuse it.
                "xim:glibc@>=2.38",
            },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "25.0.7.2" },
            -- 25.0.7.2: upstream is 25.0.7, the fourth component is ours. Adds
            -- iris and d3d12 to gallium-drivers; nothing else about the build
            -- changed, and the external DT_NEEDED closure is byte-for-byte the
            -- same set as 25.0.7.1.
            --
            -- The source needed ONE patch to build at all:
            -- `.agents/tools/graphics/patches/mesa-25.0.7-glibc-2.42-c11-threads.patch`.
            -- ISO C23 moved once_flag/call_once into <stdlib.h>, glibc >= 2.42
            -- followed, and mesa's own src/c11 shim redefines both -- so 25.0.7
            -- cannot compile against the glibc 2.44 in this index, and 25.0.7 is
            -- the last release of its series. 25.0.7.1 was built when this sysroot
            -- was glibc 2.39; the same source and command now fail without the
            -- patch. Worth knowing before anyone tries to reproduce the payload.
            ["25.0.7.2"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/mesa/releases/download/25.0.7.2/mesa-25.0.7.2-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/mesa/releases/download/25.0.7.2/mesa-25.0.7.2-linux-x86_64.tar.gz",
                },
                sha256 = "b589513ea1834ba995456680ad57a117428ba38299d8cc37d8fe301e5f6e6c9b",
            },
            -- 25.0.7.1: upstream is 25.0.7, the fourth component is ours.
            -- The payload was rebuilt with the full driver set, and a payload
            -- whose contents changed has to be a different version — a GitCode
            -- release asset is written once and cannot be deleted, so reusing
            -- 25.0.7 would leave two different tarballs claiming one name.
            ["25.0.7.1"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/mesa/releases/download/25.0.7.1/mesa-25.0.7.1-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/mesa/releases/download/25.0.7.1/mesa-25.0.7.1-linux-x86_64.tar.gz",
                },
                sha256 = "84789c203ead56343b64d9edb76c1ff4fe7e886ba4194e6bc79e332e66e8867b",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.libxpkg.subos")
import("xim.pkgindex.sysroot")
import("xim.pkgindex.selfcontain")
import("xim.pkgindex.graphics")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    -- The tarball's top-level directory is upstream's `mesa-25.0.7`; only the
    -- ASSET is named 25.0.7.1. Moving the wrong name leaves the download cache
    -- as the payload and install() still returns true, which is how this was
    -- found: a package that installed cleanly and had no `lib/` at all.
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

    -- The Vulkan ICD manifests need the same treatment, and worse: they ship
    -- `"library_path": "/usr/lib/libvulkan_radeon.so"` — not a bare SONAME
    -- that happens to resolve against the host, an ABSOLUTE host path. On a
    -- machine with mesa installed that loads the host's driver under our
    -- loader; on one without, it fails. Neither is this package.
    -- `ls`, not os.files: os.files is an xmake API and this hook runs in
    -- libxpkg's plain-Lua sandbox, where it is simply absent. The call raised,
    -- the hook aborted, and the package still reported success — with the ICDs
    -- left pointing at /usr/lib.
    local icddir = path.join(dir, "share/vulkan/icd.d")
    if os.isdir(icddir) then
        local names = {}
        local lsf = io.popen(string.format([[ls -1 "%s"/*.json 2>/dev/null]], icddir))
        if lsf then
            for line in lsf:lines() do
                local n = line:gsub("[\r\n]+$", "")
                if n ~= "" then table.insert(names, n) end
            end
            lsf:close()
        end
        for _, icd in ipairs(names) do
            local text = io.readfile(icd)
            -- Matched by the value's basename rather than by a list of driver
            -- names, so a driver added upstream is covered without an edit
            -- here — and a list that silently stops covering a new file is
            -- exactly the shape that ships a working-looking package.
            io.writefile(icd, (text:gsub('("library_path"%s*:%s*")([^"]+)(")',
                function(pre, val, post)
                    local base = val:match("([^/]+)$") or val
                    return pre .. path.join(dir, "lib", base) .. post
                end)))
        end
    end

    -- Stamp this payload's own dependency closure onto its libraries, so they
    -- resolve from our payloads and not from the host's ld.so.cache.
    selfcontain.seal(pkginfo.install_dir())
    return true
end

function config()
    local dir = pkginfo.install_dir()
    local tag = package.name .. "@" .. pkginfo.version()

    xvm.add(package.name)

    -- Only `lib/*.so*`, so the driver modules under `lib/dri/` stay
    -- out of `<subos>/lib`: those are loaded by path through
    -- LIBGL_DRIVERS_PATH below, and are not link targets.
    sysroot.declare_libs(dir, "lib", tag, pkginfo.version())

    -- Headers into the subos sysroot, so a compiler in this subos can build
    -- against the stack rather than only run it.
    --
    -- _tree because `EGL/`, `GL/` and `KHR/` are libglvnd's directories that
    -- mesa adds files to. Declaring the directory would place it whole, and a
    -- file asset is placed by rename(2) -- mesa's four headers would replace
    -- libglvnd's twenty rather than join them.
    if not sysroot.declare_headers_tree(dir, "include", "usr/include", tag) then
        sysroot.install_headers_tree(
            path.join(dir, "include"),
            path.join(system.subos_sysrootdir(), "usr", "include"))
    end

    -- The discovery layer, assembled into the SUBOS rather than announced from
    -- the payload.
    --
    -- What changed and why. These three variables used to name `${pkgdir}`
    -- directly -- this payload -- and were declared only through `subos.env`.
    -- Both halves were wrong:
    --
    --   * `${pkgdir}` pins a version directory, so upgrading mesa leaves any
    --     recorded consumer environment naming the old one.
    --   * `subos.env` alone is applied by `subos use` and nothing else, so
    --     `xlings install godot && godot` in an ordinary shell got a subos on
    --     PATH and none of these paths. That is the gap that made the whole
    --     22-package stack unreachable from the terminal a user actually has.
    --
    -- So: place the driver modules and the vendor JSON into the subos view,
    -- and declare the SUBOS paths. The view is the stable indirection -- the
    -- same role /run/opengl-driver plays on NixOS -- and it is what lets a
    -- consumer's shim carry the same values (graphics.consumer_envs) without
    -- knowing anything about mesa's payload.
    --
    -- The vendor JSON goes into the ONE shared directory, so cross-vendor
    -- priority is decided by filename (`10_nvidia` < `50_mesa`) as it is on the
    -- host, rather than by which package's binding string sorts later. See
    -- libs/graphics.lua for the libglvnd scanning rules that make that the
    -- only correct arrangement.
    graphics.declare_dri(dir, "lib/dri", tag)
    graphics.declare_egl_vendor(dir, "share/glvnd/egl_vendor.d/50_mesa.json", tag)

    -- The Vulkan ICD manifests, into the subos for the same reason the vendor
    -- JSON goes there: the loader reads $XDG_DATA_DIRS/vulkan/icd.d, and a
    -- manifest that stays in the payload is never found -- the loader silently
    -- serves the HOST's ICDs instead.
    graphics.declare_vulkan_icd(dir, "share/vulkan/icd.d", tag)

    -- And the shell scope as well, from the same table, so entering the subos
    -- and running a program through its shim cannot disagree.
    graphics.declare_subos_env(tag)
    return true
end

function uninstall()
    -- Nothing for the env declarations: they are provider-scoped and xlings
    -- drops the whole section with the package. A recipe removing them itself
    -- would be a second owner of that state.
    xvm.remove(package.name)
    return true
end
