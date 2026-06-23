package = {
    spec = "1",
    homepage = "https://github.com/openxlings/xim-pkgindex",

    name = "mcpp-vscode-clangd",
    description = "Configure VSCode clangd support for mcpp LLVM projects",
    maintainers = {"xim team"},
    licenses = {"Apache-2.0"},

    type = "config",
    namespace = "config",
    status = "dev",
    categories = {"cpp", "vscode", "config"},
    keywords = {"mcpp", "vscode", "clangd", "llvm", "cpp-modules", "import-std"},

    xpm = {
        linux = {
            deps = { "xim:mcpp", "xim:code", "xim:llvm-tools@20.1.7" },
            ["latest"] = { ref = "20.1.7" },
            ["20.1.7"] = {},
        },
        windows = {
            deps = { "xim:mcpp", "xim:code", "xim:llvm-tools@20.1.7" },
            ["latest"] = { ref = "20.1.7" },
            ["20.1.7"] = {},
        },
    },
}

import("xim.libxpkg.json")
import("xim.libxpkg.log")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")

function install()
    return true
end

function config()
    local root = system.rundir()
    if not os.isfile(path.join(root, "mcpp.toml")) then
        log.warn("mcpp-vscode-clangd skipped: mcpp.toml not found in " .. root)
        return true
    end
    local vscode_dir = path.join(root, ".vscode")
    local settings_file = path.join(vscode_dir, "settings.json")
    if not os.isdir(vscode_dir) then
        os.mkdir(vscode_dir)
    end
    local settings = os.isfile(settings_file) and json.loadfile(settings_file) or {}
    local clangd_exe = os.host() == "windows" and "clangd.exe" or "clangd"
    settings["clangd.path"] = path.join(pkginfo.dep_install_dir("llvm-tools", pkginfo.version()), "bin", clangd_exe)
    -- Enable clangd's C++20 modules support so mcpp's `import std;` /
    -- `import <module>;` projects resolve correctly under the editor.
    settings["clangd.arguments"] = { "--experimental-modules-support" }
    json.savefile(settings_file, settings, { indent = true })
    system.exec("code --install-extension llvm-vs-code-extensions.vscode-clangd")
    os.cd(root)
    system.exec("mcpp toolchain install llvm@" .. pkginfo.version() .. " default")
    os.tryrm(path.join(root, "compile_commands.json"))
    system.exec("mcpp build")
    return true
end

function uninstall()
    return true
end
