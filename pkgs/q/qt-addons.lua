-- Qt 6.11.1 "Additional Libraries" -- every optional add-on module the
-- official online installer lists under that node (qt3d, qtcharts,
-- qtmultimedia, qtwebsockets, ... 33-34 modules depending on platform),
-- prebuilt from the SAME official repository pkgs/q/qt.lua reads
-- (download.qt.io/online/qtsdkrepository). See that recipe's header for the
-- sourcing/verification methodology (Updates.xml cross-check, SHA-1
-- verification against Qt's own sidecars) and the mirror list -- both are
-- identical here and not repeated in full below.
--
-- WHY A SEPARATE PACKAGE, A SEPARATE INSTALL PREFIX. This is the "Additional
-- Libraries" node of https://www.qt.io/download-qt-installer, laid out from
-- its OWN prefix (its archives are not extracted into qt's install_dir) --
-- xim payloads are privately owned, and writing into a dependency's install
-- directory is a second owner of state that package never agreed to. A
-- consumer that needs both (mcpp's rules-qt is the shape) adds BOTH
-- prefixes to its search path, exactly as the online installer's own
-- combined install would have qtbase's and the add-ons' directories be one
-- tree, except split at the package boundary instead of at the filesystem.
--
-- `deps = { "xim:qt@6.11.1.1" }` on every platform: every add-on module links
-- against qtbase/qtdeclarative, so installing qt-addons without qt installed
-- resolves to a set of libraries and QML plugins with nothing to run them.
--
-- LICENCE. The base (pkgs/q/qt.lua) is LGPL-3.0. THESE MODULES ARE NOT ALL
-- THE SAME LICENCE -- quoting Qt's own Updates.xml wording for this node
-- verbatim, because paraphrasing a licence gate is how a paraphrase becomes
-- the thing someone relied on:
--
--   "Most of the additional libraries are available under commercial
--    licenses from The Qt Company, or under GPL v3."
--
-- A consumer linking any of these into a product under anything other than
-- GPLv3 terms needs a commercial Qt licence for that module -- this recipe
-- installs the bits, it does not clear that question for you.
--
-- SIZES (compressed download / this module set only, all 33-34 modules):
--   windows-x86_64   ~178 MB   (1.76 GB unpacked)
--   windows-aarch64  ~160 MB
--   linux-x86_64     ~128 MB
--   linux-aarch64    ~133 MB
--   macosx           ~161 MB   (ONE universal x86_64+arm64 payload; 33
--                               modules -- no qtactiveqt, a Windows ActiveX
--                               bridge with no macOS equivalent)
--
-- MODULE-SET DIFFERENCES ACROSS PLATFORMS (both real, not an omission here):
--   qtactiveqt          windows only (ActiveX/COM bridge)
--   qtwaylandcompositor  linux only (Wayland compositor support; windows and
--                        macosx have no Wayland compositor to support)
package = {
    spec = "2",

    name = "qt-addons",
    description = "Qt 6 'Additional Libraries' add-on modules (Qt Charts, Qt Multimedia, Qt WebSockets, Qt 3D, ...), prebuilt from the official online-installer repository; own install prefix, requires xim:qt",

    maintainers = {"The Qt Company"},
    -- Most modules: GPL-3.0-only OR a commercial Qt licence (see header).
    -- A handful (e.g. qt5compat) are LGPL-3.0 -- Qt's own Updates.xml is the
    -- per-module source of truth; this field states the node's OWN dominant
    -- terms, not a per-module breakdown.
    licenses = {"GPL-3.0-only", "LicenseRef-Qt-Commercial"},
    homepage = "https://www.qt.io",
    docs = "https://doc.qt.io",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"gui", "framework", "c++"},
    keywords = {"qt", "qt6", "qt-addons", "qtcharts", "qtmultimedia", "qt3d", "gui", "c++"},

    xvm_enable = true,

    xpm = {
        windows = {
            deps = { "xim:7zip", "xim:qt@6.11.1.1" },
            ["latest"] = { ref = "6.11.1.1" },
            -- 6.11.1.1: the same archives under the key xim:qt 6.11.1.1 took,
            -- so the add-ons pair with the base that carries its runtime
            -- closure.
            ["6.11.1.1"] = {},
            ["6.11.1"] = {},
        },
        linux = {
            deps = { "xim:7zip", "xim:qt@6.11.1.1" },
            ["latest"] = { ref = "6.11.1.1" },
            -- 6.11.1.1: the same archives under the key xim:qt 6.11.1.1 took,
            -- so the add-ons pair with the base that carries its runtime
            -- closure.
            ["6.11.1.1"] = {},
            ["6.11.1"] = {},
        },
        macosx = {
            deps = { "xim:7zip", "xim:qt@6.11.1.1" },
            ["latest"] = { ref = "6.11.1.1" },
            -- 6.11.1.1: the same archives under the key xim:qt 6.11.1.1 took,
            -- so the add-ons pair with the base that carries its runtime
            -- closure.
            ["6.11.1.1"] = {},
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

local ADDONS = {
    ["windows-x86_64"] = {
        { module = "qt3d", name = "qt3d-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.addons.qt3d.win64_msvc2022_64/6.11.1-0-202605090529qt3d-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          sha256 = "7acca52c31a45596e40e4d932a710db114bd54be32120ba61fd59efa1a6d23cc" },
        { module = "qt5compat", name = "qt5compat-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.addons.qt5compat.win64_msvc2022_64/6.11.1-0-202605090529qt5compat-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          sha256 = "64a7726d4dcdfc688fa37b6795a9d47a2b75e9210c95ec69afc241c7aad87383" },
        { module = "qtactiveqt", name = "qtactiveqt-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.addons.qtactiveqt.win64_msvc2022_64/6.11.1-0-202605090529qtactiveqt-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          sha256 = "c1b696cf4510cc0168c8186af6768193730f71a6ab43149d54eab2224ef1b8c1" },
        { module = "qtcanvaspainter", name = "qtcanvaspainter-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.addons.qtcanvaspainter.win64_msvc2022_64/6.11.1-0-202605090529qtcanvaspainter-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          sha256 = "cab43645201365a5809d4524199ba499527ba2ee292beb0953d6ca44d65266e4" },
        { module = "qtcharts", name = "qtcharts-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.addons.qtcharts.win64_msvc2022_64/6.11.1-0-202605090529qtcharts-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          sha256 = "fc1c6a0ab681f0657be393f4e43182d461a3498bbbc32ffab4128f9c99a87b01" },
        { module = "qtconnectivity", name = "qtconnectivity-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.addons.qtconnectivity.win64_msvc2022_64/6.11.1-0-202605090529qtconnectivity-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          sha256 = "07da802742640457f40078d541c026dcb2c49373ad072c209ba37fa9dc9172aa" },
        { module = "qtdatavis3d", name = "qtdatavis3d-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.addons.qtdatavis3d.win64_msvc2022_64/6.11.1-0-202605090529qtdatavis3d-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          sha256 = "f6bbb286ec4af99ac0da4c12952c6d7783dec5165c6d3cc66f4274bbdf23f39f" },
        { module = "qtgraphs", name = "qtgraphs-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.addons.qtgraphs.win64_msvc2022_64/6.11.1-0-202605090529qtgraphs-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          sha256 = "6b6d4a14117beea0e9a062edb78924c4833dfaa8d074bea383a93f3bfa8fc34d" },
        { module = "qtgrpc", name = "qtgrpc-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.addons.qtgrpc.win64_msvc2022_64/6.11.1-0-202605090529qtgrpc-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          sha256 = "c4e4cd8d542041467740453162212450c163b18cab8c759e9d9bb46a67be3f37" },
        { module = "qthttpserver", name = "qthttpserver-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.addons.qthttpserver.win64_msvc2022_64/6.11.1-0-202605090529qthttpserver-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          sha256 = "b6734064c697b4227e11a07db3a007ccc0a61d68c463b7dac479bf2339ac3004" },
        { module = "qtimageformats", name = "qtimageformats-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.addons.qtimageformats.win64_msvc2022_64/6.11.1-0-202605090529qtimageformats-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          sha256 = "8ba70600a3343fa0f1101fd304be32a58c3fe85fc6c6b316115e9d03a1be560a" },
        { module = "qtlanguageserver", name = "qtlanguageserver-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.addons.qtlanguageserver.win64_msvc2022_64/6.11.1-0-202605090529qtlanguageserver-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          sha256 = "0f9cffaee20d78c1e54efdafbd688624fcf4d089795b1a86ce78ed0b8548cf50" },
        { module = "qtlocation", name = "qtlocation-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.addons.qtlocation.win64_msvc2022_64/6.11.1-0-202605090529qtlocation-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          sha256 = "34db1dc3a67d5e5c986be5299c840d54f826320217781519a67fba158b548779" },
        { module = "qtlottie", name = "qtlottie-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.addons.qtlottie.win64_msvc2022_64/6.11.1-0-202605090529qtlottie-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          sha256 = "1083d2e32f52bdad43cc1badba5eaaf1e87b9a027051ea9880a3d2a90a05411d" },
        { module = "qtmultimedia", name = "qtmultimedia-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.addons.qtmultimedia.win64_msvc2022_64/6.11.1-0-202605090529qtmultimedia-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          sha256 = "e7255e7ed621c6e4fc5af9f5a1614b45260a960f03bcb4b1f37f8e910f6c8fd9" },
        { module = "qtnetworkauth", name = "qtnetworkauth-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.addons.qtnetworkauth.win64_msvc2022_64/6.11.1-0-202605090529qtnetworkauth-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          sha256 = "0e878a00815cfc76f8f3c514bb0a22c271bf89e5a7c6c6adb06060a5d9457835" },
        { module = "qtopenapi", name = "qtopenapi-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.addons.qtopenapi.win64_msvc2022_64/6.11.1-0-202605090529qtopenapi-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          sha256 = "8b7ddc98e1fdec4347a8ca96325a97b8c375e25c5b36a7eb71d978a862a41b0a" },
        { module = "qtpositioning", name = "qtpositioning-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.addons.qtpositioning.win64_msvc2022_64/6.11.1-0-202605090529qtpositioning-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          sha256 = "25fc3cf85eba7eb214f9399150e21da99fb8b9aa2032030ec7f921f84161ae2b" },
        { module = "qtquick3d", name = "qtquick3d-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.addons.qtquick3d.win64_msvc2022_64/6.11.1-0-202605090529qtquick3d-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          sha256 = "6ff053df3589cd7c444f2f85881138fc2e4254810293e587bd428723594a068c" },
        { module = "qtquick3dphysics", name = "qtquick3dphysics-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.addons.qtquick3dphysics.win64_msvc2022_64/6.11.1-0-202605090529qtquick3dphysics-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          sha256 = "12ac0ae5b30d6933dc5b0472203ac8e193d0586641a839ea73e2ccab409e8608" },
        { module = "qtquickeffectmaker", name = "qtquickeffectmaker-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.addons.qtquickeffectmaker.win64_msvc2022_64/6.11.1-0-202605090529qtquickeffectmaker-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          sha256 = "f5a279b5bf2d5bec8365cc446c93416664a99d73fb07340fe9f1179f6a433f4b" },
        { module = "qtquicktimeline", name = "qtquicktimeline-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.addons.qtquicktimeline.win64_msvc2022_64/6.11.1-0-202605090529qtquicktimeline-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          sha256 = "140ae2b0b7c6815010b3909415f7f8604702817a0d090e2afcfb748809244ead" },
        { module = "qtremoteobjects", name = "qtremoteobjects-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.addons.qtremoteobjects.win64_msvc2022_64/6.11.1-0-202605090529qtremoteobjects-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          sha256 = "a3786101e8e3d1cb36b8aace2eba787cd690b2724b25c38d9cd7b6591ffe46a2" },
        { module = "qtscxml", name = "qtscxml-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.addons.qtscxml.win64_msvc2022_64/6.11.1-0-202605090529qtscxml-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          sha256 = "2c30d5f4b5cf674fa5ee3f06b839580be5940f169ab585c13cc47b4b3cf51865" },
        { module = "qtsensors", name = "qtsensors-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.addons.qtsensors.win64_msvc2022_64/6.11.1-0-202605090529qtsensors-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          sha256 = "404d22bb2c78736f66d03128618cae53e5f6634848059e74bed223d8bd19bffd" },
        { module = "qtserialbus", name = "qtserialbus-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.addons.qtserialbus.win64_msvc2022_64/6.11.1-0-202605090529qtserialbus-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          sha256 = "c19ec121cac98a1f6ed29e6c7b7f30f7f8cec09575038663e368865b9fde730d" },
        { module = "qtserialport", name = "qtserialport-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.addons.qtserialport.win64_msvc2022_64/6.11.1-0-202605090529qtserialport-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          sha256 = "8c9f3d91917ea5ecf8e6175fa02dd20578e82ea19e11f157fe9ca66e335fee51" },
        { module = "qtshadertools", name = "qtshadertools-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.addons.qtshadertools.win64_msvc2022_64/6.11.1-0-202605090529qtshadertools-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          sha256 = "e95dfb3d961bb27c7315b684f74213245b63965add30936ce6f51e5b1be4e124" },
        { module = "qtspeech", name = "qtspeech-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.addons.qtspeech.win64_msvc2022_64/6.11.1-0-202605090529qtspeech-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          sha256 = "db39d0f413389d03f1043427cd6ae35d808a7a85ee482260c8a1885f4e4ee79f" },
        { module = "qttasktree", name = "qttasktree-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.addons.qttasktree.win64_msvc2022_64/6.11.1-0-202605090529qttasktree-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          sha256 = "b959fc6257f6edd87817f0ca97b87e053ad8bd7b6ccf4606a84848ccfb18e5ca" },
        { module = "qtvirtualkeyboard", name = "qtvirtualkeyboard-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.addons.qtvirtualkeyboard.win64_msvc2022_64/6.11.1-0-202605090529qtvirtualkeyboard-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          sha256 = "2bb723942eed3268f46fa450e577d03b6770e213bd28542cc8a155a5352c7087" },
        { module = "qtwebchannel", name = "qtwebchannel-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.addons.qtwebchannel.win64_msvc2022_64/6.11.1-0-202605090529qtwebchannel-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          sha256 = "9921b671c6b7c4e66dd34d1d0b6aafdd5ce1abf10d1b264fe19c52bce028f54e" },
        { module = "qtwebsockets", name = "qtwebsockets-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.addons.qtwebsockets.win64_msvc2022_64/6.11.1-0-202605090529qtwebsockets-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          sha256 = "0cd0f67275e56473ba81ee75c2d7b1ece97eb580b124df0435522ef81af2cd7f" },
        { module = "qtwebview", name = "qtwebview-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          path = "windows_x86/desktop/qt6_6111/qt6_6111_msvc2022_64/qt.qt6.6111.addons.qtwebview.win64_msvc2022_64/6.11.1-0-202605090529qtwebview-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-X86_64.7z",
          sha256 = "04f1d3ed2555ca1f5955c50bac326779a7dabfe590a0fdd2e17ff9708b056d66" },
    },
    ["windows-aarch64"] = {
        { module = "qt3d", name = "qt3d-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          path = "windows_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qt3d.win64_msvc2022_arm64/6.11.1-0-202605090529qt3d-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          sha256 = "8d8e82e59065eeebb805c916db15828d592aaf06faa7f0e987129b2bac9549ab" },
        { module = "qt5compat", name = "qt5compat-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          path = "windows_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qt5compat.win64_msvc2022_arm64/6.11.1-0-202605090529qt5compat-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          sha256 = "1ac12ff1a5685715207adc643f00ec70c456c0cb450715d7cdd11d655496249f" },
        { module = "qtactiveqt", name = "qtactiveqt-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          path = "windows_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtactiveqt.win64_msvc2022_arm64/6.11.1-0-202605090529qtactiveqt-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          sha256 = "4bde0f06ca5e64283f7238d5128c88408b3c7dc898d6763514b1d874bd2124c6" },
        { module = "qtcanvaspainter", name = "qtcanvaspainter-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          path = "windows_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtcanvaspainter.win64_msvc2022_arm64/6.11.1-0-202605090529qtcanvaspainter-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          sha256 = "a5c8b0a62ba21427ebf50360a43329edc2de911c738ddccd8ab0a1dd24c0652e" },
        { module = "qtcharts", name = "qtcharts-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          path = "windows_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtcharts.win64_msvc2022_arm64/6.11.1-0-202605090529qtcharts-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          sha256 = "4daa767407f3f466171c18661aae8a8ff6f16ef9e6b54ca85f86119f395daca4" },
        { module = "qtconnectivity", name = "qtconnectivity-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          path = "windows_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtconnectivity.win64_msvc2022_arm64/6.11.1-0-202605090529qtconnectivity-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          sha256 = "8ef39abb90b576f487b921e3ca08225158e356f9c8c3e595381bfd48835cd3bf" },
        { module = "qtdatavis3d", name = "qtdatavis3d-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          path = "windows_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtdatavis3d.win64_msvc2022_arm64/6.11.1-0-202605090529qtdatavis3d-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          sha256 = "c9c54fb30c807f8c46abed730082c40cb9eeb84a9fc398f1d4552b5ffe47e1dc" },
        { module = "qtgraphs", name = "qtgraphs-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          path = "windows_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtgraphs.win64_msvc2022_arm64/6.11.1-0-202605090529qtgraphs-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          sha256 = "e52a660f5f66d31bb94cf99a8f31964f8bd27305ef8b4d3c3b75731700fd0d74" },
        { module = "qtgrpc", name = "qtgrpc-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          path = "windows_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtgrpc.win64_msvc2022_arm64/6.11.1-0-202605090529qtgrpc-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          sha256 = "49aa8daa6391106cdcc8279031643009563e1ed30c9c1eb9de996657c798dbe4" },
        { module = "qthttpserver", name = "qthttpserver-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          path = "windows_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qthttpserver.win64_msvc2022_arm64/6.11.1-0-202605090529qthttpserver-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          sha256 = "60116e1ec2c3443e790acabb0b5bada6c20d53b377eb8073f78de837bb17f7e0" },
        { module = "qtimageformats", name = "qtimageformats-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          path = "windows_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtimageformats.win64_msvc2022_arm64/6.11.1-0-202605090529qtimageformats-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          sha256 = "bbbba8333f8f7f428609fd7cbedf6fedb30084da87e45d2f15003c7ca496a5f8" },
        { module = "qtlanguageserver", name = "qtlanguageserver-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          path = "windows_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtlanguageserver.win64_msvc2022_arm64/6.11.1-0-202605090529qtlanguageserver-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          sha256 = "8197ebd9cabf7db5a8b3942730454788c7ef763cc5050a9c46bae78eeba85340" },
        { module = "qtlocation", name = "qtlocation-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          path = "windows_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtlocation.win64_msvc2022_arm64/6.11.1-0-202605090529qtlocation-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          sha256 = "9e6f4807ae323404b8ca3b8b62061d9a469bff65868e63533cdbe06732c3a5c5" },
        { module = "qtlottie", name = "qtlottie-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          path = "windows_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtlottie.win64_msvc2022_arm64/6.11.1-0-202605090529qtlottie-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          sha256 = "8a1295f76f0ae7a28425df37a58314493950b8741504918abe26987bb3f97699" },
        { module = "qtmultimedia", name = "qtmultimedia-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          path = "windows_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtmultimedia.win64_msvc2022_arm64/6.11.1-0-202605090529qtmultimedia-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          sha256 = "bae2cb6fed9f4e1ef8a238e20d493179ddd7f1e2e2e326bc798e180a441a7a25" },
        { module = "qtnetworkauth", name = "qtnetworkauth-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          path = "windows_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtnetworkauth.win64_msvc2022_arm64/6.11.1-0-202605090529qtnetworkauth-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          sha256 = "1b206ba5fa129f228ed0ebcaa5ba588aa8107f2c98a96ebd3683c2fcd6c61208" },
        { module = "qtopenapi", name = "qtopenapi-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          path = "windows_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtopenapi.win64_msvc2022_arm64/6.11.1-0-202605090529qtopenapi-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          sha256 = "a49fbd9dba64816dbe8165ceaa6684ad1a45462f492ddd06518832bfe0ddc2c4" },
        { module = "qtpositioning", name = "qtpositioning-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          path = "windows_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtpositioning.win64_msvc2022_arm64/6.11.1-0-202605090529qtpositioning-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          sha256 = "e67d78b4ce0e8815d13490e7d792f27d9683c992dcc92f7f7695b1e1711dc891" },
        { module = "qtquick3d", name = "qtquick3d-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          path = "windows_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtquick3d.win64_msvc2022_arm64/6.11.1-0-202605090529qtquick3d-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          sha256 = "9fa806dcb0f5e646e929b6085c2030d1abbcc9f12297308f4d5306ad883fd3fb" },
        { module = "qtquick3dphysics", name = "qtquick3dphysics-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          path = "windows_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtquick3dphysics.win64_msvc2022_arm64/6.11.1-0-202605090529qtquick3dphysics-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          sha256 = "ff1fcdf722864c0a236f79bb819567f16abdbf0773317338691bb08e3597dc5a" },
        { module = "qtquickeffectmaker", name = "qtquickeffectmaker-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          path = "windows_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtquickeffectmaker.win64_msvc2022_arm64/6.11.1-0-202605090529qtquickeffectmaker-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          sha256 = "e5741216bd7c69a54566724131e300c0f310e753ef730adc6ba4fae4b8e7570c" },
        { module = "qtquicktimeline", name = "qtquicktimeline-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          path = "windows_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtquicktimeline.win64_msvc2022_arm64/6.11.1-0-202605090529qtquicktimeline-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          sha256 = "bf630f0eb2ee33bdc1c563e607301c080d2527bcae476d4ee5295b3972b8224d" },
        { module = "qtremoteobjects", name = "qtremoteobjects-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          path = "windows_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtremoteobjects.win64_msvc2022_arm64/6.11.1-0-202605090529qtremoteobjects-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          sha256 = "32d82000fbe6ee1392dbdc26349f46695aeda2ebc6592c7261e42408df170179" },
        { module = "qtscxml", name = "qtscxml-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          path = "windows_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtscxml.win64_msvc2022_arm64/6.11.1-0-202605090529qtscxml-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          sha256 = "d20bdee68d3b23c3a3fc4d9adcac9c52814f90e4dacf6f88046e8a4013af75c3" },
        { module = "qtsensors", name = "qtsensors-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          path = "windows_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtsensors.win64_msvc2022_arm64/6.11.1-0-202605090529qtsensors-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          sha256 = "fb5f1e5930f88f12afb19cb0631a7c4a5f6dd8f6097e84ab0bd25cd1ae4b545b" },
        { module = "qtserialbus", name = "qtserialbus-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          path = "windows_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtserialbus.win64_msvc2022_arm64/6.11.1-0-202605090529qtserialbus-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          sha256 = "72fdef1de02cc47e84441601eeb1a8886906567b5700bc811bcf156f802ce3fc" },
        { module = "qtserialport", name = "qtserialport-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          path = "windows_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtserialport.win64_msvc2022_arm64/6.11.1-0-202605090529qtserialport-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          sha256 = "684b1f2bf73e693471c693dfdc41886cc3e81af6c9fe8a831b17051f378bd3cd" },
        { module = "qtshadertools", name = "qtshadertools-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          path = "windows_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtshadertools.win64_msvc2022_arm64/6.11.1-0-202605090529qtshadertools-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          sha256 = "3dd9d0769456c49656614af7b3e6958b86f350e02b04043c5002f07f3e8643d6" },
        { module = "qtspeech", name = "qtspeech-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          path = "windows_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtspeech.win64_msvc2022_arm64/6.11.1-0-202605090529qtspeech-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          sha256 = "9d796e4a6e1395b9cf5cfd3a13fab6055e3763302f0594ef647a3953d1dfe0fa" },
        { module = "qttasktree", name = "qttasktree-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          path = "windows_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qttasktree.win64_msvc2022_arm64/6.11.1-0-202605090529qttasktree-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          sha256 = "217538f0a6b4069e269faa16db018094f79f7c1ec50313f841eec730f057edfc" },
        { module = "qtvirtualkeyboard", name = "qtvirtualkeyboard-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          path = "windows_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtvirtualkeyboard.win64_msvc2022_arm64/6.11.1-0-202605090529qtvirtualkeyboard-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          sha256 = "219c45deab7a690d7707291dae35428952f24fc10e4f16ffa559bde171e1d9e7" },
        { module = "qtwebchannel", name = "qtwebchannel-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          path = "windows_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtwebchannel.win64_msvc2022_arm64/6.11.1-0-202605090529qtwebchannel-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          sha256 = "1657bebde722333111e11f328a905636f724c8d75fd229da2fdce58e06fcad5b" },
        { module = "qtwebsockets", name = "qtwebsockets-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          path = "windows_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtwebsockets.win64_msvc2022_arm64/6.11.1-0-202605090529qtwebsockets-Windows-Windows_11_23H2-MSVC2022-Windows-Windows_11_23H2-AARCH64.7z",
          sha256 = "da977ad4b149aabfc3e98709edc97a5ff17910dcd79d14b9b582aca02a1a5c9d" },
        { module = "qtwebview", name = "qtwebview-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-ARM64.7z",
          path = "windows_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtwebview.win64_msvc2022_arm64/6.11.1-0-202605090529qtwebview-Windows-Windows_11_24H2-MSVC2022-Windows-Windows_11_24H2-ARM64.7z",
          sha256 = "abb21847cba2b1833f17c0d173d8b7d9959dd48e081ad7bdea436f90102535fc" },
    },
    ["linux-x86_64"] = {
        { module = "qt3d", name = "qt3d-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qt3d.linux_gcc_64/6.11.1-0-202605090529qt3d-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          sha256 = "a4cc6173c1845990bd36a08a5b356de4660e4370d6a945ece039484a92729582" },
        { module = "qt5compat", name = "qt5compat-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qt5compat.linux_gcc_64/6.11.1-0-202605090529qt5compat-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          sha256 = "0d6b6f8ef08c489f5bd9fe6bfcd2eedbceb38f631b9472755a11b52ea26e5218" },
        { module = "qtcanvaspainter", name = "qtcanvaspainter-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtcanvaspainter.linux_gcc_64/6.11.1-0-202605090529qtcanvaspainter-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          sha256 = "240f901beb15c358e2a237f559a7f6179359ddeae0038da0175e24f4d11253fd" },
        { module = "qtcharts", name = "qtcharts-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtcharts.linux_gcc_64/6.11.1-0-202605090529qtcharts-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          sha256 = "0f353966c33249543501a0de581cba8d69249adb043e120c72ae4f90fac8ffd4" },
        { module = "qtconnectivity", name = "qtconnectivity-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtconnectivity.linux_gcc_64/6.11.1-0-202605090529qtconnectivity-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          sha256 = "6236eed5203ba0a94f1ab360fe9080a8ee146d77b5df7975e6b23778fc6512dd" },
        { module = "qtdatavis3d", name = "qtdatavis3d-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtdatavis3d.linux_gcc_64/6.11.1-0-202605090529qtdatavis3d-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          sha256 = "6008736fdb8911a866fb38f40a195d40ce5ef3d8a39aa9288117a3e574aacf31" },
        { module = "qtgraphs", name = "qtgraphs-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtgraphs.linux_gcc_64/6.11.1-0-202605090529qtgraphs-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          sha256 = "3e2621c3d8b270713a2e006ff58d03fc7adcba7ec1494e75b9099e56d665b159" },
        { module = "qtgrpc", name = "qtgrpc-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtgrpc.linux_gcc_64/6.11.1-0-202605090529qtgrpc-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          sha256 = "f6d061b23db9f53ac9a122c8b40008f1eff1f9bcd010690eeebf9fa1936525e8" },
        { module = "qthttpserver", name = "qthttpserver-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qthttpserver.linux_gcc_64/6.11.1-0-202605090529qthttpserver-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          sha256 = "6c2915118a419bd60509409853a755903a90a639e2cf5b0b6a1e018982837af2" },
        { module = "qtimageformats", name = "qtimageformats-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtimageformats.linux_gcc_64/6.11.1-0-202605090529qtimageformats-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          sha256 = "36d582d5f2a01823686a6b1743f4d759f57bdaf4a93bb1fd446a7eadb6c49644" },
        { module = "qtlanguageserver", name = "qtlanguageserver-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtlanguageserver.linux_gcc_64/6.11.1-0-202605090529qtlanguageserver-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          sha256 = "16434d00a81e69f50a06bdd3bd03b748a3f667f81a102340c99718aac8aeb870" },
        { module = "qtlocation", name = "qtlocation-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtlocation.linux_gcc_64/6.11.1-0-202605090529qtlocation-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          sha256 = "14920bbe4af1f12bd975c6d0f2a3827fe7863ccac05e4286b869ccce6fdd09e1" },
        { module = "qtlottie", name = "qtlottie-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtlottie.linux_gcc_64/6.11.1-0-202605090529qtlottie-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          sha256 = "b9e3525fe9aeac478c5b67a31cef9a42a60f3651423f74740085471234cc9d6c" },
        { module = "qtmultimedia", name = "qtmultimedia-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtmultimedia.linux_gcc_64/6.11.1-0-202605090529qtmultimedia-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          sha256 = "111f0624298a918e33787ba2f7b4507121003484ef755ace0e9e1964161ac1f6" },
        { module = "qtnetworkauth", name = "qtnetworkauth-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtnetworkauth.linux_gcc_64/6.11.1-0-202605090529qtnetworkauth-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          sha256 = "062ba55ee04e2060df0dd4054698d96389a745335fcdb63fe09c0fdd31b9f084" },
        { module = "qtopenapi", name = "qtopenapi-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtopenapi.linux_gcc_64/6.11.1-0-202605090529qtopenapi-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          sha256 = "99f1a660284c2c1c8057164a898ab74863436e597a8be518a6944664c52ba4df" },
        { module = "qtpositioning", name = "qtpositioning-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtpositioning.linux_gcc_64/6.11.1-0-202605090529qtpositioning-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          sha256 = "9637b35a2d7cd4fc07b71b908c28e0337c27c005d8a1315247a502ff2800006f" },
        { module = "qtquick3d", name = "qtquick3d-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtquick3d.linux_gcc_64/6.11.1-0-202605090529qtquick3d-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          sha256 = "f60489120edaa8d58ecb39c65cd2f9465b13c4c8978c82e46b2440705a013129" },
        { module = "qtquick3dphysics", name = "qtquick3dphysics-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtquick3dphysics.linux_gcc_64/6.11.1-0-202605090529qtquick3dphysics-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          sha256 = "c2ec5e2ca0ffabc1bfd0bae51e213e63ce4c747294139cd8eaaa5972c9074a6d" },
        { module = "qtquickeffectmaker", name = "qtquickeffectmaker-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtquickeffectmaker.linux_gcc_64/6.11.1-0-202605090529qtquickeffectmaker-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          sha256 = "c84363392cfd4814777143c9bf73c599004480452f0d50ece221fc235831a6ca" },
        { module = "qtquicktimeline", name = "qtquicktimeline-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtquicktimeline.linux_gcc_64/6.11.1-0-202605090529qtquicktimeline-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          sha256 = "5461674242b4978348c27078b0e7323889348105e6736731792bd55bc3f71114" },
        { module = "qtremoteobjects", name = "qtremoteobjects-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtremoteobjects.linux_gcc_64/6.11.1-0-202605090529qtremoteobjects-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          sha256 = "9347d636b2cab9bd065525cddcc75ba55c57eca8b8b1dcfe9c8e56fdcb2bd634" },
        { module = "qtscxml", name = "qtscxml-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtscxml.linux_gcc_64/6.11.1-0-202605090529qtscxml-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          sha256 = "40aa2b4950bd5e1ddfeb6b370067989a256cff405e6408a0aa139f511ccefc62" },
        { module = "qtsensors", name = "qtsensors-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtsensors.linux_gcc_64/6.11.1-0-202605090529qtsensors-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          sha256 = "91f803b1d98078074b1e827ce9033461ceaef8de8d4b3ce797d940eca484d781" },
        { module = "qtserialbus", name = "qtserialbus-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtserialbus.linux_gcc_64/6.11.1-0-202605090529qtserialbus-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          sha256 = "530665cabdd6c4be3077367522647b9e7d370687fb401f266b16fa606cabc486" },
        { module = "qtserialport", name = "qtserialport-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtserialport.linux_gcc_64/6.11.1-0-202605090529qtserialport-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          sha256 = "3d815200f9d1b7127e52385d5f7fd5c4b1de3a356e8caf457c7bf1a079f49ac6" },
        { module = "qtshadertools", name = "qtshadertools-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtshadertools.linux_gcc_64/6.11.1-0-202605090529qtshadertools-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          sha256 = "34ecf446a24fcf5779374c5c02e102153558a78df45eee2ff9330f733853e4b6" },
        { module = "qtspeech", name = "qtspeech-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtspeech.linux_gcc_64/6.11.1-0-202605090529qtspeech-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          sha256 = "eae06eb818b1f61d35070843905d47127c19f55115d5e4f8304f28cafa1f3b4c" },
        { module = "qttasktree", name = "qttasktree-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qttasktree.linux_gcc_64/6.11.1-0-202605090529qttasktree-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          sha256 = "97b0195f3cda94ecdd2f3d6b21ac93d8615cc21e68acab2fb01f503fa9e397ee" },
        { module = "qtvirtualkeyboard", name = "qtvirtualkeyboard-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtvirtualkeyboard.linux_gcc_64/6.11.1-0-202605090529qtvirtualkeyboard-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          sha256 = "e73394792618dfa8fbfc1c6cbb20fd477b0835f0c96a00c56bbd971407e57723" },
        { module = "qtwaylandcompositor", name = "qtwayland-compositor-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtwaylandcompositor.linux_gcc_64/6.11.1-0-202605090529qtwayland-compositor-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          sha256 = "ddce46587ce9f50ae5bdcf0a00a458f72d891a42d88ac851b73df589dbb46027" },
        { module = "qtwebchannel", name = "qtwebchannel-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtwebchannel.linux_gcc_64/6.11.1-0-202605090529qtwebchannel-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          sha256 = "2f3ebba6e572a7ed1eab71eee25e69ff42fce47ca4a685efa24a14d1e1fe55b9" },
        { module = "qtwebsockets", name = "qtwebsockets-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtwebsockets.linux_gcc_64/6.11.1-0-202605090529qtwebsockets-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          sha256 = "1bfa33207476c578553d5aaa97bd01afb4e54d6dc612d214d6485e2178d35a7d" },
        { module = "qtwebview", name = "qtwebview-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          path = "linux_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtwebview.linux_gcc_64/6.11.1-0-202605090529qtwebview-Linux-RHEL_9_6-GCC-Linux-RHEL_9_6-X86_64.7z",
          sha256 = "251758a575fd5f2c71b011e843ad115384f2f9af0eb61c478b2de6af45106520" },
    },
    ["linux-aarch64"] = {
        { module = "qt3d", name = "qt3d-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qt3d.linux_gcc_arm64/6.11.1-0-202605090529qt3d-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          sha256 = "861c2a23090995f36cf68f78dbbb64dd7a1d4ea7b067bdb8eb05d0ab08c9e0df" },
        { module = "qt5compat", name = "qt5compat-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qt5compat.linux_gcc_arm64/6.11.1-0-202605090529qt5compat-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          sha256 = "e6add33b1167b740826217833e2125fca964153c06333d10e756aa0083bdf30b" },
        { module = "qtcanvaspainter", name = "qtcanvaspainter-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtcanvaspainter.linux_gcc_arm64/6.11.1-0-202605090529qtcanvaspainter-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          sha256 = "3eeaa8034003a36b85dac7413e9ad544273f67901c63675acfd9c985bfb5eebe" },
        { module = "qtcharts", name = "qtcharts-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtcharts.linux_gcc_arm64/6.11.1-0-202605090529qtcharts-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          sha256 = "78aa227e83cf746a57a40bb08a33fe11acaa0075b7a5d68012231e6a5eb1fc03" },
        { module = "qtconnectivity", name = "qtconnectivity-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtconnectivity.linux_gcc_arm64/6.11.1-0-202605090529qtconnectivity-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          sha256 = "82bff6fd1994aa4957bc0720bde7d2c267d41f0ead9a789fe699e11724ad7783" },
        { module = "qtdatavis3d", name = "qtdatavis3d-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtdatavis3d.linux_gcc_arm64/6.11.1-0-202605090529qtdatavis3d-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          sha256 = "71149d30ca19de9dfcc78d8f1f02212a11430db39fb80b1b21a76bc6c4bffeeb" },
        { module = "qtgraphs", name = "qtgraphs-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtgraphs.linux_gcc_arm64/6.11.1-0-202605090529qtgraphs-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          sha256 = "60b1a676c7c074bd2f41291487228e1d6595308842e1cbd3a4c49ed7dbcb3291" },
        { module = "qtgrpc", name = "qtgrpc-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtgrpc.linux_gcc_arm64/6.11.1-0-202605090529qtgrpc-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          sha256 = "57c4d3970504584ab8ef7ccdcd36766b8c733c66f5090aee226060d4a99d26a5" },
        { module = "qthttpserver", name = "qthttpserver-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qthttpserver.linux_gcc_arm64/6.11.1-0-202605090529qthttpserver-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          sha256 = "15009d9cf9c039526d47a32d8634edb80c4a3c3b6e07abd465457ac8075e47a4" },
        { module = "qtimageformats", name = "qtimageformats-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtimageformats.linux_gcc_arm64/6.11.1-0-202605090529qtimageformats-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          sha256 = "60b4b31045a7df6e3dd7f0686207dfe461322c4d16a71d9b32a5fcfe702c36de" },
        { module = "qtlanguageserver", name = "qtlanguageserver-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtlanguageserver.linux_gcc_arm64/6.11.1-0-202605090529qtlanguageserver-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          sha256 = "7cb5f690c8da1aacfec649fe54fc45977054140ce9c6e65b33e3c49f27c033e5" },
        { module = "qtlocation", name = "qtlocation-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtlocation.linux_gcc_arm64/6.11.1-0-202605090529qtlocation-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          sha256 = "827c3d324cb986249e51dd7af93bb8e02f4f789849b50ccba181e8bd5ceddcee" },
        { module = "qtlottie", name = "qtlottie-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtlottie.linux_gcc_arm64/6.11.1-0-202605090529qtlottie-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          sha256 = "c0792ab8ee97626064129d4a3ce1654600bd5398dda599e55010dea6e1b9a014" },
        { module = "qtmultimedia", name = "qtmultimedia-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtmultimedia.linux_gcc_arm64/6.11.1-0-202605090529qtmultimedia-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          sha256 = "7ba2b1b514b2e481800e3226b3cbe554b42d75cf71fb2f45d3413b8fb5a45b11" },
        { module = "qtnetworkauth", name = "qtnetworkauth-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtnetworkauth.linux_gcc_arm64/6.11.1-0-202605090529qtnetworkauth-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          sha256 = "7fd5a217cf8db7f1ce5cd38dcc2a8f461de43451e982439c30dbab0826ae9983" },
        { module = "qtopenapi", name = "qtopenapi-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtopenapi.linux_gcc_arm64/6.11.1-0-202605090529qtopenapi-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          sha256 = "0c489b7cd95597558f6ffa561044b0bc21988c4642b70d8014ce8f4dda1cb123" },
        { module = "qtpositioning", name = "qtpositioning-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtpositioning.linux_gcc_arm64/6.11.1-0-202605090529qtpositioning-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          sha256 = "793bac58933917e9237b388f8333d9226923f01c0b14a2f88f8f648c08d687e5" },
        { module = "qtquick3d", name = "qtquick3d-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtquick3d.linux_gcc_arm64/6.11.1-0-202605090529qtquick3d-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          sha256 = "ba64d4e741233bfa46cbb9de8c15d4b66ca3f5a81e8082454ebd1e3b634a98a6" },
        { module = "qtquick3dphysics", name = "qtquick3dphysics-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtquick3dphysics.linux_gcc_arm64/6.11.1-0-202605090529qtquick3dphysics-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          sha256 = "a95b40e70c896128b3b61348be0c69f45eebcb981af69a37babb6ea045862a32" },
        { module = "qtquickeffectmaker", name = "qtquickeffectmaker-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtquickeffectmaker.linux_gcc_arm64/6.11.1-0-202605090529qtquickeffectmaker-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          sha256 = "9cccb051244f14a50b12015cefdd92f1f193f4c2512ea4c3e2ef62bd5f44b3a1" },
        { module = "qtquicktimeline", name = "qtquicktimeline-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtquicktimeline.linux_gcc_arm64/6.11.1-0-202605090529qtquicktimeline-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          sha256 = "54cad3d06fcba0554e85a8b4941cc1201a72d36b98fce626676541fcb2c6f91b" },
        { module = "qtremoteobjects", name = "qtremoteobjects-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtremoteobjects.linux_gcc_arm64/6.11.1-0-202605090529qtremoteobjects-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          sha256 = "95736f4b9c26d0bfe8f1cbf60808c29632ad0e9c2c7b52f5ae36c99505b128c2" },
        { module = "qtscxml", name = "qtscxml-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtscxml.linux_gcc_arm64/6.11.1-0-202605090529qtscxml-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          sha256 = "a6054983e59ca5ca570f1820b70ef1df4672614fe46c6e8d6f3cf2bbb1f8fa47" },
        { module = "qtsensors", name = "qtsensors-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtsensors.linux_gcc_arm64/6.11.1-0-202605090529qtsensors-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          sha256 = "a28518ab71dbbebe4b16f013ecd7232891c5e81f0a0221bb47c932b05c23c1da" },
        { module = "qtserialbus", name = "qtserialbus-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtserialbus.linux_gcc_arm64/6.11.1-0-202605090529qtserialbus-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          sha256 = "2243dea7b94b0d893dd90c31a18b96c8fee7e1332b9ba196a76175c45833cde9" },
        { module = "qtserialport", name = "qtserialport-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtserialport.linux_gcc_arm64/6.11.1-0-202605090529qtserialport-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          sha256 = "6fa1088afa1be02657e725202981b4b3ace8ffb74a03746b481edd805c9e3c69" },
        { module = "qtshadertools", name = "qtshadertools-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtshadertools.linux_gcc_arm64/6.11.1-0-202605090529qtshadertools-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          sha256 = "3178a0637068e6d3ca87a9046a0c8d4210fe5072fe71a5d5970d4661514e8b88" },
        { module = "qtspeech", name = "qtspeech-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtspeech.linux_gcc_arm64/6.11.1-0-202605090529qtspeech-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          sha256 = "45216ad76489719674357a8173efef596d67959d627ca7ec581078a77c9878ac" },
        { module = "qttasktree", name = "qttasktree-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qttasktree.linux_gcc_arm64/6.11.1-0-202605090529qttasktree-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          sha256 = "72a9467270151da5e11f5dee4a1ae70680f5ef9131ad22540ddd27e75c74ec4b" },
        { module = "qtvirtualkeyboard", name = "qtvirtualkeyboard-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtvirtualkeyboard.linux_gcc_arm64/6.11.1-0-202605090529qtvirtualkeyboard-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          sha256 = "a82119e1aeb9af11f49e14ef9bc55b9deb7adab3464d10f103f0633100cce863" },
        { module = "qtwaylandcompositor", name = "qtwayland-compositor-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtwaylandcompositor.linux_gcc_arm64/6.11.1-0-202605090529qtwayland-compositor-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          sha256 = "52fc963baf04cac2426a6720dc4c9f0a688a7dc32707319db583eb35df00490a" },
        { module = "qtwebchannel", name = "qtwebchannel-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtwebchannel.linux_gcc_arm64/6.11.1-0-202605090529qtwebchannel-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          sha256 = "4b51baff9b03383275e2434374f9340e26bbb7c19fbfa8c3bd16966ecd0a54e7" },
        { module = "qtwebsockets", name = "qtwebsockets-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtwebsockets.linux_gcc_arm64/6.11.1-0-202605090529qtwebsockets-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          sha256 = "2032343b4c7299a19580372a4dbd52b92d12f98dd6e7e4dd85762b9d099366c0" },
        { module = "qtwebview", name = "qtwebview-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          path = "linux_arm64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtwebview.linux_gcc_arm64/6.11.1-0-202605090529qtwebview-Linux-Ubuntu_24_04-GCC-Linux-Ubuntu_24_04-AARCH64.7z",
          sha256 = "b3fbf9ecafa5df42fb97937be89dfcc99ee4a5ca4eb9eaa900bb8729f3441d4d" },
    },
    ["macosx"] = {
        { module = "qt3d", name = "qt3d-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          path = "mac_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qt3d.clang_64/6.11.1-0-202605090526qt3d-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          sha256 = "db8f4b853fae4d31a14487b2e5720973435fe57003e03e3b0e72045fbc0ffb6a" },
        { module = "qt5compat", name = "qt5compat-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          path = "mac_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qt5compat.clang_64/6.11.1-0-202605090526qt5compat-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          sha256 = "8894236e08e1687c697281d09b87ad8acc9171ee546cc14e1d8273a7994ead98" },
        { module = "qtcanvaspainter", name = "qtcanvaspainter-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          path = "mac_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtcanvaspainter.clang_64/6.11.1-0-202605090526qtcanvaspainter-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          sha256 = "343a8ae81ac0e240f8030a2db0f3792b1f47753d0011d0d79fb21eb8772abff9" },
        { module = "qtcharts", name = "qtcharts-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          path = "mac_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtcharts.clang_64/6.11.1-0-202605090526qtcharts-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          sha256 = "100306c209da3168c6499ae73908917c3fa59b73a6d88e9d78283d162b35267e" },
        { module = "qtconnectivity", name = "qtconnectivity-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          path = "mac_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtconnectivity.clang_64/6.11.1-0-202605090526qtconnectivity-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          sha256 = "f0084884a1ee2dfca768c86ef760c123f8e83e01c2d37fc4146c97ea38146292" },
        { module = "qtdatavis3d", name = "qtdatavis3d-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          path = "mac_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtdatavis3d.clang_64/6.11.1-0-202605090526qtdatavis3d-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          sha256 = "9c0f9e11c5e25fed855efc547eea9ea44954e4b423a0d0bd58bb03e36369f30f" },
        { module = "qtgraphs", name = "qtgraphs-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          path = "mac_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtgraphs.clang_64/6.11.1-0-202605090526qtgraphs-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          sha256 = "253cedb4b0eb22b99a6404400749e9117c190861b6d184f8025b81eed86e0dc3" },
        { module = "qtgrpc", name = "qtgrpc-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          path = "mac_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtgrpc.clang_64/6.11.1-0-202605090526qtgrpc-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          sha256 = "dc07fd7322cfd9d7571fa2e19497f44aaf5ec1f341221388c0068947e20a2a18" },
        { module = "qthttpserver", name = "qthttpserver-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          path = "mac_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qthttpserver.clang_64/6.11.1-0-202605090526qthttpserver-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          sha256 = "c7eba6a2f346192d7efa60d9c6a69fc1a70f62bb2eb64e20a33785f2d1d7dcc2" },
        { module = "qtimageformats", name = "qtimageformats-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          path = "mac_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtimageformats.clang_64/6.11.1-0-202605090526qtimageformats-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          sha256 = "fa77e587f5708ccc18609f0948118d3cb5f914ebe1a4b38b09326463abf8eb7f" },
        { module = "qtlanguageserver", name = "qtlanguageserver-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          path = "mac_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtlanguageserver.clang_64/6.11.1-0-202605090526qtlanguageserver-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          sha256 = "b889021952c34bdd8720d2aaef4257df9932e5909eaf84b2684a6068eeb2a09e" },
        { module = "qtlocation", name = "qtlocation-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          path = "mac_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtlocation.clang_64/6.11.1-0-202605090526qtlocation-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          sha256 = "71bdf1f1edb09ec857ba2d06302ba379f69f6bbdc183d663a1b8f7db8763b63b" },
        { module = "qtlottie", name = "qtlottie-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          path = "mac_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtlottie.clang_64/6.11.1-0-202605090526qtlottie-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          sha256 = "dd12366d97329613ebb91fc0d38eaced750196c268304476c10465243e6262aa" },
        { module = "qtmultimedia", name = "qtmultimedia-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          path = "mac_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtmultimedia.clang_64/6.11.1-0-202605090526qtmultimedia-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          sha256 = "c2ac56caeac1e7071802191e075a793972812ca6ecbee7769d3445bf1a9a184a" },
        { module = "qtnetworkauth", name = "qtnetworkauth-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          path = "mac_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtnetworkauth.clang_64/6.11.1-0-202605090526qtnetworkauth-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          sha256 = "634c582d62dc6b491549155df18d08f56d8cb615b3a94a0379fba0f66ad4419a" },
        { module = "qtopenapi", name = "qtopenapi-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          path = "mac_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtopenapi.clang_64/6.11.1-0-202605090526qtopenapi-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          sha256 = "80cc5e544f118367e3def83042d200ae2e2e29c6b995ee8c8a4d927f862d1b14" },
        { module = "qtpositioning", name = "qtpositioning-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          path = "mac_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtpositioning.clang_64/6.11.1-0-202605090526qtpositioning-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          sha256 = "3c7221b1c0f93766f8ca3e018fe09e68d8e99bbee4fb1f002d865180295133ff" },
        { module = "qtquick3d", name = "qtquick3d-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          path = "mac_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtquick3d.clang_64/6.11.1-0-202605090526qtquick3d-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          sha256 = "cdd30e50489cc240a3deec881453e7ec03374ce62fee6c2044cb1af2ae1dd2c5" },
        { module = "qtquick3dphysics", name = "qtquick3dphysics-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          path = "mac_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtquick3dphysics.clang_64/6.11.1-0-202605090526qtquick3dphysics-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          sha256 = "a7e010eb1ae56d1a596232691b8bbbc4e4f8dc09b7a4b19abf1551a7bd5d18e1" },
        { module = "qtquickeffectmaker", name = "qtquickeffectmaker-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          path = "mac_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtquickeffectmaker.clang_64/6.11.1-0-202605090526qtquickeffectmaker-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          sha256 = "c1315a1a36a66d001351e9f0e50a4d9b0d1f44e07a8ced26cf62300aa1b0af19" },
        { module = "qtquicktimeline", name = "qtquicktimeline-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          path = "mac_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtquicktimeline.clang_64/6.11.1-0-202605090526qtquicktimeline-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          sha256 = "223809879e08c217d12b3f021375869df634b2048f3f9664488db8c32c8c2658" },
        { module = "qtremoteobjects", name = "qtremoteobjects-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          path = "mac_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtremoteobjects.clang_64/6.11.1-0-202605090526qtremoteobjects-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          sha256 = "1788154c4165118b1763ca46550862c1b5569217a4ec4d1636a6a8368add8449" },
        { module = "qtscxml", name = "qtscxml-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          path = "mac_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtscxml.clang_64/6.11.1-0-202605090526qtscxml-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          sha256 = "e0a8492322cb844b2418a029671e8bf6410767c4ca153dc2d49ae52242d96afc" },
        { module = "qtsensors", name = "qtsensors-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          path = "mac_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtsensors.clang_64/6.11.1-0-202605090526qtsensors-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          sha256 = "74e59fec1dba1303bef20aac8a2cedae5220fdc9e49fc1f7739584601ba22379" },
        { module = "qtserialbus", name = "qtserialbus-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          path = "mac_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtserialbus.clang_64/6.11.1-0-202605090526qtserialbus-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          sha256 = "715fdd513ee7b52d980476ca1e2a2017efe171646ad353229ddaf59fa237b28d" },
        { module = "qtserialport", name = "qtserialport-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          path = "mac_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtserialport.clang_64/6.11.1-0-202605090526qtserialport-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          sha256 = "eb80d3597c30ee83499cd4a0112d1d16444cf311539d6cae0ea210aa49821e50" },
        { module = "qtshadertools", name = "qtshadertools-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          path = "mac_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtshadertools.clang_64/6.11.1-0-202605090526qtshadertools-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          sha256 = "d51e9a9358b66c65f72f1827fc6934be8b73a4bfaad0db3a3f72405213078084" },
        { module = "qtspeech", name = "qtspeech-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          path = "mac_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtspeech.clang_64/6.11.1-0-202605090526qtspeech-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          sha256 = "3db8ee976858e3f56fde87702e0c98b4c10c92363c1cb9659024fd628089361b" },
        { module = "qttasktree", name = "qttasktree-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          path = "mac_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qttasktree.clang_64/6.11.1-0-202605090526qttasktree-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          sha256 = "995bf1363e0993c146725c9bfdf170a1f92f77cd4f115e8f6cfeed1cf5e3c9a7" },
        { module = "qtvirtualkeyboard", name = "qtvirtualkeyboard-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          path = "mac_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtvirtualkeyboard.clang_64/6.11.1-0-202605090526qtvirtualkeyboard-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          sha256 = "b98e0dc12839e85cfab8c1c541c39557083e637fb1b742a22edc4fe593a341ca" },
        { module = "qtwebchannel", name = "qtwebchannel-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          path = "mac_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtwebchannel.clang_64/6.11.1-0-202605090526qtwebchannel-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          sha256 = "a447fecea87d43a85387351b4f2eb79cfcad2d422ed52b4e49621c7bf701a294" },
        { module = "qtwebsockets", name = "qtwebsockets-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          path = "mac_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtwebsockets.clang_64/6.11.1-0-202605090526qtwebsockets-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          sha256 = "43e0a0bed24b5dbd7db8f8be8e39cb6d936b1068ce0d47af6ce040add004c930" },
        { module = "qtwebview", name = "qtwebview-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          path = "mac_x64/desktop/qt6_6111/qt6_6111/qt.qt6.6111.addons.qtwebview.clang_64/6.11.1-0-202605090526qtwebview-MacOS-MacOS_15-Clang-MacOS-MacOS_15-X86_64-ARM64.7z",
          sha256 = "b01942d6667793528a7fab70788c4adbd74a5032403ac1f5562bec237ac190ba" },
    },
}

local function marker_path()
    return path.join(pkginfo.install_dir(), ".qt-addons-archives.txt")
end

function install()
    local key = qtsdk.host_key()
    if not key then
        log.error("qt-addons: could not determine host platform/arch for this install")
        return false
    end
    local list = ADDONS[key]
    if not list then
        log.error("qt-addons: no archive list for host platform '" .. key .. "'")
        return false
    end

    local install_dir = pkginfo.install_dir()
    os.tryrm(install_dir)
    fs.mkdir_p(install_dir)

    if not qtsdk.fetch_and_extract(list, install_dir, marker_path(), "qt-addons") then
        return false
    end

    return installed()
end

-- Same shape as pkgs/q/qt.lua's installed(): the marker (module -> sha256,
-- appended per-archive during install()) is checked against THIS recipe's
-- CURRENT list, covering all 33-34 modules; a couple of sentinel files (one
-- per representative module, present on every platform this recipe lists)
-- back it up against a hand-edited install directory.
function installed()
    local key = qtsdk.host_key()
    if not key then return false end
    local list = ADDONS[key]
    if not list then return false end

    local marker = qtsdk.read_marker(marker_path())
    if not marker then return false end
    for _, e in ipairs(list) do
        if marker[e.module] ~= e.sha256 then return false end
    end

    local d = pkginfo.install_dir()
    local osname = os.host()

    -- qtcharts: present on every platform this recipe supports.
    if osname == "windows" then
        if not os.isfile(path.join(d, "lib", "Qt6Charts.lib")) then return false end
    elseif osname == "linux" then
        if not os.isfile(path.join(d, "lib", "libQt6Charts.so.6")) then return false end
    else
        if not os.isfile(path.join(d, "lib", "QtCharts.framework", "QtCharts")) then return false end
    end

    -- qt3d: also present on every platform this recipe supports, and built
    -- from an entirely different upstream module than qtcharts -- catches a
    -- 7z extraction that landed one module but not the other.
    if osname == "windows" then
        if not os.isfile(path.join(d, "lib", "Qt63DCore.lib")) then return false end
    elseif osname == "linux" then
        if not os.isfile(path.join(d, "lib", "libQt63DCore.so.6")) then return false end
    else
        if not os.isfile(path.join(d, "lib", "Qt3DCore.framework", "Qt3DCore")) then return false end
    end

    return true
end

function config()
    -- Same umbrella-root shape as pkgs/q/qt.lua and pkgs/7/7zip.lua: nothing
    -- here needs a PATH shim (a consumer finds these libraries/QML plugins
    -- via this package's install prefix, not PATH).
    xvm.add(package.name, { type = "group" })
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
