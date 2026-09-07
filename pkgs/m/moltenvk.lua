-- MoltenVK — Vulkan on macOS, implemented over Metal.
--
-- WHY THIS PACKAGE EXISTS.
--
-- macOS has no native Vulkan. Apple's platform interface is Metal, and every
-- Vulkan implementation there is a translation layer; MoltenVK is Khronos's
-- own. Without it a machine running macOS enumerates no Vulkan device at all,
-- and every macOS runner in this ecosystem is such a machine -- which is the
-- same shape `xim:mesa-lavapipe` answers on Linux, with one difference that
-- matters: lavapipe is a SOFTWARE rasteriser and this is the machine's real
-- GPU, reached through Metal.
--
-- THE ONE THING A CONSUMER MUST DO, AND WHY IT IS NOT THIS PACKAGE'S TO DO.
--
-- The manifest this payload carries declares `"is_portability_driver": true`,
-- and the Vulkan loader does NOT offer a portability driver to
-- `vkEnumeratePhysicalDevices` unless the instance enables
-- `VK_KHR_portability_enumeration` and sets
-- `VK_INSTANCE_CREATE_ENUMERATE_PORTABILITY_BIT_KHR`. A device that then
-- advertises `VK_KHR_portability_subset` must have it enabled at
-- `vkCreateDevice` or that call fails.
--
-- So a program written against a native driver alone sees no device here, and
-- has no way to tell that apart from a machine with no GPU. That is a property
-- of the program rather than of the packaging, and no install hook can supply
-- it -- which is why it is written down here instead.
--
-- WHY A REPACK.
--
-- `MoltenVK-macos.tar` is 57 MB and is not compressed; it carries a static
-- xcframework, the Vulkan headers and the documentation alongside the dynamic
-- driver. A loader-driven consumer needs two files. The repack is 3.3 MB and
-- copies every byte -- nothing is rebuilt. Recipe, script and the upstream
-- sha256: https://github.com/xlings-res/moltenvk
package = {
    spec = "2",

    homepage = "https://github.com/KhronosGroup/MoltenVK",
    name = "moltenvk",
    description = "MoltenVK — Vulkan on macOS, implemented over Metal",

    authors = {"The Khronos Group"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/KhronosGroup/MoltenVK",
    docs = "https://github.com/KhronosGroup/MoltenVK/blob/main/Docs/MoltenVK_Runtime_UserGuide.md",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"graphics", "vulkan", "lib"},
    keywords = {"vulkan", "metal", "moltenvk", "macos", "portability"},

    -- ONE ASSET FOR BOTH ARCHITECTURES, AND THAT IS UPSTREAM'S SHAPE RATHER
    -- THAN A SHORTCUT. `libMoltenVK.dylib` is a Mach-O universal binary
    -- carrying x86_64 and arm64 slices, so the two entries below name the same
    -- file and the same digest by construction; splitting it would produce two
    -- downloads of one artifact.
    --
    -- NO `deps`. The payload is one dylib whose external references are macOS
    -- system frameworks (Metal, Foundation, IOSurface), which are the host's by
    -- definition -- there is no closure here for this index to supply.
    xpm = {
        macosx = {
            ["latest"] = { ref = "1.4.2" },
            ["1.4.2"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/moltenvk/releases/download/1.4.2/moltenvk-1.4.2-macosx-universal.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/moltenvk/releases/download/1.4.2/moltenvk-1.4.2-macosx-universal.tar.gz",
                    },
                    sha256 = "f87bfea71b6375de348fcb27a576af31ede2f99ff6e43dbcd9707597c34e2f8e",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/moltenvk/releases/download/1.4.2/moltenvk-1.4.2-macosx-universal.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/moltenvk/releases/download/1.4.2/moltenvk-1.4.2-macosx-universal.tar.gz",
                    },
                    sha256 = "f87bfea71b6375de348fcb27a576af31ede2f99ff6e43dbcd9707597c34e2f8e",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.log")
import("xim.libxpkg.xvm")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)

    -- The archive's top-level directory carries the version, and moving the
    -- wrong name leaves the download cache as the payload while install() still
    -- reports success -- a package that installs cleanly and has no `lib/`.
    local top = "moltenvk-" .. pkginfo.version()
    if not os.isdir(top) then
        log.error("moltenvk: expected %s in the extracted archive", top)
        return false
    end
    os.mv(top, dir)

    -- THE MANIFEST'S PATH IS RELATIVE TO THE MANIFEST, AND THE SPLIT MOVED IT.
    --
    -- Upstream ships `"library_path": "./libMoltenVK.dylib"`, correct where it
    -- sits beside the dylib and wrong once the two are separated into `lib/`
    -- and `share/vulkan/icd.d/`. The loader resolves the path against the
    -- manifest it READ, so this is rewritten to the payload's absolute path --
    -- the same rewrite `xim:mesa-lavapipe` performs on its own, for the same
    -- reason.
    local icddir = path.join(dir, "share/vulkan/icd.d")
    if os.isdir(icddir) then
        local lsf = io.popen(string.format([[ls -1 "%s"/*.json 2>/dev/null]], icddir))
        if lsf then
            for line in lsf:lines() do
                local icd = line:gsub("[\r\n]+$", "")
                if icd ~= "" then
                    local text = io.readfile(icd)
                    io.writefile(icd, (text:gsub('("library_path"%s*:%s*")([^"]+)(")',
                        function(pre, val, post)
                            local base = val:match("([^/]+)$") or val
                            return pre .. path.join(dir, "lib", base) .. post
                        end)))
                end
            end
            lsf:close()
        end
    end

    return os.isfile(path.join(dir, "lib", "libMoltenVK.dylib"))
end

function config()
    local dir = pkginfo.install_dir()

    -- THE ROOT AND NOTHING ELSE, AND THE ABSENCE IS THE DESIGN.
    --
    -- `xim:mesa-lavapipe` places its manifest into the subos view and sets the
    -- loader's search variables there, because Linux has a subos and the mcpp
    -- artifact runs behind a private loader. macOS has neither: dyld resolves
    -- normally, and the loader reads `/usr/local/share/vulkan/icd.d` or the
    -- path named by `VK_DRIVER_FILES`. Writing into a system directory is not
    -- this index's business, so the payload is placed and named, and the
    -- consumer points at it:
    --
    --   VK_DRIVER_FILES=<install_dir>/share/vulkan/icd.d/MoltenVK_icd.json
    --
    -- stated here because it is part of what this package promises.
    xvm.add(package.name)
    log.info("moltenvk: VK_DRIVER_FILES=%s",
             path.join(dir, "share/vulkan/icd.d", "MoltenVK_icd.json"))
    return true
end

function uninstall()
    os.tryrm(pkginfo.install_dir())
    return true
end
