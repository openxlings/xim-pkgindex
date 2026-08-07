package = {
    spec = "1",
    name = "msvc",
    description = "Microsoft Visual Studio C++ Compiler",
    maintainers = {"Microsoft"},

    type = "config",
    status = "stable",
    categories = { "toolchain", "c++", "c", "compiler" },
    keywords = { "msvc", "c++", "c" },

    xpm = {
        windows = {
            deps = { "xim:vs-buildtools@2022" },
            ["latest"] = { ref = "2022" },
            ["2022"] = {}, -- v143
        },
    }
}

import("xim.libxpkg.pkgmanager")
import("core.tool.toolchain")

-- https://learn.microsoft.com/en-us/visualstudio/install/workload-component-id-vs-build-tools?view=vs-2022
--local msvc_compiler = "Microsoft.VisualStudio.Component.VC.Tools.x86.x64"
local msvc_component = "Microsoft.VisualStudio.Workload.VCTools"
-- kernel32.lib issues need refresh

function installed()
    local msvc_path = [[C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC]]
    return os.isdir(msvc_path) or toolchain.load("msvc"):check() == "2022"
end

function install()
    os.exec(
        "vs_BuildTools.exe" ..
        -- " --installPath " .. vs_install_path ..
        " --add " .. msvc_component ..
        " --includeRecommended" ..
        -- " --quiet " ..
        " --passive " ..
        -- " --norestart " ..
        " --wait " -- ..
    )
    return true
end

function uninstall()
    if not os.isfile("vs_BuildTools.exe") then pkgmanager.install("vs-buildtools") end
    os.exec(
        "vs_BuildTools.exe" ..
        " --remove " .. msvc_component ..
        " --passive " ..
        " --wait "
    )
    return true
end
