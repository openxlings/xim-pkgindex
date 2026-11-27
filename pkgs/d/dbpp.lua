-- dbpp (db++): SQLite-first ADBC database manager & CLI built with HuxerUI.
--
-- Platform and architecture coverage (upstream v0.4.1 release):
--   linux    x86_64   `build-linux-x86_64/` (`dbpp`, `dbpp.resources/`, `lib/`)
--   linux    aarch64  `build-linux-arm64/` (`dbpp`, `dbpp.resources/`, `lib/`)
--   macosx   aarch64  `dbpp.app/` in a DMG (ad-hoc signed bundle)
--   windows  x86_64   flat zip (`dbpp.exe`, `dbpp.resources/`, DLLs + VC++ CRT)
--
-- `programs` is omitted deliberately (`{}`): `dbpp` defaults to launching the
-- desktop GUI and treats unrecognized positional arguments (such as Windows
-- CI's `/?` probe) as a file path, opening the GUI instead of exiting.
-- `config()` still registers `dbpp` via `xvm.add` (supporting `--version`,
-- `--help`, `doctor`, `driver`, `profile`, `tables`, `schema`, `rows`, `query`,
-- `exec`, `sql`).
package = {
    spec = "2",

    name = "dbpp",
    namespace = "farnaherry",
    description = "SQLite-first ADBC database manager built with HuxerUI and Lib-DataTable",
    homepage = "https://github.com/FarnaHerry/dbpp",
    authors = {"FarnaHerry"},
    maintainers = {"FarnaHerry"},
    licenses = {"MIT"},
    repo = "https://github.com/FarnaHerry/dbpp",
    docs = "https://github.com/FarnaHerry/dbpp#readme",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "dev",
    categories = {"app", "database", "tools"},
    keywords = {"dbpp", "db++", "sqlite", "adbc", "database", "huxerui", "cli"},

    programs = {},
    xvm_enable = true,
    ci = { mirror = true },

    extensions = {
        autoupdate = {
            source = "https://github.com/FarnaHerry/dbpp/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/FarnaHerry/dbpp/releases/download/${tag}/dbpp-${version}-linux-x86_64.tar.gz",
                            aarch64 = "https://github.com/FarnaHerry/dbpp/releases/download/${tag}/dbpp-${version}-linux-aarch64.tar.gz",
                        },
                        macosx = {
                            aarch64 = "https://github.com/FarnaHerry/dbpp/releases/download/${tag}/dbpp-${version}-macos-arm64.dmg",
                        },
                        windows = {
                            x86_64 = "https://github.com/FarnaHerry/dbpp/releases/download/${tag}/dbpp-${version}-windows-x86_64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            -- Direct DT_NEEDED soname providers measured across `dbpp` and
            -- `lib/*.so*` on linux/x86_64 (`libadbc_driver_manager.so.113` and
            -- `libhuxerui.so` are bundled in `lib/` and reached via `$ORIGIN/lib`).
            -- The GTK4/GNOME/X11 library stack in this index currently covers
            -- `x86_64` only, so `linux/aarch64` clears `deps` below and resolves
            -- against the host loader.
            deps = {
                runtime = {
                    "xim:glibc@>=2.38",
                    "xim:gcc-runtime@>=15.1.0",
                    "xim:gtk4@>=4.16",
                    "xim:pango@>=1.52",
                    "xim:gdk-pixbuf@>=2.44",
                    "xim:cairo@>=1.18.4",
                    "xim:graphene@>=1.10",
                    "xim:libepoxy@>=1.5",
                    "xim:fontconfig@>=2.15",
                    "xim:libsoup@>=3.0",
                    "xim:glib@>=2.88",
                    "xim:libX11@>=1.8",
                    "xim:harfbuzz@>=14.4.0",
                    "xim:freetype@>=2.13.2",
                    "xim:vulkan-loader@>=1.4.313",
                },
            },
            source = "https://github.com/FarnaHerry/dbpp/releases/download/v${version}/dbpp-${version}-linux-${arch}.${ext}",
            ["latest"] = { ref = "0.4.1" },
            ["0.4.1"] = {
                sha256 = {
                    x86_64 = "bdae8f62b650d8699ecf8d4af749464e930f406bc4d7af104814bcd069aa43ef",
                    aarch64 = "c11158fe69d9bc4b0757c43f8b18de66ffcacf9122d0c3649b42599300a17783",
                },
            },
            ["0.2.3"] = {
                sha256 = {
                    x86_64 = "790d64127a3d7e4b0a9ed76f3d1f38eb193dbd55171da1be3d57d5ef5ce9183c",
                    aarch64 = "0641f3502632f5b04062622b7c5611d42e2d1533e97dab3c55c61857d5a9f883",
                },
            },
        },
        macosx = {
            source = "https://github.com/FarnaHerry/dbpp/releases/download/v${version}/dbpp-${version}-macos-${arch_alias}.${ext}",
            ["latest"] = { ref = "0.4.1" },
            ["0.4.1"] = {
                url = "https://github.com/FarnaHerry/dbpp/releases/download/v0.4.1/dbpp-0.4.1-macos-arm64.dmg",
                sha256 = {
                    aarch64 = "643c000e3ac02f35b9bf3178ca26a6d6359e400c29be136cc7d11ad357cb665f",
                },
            },
            ["0.2.3"] = {
                arch_alias = { aarch64 = "arm64" },
                sha256 = {
                    aarch64 = "d703e238c2440fb3161f588947ffe487d119fe71b4dafff9575f7955eedcfbf3",
                },
            },
        },
        windows = {
            source = "https://github.com/FarnaHerry/dbpp/releases/download/v${version}/dbpp-${version}-windows-${arch}.${ext}",
            ["latest"] = { ref = "0.4.1" },
            ["0.4.1"] = {
                sha256 = {
                    x86_64 = "4459eeafdab69358f51d465e8a43056ea9d0a1a2c3eca15bc850e384aa65fe8b",
                },
            },
            ["0.2.3"] = {
                sha256 = {
                    x86_64 = "61a508888d730b134f6d827133512194e330facd69b44cae5df144ba22ffc58d",
                },
            },
        },
    },
}

-- `gtk4`, `libsoup`, `glib`, and the X11/text libraries in this index currently
-- publish `x86_64` payloads only; keep `linux/aarch64` installable on the host
-- loader until an `aarch64` GTK4 stack exists.
local recipe_arch = (os.arch and os.arch())
if (recipe_arch == "aarch64" or recipe_arch == "arm64") and package.xpm.linux then
    package.xpm.linux.deps = nil
end

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")
import("xim.pkgindex.selfcontain")

local function quote(value)
    return "'" .. value:gsub("'", "'\\''") .. "'"
end

local function chmod_x(file)
    if os.isfile(file) then
        system.exec(string.format('chmod +x "%s"', file))
    end
end

function installed()
    return payload.present({
            "dbpp",
            "lib/libhuxerui.so",
            "lib/libadbc_driver_manager.so.113",
            "lib/libadbc_driver_sqlite.so.113.0.0",
        })
        or payload.present({
            "dbpp.app/Contents/MacOS/dbpp",
            "dbpp.app/Contents/Frameworks/libhuxerui.dylib",
        })
        or payload.present({
            "dbpp.exe",
            "huxerui.dll",
            "adbc_driver_manager.dll",
            "adbc_driver_sqlite.dll",
        })
end

function install()
    local archive, dir = pkginfo.install_file(), pkginfo.install_dir()
    if archive:match("%.dmg$") then
        os.mkdir(dir)
        local mount = dir .. "/.mount"
        os.mkdir(mount)
        system.exec("/usr/bin/hdiutil attach -readonly -nobrowse -mountpoint " ..
            quote(mount) .. " " .. quote(archive))
        local ok, err = pcall(function()
            system.exec("/usr/bin/ditto " .. quote(mount .. "/dbpp.app") ..
                " " .. quote(dir .. "/dbpp.app"))
        end)
        system.exec("/usr/bin/hdiutil detach " .. quote(mount))
        os.tryrm(mount)
        if not ok then error(err) end
    else
        payload.unpack{ extracted = { "build-linux-x86_64", "build-linux-arm64", "build-macos-arm64" } }
    end

    if os.isfile(dir .. "/dbpp.exe") then
        payload.require({
            "dbpp.exe",
            "huxerui.dll",
            "adbc_driver_manager.dll",
            "adbc_driver_sqlite.dll",
            "dbpp.resources/huxerui/resources.bin",
        })
        return true
    end

    if os.isfile(dir .. "/dbpp.app/Contents/MacOS/dbpp") then
        chmod_x(dir .. "/dbpp.app/Contents/MacOS/dbpp")
        payload.require({
            "dbpp.app/Contents/MacOS/dbpp",
            "dbpp.app/Contents/Frameworks/libhuxerui.dylib",
            "dbpp.app/Contents/Frameworks/libadbc_driver_manager..dylib",
            "dbpp.app/Contents/Frameworks/libadbc_driver_sqlite..dylib",
            "dbpp.app/Contents/Resources/HuxerUI/huxerui/resources.bin",
        })
        return true
    end

    chmod_x(dir .. "/dbpp")
    payload.require({
        "dbpp",
        "lib/libhuxerui.so",
        "lib/libadbc_driver_manager.so.113",
        "lib/libadbc_driver_sqlite.so.113.0.0",
        "dbpp.resources/huxerui/resources.bin",
    })
    selfcontain.seal(dir, { "lib" })
    return true
end

function config()
    local dir = pkginfo.install_dir()
    if os.isfile(dir .. "/dbpp.exe") then
        xvm.add(package.name, { bindir = dir, alias = "dbpp.exe" })
    elseif os.isfile(dir .. "/dbpp.app/Contents/MacOS/dbpp") then
        xvm.add(package.name, { bindir = dir .. "/dbpp.app/Contents/MacOS" })
    else
        xvm.add(package.name, { bindir = dir })
    end
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
