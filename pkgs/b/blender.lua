-- Official 4.5 LTS archives; hashes from blender-4.5.15.sha256.
-- Upstream does not publish Linux ARM64 builds for this LTS series.
local base = "https://download.blender.org/release/Blender4.5/"
local function asset(name, sha256)
    return { url = base .. "blender-4.5.15-" .. name, sha256 = sha256 }
end

package = {
    spec = "2",
    name = "blender",
    description = "Blender LTS - 3D creation suite with Python scripting and headless rendering",
    homepage = "https://www.blender.org/",
    repo = "https://projects.blender.org/blender/blender",
    docs = "https://docs.blender.org/manual/en/4.5/",
    licenses = {"GPL-3.0-or-later"},
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"graphics", "3d", "animation"},
    keywords = {"blender", "render", "modeling", "python", "animation"},
    programs = {"blender"},
    xvm_enable = true,
    xpm = {
        linux = {
            -- Keep the upstream host loader. Bundled USD/Python and optional
            -- CUDA/HIP/Level Zero plugins use the host desktop/driver ABI,
            -- like dpcpp and the JDKs. A private glibc removes that fallback.
            -- No private graphics discovery variables are injected either.
            ["latest"] = { ref = "4.5.15" },
            ["4.5.15"] = {
                x86_64 = asset("linux-x64.tar.xz",
                    "0d2b8bb2efe97e6c8eb57de6b7322f8800e1984e3125b60decca5f6771e4773e"),
            },
        },
        windows = {
            ["latest"] = { ref = "4.5.15" },
            ["4.5.15"] = {
                x86_64 = asset("windows-x64.zip",
                    "52dd02fd74877fa08e74b67d7854cf32468a232c02aaa19b6844c91285574f8d"),
                aarch64 = asset("windows-arm64.zip",
                    "a095662a0c0063ccfb3d50760462d4a3cc74e6ee20880e85f639c28bc323db93"),
            },
        },
        macosx = {
            ["latest"] = { ref = "4.5.15" },
            ["4.5.15"] = {
                x86_64 = asset("macos-x64.dmg",
                    "3801a97619292a012ede0e855ee705ae872a680474845297b777254f7f21ed78"),
                aarch64 = asset("macos-arm64.dmg",
                    "bfbc0bda099d1ab7aef0992a584f872f58bed9bb491210ad45f9ca071aa2e688"),
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

local function quote(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function executable()
    local dir = pkginfo.install_dir()
    if os.isfile(dir .. "/Blender.app/Contents/MacOS/Blender") then
        return dir .. "/Blender.app/Contents/MacOS/Blender"
    end
    return dir .. (os.isfile(dir .. "/blender.exe") and "/blender.exe" or "/blender")
end

function installed()
    local dir = pkginfo.install_dir()
    local resources = dir
    if os.isfile(dir .. "/Blender.app/Contents/MacOS/Blender") then
        resources = dir .. "/Blender.app/Contents/Resources"
    end
    -- Scripts are needed by bpy even when the editor binary is present.
    return os.isfile(executable())
        and os.isfile(resources .. "/4.5/scripts/modules/bpy/__init__.py")
end

function install()
    if installed() then return true end
    local archive, dir = pkginfo.install_file(), pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local stem = normalized:match("([^/]+)$"):gsub("%.tar%.xz$", ""):gsub("%.zip$", "")
    if archive:match("%.dmg$") then
        os.mkdir(dir)
        local mount = dir .. "/.mount"
        os.mkdir(mount)
        system.exec("/usr/bin/hdiutil attach -readonly -nobrowse -mountpoint " ..
            quote(mount) .. " " .. quote(archive))
        local ok, err = pcall(function()
            system.exec("/usr/bin/ditto " .. quote(mount .. "/Blender.app") ..
                " " .. quote(dir .. "/Blender.app"))
        end)
        system.exec("/usr/bin/hdiutil detach " .. quote(mount))
        os.tryrm(mount)
        if not ok then error(err) end
    else
        -- Preserve the complete portable tree: bundled Python, libraries,
        -- scripts and data are all resolved relative to the executable.
        os.tryrm(dir)
        os.mv(parent .. "/" .. stem, dir)
    end
    assert(installed(), "Blender executable or bpy scripts are missing")
    return true
end

function config()
    local dir = pkginfo.install_dir()
    if os.isfile(dir .. "/Blender.app/Contents/MacOS/Blender") then
        xvm.add("blender", { bindir = dir .. "/Blender.app/Contents/MacOS", alias = "Blender" })
    else
        xvm.add("blender", { bindir = dir })
    end
    return true
end

function uninstall()
    xvm.remove("blender")
    return true
end
