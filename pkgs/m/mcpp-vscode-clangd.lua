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

    -- Version model: `latest` -> `auto`, which detects the LLVM version the
    -- project actually built with (read from compile_commands.json) and
    -- installs the matching clangd. An explicit version (e.g.
    -- `mcpp-vscode-clangd@20.1.7`) pins clangd to that llvm-tools release and
    -- skips detection. `code` (VSCode) is detected at install time rather than
    -- pinned as a dependency.
    xpm = {
        linux = {
            deps = { "xim:mcpp" },
            ["latest"] = { ref = "auto" },
            ["auto"] = {},
            ["22.1.8"] = {},
            ["20.1.7"] = {},
        },
        windows = {
            deps = { "xim:mcpp" },
            ["latest"] = { ref = "auto" },
            ["auto"] = {},
            ["22.1.8"] = {},
            ["20.1.7"] = {},
        },
        macosx = {
            deps = { "xim:mcpp" },
            ["latest"] = { ref = "auto" },
            ["auto"] = {},
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

-- Return true if VSCode already has `ext` installed. `code --list-extensions`
-- prints one extension id per line; guarded by try since it fails when `code`
-- is missing.
local function has_extension(ext)
    local out = try {
        function()
            return os.iorun("code --list-extensions")
        end
    }
    return out ~= nil and out:lower():find(ext:lower(), 1, true) ~= nil
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

-- Pull the compiler invoked by the first compile_commands.json entry. mcpp
-- emits a `command` string; fall back to an `arguments` array just in case.
local function cdb_compiler(root)
    local cdb = path.join(root, "compile_commands.json")
    if not os.isfile(cdb) then
        return nil
    end
    local db = json.loadfile(cdb)
    local entry = db and db[1]
    if not entry then
        return nil
    end
    if type(entry.arguments) == "table" and entry.arguments[1] then
        return entry.arguments[1]
    end
    if type(entry.command) == "string" then
        return entry.command:match('^%s*"([^"]+)"') or entry.command:match("^%s*(%S+)")
    end
    return nil
end

-- If `compiler` is a clang/LLVM driver, return its version (e.g. "20.1.7").
-- Returns nil for gcc/msvc/unknown so the caller can print a hint and skip.
local function clang_toolchain_version(compiler)
    if not compiler then
        return nil
    end
    if not path.filename(compiler):lower():find("clang", 1, true) then
        return nil
    end
    local out = try {
        function()
            return os.iorun('"' .. compiler .. '" --version')
        end
    }
    return out and out:match("clang version%s+([%d%.]+)")
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

    -- Install the clangd extension only if it is not already present. If
    -- `code` was just installed its PATH entry may not be active in this
    -- process yet, so failures are non-fatal and reported for a manual retry.
    local ext = "llvm-vs-code-extensions.vscode-clangd"
    if has_extension(ext) then
        log.info("clangd extension already installed, skipping")
    else
        local ok = try {
            function()
                system.exec("code --install-extension " .. ext)
                return true
            end
        } or false
        if not ok then
            log.warn("could not install the vscode-clangd extension automatically; "
                .. "run 'code --install-extension " .. ext .. "' manually")
        end
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

    -- Unified first step: (re)generate compile_commands.json. clangd needs it
    -- as its build DB, and in `auto` mode it is also how we learn the real
    -- toolchain. --no-cache forces an actual compile: a cached `mcpp build`
    -- (0s) does NOT rewrite the DB, so without it a stale-removed cdb would
    -- never come back. The project's default toolchain is left untouched.
    os.tryrm(path.join(root, "compile_commands.json"))
    system.exec("mcpp build --no-cache")

    -- Requirement 2: `latest` -> `auto` detects the LLVM version the project
    -- actually built with; an explicit version is used as-is.
    local ver = pkginfo.version()
    if ver == "auto" then
        local compiler = cdb_compiler(root)
        local detected = clang_toolchain_version(compiler)
        if not detected then
            log.warn("project toolchain is not LLVM/clang (compiler: %s); "
                .. "mcpp-vscode-clangd only configures clangd for LLVM projects, skipping",
                compiler or "unknown")
            return true
        end
        log.info("auto-detected project LLVM version: %s", detected)
        ver = detected
    end

    log.info("installing llvm-tools@%s for clangd", ver)
    pkgmanager.install("llvm-tools@" .. ver)

    local tools_dir = pkginfo.dep_install_dir("llvm-tools", ver)
    if not tools_dir then
        log.warn("failed to locate llvm-tools@%s install dir; skipping clangd configuration", ver)
        return true
    end

    write_clangd_settings(root, tools_dir, ver)
    return true
end

function uninstall()
    -- No-op: leave `code` and llvm-tools in place since they may be shared
    -- with other projects/tools on the machine.
    return true
end
