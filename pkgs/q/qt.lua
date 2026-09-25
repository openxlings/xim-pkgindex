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
-- xlings-res -- Qt's own repository is not mirrored into xlings-res, the
-- mirror list below is used directly by install() (msvc.lua's `sources()` /
-- `fetch_verified()` shape: an ordered address list, same sha256 checked
-- whichever one answers, first failure falls through to the next).
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
    description = "Qt 6 base modules (qtbase, qtsvg, qtdeclarative, qttools, qttranslations + platform extras), prebuilt from the official online-installer repository; VCPKG_ROOT-style multi-module install, no qtdoc/debug-info",

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
            deps = { "xim:7zip" },
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

-- Mirrors of https://download.qt.io/online/qtsdkrepository/, in preference
-- order. Every `path` in BASE below is relative to this root on every one of
-- them -- verified reachable, not verified byte-for-byte against every other
-- mirror (Qt's own tree, unlike xlings-res, carries no independent per-file
-- signature this recipe can cross-check beyond the sha256 pinned below,
-- which every mirror is still required to answer for its bytes to be
-- accepted -- see fetch_verified()).
local MIRRORS = {
    "https://download.qt.io/online/qtsdkrepository/",
    "https://mirrors.tuna.tsinghua.edu.cn/qt/online/qtsdkrepository/",
    "https://mirrors.aliyun.com/qt/online/qtsdkrepository/",
    "https://mirrors.ustc.edu.cn/qtproject/online/qtsdkrepository/",
}

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
-- path.join mixes separators on Windows -- keep the store path's existing
-- backslashes and turn any forward slashes this recipe adds into backslashes
-- too, matching msvc.lua's winpath() (7z.exe and its arguments both need it).
local function winpath(p)
    return (p:gsub("/", "\\"))
end

-- "https://host/a/b" -> "host", for log lines that say WHICH mirror answered.
local function host_of(url)
    return (url:match("^%w+://([^/]+)")) or url
end

-- windows: certutil, exactly as msvc.lua uses it (ships with every Windows,
-- prints the digest on its own line -- no quoting gymnastics like
-- Get-FileHash needs).
local function sha256_of_windows(file)
    local ok, out = pcall(os.iorun, string.format('certutil -hashfile "%s" SHA256', file))
    if not ok or not out then return nil end
    for line in out:gmatch("[^\r\n]+") do
        local hex = line:gsub("%s+", ""):lower()
        if #hex == 64 and hex:match("^%x+$") then return hex end
    end
    return nil
end

-- linux/macosx: sha256sum first (coreutils, every Linux), shasum second
-- (macOS's own, no sha256sum by default). Whichever answers wins; a missing
-- command is just a pcall failure, not a hook crash.
local function sha256_of_posix(file)
    local ok, out = pcall(os.iorun, string.format('sha256sum "%s"', file))
    if ok and out then
        local hex = out:match("(%x+)")
        if hex and #hex == 64 then return hex:lower() end
    end
    ok, out = pcall(os.iorun, string.format('shasum -a 256 "%s"', file))
    if ok and out then
        local hex = out:match("(%x+)")
        if hex and #hex == 64 then return hex:lower() end
    end
    return nil
end

local function sha256_of(file)
    if os.host() == "windows" then return sha256_of_windows(file) end
    return sha256_of_posix(file)
end

-- Host platform key into BASE/ADDONS ("windows-x86_64", "linux-aarch64",
-- "macosx", ...). Fails closed (returns nil) rather than guessing -- see the
-- header comment for why os.arch() cannot be used here.
local function host_key()
    local osname = os.host()
    if osname == "macosx" then
        -- one universal payload serves both Apple arches -- no branch needed
        return "macosx"
    end
    local arch
    if osname == "windows" then
        local pa = (os.getenv("PROCESSOR_ARCHITECTURE") or ""):upper()
        if pa == "ARM64" then
            arch = "aarch64"
        elseif pa == "AMD64" or pa == "X86" then
            arch = "x86_64"
        end
    elseif osname == "linux" then
        local ok, out = pcall(os.iorun, "uname -m")
        local m = ok and (out or ""):gsub("%s+$", "") or ""
        if m == "aarch64" or m == "arm64" then
            arch = "aarch64"
        elseif m == "x86_64" then
            arch = "x86_64"
        end
    end
    if not arch then return nil end
    return osname .. "-" .. arch
end

-- xim:7zip's program: `7zz` on linux/macosx (pkgs/7/7zip.lua moves it
-- straight to the install root), `7z.exe` on windows (the SFX installer's
-- own name, also at the install root).
local function sevenzip_bin()
    local dir = pkginfo.dep_install_dir("xim:7zip")
    if not dir then return nil end
    local rel = os.host() == "windows" and "7z.exe" or "7zz"
    local p = path.join(dir, rel)
    if os.isfile(p) then return p end
    return nil
end

-- Download one archive and prove it is the file this recipe pinned --
-- msvc.lua's fetch_verified(), generalized from ONE address per payload to a
-- shared mirror list every archive uses (see MIRRORS above).
local function fetch_verified(relpath, dst, want)
    want = want:lower()
    if os.isfile(dst) then
        if sha256_of(dst) == want then return true end
        os.tryrm(dst)
    end
    local why = {}
    for i, mirror in ipairs(MIRRORS) do
        local url = mirror .. relpath
        if i > 1 then
            log.warn("qt: falling back to " .. host_of(url) .. " for " .. relpath ..
                      " after: " .. table.concat(why, "; "))
        else
            log.info("qt: fetching " .. relpath .. " from " .. host_of(url))
        end
        -- pcall: curl -f exits non-zero on a 404 and system.exec RAISES on a
        -- non-zero exit -- without this the first missing mirror would abort
        -- the whole install instead of falling through to the next one.
        pcall(system.exec, string.format('curl -fsSL --retry 3 -o "%s" "%s"', dst, url))
        if os.isfile(dst) then
            local got = sha256_of(dst)
            if got == want then return true end
            table.insert(why, host_of(url) .. ": sha256 " .. tostring(got))
            os.tryrm(dst)
        else
            table.insert(why, host_of(url) .. ": no file")
        end
    end
    log.error("qt: could not obtain " .. relpath ..
              "\n  expected sha256 " .. want ..
              "\n  tried:\n    " .. table.concat(why, "\n    "))
    return false
end

-- 7-Zip 21+ refuses to write a symlink whose target is ITSELF another
-- symlink from the same archive ("Dangerous link via another link was
-- ignored"), and exits non-zero even though every real payload extracted
-- fine -- it just leaves a 0-byte REGULAR FILE where the first-hop symlink
-- belongs. MEASURED (2026-09-26) against qtbase's own
-- lib/libQt6DBus.so -> libQt6DBus.so.6 -> libQt6DBus.so.6.11.1 chain: exit
-- code 2, both real payloads (`.so.6`, the versioned `.so.6.11.1`) land
-- correctly, only `libQt6DBus.so` itself comes out as an empty file instead
-- of a symlink. The fix recreates that one symlink from its already-correct
-- sibling (`ln -sf libFoo.so.<N> libFoo.so`) rather than fail the whole
-- archive over a placeholder any linker step needs anyway.
--
-- POSIX only. Checked against a real 7zz extraction of the macOS qtbase
-- archive too (2026-09-26): framework bundles ARE internally symlink chains
-- (Versions/Current -> A, QtCore -> Versions/Current/QtCore, ...), but each
-- symlink's target is a MULTI-COMPONENT path through a real directory, not
-- another symlink's bare name in the same directory -- 7-Zip's check does
-- not fire there (exit 0, every framework symlink came out correct). So this
-- is a linux-only repair, and rightly so: there was nothing to repair on
-- macOS to begin with.
--
-- `dest_dir` is where extract_7z() just unpacked ONE archive, and where the
-- broken placeholder ends up differs by archive shape (see
-- FLAT_MODULE_SUBDIR below): a normal Qt module archive is prefix-rooted, so
-- its `.so` files land in `dest_dir/lib`; a FLAT archive (icu) is instead
-- extracted directly into what is already install_dir/lib, so its `.so`
-- files land in `dest_dir` itself. Trying both candidates once is cheaper
-- than threading "which shape was this" through two more functions, and a
-- candidate that does not exist is just skipped.
local function so_repair_dirs(dest_dir)
    return { dest_dir, path.join(dest_dir, "lib") }
end

local function repair_broken_so_symlinks(dest_dir)
    if os.host() == "windows" then return end
    for _, libdir in ipairs(so_repair_dirs(dest_dir)) do
        if os.isdir(libdir) then
            pcall(system.exec, string.format(
                [[sh -c 'cd "%s" && for f in *.so; do [ -f "$f" ] || continue; [ -s "$f" ] && continue; cand=$(ls -1 "$f".* 2>/dev/null | grep -E "\.so\.[0-9]+$" | sort -V | head -1); [ -n "$cand" ] && ln -sf "$(basename "$cand")" "$f"; done']],
                libdir))
        end
    end
end

-- True when no 0-byte "*.so" placeholder remains in either candidate dir --
-- the signal that repair_broken_so_symlinks() actually resolved everything
-- extract_7z()'s non-zero exit could have meant, as opposed to a real
-- failure (truncated download, corrupt archive, full disk, ...) that
-- happens to share a non-zero exit code with this one specific case.
local function no_broken_so_placeholders(dest_dir)
    for _, libdir in ipairs(so_repair_dirs(dest_dir)) do
        if os.isdir(libdir) then
            local ok, out = pcall(os.iorun, string.format(
                'find "%s" -maxdepth 1 -name "*.so" -size 0 -type f', libdir))
            if ok and out and out:match("%S") then return false end
        end
    end
    return true
end

-- Extract one .7z into dest_dir via the xim:7zip binary.
--
-- Windows: exe left UNQUOTED, arguments quoted -- msvc.lua's measured cmd /c
-- quoting gotcha (quoting the exe when more quoted args follow makes cmd
-- strip the outer quotes and mangle the line). `-o<dir>` is one token, no
-- space, so the quote sits right after `-o`. Every path is winpath()'d.
-- POSIX: no such hazard, quote everything normally.
local function extract_7z(zbin, archive, dest_dir)
    if os.host() == "windows" then
        return pcall(system.exec, string.format('%s x -y "-o%s" "%s"',
            winpath(zbin), winpath(dest_dir), winpath(archive)))
    end
    local ok = pcall(system.exec, string.format('"%s" x -y "-o%s" "%s"',
        zbin, dest_dir, archive))
    if ok then return true end
    -- See repair_broken_so_symlinks() above for what this is and is not.
    repair_broken_so_symlinks(dest_dir)
    return no_broken_so_placeholders(dest_dir)
end

-- A HANDFUL of archives in this repository are NOT laid out from the
-- install prefix root the way every Qt module archive is (qtbase, qtsvg,
-- qtcharts, ... all extract straight into install_dir with their own
-- include/, lib/, ... at the top). These three are flat single/few-file
-- redistributables Qt's own installer places into a SPECIFIC subdirectory
-- of the prefix, and this table is that mapping -- MEASURED by listing each
-- archive (`7zz l`) rather than assumed:
--   icu             -- linux/linux-aarch64 base: 12 files, ALL at archive
--                      root (libicu*.so.73[.2]), belongs under lib/
--   d3dcompiler_47  -- windows-x86_64 base: ONE file (d3dcompiler_47.dll)
--                      at archive root, belongs under bin/ (deployed beside
--                      an app's own Qt DLLs, Qt's documented convention)
--   opengl32sw      -- windows-x86_64 base: ONE file (opengl32sw.dll),
--                      same shape and reason as d3dcompiler_47
-- Every other module in BASE/ADDONS is prefix-rooted and needs no entry
-- here -- extracting an addon module straight into install_dir is correct.
local FLAT_MODULE_SUBDIR = {
    icu = "lib",
    d3dcompiler_47 = "bin",
    opengl32sw = "bin",
}

-- Fetch+verify+extract every archive in `list` into install_dir, recording
-- each one into `marker` AS SOON AS it lands -- not the whole list up front
-- -- so a mid-run failure leaves the marker naming only what actually made
-- it in (xpackage-spec.md rule R4: assert on the artifact, not the intent).
-- installed() below treats the marker as authoritative and checks it
-- against THIS recipe's current list, module by module and sha256 by
-- sha256, plus a few sentinel files.
local function fetch_and_extract(list, install_dir, marker)
    local zbin = sevenzip_bin()
    if not zbin then
        log.error("qt: no 7-Zip binary found under the xim:7zip payload " ..
                  "(declared dependency; this is a broken installation)")
        return false
    end
    local work = path.join(install_dir, ".dl")
    fs.mkdir_p(work)
    fs.mkdir_p(install_dir)

    local marker_lines = {}
    for _, e in ipairs(list) do
        local dst = path.join(work, e.name)
        if not fetch_verified(e.path, dst, e.sha256) then
            return false
        end
        local dest = install_dir
        local sub = FLAT_MODULE_SUBDIR[e.module]
        if sub then
            dest = path.join(install_dir, sub)
            fs.mkdir_p(dest)
        end
        if not extract_7z(zbin, dst, dest) then
            log.error("qt: 7zip extraction failed for " .. e.name)
            return false
        end
        os.tryrm(dst)
        table.insert(marker_lines, e.module .. " " .. e.sha256)
        -- Written after EVERY archive, not just at the end -- a hook that
        -- dies partway through still leaves a marker naming what is really
        -- there.
        io.writefile(marker, table.concat(marker_lines, "\n") .. "\n")
    end
    os.tryrm(work)
    return true
end

-- Parses the marker `fetch_and_extract` wrote: "<module> <sha256>" per line.
local function read_marker(marker)
    if not os.isfile(marker) then return nil end
    local content = io.readfile(marker) or ""
    local map = {}
    for line in content:gmatch("[^\n]+") do
        local mod, sha = line:match("^(%S+)%s+(%x+)$")
        if mod then map[mod] = sha end
    end
    return map
end

local function marker_path()
    return path.join(pkginfo.install_dir(), ".qt-archives.txt")
end

-- Written by qt.conf's own docs: relocatable installs need this file so
-- qmake/qtpaths report the right prefix after the tree is moved (which is
-- exactly what os.mv into install_dir just did). Some archives already ship
-- one (upstream's own qtbase payload sometimes does); never overwrite an
-- existing one.
local function ensure_qt_conf(install_dir)
    local conf = path.join(install_dir, "bin", "qt.conf")
    if os.isfile(conf) then return end
    fs.mkdir_p(path.join(install_dir, "bin"))
    io.writefile(conf, "[Paths]\nPrefix = ..\n")
end

function install()
    local key = host_key()
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

    if not fetch_and_extract(list, install_dir, marker_path()) then
        return false
    end

    ensure_qt_conf(install_dir)

    return installed()
end

-- Per xpkg-creater §2.2.1: "installed" means the payload matches THIS
-- recipe's current archive list, not "a directory is here". The marker
-- records exactly what fetch_and_extract() verified+extracted; a handful of
-- sentinel files (one per tool/lib/header a consumer actually links against)
-- catch a marker that is stale against a hand-edited install directory.
function installed()
    local key = host_key()
    if not key then return false end
    local list = BASE[key]
    if not list then return false end

    local marker = read_marker(marker_path())
    if not marker then return false end
    for _, e in ipairs(list) do
        if marker[e.module] ~= e.sha256 then return false end
    end

    local d = pkginfo.install_dir()
    local osname = os.host()
    local exe = osname == "windows" and ".exe" or ""

    -- qtbase's build-time tools -- MEASURED (2026-09-26, linux-x86_64): Qt6
    -- puts moc/uic/rcc under libexec/, not bin/ (the QT_HOST_PATH split
    -- introduced for cross-compilation; bin/ keeps only the GUI-facing tools
    -- -- assistant, designer, linguist, qmake, ...). Not independently
    -- verified on windows/macosx by this author; if either ships moc under
    -- bin/ instead, this check fails closed there rather than silently
    -- passing on the wrong path.
    if not os.isfile(path.join(d, "libexec", "moc" .. exe)) then return false end
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
