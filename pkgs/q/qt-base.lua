-- Qt 6.11.1, qtbase and qttools only: what a C++ program built with Qt Core,
-- Gui, Widgets, Network and the other qtbase modules needs, and what Qt's code
-- generators and Linguist tools need -- moc, uic, rcc, lupdate, lrelease --
-- from the official online-installer repository (download.qt.io/online/
-- qtsdkrepository), laid out from one install prefix, as pkgs/q/qt.lua lays
-- out the full set.
--
-- WHY A SECOND PACKAGE. pkgs/q/qt.lua installs the base metapackage, of which
-- `qtdeclarative` (Qt Quick and QML) is two thirds: 159 of 245 MB on
-- windows-x86_64. A widgets or console program does not use it -- except that
-- qttools' `lupdate` (and on Linux and macOS `lrelease`) load the QtQml
-- library, which Qt publishes only inside that archive. So this package takes
-- qtbase and qttools from Qt's repository and QtQml ALONE from xlings-res
-- (github.com/xlings-res/qt-base, gitcode.com/xlings-res/qt-base), where each
-- platform's library is republished unmodified, extracted from the pinned
-- qtdeclarative archive -- the release notes there name the archive and its
-- sha256. QtQml depends on QtNetwork and QtCore and nothing else of Qt
-- (measured on every platform: PE imports, ELF NEEDED, Mach-O load commands).
--
-- SIZES (compressed download):
--   windows-x86_64   ~71 MB   (xim:qt: ~245 MB)
--   windows-aarch64  ~56 MB   (xim:qt: ~225 MB)
--   linux-x86_64     ~59 MB   (xim:qt: ~187 MB)
--   linux-aarch64    ~56 MB   (xim:qt: ~191 MB)
--   macosx           ~73 MB   (xim:qt: ~200 MB; one universal payload)
--
-- The platform extras are xim:qt's: d3dcompiler_47 and opengl32sw on
-- windows-x86_64 (the software OpenGL fallback a deployed program may carry),
-- ICU on Linux (QtCore links it). qttranslations (~1 MB) is here too: Qt's
-- own UI strings, which windeployqt places beside a program. Not here: qtsvg
-- (an SVG image or icon needs xim:qt), qtdeclarative beyond QtQml, qtwayland. Every Qt archive entry below is xim:qt's, byte for
-- byte the same pin; the download, the mirrors and the extraction are
-- libs/qtsdk.lua's, shared with qt.lua and qt-addons.lua.
package = {
    spec = "2",

    name = "qt-base",
    description = "Qt 6 qtbase, qttools (moc, uic, rcc, lupdate, lrelease) with the QtQml library they load, and qttranslations, prebuilt, from the official online-installer repository; the widgets-and-console subset of xim:qt",

    maintainers = {"The Qt Company"},
    licenses = {"LGPL-3.0-only"},
    homepage = "https://www.qt.io",
    docs = "https://doc.qt.io",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"gui", "framework", "c++"},
    keywords = {"qt", "qt6", "qtbase", "qttools", "gui", "framework", "c++"},

    xvm_enable = true,

    xpm = {
        -- Empty version entries: install() fetches the archive set itself
        -- (pkgs/q/qt.lua's header says why), extracted with xim:7zip.
        windows = {
            deps = { "xim:7zip" },
            ["latest"] = { ref = "6.11.1" },
            ["6.11.1"] = {},
        },
        linux = {
            deps = {
                "xim:7zip",
                -- The libraries Qt's Linux build loads and does not carry
                -- (readelf -d over lib/ and plugins/platforms/): QtCore's
                -- glib, zstd and zlib; QtDBus's libdbus; QtGui's fontconfig,
                -- freetype, X11, xkbcommon and EGL/GL (libglvnd); the xcb
                -- platform plugin's xcb libraries. install() stamps their
                -- directories onto the Qt libraries' RUNPATH (libs/qtsdk.lua).
                "xim:glib", "xim:zstd", "xim:zlib", "xim:dbus",
                "xim:fontconfig", "xim:freetype", "xim:libX11", "xim:libxkbcommon",
                "xim:libglvnd", "xim:libxcb", "xim:xcb-util", "xim:xcb-util-cursor",
                "xim:xcb-util-image", "xim:xcb-util-keysyms", "xim:xcb-util-renderutil",
                "xim:xcb-util-wm",
            },
            ["latest"] = { ref = "6.11.1" },
            ["6.11.1"] = {},
        },
        macosx = {
            deps = { "xim:7zip" },
            ["latest"] = { ref = "6.11.1" },
            ["6.11.1"] = {},
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.log")
import("xim.libxpkg.xvm")
import("xim.libxpkg.fs")
import("xim.pkgindex.qtsdk")
import("xim.pkgindex.selfcontain")

local BASE = {
    ["windows-x86_64"] = {
        { module = "qtbase", name = "qtbase-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.win64_msvc2022_64/6.11.1-0-202605090529qtbase-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          sha256 = "7f97edc3937fec7383eb865e010ed5128155bf9c80a563abca450860f3e9bef5" },
        { module = "qttools", name = "qttools-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.win64_msvc2022_64/6.11.1-0-202605090529qttools-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          sha256 = "748f455851e0d81cd0e65232f6110840eda2bb980c4a4abf7e58ce97c2ff0f71" },
        { module = "d3dcompiler_47", name = "d3dcompiler_47-x64.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.win64_msvc2022_64/6.11.1-0-202605090529d3dcompiler_47-x64.7z",
          sha256 = "60a197f75dbac55661bc4697809d8422c2ab6acea68a917339bc262e6e46c0c8" },
        { module = "opengl32sw", name = "opengl32sw-64-mesa_11_2_2-signed_sha256.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.win64_msvc2022_64/6.11.1-0-202605090529opengl32sw-64-mesa_11_2_2-signed_sha256.7z",
          sha256 = "dde9302fbc8535cedf2fd75fa1826d6ac01e6fde230c976cd8ec05fe695b9db3" },
        { module = "qttranslations", name = "qttranslations-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.win64_msvc2022_64/6.11.1-0-202605090529qttranslations-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          sha256 = "2da76e41de1ed46542b8648e5d92b18f916817fac1d76121a209d72a0123093c" },
        { module = "qtqml", name = "qtqml-6.11.1-windows-x86_64.7z",
          urls = { "https://github.com/xlings-res/qt-base/releases/download/6.11.1/qtqml-6.11.1-windows-x86_64.7z",
                   "https://gitcode.com/xlings-res/qt-base/releases/download/6.11.1/qtqml-6.11.1-windows-x86_64.7z" },
          sha256 = "705260431a127088f3e0acf2acf1f2e719d32248ac1b8c7ec0242cee4697541c" },
    },
    ["windows-aarch64"] = {
        { module = "qtbase", name = "qtbase-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          path = "windows_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.win64_msvc2022_arm64/6.11.1-0-202605090529qtbase-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          sha256 = "140c316d376cb46017c32e4e1dfe5e4b3ffc959856314c8dde1adfdc2995d110" },
        { module = "qttools", name = "qttools-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          path = "windows_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.win64_msvc2022_arm64/6.11.1-0-202605090529qttools-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          sha256 = "64e9e19c3e854f20d1de18e617dd641f6dd46d2a560040fb73d0ec664dc393bb" },
        { module = "qttranslations", name = "qttranslations-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          path = "windows_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.win64_msvc2022_arm64/6.11.1-0-202605090529qttranslations-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          sha256 = "60b605002aa8a4313dc2699cfdb01f26c848b4e7d833870499550a3f43158b7b" },
        { module = "qtqml", name = "qtqml-6.11.1-windows-aarch64.7z",
          urls = { "https://github.com/xlings-res/qt-base/releases/download/6.11.1/qtqml-6.11.1-windows-aarch64.7z",
                   "https://gitcode.com/xlings-res/qt-base/releases/download/6.11.1/qtqml-6.11.1-windows-aarch64.7z" },
          sha256 = "58a16adb11c670720910f98e8edac3d703dc2847e14116c23d23aaf17b32721b" },
    },
    ["linux-x86_64"] = {
        { module = "qtbase", name = "qtbase-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.linux_gcc_64/6.11.1-0-202605090529qtbase-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          sha256 = "1d6d82d765987d657d0df136fb347e98d6e29e99ef8d1cb433abf9f15c86ab6f" },
        { module = "qttools", name = "qttools-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.linux_gcc_64/6.11.1-0-202605090529qttools-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          sha256 = "556ca500ed69300d70fe91d38e6440e55cf754f560f236f02670fab3f0a6e456" },
        { module = "icu", name = "icu-linux-Rhel8.6-x86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.linux_gcc_64/6.11.1-0-202605090529icu-linux-Rhel8.6-x86_64.7z",
          sha256 = "6ea4a612560b6eb39173bcfaa35abc08904fc124e4c0f93e1b39dd22368c33c8" },
        { module = "qttranslations", name = "qttranslations-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.linux_gcc_64/6.11.1-0-202605090529qttranslations-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          sha256 = "661a137438ad030ba74df2dcdbc8713a0f34b492970d2d53b01f795df3685367" },
        { module = "qtqml", name = "qtqml-6.11.1-linux-x86_64.7z",
          urls = { "https://github.com/xlings-res/qt-base/releases/download/6.11.1/qtqml-6.11.1-linux-x86_64.7z",
                   "https://gitcode.com/xlings-res/qt-base/releases/download/6.11.1/qtqml-6.11.1-linux-x86_64.7z" },
          sha256 = "8ff6f94142a776b9917ec0161d426ee00652108bf3d3024939b846334c960265" },
    },
    ["linux-aarch64"] = {
        { module = "qtbase", name = "qtbase-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.linux_gcc_arm64/6.11.1-0-202605090529qtbase-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          sha256 = "d162343e104d9440442bfd3f22c13eec65e268f7a3179aa369a649a4b64816c7" },
        { module = "qttools", name = "qttools-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.linux_gcc_arm64/6.11.1-0-202605090529qttools-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          sha256 = "5e509fbe98c67c655655ef53746851001f7fb5a10d5e041a6d33a09e88272cb3" },
        { module = "icu", name = "icu-linux-Debian11.6-arm64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.linux_gcc_arm64/6.11.1-0-202605090529icu-linux-Debian11.6-arm64.7z",
          sha256 = "4f5c713877407e2fcc093ff31012737a360580478047c910d02e6a6cfa4dac84" },
        { module = "qttranslations", name = "qttranslations-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.linux_gcc_arm64/6.11.1-0-202605090529qttranslations-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          sha256 = "668321f808c6d2e7cf6c42d133393b63f20b5e8ff20a540aa937d7d523f4ea83" },
        { module = "qtqml", name = "qtqml-6.11.1-linux-aarch64.7z",
          urls = { "https://github.com/xlings-res/qt-base/releases/download/6.11.1/qtqml-6.11.1-linux-aarch64.7z",
                   "https://gitcode.com/xlings-res/qt-base/releases/download/6.11.1/qtqml-6.11.1-linux-aarch64.7z" },
          sha256 = "9d992a5ad5fa067f2a84d7f7d44396eb2d9db7c6a40013a7a3b9e5c5d2173016" },
    },
    ["macosx"] = {
        { module = "qtbase", name = "qtbase-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          path = "mac_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.clang_64/6.11.1-0-202605090526qtbase-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          sha256 = "a116552ad5b6660562308e8341ce25f3c81b857ca293fb67727a9f1fcfb1fded" },
        { module = "qttools", name = "qttools-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          path = "mac_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.clang_64/6.11.1-0-202605090526qttools-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          sha256 = "9db0742ae9ba77d8bc8c8992f0c0b12547f3d89966c7196812183b58f8e93a0f" },
        { module = "qttranslations", name = "qttranslations-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          path = "mac_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.clang_64/6.11.1-0-202605090526qttranslations-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          sha256 = "e0123d643a25517c829215d4c1adb6c05e165a805f75c36f88ff036ac1ad18fa" },
        { module = "qtqml", name = "qtqml-6.11.1-macosx-universal.7z",
          urls = { "https://github.com/xlings-res/qt-base/releases/download/6.11.1/qtqml-6.11.1-macosx-universal.7z",
                   "https://gitcode.com/xlings-res/qt-base/releases/download/6.11.1/qtqml-6.11.1-macosx-universal.7z" },
          sha256 = "d918b60200712d9efdec7ae5c398b66776563265cb5954e339fe9ce14572bf7e" },
    },
}

local function marker_path()
    return path.join(pkginfo.install_dir(), ".qt-base-archives.txt")
end

function install()
    local key = qtsdk.host_key()
    if not key then
        log.error("qt-base: could not determine host platform/arch for this install")
        return false
    end
    local list = BASE[key]
    if not list then
        log.error("qt-base: no archive list for host platform '" .. key .. "'")
        return false
    end

    local install_dir = pkginfo.install_dir()
    os.tryrm(install_dir)
    fs.mkdir_p(install_dir)

    if not qtsdk.fetch_and_extract(list, install_dir, marker_path(), "qt-base") then
        return false
    end

    qtsdk.ensure_qt_conf(install_dir)
    if os.host() == "linux" then
        selfcontain.seal(install_dir, { "lib" })
        qtsdk.mark_sealed(marker_path())
    end

    return installed()
end

-- "Installed" is the marker agreeing with this recipe's archive list, module
-- by module and sha256 by sha256, and one sentinel per thing a consumer uses.
function installed()
    local key = qtsdk.host_key()
    if not key then return false end
    local list = BASE[key]
    if not list then return false end

    local marker = qtsdk.read_marker(marker_path())
    if not marker then return false end
    for _, e in ipairs(list) do
        if marker[e.module] ~= e.sha256 then return false end
    end
    -- A Linux payload installed before its runtime closure was stamped is
    -- installed again, so an update reaches the machines that have it.
    if not qtsdk.runtime_sealed(marker) then return false end

    local d = pkginfo.install_dir()
    local osname = os.host()
    local exe = osname == "windows" and ".exe" or ""

    -- qtbase's build-time tools: bin/ on windows, libexec/ elsewhere.
    local tools = osname == "windows" and "bin" or "libexec"
    if not os.isfile(path.join(d, tools, "moc" .. exe)) then return false end
    -- qttools' Linguist tools, and the QtQml library they load
    if not os.isfile(path.join(d, "bin", "lrelease" .. exe)) then return false end
    if not os.isfile(path.join(d, "bin", "lupdate" .. exe)) then return false end
    if osname == "windows" then
        if not os.isfile(path.join(d, "bin", "Qt6Qml.dll")) then return false end
    elseif osname == "linux" then
        if not os.isfile(path.join(d, "lib", "libQt6Qml.so.6")) then return false end
    else
        if not os.isfile(path.join(d, "lib", "QtQml.framework", "Versions", "A", "QtQml")) then
            return false
        end
    end

    -- qtbase headers and library
    if osname == "macosx" then
        if not os.isfile(path.join(d, "lib", "QtCore.framework", "Headers", "QString")) then
            return false
        end
        if not os.isfile(path.join(d, "lib", "QtCore.framework", "QtCore")) then return false end
    else
        if not os.isfile(path.join(d, "include", "QtCore", "QString")) then return false end
    end
    if osname == "windows" then
        if not os.isfile(path.join(d, "lib", "Qt6Core.lib")) then return false end
    elseif osname == "linux" then
        if not os.isfile(path.join(d, "lib", "libQt6Core.so.6")) then return false end
        -- ICU, which libQt6Core.so.6 needs beside it (pkgs/q/qt.lua says why
        -- this sentinel exists)
        if not os.isfile(path.join(d, "lib", "libicuuc.so.73")) then return false end
    end

    return true
end

function config()
    -- An umbrella root only, as pkgs/q/qt.lua registers: consumers locate the
    -- prefix by path, not PATH.
    xvm.add(package.name, { type = "group" })
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
