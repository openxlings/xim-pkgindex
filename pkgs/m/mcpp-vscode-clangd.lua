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

    -- The package version IS the clangd (llvm-tools) version: pick it
    -- explicitly (e.g. `mcpp-vscode-clangd@20.1.7`) or take `latest` for the
    -- newest. Version blocks mirror pkgs/l/llvm-tools.lua. `code` (VSCode) is
    -- detected at install time rather than pinned as a dependency.
    xpm = {
        linux = {
            deps = { "xim:mcpp" },
            ["latest"] = { ref = "22.1.8" },
            ["22.1.8"] = {},
            ["20.1.7"] = {},
        },
        windows = {
            deps = { "xim:mcpp" },
            ["latest"] = { ref = "22.1.8" },
            ["22.1.8"] = {},
            ["20.1.7"] = {},
        },
        macosx = {
            deps = { "xim:mcpp" },
            ["latest"] = { ref = "22.1.8" },
            ["22.1.8"] = {},
            ["20.1.7"] = {},
        },
    },
}

import("xim.libxpkg.json")
import("xim.libxpkg.log")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.pkgmanager")

-- Return true if `name` is an invokable command on the host PATH.
-- Uses os.iorun (which raises on a non-zero exit / missing binary) guarded
-- by try, mirroring how cpp.lua probes for gcc/clang.
local function has_command(name)
    local probe = (os.host() == "windows") and ("where " .. name) or (name .. " --version")
    return try {
        function()
            os.iorun(probe)
            return true
        end
    } or false
end

-- Normalize a clangd.arguments value to a list (json may load a lone string).
local function as_list(args)
    if type(args) == "table" then
        return args
    end
    return (args ~= nil) and { args } or {}
end

-- Ensure `flag` is present in a clangd.arguments list without discarding any
-- flags the user already configured (requirement 3).
local function ensure_flag(args, flag)
    args = as_list(args)
    for _, a in ipairs(args) do
        if a == flag then
            return args
        end
    end
    table.insert(args, flag)
    return args
end

-- Remove every occurrence of `flag` from a clangd.arguments list.
local function remove_flag(args, flag)
    local out = {}
    for _, a in ipairs(as_list(args)) do
        if a ~= flag then
            table.insert(out, a)
        end
    end
    return out
end

-- clangd 20.1.7 on Windows crashes (0xC0000005) building the preamble for the
-- toolchain's builtin headers when --experimental-modules-support is on. See
-- issue #393. Skip (and actively strip) the flag for that exact combination.
local function modules_flag_supported(ver)
    return not (os.host() == "windows" and ver == "20.1.7")
end

-- Merge clangd settings into .vscode/settings.json (requirement 3):
-- always overwrite clangd.path to point at the selected version, and merge
-- (never clobber) clangd.arguments so existing user flags survive.
local function write_clangd_settings(root, tools_dir, ver)
    local vscode_dir = path.join(root, ".vscode")
    if not os.isdir(vscode_dir) then
        os.mkdir(vscode_dir)
    end
    local settings_file = path.join(vscode_dir, "settings.json")
    local settings = os.isfile(settings_file) and json.loadfile(settings_file) or {}

    local clangd_exe = (os.host() == "windows") and "clangd.exe" or "clangd"
    settings["clangd.path"] = path.join(tools_dir, "bin", clangd_exe)

    -- Enable clangd's C++20 modules support so mcpp's `import std;` /
    -- `import <module>;` projects resolve correctly under the editor. Gated
    -- off (and stripped from any prior config) where it is known to crash.
    local modules_flag = "--experimental-modules-support"
    if modules_flag_supported(ver) then
        settings["clangd.arguments"] = ensure_flag(settings["clangd.arguments"], modules_flag)
    else
        settings["clangd.arguments"] = remove_flag(settings["clangd.arguments"], modules_flag)
        log.warn("clangd %s on Windows crashes with %s (issue #393); leaving it off", ver, modules_flag)
    end

    json.savefile(settings_file, settings, { indent = true })
    log.info("clangd configured: %s", settings["clangd.path"])
end

function install()
    -- Requirement 1: do not pin `code` as a fixed dependency. Detect it and
    -- only install through the package manager when it is missing.
    if has_command("code") then
        log.info("VSCode 'code' command detected, skipping install")
    else
        log.info("VSCode 'code' command not found, installing via package manager...")
        pkgmanager.install("code")
    end

    -- Install the clangd extension (idempotent). If `code` was just installed
    -- its PATH entry may not be active in this process yet, so failures are
    -- non-fatal and reported for a manual retry.
    local ok = try {
        function()
            print("\n") -- split to avoid print bug
            system.exec("code --install-extension llvm-vs-code-extensions.vscode-clangd")
            return true
        end
    } or false
    if not ok then
        log.warn("could not install the vscode-clangd extension automatically; "
            .. "run 'code --install-extension llvm-vs-code-extensions.vscode-clangd' manually")
    end
    return true
end

function config()
    local root = system.rundir()
    if not os.isfile(path.join(root, "mcpp.toml")) then
        log.warn("mcpp-vscode-clangd skipped: mcpp.toml not found in %s", root)
        return true
    end
    os.cd(root)

    -- Requirement 2: the clangd version is the explicitly selected package
    -- version (via `@version` or `latest`) -- no toolchain auto-detection.
    local ver = pkginfo.version()
    log.info("installing llvm-tools@%s for clangd", ver)
    pkgmanager.install("llvm-tools@" .. ver)

    local tools_dir = pkginfo.dep_install_dir("llvm-tools", ver)
    if not tools_dir then
        log.warn("failed to locate llvm-tools@%s install dir; skipping clangd configuration", ver)
        return true
    end

    write_clangd_settings(root, tools_dir, ver)

    -- Regenerate compile_commands.json so clangd has an up-to-date DB. The
    -- project's default toolchain is left untouched on purpose.
    os.tryrm(path.join(root, "compile_commands.json"))
    system.exec("mcpp build")
    return true
end

function uninstall()
    -- No-op: leave `code` and llvm-tools in place since they may be shared
    -- with other projects/tools on the machine.
    return true
end
