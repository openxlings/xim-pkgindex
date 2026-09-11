package = {
    spec = "2",

    homepage = "https://www.khronos.org/vulkan/",
    name = "vulkan-loader",
    description = "Vulkan ICD loader - libvulkan.so.1 / vulkan-1.dll, without which an ICD manifest is never read",

    authors = {"The Khronos Group"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/KhronosGroup/Vulkan-Loader",

    type = "package",
    archs = {"x86_64"},
    status = "stable",

    -- PLATFORMS CARRY DIFFERENT VERSIONS, ON PURPOSE. windows has 1.4.357 as
    -- well as 1.4.313; linux has 1.4.313 only.
    --
    -- The linux payload is hand-built inside an xlings subos so that it links
    -- this ecosystem's glibc rather than the host's
    -- (.agents/tools/graphics/build-in-subos.sh), and the X/GL stack --
    -- mesa, lavapipe -- is validated against it. Rebuilding it is its own
    -- deliberate change, not a side effect of this one. The windows payload is
    -- built on a runner, from the tag mcpp-index's compat.vulkan consumes
    -- (vulkan-sdk-1.4.357.0), so that xlings and mcpp hand a Windows program the
    -- same loader. Both versions export the identical 265-name surface of
    -- `vulkan-1.def`, measured, so nothing that works against one breaks
    -- against the other.
    platform_versions_diverge = true,
    categories = {"graphics", "vulkan", "lib"},
    keywords = {"vulkan", "graphics", "vulkan-loader"},

    -- Why the stack needs this at all.
    --
    -- mesa already ships a Vulkan driver (RADV) and rewrites its ICD manifest to
    -- an absolute path inside our payload -- but an ICD is a DRIVER, and a driver
    -- is loaded BY a loader. Without libvulkan.so.1 the manifest sits there
    -- unread: `vulkaninfo` cannot run, and zink (GL over Vulkan) is dead in a
    -- payload that ships it.
    --
    -- Discovery needs NO new declaration. The Vulkan loader searches
    -- $XDG_DATA_DIRS/vulkan/icd.d, and mesa's config() already prepends its
    -- share directory to XDG_DATA_DIRS. VK_DRIVER_FILES would be wrong here --
    -- it is an OVERRIDE that suppresses system discovery, so it would hide every
    -- other ICD on the machine.

    xpm = {
        linux = {
            deps = { "xim:libX11@>=1.8", "xim:libxcb@>=1.17", "xim:libXrandr@>=1.5",
                     "xim:wayland@>=1.23", "xim:glibc@>=2.38" },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "1.4.313" },
            ["1.4.313"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/vulkan-loader/releases/download/1.4.313/vulkan-loader-1.4.313-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/vulkan-loader/releases/download/1.4.313/vulkan-loader-1.4.313-linux-x86_64.tar.gz",
                },
                sha256 = "4870e17d573117378132db72d338723c849bef5aa4ae3f01eb0aabbdfabd3c2b",
            },
        },

        -- WINDOWS: THE LOADER IS NOT AN OS COMPONENT, and that is the whole
        -- reason this branch exists.
        --
        -- `vulkan-1.dll` arrives with a GPU driver, with LunarG's Vulkan
        -- Runtime redistributable, or bundled beside an application. It is
        -- Apache-2.0 and redistributing it is the ordinary arrangement -- the
        -- Runtime redistributable exists for exactly that. So a machine with
        -- no driver has no loader, and anything linking `vulkan-1.lib` dies at
        -- process start with 0xC0000135 (STATUS_DLL_NOT_FOUND) before `main`.
        --
        -- Measured, not assumed: `vulkan`, `eui-neo-vulkan` and
        -- `vulkan-hpp-module` fail that way on a `windows-2022` runner in
        -- mcpp-index and pass on images that happen to carry a driver. Four
        -- rounds of pinning images and MSVC toolsets went into looking for a
        -- runner where that and everything else worked
        -- (mcpplibs/mcpp-index#388, closed). Shipping the loader takes the
        -- image out of the question instead.
        --
        -- No ICD comes with it. The loader finds drivers through
        -- HKLM\SOFTWARE\Khronos\Vulkan\Drivers, so a driverless machine
        -- enumerates no devices -- correct, and enough: loader-level calls
        -- such as `vkEnumerateInstanceVersion` are answered by the loader
        -- alone, which is the whole surface a headless consumer asserts.
        --
        -- Built on a runner rather than by hand, because the linux payload's
        -- reason for hand-building (link OUR glibc, in an xlings subos) has no
        -- Windows counterpart and nobody here has a Windows box. The workflow
        -- is xlings-res/vulkan-loader `.github/workflows/build-windows.yml`;
        -- it pins Vulkan-Headers through upstream's own `update_deps.py`, then
        -- LOADS the DLL it just built and resolves vkEnumerateInstanceVersion,
        -- vkCreateInstance and vkGetInstanceProcAddr before publishing. An
        -- artifact that exists is not an artifact that works.
        windows = {
            -- HOW THE DLL REACHES A CONSUMER'S EXE, and why it is a
            -- declaration rather than a PATH entry.
            --
            -- A PE resolves imports by NAME against the directory of the exe
            -- and then the search path. mcpp closes that for prebuilt-DLL
            -- packages already: every `*.dll` under a dependency's runtime
            -- library_dirs is COPIED beside the produced executable, into its
            -- bin/ (mcpp `src/build/plan.cppm`, `runtimeDeployFiles`). The
            -- filter is the `.dll` extension and not a platform `if`, so a
            -- Linux payload shipping .so populates nothing and non-Windows
            -- builds are unchanged -- its own comment names the case this is:
            -- "only a Windows prebuilt-DLL package ... populates it".
            --
            -- So `bin` here, where the loader's DLL lives, and NOT `lib`,
            -- which holds the import library the linker reads.
            --
            -- MEASURED, after getting this wrong once. The first attempt
            -- declared PATH through `subos.env` instead (see config()). It
            -- installs cleanly under a full xlings -- xim-pkgindex's own
            -- windows-test passes, subos "default" present -- and fails
            -- inside mcpp's project sandbox with `config hook failed`
            -- (mcpplibs/mcpp-index#391). Two environments, one descriptor,
            -- opposite results: the declaration was reaching for a subos that
            -- a sandbox does not present the same way. This path needs no
            -- subos at all.
            exports = {
                runtime = { libdirs = { "bin" } },
            },
            -- 1.4.357 matches compat.vulkan's headers and import library
            -- (vulkan-sdk-1.4.357.0); built by the same workflow, which loads the
            -- DLL and resolves its entry points before publishing. Its exports are
            -- exactly the 265 names in that tag's `loader/vulkan-1.def`. 1.4.313
            -- stays for anything that pinned it.
            ["latest"] = { ref = "1.4.357" },
            ["1.4.357"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/vulkan-loader/releases/download/1.4.357/vulkan-loader-1.4.357-windows-x86_64.zip",
                    CN     = "https://gitcode.com/xlings-res/vulkan-loader/releases/download/1.4.357/vulkan-loader-1.4.357-windows-x86_64.zip",
                },
                sha256 = "893d369de3103783b6a606c3730ace910c05ca0c293239c4bee17d02ac941395",
            },
            ["1.4.313"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/vulkan-loader/releases/download/1.4.313/vulkan-loader-1.4.313-windows-x86_64.zip",
                    CN     = "https://gitcode.com/xlings-res/vulkan-loader/releases/download/1.4.313/vulkan-loader-1.4.313-windows-x86_64.zip",
                },
                sha256 = "7159d30530572403079e583ebab3c9834d1dd760473487d6476c8a2f34fffe22",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")
import("xim.pkgindex.sysroot")
import("xim.pkgindex.selfcontain")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    -- The archive's top directory carries the version. Naming it literally
    -- worked while one version existed; with two, the other one's install
    -- moved nothing and reported success on an empty payload.
    local top = "vulkan-loader-" .. pkginfo.version()
    if not os.isdir(top) then
        log.error("vulkan-loader: expected %s in the extracted archive", top)
        return false
    end
    os.mv(top, dir)

    if os.host() == "windows" then
        -- NOTHING TO SEAL. `selfcontain.seal` rewrites ELF RPATH; a PE has no
        -- such field and Windows resolves imports by name against the search
        -- path. The payload is bin/vulkan-1.dll + lib/vulkan-1.lib and stands
        -- on its own -- the loader imports only kernel32/advapi32/cfgmgr32,
        -- which are genuinely OS components, unlike itself.
        if not os.isfile(path.join(dir, "bin", "vulkan-1.dll")) then
            log.error("vulkan-loader: payload has no bin/vulkan-1.dll")
            return false
        end
        return true
    end

    -- Stamp this payload's own dependency closure onto its libraries, so
    -- they resolve from our payloads and not from the host's ld.so.cache.
    selfcontain.seal(pkginfo.install_dir())

    -- NO relocate/declare of this payload's .pc, unlike the rest of the X and
    -- GL stack, and that is deliberate. The payload is a lib/ and nothing
    -- else; vulkan.pc's `includedir=${prefix}/include` refers to headers that
    -- live in the SEPARATE vulkan-headers package, so there is no value this
    -- side can rewrite it to that is correct. relocate_pkgconfig says so
    -- rather than guessing:
    --
    --     pkgconfig relocation left vulkan.pc pointing at
    --     includedir=<payload>/include, which does not exist under <payload>
    --
    -- Publishing it unrewritten would be worse than not publishing it: a
    -- consumer that finds vulkan.pc and is handed /usr/include compiles
    -- against the HOST's Vulkan headers without anything saying so. Left for
    -- a change that can make the .pc point at vulkan-headers.
    return true
end

function config()
    local binding = package.name .. "@" .. pkginfo.version()
    xvm.add(package.name)

    if os.host() == "windows" then
        -- NOTHING TO DECLARE HERE, and that is the correction.
        --
        -- This branch used to prepend the payload's bin/ to PATH through
        -- `subos.env`. That was the wrong layer twice over. It claimed
        -- `exports.runtime.libdirs` was elfpatch-only and had nothing to say
        -- on Windows -- it is also what mcpp reads to COPY a dependency's
        -- DLLs beside the executable it builds, which is the mechanism this
        -- package actually needs and is now declared in the windows xpm block
        -- above. And PATH is process-wide: it would put our loader in front
        -- of the system's for every child of that shell, not just for the
        -- consumer that asked for it.
        --
        -- It also did not work. Under a full xlings the declaration is
        -- recorded and the install passes (xim-pkgindex windows-test,
        -- subos "default"); under mcpp's project sandbox the same descriptor
        -- fails with `config hook failed` (mcpplibs/mcpp-index#391). A
        -- payload whose only job is to be found beside an exe should not
        -- depend on how a subos got set up, and now does not.
        --
        -- WHAT THIS STILL DOES NOT DO: give a consumer an ICD. The loader
        -- finds drivers through HKLM\SOFTWARE\Khronos\Vulkan\Drivers, so
        -- on a machine without a GPU driver `vkEnumerateInstanceVersion`
        -- answers and device enumeration comes back empty. That is the honest
        -- state of such a machine, and it is what a headless CI runner can be
        -- held to.
        return true
    end

    sysroot.declare_libs(pkginfo.install_dir(), "lib", binding, pkginfo.version())
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
