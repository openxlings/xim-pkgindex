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

    xpm = {
        linux = {
            deps = { "xim:xkeyboard-config" },
            ["latest"] = { ref = "24.1.14-r1" },
            ["24.1.14-r1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "@SHA_XWAYLAND_X86_64@",
                    aarch64 = "@SHA_XWAYLAND_AARCH64@",
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
    return luban_component.config(package.programs)
end

function uninstall()
    return luban_component.uninstall(package.programs)
end
