package = {
    spec = "1",

    name = "xwayland",
    namespace = "luban",
    description = "Xwayland for the Luban desktops: X11 programs on Wayland, without GPU acceleration (no glamor, no GLX)",

    homepage = "https://gitlab.freedesktop.org/xorg/xserver",
    repo = "https://gitlab.freedesktop.org/xorg/xserver",
    licenses = {"MIT"},

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"x11", "wayland", "luban"},
    keywords = {"xwayland", "x11", "xorg", "wayland", "luban"},

    -- Form: a bundle built from source (xlings: 2026-10-18 Luban OS
    -- distribution design §4.6, §13.5). Alpine's Xwayland links glamor and
    -- GLX and through them mesa and LLVM (248 MB); a Luban machine has no GPU,
    -- so this one is Alpine 3.24's source and patch configured without
    -- either (tools/res/build.sh xwayland): 11 MB, 21 libraries, private in
    -- libexec/xwayland. Its keymaps are xim:xkeyboard-config's.
    programs = {"Xwayland", "xkbcomp"},
    xvm_enable = true,

    -- How it is checked (xlings design 2026-10-21 §6.1): luban status --check runs
    -- `run` and `launcher`; a desktop session (luban-os-ci L3) the rest.
    extensions = { luban = { checks = {
        { id = "xwayland-runs", what = "it starts", run = "Xwayland -version", timeout = 20 },
    } } },

    xpm = {
        linux = {
            deps = { "xim:xkeyboard-config" },
            ["latest"] = { ref = "24.1.14-r1" },
            ["24.1.14-r1"] = {
                -- 1: its checks written where a system's self-check reads them (xlings design 2026-10-21 §6.1);
                -- its loader searches only its tree (xlings design 2026-10-21 J12).
                revision = 1,
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "47c4a3c47eae89049d31a917606daec1e2b359b1e5099652c855312e2e9cfed2",
                    aarch64 = "6e4c1cc3f7f671f9a9ea01e7c70645bb8e4dd1677e8fa62147ebff8c0a4a5e5e",
                },
            },
        },
    },
}

import("xim.pkgindex.luban_component")

function install()
    return luban_component.install({ "bin/Xwayland" })
end

function config()
    return luban_component.config(package.programs, nil, package.extensions.luban.checks)
end

function uninstall()
    return luban_component.uninstall(package.programs)
end
