package = {
    spec = "2",
    homepage = "https://github.com/KhronosGroup/Vulkan-ValidationLayers",
    name = "vulkan-validation-layers",
    description = "The Khronos Vulkan validation layer (VK_LAYER_KHRONOS_validation), built for this ecosystem's glibc",
    authors = {"The Khronos Group"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/KhronosGroup/Vulkan-ValidationLayers",
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "vulkan", "lib"},
    keywords = {"vulkan", "validation", "layer", "VK_LAYER_KHRONOS_validation", "debug"},

    -- WHY THIS IS PACKAGED
    --
    -- A debug build of a Vulkan program asks the loader for
    -- VK_LAYER_KHRONOS_validation. The loader finds the layer through a JSON
    -- manifest and then dlopens the library it names -- and a program built by
    -- mcpp runs on this ecosystem's glibc, whose loader searches the payloads
    -- on its RPATH and never the host's /usr/lib. The host's copy of the layer
    -- is therefore found by manifest and lost at dlopen, and the program dies
    -- in vkCreateInstance. Host drivers are bridged into the process because a
    -- driver can only come from the machine (compat.vulkan-runtime); a layer is
    -- ordinary software and belongs in the ecosystem like any other library.
    --
    -- ONE .so, ONE MANIFEST, AND NOTHING TO RESOLVE
    --
    -- Built with -static-libstdc++ -static-libgcc, so the library's NEEDED set
    -- is glibc's alone (measured: libc, libm, ld-linux) and it loads into any
    -- process regardless of which libstdc++ that process carries -- the layer
    -- API is C, nothing crosses the boundary. The manifest's library_path is
    -- rewritten to an absolute payload path in install(); config() places the
    -- manifest in the subos's share/vulkan/explicit_layer.d and puts that
    -- share on XDG_DATA_DIRS, which is what the loader reads and what mcpp
    -- carries into `mcpp run` (mcpp#352).
    --
    -- Version = the Vulkan SDK tag the layer is built from, the same line
    -- mcpp-index's compat.vulkan (the loader) tracks.

    xpm = {
        linux = {
            deps = { "xim:glibc@>=2.38" },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "1.4.357.0" },
            ["1.4.357.0"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/vulkan-validation-layers/releases/download/1.4.357.0/vulkan-validation-layers-1.4.357.0-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/vulkan-validation-layers/releases/download/1.4.357.0/vulkan-validation-layers-1.4.357.0-linux-x86_64.tar.gz",
                },
                sha256 = "22011723f5d140eb85b8587716b75a4cabd212285181a18b1fa27cc29a804675",
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

local LAYER_DIR = "share/vulkan/explicit_layer.d"

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("vulkan-validation-layers-" .. pkginfo.version(), dir)

    -- The manifest ships `"library_path": "../../../lib/libVkLayer_khronos_validation.so"`,
    -- relative to itself. config() copies the manifest into the subos, where
    -- that path points at nothing, so it becomes the absolute payload path
    -- here -- the same treatment mesa gives its ICD manifests, and for the
    -- same reason.
    local layerdir = path.join(dir, LAYER_DIR)
    if os.isdir(layerdir) then
        local names = {}
        local lsf = io.popen(string.format([[ls -1 "%s"/*.json 2>/dev/null]], layerdir))
        if lsf then
            for line in lsf:lines() do
                local n = line:gsub("[\r\n]+$", "")
                if n ~= "" then table.insert(names, n) end
            end
            lsf:close()
        end
        for _, manifest in ipairs(names) do
            local text = io.readfile(manifest)
            io.writefile(manifest, (text:gsub('("library_path"%s*:%s*")([^"]+)(")',
                function(pre, val, post)
                    local base = val:match("([^/]+)$") or val
                    return pre .. path.join(dir, "lib", base) .. post
                end)))
        end
    end

    selfcontain.seal(dir)
    return true
end

function config()
    local dir = pkginfo.install_dir()
    local tag = package.name .. "@" .. pkginfo.version()
    xvm.add(package.name)
    sysroot.declare_libs(dir, "lib", tag, pkginfo.version())
    graphics.declare_vulkan_layer(dir, LAYER_DIR, tag)
    -- XDG_DATA_DIRS alone: that is the one row this payload fills.
    graphics.declare_subos_env(tag, { ["XDG_DATA_DIRS"] = true })
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
