local function asset(version, filename, sha256)
    return {
        url = string.format(
            "https://github.com/FarnaHerry/Clash-Flux/releases/download/v%s/%s",
            version, filename),
        sha256 = sha256,
    }
end

package = {
    spec = "2",

    name = "clash-flux",
    namespace = "farnaherry",
    description = "C++23 desktop proxy client built around the mihomo core and Clash Verge Rev-style workflows",
    homepage = "https://github.com/FarnaHerry/Clash-Flux",
    authors = {"FarnaHerry"},
    maintainers = {"FarnaHerry"},
    licenses = {"MIT"},
    repo = "https://github.com/FarnaHerry/Clash-Flux",
    docs = "https://github.com/FarnaHerry/Clash-Flux#readme",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"app", "network", "proxy", "tools"},
    keywords = {"clash", "mihomo", "proxy", "tun", "desktop"},

    programs = {"clash-flux"},
    xvm_enable = true,
    ci = { mirror = true },

    -- Linux ships x86_64 and aarch64; macOS ships arm64; Windows ships x86_64.
    -- Unsupported platform/architecture combinations stay absent by design.
    xpm = {
        linux = {
            ["latest"] = { ref = "0.3.131" },
            ["0.3.131"] = {
                url = "https://github.com/FarnaHerry/Clash-Flux/releases/download/v${version}/clash-flux-${version}-linux-${arch}.${ext}",
                sha256 = {
                    x86_64 = "4357995dabe0b087a3e6f1dc1f19881ce0d312c69589eb3ed534f8af0a08694d",
                    aarch64 = "a0e72d8ab398d5d524f376e6fa28031ee913df9cadfa3579add5e297464d4979",
                },
            },
            ["0.1.3"] = {
                x86_64 = asset("0.1.3", "clash-flux-v0.1.3-build-linux-x86_64.tar.gz",
                    "87263deb4ea50ec19a8c5c96b2c348f3b785e91607109b52d35f83663c2760d5"),
                aarch64 = asset("0.1.3", "clash-flux-v0.1.3-build-linux-arm64.tar.gz",
                    "578503bebff0111fbbd11b9518387b3f43b84419a4cf4684eec744eed83f8195"),
            },
        },
        macosx = {
            ["latest"] = { ref = "0.3.131" },
            ["0.3.131"] = {
                url = "https://github.com/FarnaHerry/Clash-Flux/releases/download/v${version}/clash-flux-${version}-macos-${arch_alias}.${ext}",
                arch_alias = { aarch64 = "arm64" },
                sha256 = {
                    aarch64 = "ca974e97b942fea7189b37274d16e99ca5b03375578789b11264ac5b2279d416",
                },
            },
            ["0.1.3"] = {
                aarch64 = asset("0.1.3", "clash-flux-v0.1.3-build-macos-arm64.tar.gz",
                    "908b9b07f5b3c05d040adf9c73839b4ca0132d20587b0f506eb70aad6493c077"),
            },
        },
        windows = {
            ["latest"] = { ref = "0.3.131" },
            ["0.3.131"] = {
                url = "https://github.com/FarnaHerry/Clash-Flux/releases/download/v${version}/clash-flux-${version}-windows-${arch}.${ext}",
                sha256 = {
                    x86_64 = "5fe666eccc505c7dad83eaca33a0b6110f7acbef85b65b5ed354372cca02227a",
                },
            },
            ["0.1.3"] = {
                x86_64 = asset("0.1.3", "clash-flux-v0.1.3-windows-x86_64.zip",
                    "90f69e2cf5190dee8be8d2dd0c9b20e485ce89686d9485f1f8379c610461a4a2"),
            },
        },
    },
}

-- 0.3.131 links GTK 4, libsoup 3, OpenSSL 3, nghttp2, and Vulkan on Linux.
-- The GTK 4 stack in this index currently targets x86_64 only, so declare the
-- direct DT_NEEDED providers on x86_64 and let aarch64 fall back to host libs.
local recipe_arch = (os.arch and os.arch())
if recipe_arch ~= "aarch64" and recipe_arch ~= "arm64" and recipe_arch ~= "x86_64" then
    recipe_arch = (type(is_arch) == "function" and is_arch("aarch64")) and "aarch64" or "x86_64"
end
if recipe_arch == "x86_64" then
    package.xpm.linux.deps = {
        runtime = {
            "xim:glibc@>=2.38",
            "xim:gcc-runtime@>=15.1.0",
            "xim:zlib@>=1.3",
            "xim:openssl@>=3.0",
            "xim:gtk4@>=4.16",
            "xim:pango@>=1.52",
            "xim:harfbuzz@>=14.4",
            "xim:cairo@>=1.18.4",
            "xim:vulkan-loader@>=1.4",
            "xim:graphene@>=1.10",
            "xim:glib@>=2.88",
            "xim:gdk-pixbuf@>=2.44",
            "xim:libX11@>=1.8",
            "xim:libXext@>=1.3",
            "xim:nghttp2@>=1.67",
            "xim:libepoxy@>=1.5",
            "xim:fontconfig@>=2.15",
            "xim:freetype@>=2.13",
            "xim:libsoup@>=3.6",
        },
    }
end

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

local function winpath(p)
    return (p:gsub("/", "\\"))
end

local function copy_payload(src, dst)
    os.mkdir(dst)
    if is_host("windows") then
        system.exec(string.format('xcopy "%s\\*" "%s\\" /E /I /Y /Q',
            winpath(src), winpath(dst)))
    else
        system.exec(string.format('cp -a "%s"/. "%s"/', src, dst))
    end
end

-- Unix tarballs wrap the staged directory in a platform-specific top-level
-- folder. Locate it by the application artifact instead of assuming the
-- archive stem is also the extracted folder name.
local function unix_payload_root(base)
    for _, dir in ipairs(os.dirs(path.join(base, "*"))) do
        if is_host("macosx") then
            if os.isdir(path.join(dir, "clash-flux.app")) then
                return dir
            end
        elseif os.isfile(path.join(dir, "clash-flux")) then
            return dir
        end
    end
    error("cannot locate the clash-flux release payload under " .. tostring(base))
end

local function chmod_if_file(filename)
    if os.isfile(filename) then
        system.exec(string.format('chmod +x "%s"', filename))
    end
end

function install()
    local dir = pkginfo.install_dir()
    local base = path.directory(pkginfo.install_file())
    os.tryrm(dir)

    if is_host("windows") then
        copy_payload(base, dir)
    else
        copy_payload(unix_payload_root(base), dir)
    end

    local exe
    if is_host("macosx") then
        exe = path.join(dir, "clash-flux.app", "Contents", "MacOS", "clash-flux")
    else
        exe = path.join(dir, is_host("windows") and "clash-flux.exe" or "clash-flux")
    end
    if not is_host("windows") then
        local bin_root = is_host("macosx")
            and path.join(dir, "clash-flux.app", "Contents", "MacOS")
            or dir
        chmod_if_file(exe)
        chmod_if_file(path.join(bin_root, "clash-flux-updater"))
        chmod_if_file(path.join(bin_root, "engines", "mihomo"))
        chmod_if_file(path.join(bin_root, "engines", "sing-box"))
    end
    return os.isfile(exe)
end

function config()
    local bindir = pkginfo.install_dir()
    if is_host("macosx") then
        bindir = path.join(bindir, "clash-flux.app", "Contents", "MacOS")
    end
    xvm.add(package.name, { bindir = bindir })
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
