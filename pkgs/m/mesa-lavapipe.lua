package = {
    spec = "2",

    -- THE TWO PLATFORMS CARRY DIFFERENT VERSIONS, AND THAT IS A PROPERTY OF
    -- WHERE EACH PAYLOAD COMES FROM.
    --
    -- Linux is built by this ecosystem (26.2.1). Windows is repacked from
    -- `pal1000/mesa-dist-win`, because Mesa publishes no Windows binaries of
    -- its own, and that redistribution publishes 26.1.7 and 26.2.0. There is
    -- no 26.2.1 of the Windows build and no 26.2.0 of the Linux one, so the
    -- sets cannot be made equal by choosing differently. Declared here so this
    -- reads as a decision rather than as a bump that landed in one section and
    -- was forgotten in the other.
    platform_versions_diverge = true,

    homepage = "https://docs.mesa3d.org/drivers/llvmpipe.html",
    name = "mesa-lavapipe",
    description = "Mesa lavapipe — Vulkan on the CPU, for machines with no GPU driver",

    authors = {"Mesa contributors"},
    -- The set, not the headline. This payload is a closure of 25 upstream
    -- packages and each one's terms travel with it; `licenses/` inside the
    -- payload carries the texts and `PROVENANCE.md` says which package
    -- contributed which. libiconv is LGPL-2.1 and libgcc is GPL-3.0 with the
    -- runtime exception: both are redistributable here, and both are invisible
    -- if only "MIT" is written down.
    licenses = {
        "MIT", "Apache-2.0", "Apache-2.0 WITH LLVM-exception", "BSD-3-Clause",
        "NCSA", "Zlib", "0BSD", "LGPL-2.1", "GPL-3.0-with-GCC-exception",
    },
    repo = "https://gitlab.freedesktop.org/mesa/mesa",
    docs = "https://docs.mesa3d.org/drivers/llvmpipe.html",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"graphics", "vulkan", "lib"},
    keywords = {"mesa", "lavapipe", "vulkan", "llvmpipe", "software-rasterizer", "cpu"},

    -- WHAT THIS PACKAGE IS FOR.
    --
    -- `xim:mesa` builds from source in a subos and ships `-Dvulkan-drivers=amd`
    -- — RADV, for AMD hardware. A machine with no GPU, or with a GPU whose
    -- vendor ICD is not installed, therefore enumerates no Vulkan device at
    -- all, and every CI runner in this ecosystem is such a machine. That is
    -- what this package answers: a Vulkan device that is always available,
    -- because it is the CPU.
    --
    -- WHY A REPACK AND NOT A BUILD. Mesa's Vulkan drivers need glslang at build
    -- time, which is why `xim:mesa` left them out; that dependency now exists
    -- (`xim:glslang`) and the source route is open. It was not taken because a
    -- payload built here is linked against THIS machine's glibc, which is the
    -- failure `build-in-subos.sh` exists to prevent, while conda-forge's Linux
    -- binaries are built against glibc 2.17 — older than any target this index
    -- supports — and they carry that property for the whole closure rather
    -- than for one library. Recipe, scripts and measurements:
    -- https://github.com/xlings-res/mesa-lavapipe
    --
    -- NO `deps`, AND THAT IS THE DESIGN.
    --
    -- Every `lib/*.so*` in the payload carries `DT_RPATH = $ORIGIN`, written
    -- when the payload was assembled, and the closure is complete inside that
    -- one directory. Declaring a dependency here would hand the payload to
    -- predicate-driven elfpatch, which REPLACES DT_RPATH with a DT_RUNPATH of
    -- its own — and the distinction is not cosmetic:
    --
    --   RUNPATH=$ORIGIN   loader_icd_scan: Failed loading library associated
    --                     with ICD JSON …/libvulkan_lvp.so. Ignoring this JSON
    --   RPATH=$ORIGIN     devices=1 / CPU llvmpipe (LLVM 22.1.8, 256 bits)
    --
    -- because a non-empty DT_RUNPATH on a dlopen'd object switches off the
    -- EXECUTABLE's inherited DT_RPATH for that object's dependencies, and an
    -- xlings-built binary reaches its C library only through that inherited
    -- path. `selfcontain.seal` is not called for the same reason and because
    -- there is nothing outside this payload for it to close over.
    --
    -- NOTHING IS DECLARED INTO THE SUBOS LIBRARY VIEW. The payload contains a
    -- libz, a libdrm, a libxcb and an LLVM, and every one of them is a name
    -- some other package in this index also provides. They stay private to the
    -- payload; only the ICD manifest is placed, into the one directory the
    -- Khronos loader reads.
    --
    -- aarch64 is repacked the same way, from conda-forge's linux-aarch64
    -- build. The two closures are not byte-identical in file count: the
    -- aarch64 build of mesa-lavapipe itself is upstream's build_number 0
    -- (2026-08-20), while the published x86_64 payload comes from build_number
    -- 2 (2026-09-02), which added a dependency on `libllvmspirv22` that build 0
    -- does not declare -- so the x86_64 payload's `lib/` carries one file
    -- (`libLLVMSPIRVLib.so.22.1`, NCSA licensed) that aarch64's does not.
    -- libdrm's own conda-forge package additionally ships `libdrm_etnaviv` and
    -- `libdrm_freedreno` (ARM SoC display drivers) only on aarch64, and GCC's
    -- `libquadmath` only on x86_64. None of the four is DT_NEEDED by anything
    -- else in either closure (checked with `readelf -d` across every object),
    -- so the difference does not reach `libvulkan_lvp.so` or change what the
    -- package provides.
    xpm = {
        linux = {
            ["latest"] = { ref = "26.2.1" },
            ["26.2.1"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/mesa-lavapipe/releases/download/26.2.1/mesa-lavapipe-26.2.1-linux-x86_64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/mesa-lavapipe/releases/download/26.2.1/mesa-lavapipe-26.2.1-linux-x86_64.tar.gz",
                    },
                    sha256 = "104f5f4b8aee088dd9b81df5935c5d43e4982a9c62ef0465e3587b25d0e3267d",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/mesa-lavapipe/releases/download/26.2.1/mesa-lavapipe-26.2.1-linux-aarch64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/mesa-lavapipe/releases/download/26.2.1/mesa-lavapipe-26.2.1-linux-aarch64.tar.gz",
                    },
                    sha256 = "4fd34bbb6ce3279a2a5d81ab9049b8e08e80e6f5c872042b14c2a65c41ac53e0",
                },
            },
        },

        -- WINDOWS, AND THE PAYLOAD IS SOMEONE ELSE'S REDISTRIBUTION.
        --
        -- Mesa publishes no Windows binaries. `pal1000/mesa-dist-win` does,
        -- and this payload is two files out of its `release-msvc` archive,
        -- repacked into the same layout as the Linux ones. The provenance is
        -- named in the payload's own PROVENANCE.md rather than left implicit,
        -- because "where did this come from" has a different answer on this
        -- platform.
        --
        -- MEASURED BEFORE IT WAS TAKEN: `vulkan_lvp.dll` imports ADVAPI32,
        -- GDI32, KERNEL32, ntdll, ole32, SHELL32 and USER32 and nothing else
        -- -- in particular NOT MSVCP140 or VCRUNTIME140, so it needs no Visual
        -- C++ redistributable on the machine. A payload that depended on
        -- something this ecosystem has not configured is the dependency this
        -- index exists to remove, and that check is what decided between the
        -- available builds.
        windows = {
            ["latest"] = { ref = "26.2.0" },
            ["26.2.0"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/mesa-lavapipe/releases/download/26.2.0/mesa-lavapipe-26.2.0-windows-x86_64.zip",
                        CN     = "https://gitcode.com/xlings-res/mesa-lavapipe/releases/download/26.2.0/mesa-lavapipe-26.2.0-windows-x86_64.zip",
                    },
                    sha256 = "fa4808f62b395774f0cb4dc559345ac13e9c1ed9885f131adfd23a2176e7aed1",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.log")
import("xim.libxpkg.xvm")
import("xim.pkgindex.graphics")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    -- The tarball's top-level directory carries the version, and moving the
    -- wrong name leaves the download cache as the payload while install() still
    -- reports success — a package that installs cleanly and has no `lib/`.
    local top = "mesa-lavapipe-" .. pkginfo.version()
    if not os.isdir(top) then
        log.error("mesa-lavapipe: expected %s in the extracted archive", top)
        return false
    end
    os.mv(top, dir)

    -- The ICD manifest ships a path relative to itself -- on Linux
    -- `"../../../lib/libvulkan_lvp.so"`, on Windows `".\\vulkan_lvp.dll"` --
    -- which is correct where it sits on one host, wrong on the other, and wrong
    -- on both once config() places a copy into the subos view: the loader
    -- resolves the path against the manifest it READ. Rewritten to the
    -- payload's absolute path, the way `xim:mesa` rewrites its own.
    --
    -- THE RESULT HAS TO BE VALID JSON, AND ON WINDOWS IT WAS NOT.
    --
    -- `path.join` produces `\` there, and this writes the value into a JSON
    -- string. `"C:\Users\...\lib\vulkan_lvp.dll"` contains `\U`, which is not
    -- a JSON escape. The loader parses manifests with cJSON, and one it cannot
    -- parse is an ICD it SKIPS -- no error reaches the application, which sees
    -- zero physical devices. Measured against the published 26.2.0 Windows
    -- payload, where `mcpp`'s offscreen example prints `render unavailable`.
    --
    -- Forward slashes settle it: `LoadLibrary` accepts them and they need no
    -- escape. The same spelling is correct on every host, so there is no branch.
    local icddir = path.join(dir, "share/vulkan/icd.d")
    if os.isdir(icddir) then
        -- LISTING A DIRECTORY IS A DIFFERENT COMMAND ON THE TWO HOSTS. `ls` is
        -- not one on Windows; cmd's `dir /b` prints bare names, so the
        -- directory is prepended. A shared invocation does not fail loudly
        -- there -- it returns nothing, and an ICD whose `library_path` was
        -- never rewritten is a driver the loader silently declines to load.
        local names = {}
        local cmd
        if is_host("windows") then
            cmd = string.format([[dir /b "%s\*.json" 2>nul]], icddir:gsub("/", "\\"))
        else
            cmd = string.format([[ls -1 "%s"/*.json 2>/dev/null]], icddir)
        end
        local lsf = io.popen(cmd)
        if lsf then
            for line in lsf:lines() do
                local n = line:gsub("[\r\n]+$", "")
                if n ~= "" then
                    table.insert(names, is_host("windows") and path.join(icddir, n) or n)
                end
            end
            lsf:close()
        end
        for _, icd in ipairs(names) do
            local text = io.readfile(icd)
            io.writefile(icd, (text:gsub('("library_path"%s*:%s*")([^"]+)(")',
                function(pre, val, post)
                    -- BOTH SEPARATORS, because the value's own spelling is the
                    -- publisher's. Matching `[^/]+` alone leaves `.\` attached
                    -- to a Windows name and produces `lib\.\vulkan_lvp.dll`.
                    local base = val:match("([^/\\]+)$") or val
                    local abs  = path.join(dir, "lib", base)
                    return pre .. abs:gsub("\\", "/") .. post
                end)))
        end
    end

    -- The driver's file name is the host's. A check written for one spelling
    -- passes vacuously on the other only if the file is allowed to be absent,
    -- and it is not: a payload without it is not this package.
    local driver = is_host("windows") and "vulkan_lvp.dll" or "libvulkan_lvp.so"
    return os.isfile(path.join(dir, "lib", driver))
end

function config()
    local dir = pkginfo.install_dir()
    local tag = package.name .. "@" .. pkginfo.version()

    -- The node every `xvm.files` binding below points at. A binding whose root
    -- the recipe never registers is refused (`xvm-binding-root-missing`), and
    -- the package installs but places nothing -- so this line is not
    -- bookkeeping, it is what makes the ICD manifest reach the subos.
    xvm.add(package.name)

    -- THE SUBOS VIEW IS A LINUX CONSTRUCTION, SO THE TWO CALLS BELOW ARE TOO.
    --
    -- On Linux the manifest goes into the shared ICD directory, so cross-vendor
    -- priority is decided by filename as it is on a host, and `XDG_DATA_DIRS`
    -- makes the loader look there at all. A manifest that stays in the payload
    -- is never found, and the failure is invisible: the loader falls through to
    -- the HOST's /usr/share and usually finds something.
    --
    -- Windows has neither: the loader reads the registry, or the path named by
    -- `VK_DRIVER_FILES`. This package therefore places the payload and stops;
    -- naming the ICD is the consumer's, and the manifest's absolute path is
    -- `<install_dir>/share/vulkan/icd.d/lvp_icd.x86_64.json` -- stated here
    -- because it is now part of what this package promises.
    if is_host("linux") then
        graphics.declare_vulkan_icd(dir, "share/vulkan/icd.d", tag)
        graphics.declare_subos_env(tag, graphics.VULKAN_ICD_ONLY)
    end
    return true
end

function uninstall()
    os.tryrm(pkginfo.install_dir())
    return true
end
