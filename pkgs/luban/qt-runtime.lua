package = {
    spec = "1",

    name = "qt-runtime",
    namespace = "luban",
    description = "The Qt the Luban Qt desktops share: Qt 6 (base, wayland, svg, declarative), mesa and their libraries -- no programs",

    homepage = "https://www.qt.io",
    repo = "https://code.qt.io/cgit/qt/qtbase.git",
    licenses = {"LGPL-3.0-only", "GPL-2.0-only", "MIT"},

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"luban", "runtime", "qt"},
    keywords = {"qt", "qt6", "runtime", "mesa", "luban"},

    -- What luban:lxqt and luban:kde share (xlings: 2026-10-18 Luban OS
    -- distribution design §13.5): Alpine 3.24's Qt 6.11 -- base (with its
    -- platform plugins), wayland, svg, declarative -- the mesa its GUI links
    -- (llvmpipe where there is no GPU) and every library they need, with the
    -- musl loader, in libexec/qt-runtime/{lib,plugins,qml}
    -- (tools/res/build.sh qt-runtime). No programs: a Qt desktop names this
    -- version exactly, and its programs find these libraries through the
    -- library path its recipe writes into them.
    --
    -- Form: a runtime (design §4.6) -- the largest part the Qt desktops
    -- have in common, built once; when Qt and the frameworks become atomic
    -- packages (an Arch snapshot import), the desktops that name it move,
    -- not their names.
    xpm = {
        linux = {
            ["latest"] = { ref = "6.11.1-r2" },
            ["6.11.1-r2"] = {
                -- 1: its loader searches only its tree (xlings design 2026-10-21 J12).
                revision = 1,
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "7e8b9924547fd23f02f8a91a9cf2d622c3c4d1d8a3700c1ab4b086c71bcf5e78",
                    aarch64 = "e54aecb32fff12365eda846a77975f95ffde7264eb8d3109510d726c8dda283a",
                },
            },
        },
    },
}

import("xim.pkgindex.luban_component")

function install()
    return luban_component.install({ "libexec/qt-runtime/lib/libQt6Core.so.6", "libexec/qt-runtime/plugins/platforms/libqwayland.so" })
end

function config()
    return luban_component.config({}, {})
end

function uninstall()
    return luban_component.uninstall({})
end
