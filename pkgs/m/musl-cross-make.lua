package = {
    spec = "1",
    -- base info
    name = "musl-cross-make",
    description = "Simple makefile-based build for musl cross compiler",

    authors = {"Rich Felker, et al."},
    contributors = "https://github.com/richfelker/musl-cross-make/graphs/contributors",
    licenses = {"MIT"},
    repo = "https://github.com/richfelker/musl-cross-make",

    -- xim pkg info
    type = "script",
    status = "stable",
    categories = {"linux", "build-helper", "toolchain"},
    keywords = {"linux", "musl", "libc", "toolchain", "compiler", "makefile", "gcc"},
    programs = { "musl-cross-make" },

    -- xvm: xlings version management
    xvm_enable = true,

    xpm = {
        linux = {
            deps = { "make", "gcc" }, -- musl-gcc ?
            ["latest"] = { ref = "0.0.1" },
            ["0.0.1"] = {
                url = {
                    GLOBAL = "https://github.com/richfelker/musl-cross-make.git",
                    CN = "https://gitcode.com/xlings-res/musl-cross-make.git",
                },
                sha256 = nil,
            },
        },
    },
}

import("xim.libxpkg.log")
import("xim.libxpkg.xvm")
import("xim.libxpkg.system")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.utils")

local function get_source_script_file()
    return path.join(system.xpkgdir(), "musl-cross-make.lua")
end

function install()
    -- install musl-cross-make script
    local target_script_file = path.join(pkginfo.install_dir(), "musl-cross-make.lua")
    os.tryrm(target_script_file)
    os.cp(get_source_script_file(), target_script_file)
    -- install musl-cross-make source
    os.mv("musl-cross-make", pkginfo.install_dir())
    return true
end

function config()
    local target_script_file = path.join(pkginfo.install_dir(), "musl-cross-make.lua")
    xvm.add("musl-cross-make", {
        alias = "xlings script " .. target_script_file,
        bindir = "TODO-FIX-SPATH-ISSUES",
    })
    return true
end

function verify_and_choice_from_list(target, target_list, opt)
    if opt.header_tips then
        cprint(opt.header_tips)
    end

    target = target or opt.default

    local in_list = false
    for _, t in ipairs(target_list) do
        if string.find(t, target, 1, true) then target = t end
        if t == target then
            in_list = true
            cprint("  ${green}" .. t .. " ${blink}<")
        else
            cprint("  " .. t)
        end
        os.sleep(200) -- sleep to avoid too fast output
    end

    if not in_list and target then
        cprint("  ${green}" .. target .. " ${blink}<")
    end

    if opt.footer_tips and target then
        cprint(opt.footer_tips .. " - ${green}" .. target)
    end

    return target

end

function config_gcc_specs(cmds)

    -- create specs for dynamic linker
    if not os.isdir(cmds["--output"]) then
        log.error("Output directory not found: " .. cmds["--output"])
        return false
    end

    local gcc_bin = path.join(
        cmds["--output"], "bin",
        cmds["--target"] .. "-gcc"
    )

    if not os.isfile(gcc_bin) then
        log.error("GCC binary not found: " .. gcc_bin)
        return false
    end

    log.info("%s - ok", gcc_bin)

    local default_specs_content = os.iorun(gcc_bin .. " -dumpspecs")
    local default_specs_file = os.iorun(gcc_bin .. " -print-libgcc-file-name")

    default_specs_file = path.join(
        path.directory(default_specs_file:trim()),
        "specs"
    )

    log.info("Default specs path: " .. default_specs_file)

    -- replace dynamic linker in specs
    local old_dynamic_linker = "/lib/ld-musl-%s.so.1"
    local arch = cmds["--target"]:split("-linux")[1]
    old_dynamic_linker = string.format(old_dynamic_linker, arch)
    default_specs_content = string.replace(
        default_specs_content,
        -- support multi-arch?
        old_dynamic_linker, cmds["--with-dynamic-linker"],
        { plain = true }
    )

    log.warn(string.format(
        "Replacing dynamic linker in specs: %s -> %s",
        old_dynamic_linker, cmds["--with-dynamic-linker"]
    ))

    -- runtime path
    local rpath = "*link:\n%{!static:%{!shared:%{!static-pie: --enable-new-dtags -rpath /home/xlings/.xlings_data/lib }}} "

    default_specs_content = string.replace(
        default_specs_content,
        "*link:\n", rpath,
        { plain = true }
    )

    log.info("Adding x-default rpath to specs: /home/xlings/.xlings_data/lib")

    io.writefile(default_specs_file, default_specs_content)

    log.info("Dynamic linker set to: " .. cmds["--with-dynamic-linker"])
    log.info("Specs file updated: " .. default_specs_file)

    return true
end

function info_tips(version, cmds)
    cprint("\n${dim}---\n")

    cprint("${bright}version: ${green}" .. version)
    cprint("${bright}target: ${green}" .. cmds["--target"])
    cprint("${bright}output: ${green}" .. cmds["--output"])

    if cmds["--with-dynamic-linker"] then
        cprint("${bright}with-dynamic-linker: ${green}" .. cmds["--with-dynamic-linker"])
    end
    if cmds["--static"] then
        cprint("${bright}static: ${green}" .. cmds["--static"])
    end
    if cmds["--config-mak"] then
        cprint("${bright}config-mak: ${green}" .. cmds["--config-mak"])
    end

    if cmds["--compress"] then
        cprint("${bright}compress: ${green}" .. cmds["--compress"])
    end

    cprint("\n${dim}---\n")
end

function __try_run(cmd)
    return try {
        function()
            system.exec(cmd, { retry = 3 })
            return true
        end,
        catch = function(err)
            return false
        end
    }
end

-- version tips
-- https://gcc.gnu.org/releases.html
-- musl-cross-make supports auto-mirror ftp
local gcc_version_list = {
    "9.4.0", -- ubuntu20.04~
    "10.3.0", -- debian11~
    "11.5.0", -- ubuntu22.04~
    "12.4.0", -- debian12~
    "13.3.0", -- ubuntu24.04
    "15.1.0",
    -- more...
}

local target_list = {
    "i486-linux-musl",
    "x86_64-linux-musl",
    "aarch64-linux-musl",
    "arm-linux-musleabi",
    "arm-linux-musleabihf",
    "sh2eb-linux-muslfdpic",
    -- ...
}

-- invalid conversion '%{' to 'format' - % -> %%
-- %{!rpath*: -Wl,-rpath=/home/xlings/.xlings_data/lib } -- syntax?
-- %{!dynamic-linker*: -Wl,--dynamic-linker=/home/xlings/.xlings_data/lib/ld-musl-x86_64.so.1 }
local config_mak_template = [[
# 
# xlings/xscript: musl-cross-make's config.mak template - 0.0.1

GCC_VER = %s
TARGET = %s
OUTPUT = %s

# Pin musl to 1.2.5 explicitly. Without this the build inherits musl-cross-make's
# default (or git-master), and musl >= 1.2.6 registers the main thread's robust
# list (set_robust_list) at startup — which Android 13's app seccomp TRAPs as
# SIGSYS, so EVERY binary from a 1.2.6 toolchain dies with "Bad system call" on
# Termux. 1.2.5 doesn't make that call. Keep all toolchains (cross + native) on
# 1.2.5 for Android compatibility. See .agents docs 2026-06-23-termux-android-adaptation.
MUSL_VER = 1.2.5

# [OK] - RPATH -> RUNPATH (by --enable-new-dtags) and append with --with-specs
# [X]  - GCC_CONFIG += -Wl,--with-dynamic-linker=/home/xlings/.xlings_data/lib/ld-musl-x86_64.so.1
# [X]  - have'nt -Wl,--with-dynamic-linker only use --dynamic-linker by --with-extra-ldflags
# [X]  - GCC_CONFIG += --with-extra-ldflags=" xxx -Wl,--enable-new-dtags -Wl,-rpath,/home/xlings/.xlings_data/lib "

# [X] - Add default linker and rpath via specs and control by --xlings-config-no
# [X] - Note: Custom option dont use {-f, -W, -g, -O } save keywords, suggest use -X -Z
# GCC_CONFIG += --with-specs='%%{!static:%%{!shared:%%{!static-pie: -Wl,--enable-new-dtags -Wl,-rpath,/home/xlings/.xlings_data/lib }}}'

# COMMON_CONFIG += CC="gcc -static" CXX="g++ -static"
%s
]]

-- Note: haven't --with-dynamic-linker option for gcc, but --with-sysroot ok
-- --with-dynamic-linker -> default -Wl,--dynamic-linker by --with-extra-ldflags
local __xscript_input = {
    --["--version"] = false,
    ["--target"] = false,
    ["--output"] = false,
    -- note: --with-dynamic-linker -> set default -Wl,--dynamic-linker
    ["--with-dynamic-linker"] = false,
    -- note: --with-sysroot, -Wl,--sysroot= and -Wl,-rpath=... different 
    --["--with-sysroot"] = false,
    ["--static"] = false, -- boolean
    ["--config-mak"] = false,
    ["--compress"] = false,
    ["--clean"] = true,
    ["-h"] = false,
    ["--help"] = false,
    -- --with-extra-ldflags append?
}

-- function main() inherits failed for package?
-- avoid to call main when import this package?
function xpkg_main(version, ...)

    local extra_args = { ... }
    local cmds = {}
    local i = 1
    while i <= #extra_args do
        local arg = extra_args[i]
        if __xscript_input[arg] ~= nil and i < #extra_args then
            cmds[arg] = extra_args[i + 1]
            i = i + 2
        elseif __xscript_input[arg] ~= nil then
            cmds[arg] = true
            i = i + 1
        else
            i = i + 1
        end
    end

    --print(cmds)

    if (version == "-h" or version == "--help") or cmds["-h"] or cmds["--help"] then
        cprint("Usage: ${cyan}musl-cross-make [version] [options]")
        cprint("")
        cprint("Example:")
        cprint("  ${cyan}musl-cross-make 15.1.0")
        cprint("  ${cyan}musl-cross-make 15.1.0 --target x86_64 --output mygcc15")
        cprint("")
        return
    end

    --local target = cmds["--target"]
    --local output = cmds["--output"]

    if cmds["--static"] then
        -- Fully-static toolchain, per config.mak.dist's documented recipe.
        -- Two non-obvious requirements (a plain `CC="gcc -static"` gets BOTH
        -- wrong and yields a host-glibc-dynamic toolchain whose g++ dies with
        -- exit 127 on a cold sandbox):
        --   1. Build WITH the musl host compiler (<host>-linux-musl-gcc), not
        --      the glibc `gcc` — otherwise the "static" binaries are glibc-
        --      static (NSS dlopen still wants glibc). Requires xim:musl-gcc for
        --      the build host to be installed.
        --   2. Use the DOUBLE `-static --static`: the 2nd `--static` is passed
        --      to the linker, piercing binutils' libtool (which silently drops a
        --      lone `-static`, producing a DYNAMIC as-new/ld → broken target
        --      musl libc configure).
        -- `-g0 -Os` + `LDFLAGS=-s` strip & shrink (≈90 MB vs ≈830 MB unstripped).
        local host = (os.arch() == "arm64") and "aarch64" or os.arch()
        local cc  = host .. "-linux-musl-gcc"
        local cxx = host .. "-linux-musl-g++"
        cmds["--static"] = string.format(
            'COMMON_CONFIG += CC="%s -static --static" CXX="%s -static --static"\n'
            .. 'COMMON_CONFIG += CFLAGS="-g0 -Os" CXXFLAGS="-g0 -Os" LDFLAGS="-s"',
            cc, cxx)
    end

    version = verify_and_choice_from_list(
        version,
        gcc_version_list,
        {
            header_tips = "GCC version for musl-cross-make:",
            footer_tips = "Selected GCC version",
            default = "11.5.0",
        }
    )

    cmds["--target"] = verify_and_choice_from_list(
        cmds["--target"],
        target_list,
        {
            header_tips = "Target architecture for musl-cross-make:",
            footer_tips = "Selected target architecture",
            default = "x86_64-linux-musl",
        }
    )

    local default_outputdir = string.format(
        "musl-gcc-%s-linux-%s",
        version, cmds["--target"]:split("-linux")[1]
    )

    cmds["--output"] = cmds["--output"] or default_outputdir
    cmds["--output"] = utils.filepath_to_absolute(cmds["--output"])

    if cmds["--compress"] then
        cmds["--compress"] = cmds["--output"] .. ".tar.gz"
    end

    info_tips(version, cmds)

    cprint("start build ${blink}...")
    os.sleep(3000) -- wait user check and confirmation

    local project_dir = path.join(system.xpkgdir(), "musl-cross-make")
    local ret_ok = true

    if not os.isdir(project_dir) then
        cprint("${red}Error: musl-cross-make project directory not found!")
        cprint("Tips: try remove and reinstall musl-cross-make package.")
        cprint("")
        cprint("  ${cyan}xlings remove musl-cross-make")
        cprint("  ${cyan}xlings install musl-cross-make")
        cprint("")
        ret_ok = false
    end

    local config_mak_file = path.join(project_dir, "config.mak")
    local config_mak = string.format(
        config_mak_template,
        version, cmds["--target"], cmds["--output"],
        --cmds["--with-dynamic-linker"] or "",
        cmds["--static"] or ""
    )

    if cmds["--config-mak"] then
        local config_file
        -- if network file
        if string.find(cmds["--config-mak"], "://", 1, true) then
            local tmpdir = os.tmpname() .. "_dl"
            os.mkdir(tmpdir)
            if utils.try_download_and_check(cmds["--config-mak"], tmpdir) then
                local fname = cmds["--config-mak"]:match("[^/]+$") or "config.mak"
                config_file = path.join(tmpdir, fname)
            end
        else
            config_file = utils.filepath_to_absolute(cmds["--config-mak"])
        end
        if config_file and os.isfile(config_file) then
            config_mak = io.readfile(config_file)
        end
    end

    io.writefile(config_mak_file, config_mak)

    os.cd(project_dir)

    if ret_ok and cmds["--clean"] ~= "false" then
        log.warn("-> clearing previous build files...")
        ret_ok = __try_run("make clean")
    else
        log.error("Project dir not found, aborting build.")
    end

    if ret_ok then
        log.warn("-> building with musl-cross-make...")
        ret_ok = __try_run("make -j8")
    else
        log.error("Failed to clear previous build files, aborting build.")
    end

    if ret_ok then
        log.warn("-> installing to " .. cmds["--output"] .. " ...")
        ret_ok = __try_run("make install")
    else
        log.error("Build failed, aborting installation.")
    end

    if ret_ok and cmds["--with-dynamic-linker"] then
        log.warn("-> config compiler specs(dynamic linker, rpath)...")
        ret_ok = config_gcc_specs(cmds)
    end

    if ret_ok and cmds["--compress"] then
        if os.isfile(cmds["--compress"]) then os.tryrm(cmds["--compress"]) end
        log.warn("-> start compress...")
        local parent_dir = path.directory(cmds["--output"])
        local dir_name = path.filename(cmds["--output"])
        os.exec(string.format('tar -czf "%s" -C "%s" "%s"', cmds["--compress"], parent_dir, dir_name))
    end

    -- tips
    info_tips(version, cmds)

    cprint("\n\t${bright dim}[ musl-cross-make(xlings) 0.0.1 ]\n")

    if ret_ok then
        cprint("${green}Build and install completed successfully!")
    else
        cprint("${red}Build or install failed!")
        cprint("Please check the output for errors.")
        cprint("")
        cprint("QA-List: https://xlings.d2learn.org/documents/qa.html")
        cprint("")
        raise("musl-cross-make build failed!")
    end
end