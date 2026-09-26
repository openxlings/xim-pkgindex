-- Prebuilt Qt 6.11.1 from the official online-installer repository
-- (download.qt.io/online/qtsdkrepository), the SAME .7z payloads
-- `qt-online-installer`/`aqtinstall` fetch -- this recipe just resolves and
-- verifies them itself instead of going through either tool.
--
-- WHAT THIS PACKAGE IS: the base install -- qtbase, qtsvg, qtdeclarative,
-- qttools, qttranslations, plus platform extras (d3dcompiler_47/opengl32sw on
-- windows-x86_64; qtwayland/icu on linux) -- laid out from ONE install
-- prefix (bin/, include/, lib/, plugins/, ...). The 34 optional "Additional
-- Libraries" modules (Qt Charts, Qt Multimedia, Qt WebSockets, ...) are
-- pkgs/q/qt-addons.lua, in ITS OWN install prefix, not this one -- see that
-- recipe's header for why the split and how a consumer joins the two.
--
-- SOURCED FROM: the official repository's per-platform Updates.xml, cross-
-- checked module-by-module against https://www.qt.io/download-qt-installer
-- (which modules belong to "Desktop" base vs "Additional Libraries").
-- `qtdoc` is excluded (it is part of upstream's own base metapackage, but it
-- is 100+ MB of HTML/QCH documentation with no runtime purpose for a build
-- toolchain); debug-info archives (the separate `*-debug-info-*` payloads
-- Updates.xml lists beside every module) are excluded for the same reason.
-- Every archive's sha256 below was independently computed from the
-- downloaded bytes AND cross-checked against upstream's own published
-- `.sha1` sidecar for that same file (SHA-1, since that is the digest
-- Qt itself publishes) -- so this table is not a blind mirror of a hash
-- Qt never signed off on, it agrees with Qt's own checksum for every entry.
--
-- SIZES (compressed download / this module set only):
--   windows-x86_64   ~245 MB   (2.26 GB unpacked; the online installer's
--                               own qtbase node also carries qtdoc, which
--                               would add well over 1 GB unpacked for zero
--                               runtime benefit here -- see above)
--   windows-aarch64  ~225 MB   (no d3dcompiler_47/opengl32sw: upstream ships
--                               neither for the ARM64 desktop target)
--   linux-x86_64     ~187 MB
--   linux-aarch64    ~191 MB
--   macosx           ~200 MB   (ONE universal x86_64+arm64 payload)
--
-- MIRRORS. download.qt.io itself already redirects to a nearby CDN node; the
-- three others are China-based research-network mirrors of the identical
-- `online/qtsdkrepository` tree (Tsinghua, Aliyun, USTC). These are NOT
-- xlings-res -- Qt's own repository is not mirrored into xlings-res. The
-- mirror list, the verified download (msvc.lua's `sources()` /
-- `fetch_verified()` shape: an ordered address list, same sha256 checked
-- whichever one answers, first failure falls through to the next), the 7-Zip
-- extraction and the host detection below are libs/qtsdk.lua's, shared with
-- qt-base.lua and qt-addons.lua.
--
-- WHY THIS PACKAGE FETCHES MANUALLY INSTEAD OF THROUGH `xpm`. `xpm` resolves
-- ONE url+sha256 per version+arch; this module set is SEVERAL archives per
-- arch (5-7 for this package, 33-34 for qt-addons), so -- exactly like
-- pkgs/m/msvc.lua's VSIX payload set -- the version entries below are empty
-- and install() fetches+verifies the whole set itself.
--
-- WHY 7-ZIP. Every archive is `.7z`; xlings has no built-in 7z reader (this
-- is why pkgs/7/7zip.lua exists as a declared dependency), so install() shells
-- out to the just-installed `xim:7zip` binary (`7zz` on linux/macosx, `7z.exe`
-- on windows) via `pkginfo.dep_install_dir("xim:7zip")`.
--
-- HOST ARCH INSIDE install(). `os.arch()` is measured elsewhere in this index
-- (pkgs/n/node.lua, pkgs/a/appimagetool.lua) as unbound in the C++ xim hook
-- runtime, and this recipe has no per-arch `xpm` download to read the arch
-- back out of (msvc.lua's and android-ndk.lua's trick), because THIS
-- platform genuinely has two arches to choose between (windows, linux) where
-- those two do not. So host arch is read directly: `PROCESSOR_ARCHITECTURE`
-- on windows (a real env var every Windows host exports; not exercised
-- against a native-ARM64 host by this author -- flagged in the PR), `uname
-- -m` on linux. macosx needs no arch branch at all: one universal payload
-- serves both Apple arches.
package = {
    spec = "2",

    name = "qt",
    description = "Qt 6 base modules (qtbase, qtsvg, qtdeclarative, qttools, qttranslations and the platform extras), prebuilt, from the official online-installer repository, extracted into one prefix; documentation and debug symbols excluded",

    maintainers = {"The Qt Company"},
    licenses = {"LGPL-3.0-only"},
    homepage = "https://www.qt.io",
    docs = "https://doc.qt.io",

    type = "package",
    -- macosx x86_64/aarch64 are served by ONE universal payload (see xpm.macosx below).
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"gui", "framework", "c++"},
    keywords = {"qt", "qt6", "gui", "framework", "c++", "qmake", "cmake"},

    xvm_enable = true,

    xpm = {
        -- Empty version entries deliberately: install() fetches the whole
        -- module SET itself (see header). `deps` on xim:7zip is what
        -- extracts every `.7z` archive below.
        windows = {
            deps = { "xim:7zip" },
            ["latest"] = { ref = "6.11.1" },
            ["6.11.1"] = {},
        },
        linux = {
            deps = {
                "xim:7zip",
                -- Qt's official Linux build names these by SONAME and carries
                -- RUNPATH=$ORIGIN only (readelf -d over lib/ and
                -- plugins/platforms/). Declaring them with xim:glibc -- the
                -- loader provider -- makes xlings patch the whole payload
                -- after install(): every executable (moc, lupdate, ...) runs
                -- under the xlings loader, and every ELF file's RUNPATH is the
                -- closure of these packages and this payload's lib/, so the
                -- tools and a program linked by mcpp share one loader and libc.
                "xim:glibc",
                "xim:glib", "xim:zstd", "xim:zlib", "xim:dbus",
                "xim:fontconfig", "xim:freetype", "xim:libX11", "xim:libxkbcommon",
                "xim:libglvnd", "xim:libxcb", "xim:xcb-util", "xim:xcb-util-cursor",
                "xim:xcb-util-image", "xim:xcb-util-keysyms", "xim:xcb-util-renderutil",
                "xim:xcb-util-wm",
            },
            exports = {
                runtime = { libdirs = { "lib" } },
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
import("xim.libxpkg.system")
import("xim.libxpkg.log")
import("xim.libxpkg.xvm")
import("xim.libxpkg.fs")
import("xim.pkgindex.qtsdk")

local BASE = {
    ["windows-x86_64"] = {
        { module = "qtbase", name = "qtbase-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.win64_msvc2022_64/6.11.1-0-202605090529qtbase-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          sha256 = "7f97edc3937fec7383eb865e010ed5128155bf9c80a563abca450860f3e9bef5" },
        { module = "qtsvg", name = "qtsvg-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.win64_msvc2022_64/6.11.1-0-202605090529qtsvg-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          sha256 = "1d75ccf1f1a8fc78612c2c78bc2448f8f68949096d38ff9afe21980e0cb3d9b5" },
        { module = "qtdeclarative", name = "qtdeclarative-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.win64_msvc2022_64/6.11.1-0-202605090529qtdeclarative-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          sha256 = "fc716b905581922ee8254740ae0017fcdc90b58138109ce0d9a927c099412f44" },
        { module = "qttools", name = "qttools-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.win64_msvc2022_64/6.11.1-0-202605090529qttools-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          sha256 = "748f455851e0d81cd0e65232f6110840eda2bb980c4a4abf7e58ce97c2ff0f71" },
        { module = "qttranslations", name = "qttranslations-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.win64_msvc2022_64/6.11.1-0-202605090529qttranslations-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          sha256 = "2da76e41de1ed46542b8648e5d92b18f916817fac1d76121a209d72a0123093c" },
        { module = "d3dcompiler_47", name = "d3dcompiler_47-x64.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.win64_msvc2022_64/6.11.1-0-202605090529d3dcompiler_47-x64.7z",
          sha256 = "60a197f75dbac55661bc4697809d8422c2ab6acea68a917339bc262e6e46c0c8" },
        { module = "opengl32sw", name = "opengl32sw-64-mesa_11_2_2-signed_sha256.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.win64_msvc2022_64/6.11.1-0-202605090529opengl32sw-64-mesa_11_2_2-signed_sha256.7z",
          sha256 = "dde9302fbc8535cedf2fd75fa1826d6ac01e6fde230c976cd8ec05fe695b9db3" },
        -- The VC++ runtime Qt's MSVC DLLs import (MSVCP140, VCRUNTIME140,
        -- VCRUNTIME140_1, ...), taken from the redistributable Microsoft
        -- publishes for app-local deployment and placed in bin/ beside Qt's
        -- DLLs, so a program's runtime closure does not depend on the target
        -- machine having the VC++ Redistributable installed. Same vsix and
        -- pin as pkgs/m/msvc.lua's 14.44.35207 toolset.
        { module = "vcruntime", name = "Microsoft.VC.14.44.17.14.CRT.Redist.X64.base.vsix",
          urls = { "https://gitcode.com/xlings-res/msvc/releases/download/14.44.35207/Microsoft.VC.14.44.17.14.CRT.Redist.X64.base.vsix",
                   "https://download.visualstudio.microsoft.com/download/pr/45d3b8dd-bced-4b37-9974-142f748d710c/4aaf54db0bfc9435f7c3660e1a00237a4b556042bfeea64bde44c2e0194e6ee5/Microsoft.VC.14.44.17.14.CRT.Redist.X64.base.vsix" },
          pick = { from = "Contents/VC/Redist/MSVC/14.44.35112/x64/Microsoft.VC143.CRT", to = "bin" },
          sha256 = "4aaf54db0bfc9435f7c3660e1a00237a4b556042bfeea64bde44c2e0194e6ee5" },
    },
    ["windows-aarch64"] = {
        { module = "qtbase", name = "qtbase-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          path = "windows_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.win64_msvc2022_arm64/6.11.1-0-202605090529qtbase-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          sha256 = "140c316d376cb46017c32e4e1dfe5e4b3ffc959856314c8dde1adfdc2995d110" },
        { module = "qtsvg", name = "qtsvg-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          path = "windows_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.win64_msvc2022_arm64/6.11.1-0-202605090529qtsvg-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          sha256 = "75405e4f01525b6cc87c832e2ef9b61ce6e14dbeb898235a6fba7b88c2f32f22" },
        { module = "qtdeclarative", name = "qtdeclarative-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          path = "windows_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.win64_msvc2022_arm64/6.11.1-0-202605090529qtdeclarative-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          sha256 = "eb14283660c8cd4afb1b0a5d58aa4ae76aa98cece91e85b3a894a0e646e31d67" },
        { module = "qttools", name = "qttools-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          path = "windows_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.win64_msvc2022_arm64/6.11.1-0-202605090529qttools-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          sha256 = "64e9e19c3e854f20d1de18e617dd641f6dd46d2a560040fb73d0ec664dc393bb" },
        { module = "qttranslations", name = "qttranslations-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          path = "windows_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.win64_msvc2022_arm64/6.11.1-0-202605090529qttranslations-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          sha256 = "60b605002aa8a4313dc2699cfdb01f26c848b4e7d833870499550a3f43158b7b" },
    },
    ["linux-x86_64"] = {
        { module = "qtbase", name = "qtbase-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.linux_gcc_64/6.11.1-0-202605090529qtbase-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          sha256 = "1d6d82d765987d657d0df136fb347e98d6e29e99ef8d1cb433abf9f15c86ab6f" },
        { module = "qtsvg", name = "qtsvg-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.linux_gcc_64/6.11.1-0-202605090529qtsvg-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          sha256 = "3ecf5da46f425eb392d88dc1fca96cde55e52cc6974a68c8088852735dc2b0eb" },
        { module = "qtdeclarative", name = "qtdeclarative-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.linux_gcc_64/6.11.1-0-202605090529qtdeclarative-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          sha256 = "1eaeb3dc66eb50b2513791b694caaf07e6e667cd296cea8f97df1b1a675f550d" },
        { module = "qttools", name = "qttools-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.linux_gcc_64/6.11.1-0-202605090529qttools-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          sha256 = "556ca500ed69300d70fe91d38e6440e55cf754f560f236f02670fab3f0a6e456" },
        { module = "qttranslations", name = "qttranslations-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.linux_gcc_64/6.11.1-0-202605090529qttranslations-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          sha256 = "661a137438ad030ba74df2dcdbc8713a0f34b492970d2d53b01f795df3685367" },
        { module = "qtwayland", name = "qtwayland-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.linux_gcc_64/6.11.1-0-202605090529qtwayland-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          sha256 = "d9b6e5122963f02272a793ed3284fffb66e6fa759ba7dd343ffe5fe8ab3535a2" },
        { module = "icu", name = "icu-linux-Rhel8.6-x86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.linux_gcc_64/6.11.1-0-202605090529icu-linux-Rhel8.6-x86_64.7z",
          sha256 = "6ea4a612560b6eb39173bcfaa35abc08904fc124e4c0f93e1b39dd22368c33c8" },
    },
    ["linux-aarch64"] = {
        { module = "qtbase", name = "qtbase-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.linux_gcc_arm64/6.11.1-0-202605090529qtbase-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          sha256 = "d162343e104d9440442bfd3f22c13eec65e268f7a3179aa369a649a4b64816c7" },
        { module = "qtsvg", name = "qtsvg-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.linux_gcc_arm64/6.11.1-0-202605090529qtsvg-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          sha256 = "a92e20c4b1604e9fe5cf81acd5b7c07a8fb274d6eb6fb3434fbb0b204e35a6b9" },
        { module = "qtdeclarative", name = "qtdeclarative-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.linux_gcc_arm64/6.11.1-0-202605090529qtdeclarative-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          sha256 = "bb890266e01f7ec79b0d4ac85c67e23005e6c458b59b86a8efaab8b887908630" },
        { module = "qttools", name = "qttools-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.linux_gcc_arm64/6.11.1-0-202605090529qttools-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          sha256 = "5e509fbe98c67c655655ef53746851001f7fb5a10d5e041a6d33a09e88272cb3" },
        { module = "qttranslations", name = "qttranslations-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.linux_gcc_arm64/6.11.1-0-202605090529qttranslations-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          sha256 = "668321f808c6d2e7cf6c42d133393b63f20b5e8ff20a540aa937d7d523f4ea83" },
        { module = "qtwayland", name = "qtwayland-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.linux_gcc_arm64/6.11.1-0-202605090529qtwayland-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          sha256 = "07dbd4c2be73f50569967ddd1a0a7db6187052c8fa6434a18afe5e8fcf5d2ced" },
        { module = "icu", name = "icu-linux-Debian11.6-arm64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.linux_gcc_arm64/6.11.1-0-202605090529icu-linux-Debian11.6-arm64.7z",
          sha256 = "4f5c713877407e2fcc093ff31012737a360580478047c910d02e6a6cfa4dac84" },
    },
    ["macosx"] = {
        { module = "qtbase", name = "qtbase-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          path = "mac_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.clang_64/6.11.1-0-202605090526qtbase-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          sha256 = "a116552ad5b6660562308e8341ce25f3c81b857ca293fb67727a9f1fcfb1fded" },
        { module = "qtdeclarative", name = "qtdeclarative-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          path = "mac_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.clang_64/6.11.1-0-202605090526qtdeclarative-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          sha256 = "25328fb08c7f9b53e414fa81618c1ffaecef3d350d60670a85d51378fb44d1c5" },
        { module = "qtsvg", name = "qtsvg-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          path = "mac_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.clang_64/6.11.1-0-202605090526qtsvg-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          sha256 = "e380ff67d701187ef76754cd9c14b955aff665f524ba7f064dc124406936ffa7" },
        { module = "qttools", name = "qttools-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          path = "mac_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.clang_64/6.11.1-0-202605090526qttools-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          sha256 = "9db0742ae9ba77d8bc8c8992f0c0b12547f3d89966c7196812183b58f8e93a0f" },
        { module = "qttranslations", name = "qttranslations-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          path = "mac_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.clang_64/6.11.1-0-202605090526qttranslations-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          sha256 = "e0123d643a25517c829215d4c1adb6c05e165a805f75c36f88ff036ac1ad18fa" },
    },
}

local function marker_path()
    return path.join(pkginfo.install_dir(), ".qt-archives.txt")
end

function install()
    local key = qtsdk.host_key()
    if not key then
        log.error("qt: could not determine host platform/arch for this install")
        return false
    end
    local list = BASE[key]
    if not list then
        log.error("qt: no archive list for host platform '" .. key .. "'")
        return false
    end

    local install_dir = pkginfo.install_dir()
    os.tryrm(install_dir)
    fs.mkdir_p(install_dir)

    if not qtsdk.fetch_and_extract(list, install_dir, marker_path(), "qt") then
        return false
    end

    qtsdk.ensure_qt_conf(install_dir)
    qtsdk.mark_runtime(marker_path())

    return installed()
end

-- Per xpkg-creater §2.2.1: "installed" means the payload matches THIS
-- recipe's current archive list, not "a directory is here". The marker
-- records exactly what fetch_and_extract() verified+extracted; a handful of
-- sentinel files (one per tool/lib/header a consumer actually links against)
-- catch a marker that is stale against a hand-edited install directory.
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
    -- A payload installed before its runtime closure was declared (Linux:
    -- the loader and RUNPATH; Windows: the VC++ runtime in bin/) is installed
    -- again, so an update reaches the machines that have it.
    if not qtsdk.runtime_current(marker) then return false end

    local d = pkginfo.install_dir()
    local osname = os.host()
    local exe = osname == "windows" and ".exe" or ""

    -- qtbase's build-time tools. MEASURED: on linux and macosx Qt 6 puts
    -- moc/uic/rcc under libexec/ (bin/ keeps the user-facing tools); on
    -- windows they stay in bin/ -- this index's windows-test failed this
    -- check against a complete install while it looked in libexec/ there.
    local tools = osname == "windows" and "bin" or "libexec"
    if not os.isfile(path.join(d, tools, "moc" .. exe)) then return false end
    -- qttranslations
    if not os.isfile(path.join(d, "bin", "lrelease" .. exe)) then return false end

    -- qtbase headers -- a file unique to the module, not the include/ dir
    if osname == "macosx" then
        if not os.isfile(path.join(d, "lib", "QtCore.framework", "Headers", "QString")) then
            return false
        end
    else
        if not os.isfile(path.join(d, "include", "QtCore", "QString")) then
            return false
        end
    end

    -- qtbase shared library -- a file, not the lib/ dir
    if osname == "windows" then
        if not os.isfile(path.join(d, "lib", "Qt6Core.lib")) then return false end
        -- the VC++ runtime placed beside Qt's DLLs (windows-x86_64)
        if qtsdk.host_key() == "windows-x86_64"
           and not os.isfile(path.join(d, "bin", "msvcp140.dll")) then
            return false
        end
    elseif osname == "linux" then
        if not os.isfile(path.join(d, "lib", "libQt6Core.so.6")) then return false end
        -- icu -- the module whose archive is flat (see FLAT_MODULE_SUBDIR):
        -- libQt6Core.so.6 NEEDS these with RUNPATH=$ORIGIN, so a marker that
        -- says "icu extracted" but a wrong destination directory (the bug
        -- this sentinel exists to catch) leaves qmake/qtdiag/every Qt binary
        -- unable to start. MEASURED 2026-09-26: before the fix, the icu
        -- archive's 12 files landed at install_dir root instead of
        -- install_dir/lib, and `qmake --version` failed with
        -- "libicui18n.so.73: cannot open shared object file".
        if not os.isfile(path.join(d, "lib", "libicuuc.so.73")) then return false end
    else
        if not os.isfile(path.join(d, "lib", "QtCore.framework", "QtCore")) then return false end
    end

    return true
end

function config()
    -- No program needs a PATH shim for a correct build (mcpp's rules-qt and
    -- CMake's own find_package(Qt6) both locate this by CMAKE_PREFIX_PATH /
    -- an absolute prefix, not PATH) -- register an umbrella root only, the
    -- same shape 7zip.lua uses to keep xlings self doctor from reporting an
    -- orphan shim (openxlings/xlings#452).
    xvm.add(package.name, { type = "group" })
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
