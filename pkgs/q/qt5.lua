package = {
    spec = "2",
    name = "qt5",
    description = "Qt 5 qtbase runtime and tools from the official Qt SDK",
    homepage = "https://www.qt.io",
    licenses = {"LGPL-3.0-only"},
    type = "package",
    archs = {"x86_64"},
    status = "dev",
    categories = {"library", "gui"},
    xvm_enable = true,
    xpm = {
        linux = {
            deps = {
                runtime = {
                    "xim:glibc", "xim:gcc-runtime", "xim:glib",
                    "xim:gtk3", "xim:atk", "xim:cairo", "xim:libcups", "xim:dbus",
                    "xim:libdrm", "xim:fontconfig", "xim:freetype", "xim:gdk-pixbuf",
                    "xim:krb5", "xim:pango", "xim:zlib", "xim:libglvnd",
                    "xim:libX11", "xim:libXext", "xim:libxcb", "xim:libxkbcommon",
                    "xim:xcb-util", "xim:xcb-util-image", "xim:xcb-util-keysyms",
                    "xim:xcb-util-renderutil", "xim:xcb-util-wm",
                },
                -- 7-Zip only unpacks the archives in install(); it is not part of what the
                -- payload loads, so it is a build dep (docs/contributing.md §5.5).
                build = { "xim:7zip" },
            },
            exports = { runtime = { libdirs = {"lib"} } },
            ["latest"] = { ref = "5.15.2" },
            ["5.15.2"] = {},
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.qtsdk")

local prefix = "linux_x64/desktop/qt5_5152/qt.qt5.5152.gcc_64/5.15.2-0-202011130601"
local archives = {
    {
        module = "qtbase",
        name = "qtbase-Linux-RHEL_7_6-GCC-Linux-RHEL_7_6-X86_64.7z",
        path = prefix .. "qtbase-Linux-RHEL_7_6-GCC-Linux-RHEL_7_6-X86_64.7z",
        sha256 = "df4740feb9e9639ae5c95289988663d65f69a46fa9ccfb50742e9d73f0a04ac9",
    },
    {
        -- Qt 5's ICU 56 archive nests under the same tree as qtbase, unlike
        -- Qt 6's flat ICU archive, so it is extracted with qtbase's layout
        module = "qt5-icu",
        name = "icu-linux-Rhel7.2-x64.7z",
        path = prefix .. "icu-linux-Rhel7.2-x64.7z",
        sha256 = "a020e747e968bf98517992a9636a75362e83a5265c28e4339e1ab3cd6d74755c",
    },
}

function installed()
    local dir = pkginfo.install_dir()
    local marker = qtsdk.read_marker(dir .. "/.qt5-archives.txt")
    if not marker then return false end
    for _, entry in ipairs(archives) do
        if marker[entry.module] ~= entry.sha256 then return false end
    end
    for _, file in ipairs({"lib/libQt5Core.so.5", "lib/libQt5Gui.so.5",
        "lib/libQt5Widgets.so.5", "lib/libicuuc.so.56", "lib/libicui18n.so.56"}) do
        if not os.isfile(dir .. "/" .. file) then return false end
    end
    return true
end

function install()
    assert(qtsdk.host_key() == "linux-x86_64", "qt5: no verified SDK for this architecture")
    local dir = pkginfo.install_dir()
    local stage = dir .. "-sdk"
    os.tryrm(stage)
    if not qtsdk.fetch_and_extract(archives, stage, stage .. "/.qt5-archives.txt", "qt5") then
        return false
    end
    os.tryrm(dir)
    os.mv(stage .. "/5.15.2/gcc_64", dir)
    os.mv(stage .. "/.qt5-archives.txt", dir .. "/.qt5-archives.txt")
    os.tryrm(stage)
    -- These SQL driver plugins link ODBC/PostgreSQL client libraries this
    -- index does not carry; they are not part of a desktop runtime
    qtsdk.prune(dir, {"plugins/sqldrivers/libqsqlodbc.so", "plugins/sqldrivers/libqsqlpsql.so"})
    qtsdk.ensure_qt_conf(dir)
    return installed()
end

function config()
    xvm.add("qt5", {type = "group"})
    return true
end

function uninstall()
    xvm.remove("qt5")
    return true
end
