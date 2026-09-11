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
            ["latest"] = { ref = "1.4.313" },
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
import("xim.libxpkg.subos")
import("xim.pkgindex.sysroot")
import("xim.pkgindex.selfcontain")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("vulkan-loader-1.4.313", dir)

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
        -- PATH, because that is where Windows looks. There is no RPATH to
        -- stamp and no sysroot to declare into: `sysroot.declare_libs` builds
        -- a linker view for ELF, and `exports.runtime.libdirs` is read by
        -- xlings's elfpatch, which has nothing to patch here. A PE resolves
        -- its imports by NAME, against the directory of the exe and then the
        -- search path -- so the payload's bin/ has to be on it.
        --
        -- `${pkgdir}` and not an absolute path: the spec requires a
        -- placeholder, and a literal would pin the declaration to the machine
        -- that wrote it. `prepend` and not `set`, because PATH is a list and
        -- more than one provider is entitled to be on it -- a `set` by one
        -- provider beats every other prepend in xlings's resolution.
        --
        -- WHAT THIS DOES NOT DO: give a consumer an ICD. The loader finds
        -- drivers through the registry, so on a machine without a GPU driver
        -- `vkEnumerateInstanceVersion` answers and device enumeration comes
        -- back empty. That is the honest state of such a machine, and it is
        -- what a headless CI runner can be held to.
        if type(subos.env) == "function" then
            subos.env{ var = "PATH", op = "prepend",
                       value = "${pkgdir}/bin", binding = binding }
        end
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
