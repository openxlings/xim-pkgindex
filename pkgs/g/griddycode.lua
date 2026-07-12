package = {
    spec = "2",

    -- base info
    name = "griddycode",
    description = "A code editor made with Godot. Code has never been more lit!",

    maintainers = {"face-hh"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/face-hh/griddycode",
    ci = { mirror = true, update = true },

    -- xim pkg info
    type = "package",
    archs = {"x86_64"},
    status = "stable", -- dev, stable, deprecated
    categories = {"editor", "code"},
    keywords = {"code", "editor", "cross-platform"},

    programs = { "griddycode" },

    -- xvm: xlings version management
    xvm_enable = true,

    xpm = {
        linux = {
            -- Runtime deps. Godot-built executable is dynamically
            -- linked: NEEDED libc.so.6 / libdl.so.2 / libm.so.6 /
            -- libpthread.so.0 (glibc). Godot statically links its C++
            -- runtime, so libstdc++/libgcc_s are NOT in NEEDED.
            -- (The bundled lib*.so files in Linux/ are dlopen'd at
            -- runtime by Godot itself, not via DT_NEEDED.)
            -- Note: GUI runtime (libGL/libX11/libGLFW/libXi) is NOT
            -- declared here — those are system libs xim doesn't
            -- ship; users on hermetic distros won't be able to run
            -- griddycode anyway without an X11/Wayland session.
            deps = {
                runtime = { "xim:glibc@2.39" },
            },
            url_template = "https://github.com/face-hh/griddycode/releases/download/v{version}/Linux.zip",
            ["latest"] = { ref = "1.2.2" },
            ["1.2.2"] = { url = "https://github.com/face-hh/griddycode/releases/download/v1.2.2/Linux.zip" },
        },
        windows = {
            url_template = "https://github.com/face-hh/griddycode/releases/download/v{version}/Windows.zip",
            ["latest"] = { ref = "1.2.2" },
            ["1.2.2"] = { url = "https://github.com/face-hh/griddycode/releases/download/v1.2.2/Windows.zip" },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    os.tryrm(pkginfo.install_dir())
    if os.host() == "windows" then
        os.mv("Windows", pkginfo.install_dir())
    else
        os.mv("Linux", pkginfo.install_dir())
    end
    return true
end

function config()

    local bin_file = "GriddyCode.sh"
    local target_name = "griddycode"

    if os.host() == "windows" then
        bin_file = "GriddyCode.exe"
        target_name = "griddycode.exe"
    end

    local src = path.join(pkginfo.install_dir(), string.format("Bussin %s", bin_file))
    local dst = path.join(pkginfo.install_dir(), target_name)
    os.mv(src, dst)

    xvm.add("griddycode")

    return true
end

function uninstall()
    xvm.remove("griddycode")
    return true
end
