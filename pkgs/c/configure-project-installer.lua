package = {
    spec = "1",
    name = "configure-project-installer",
    description = "Build & Install (from source) helper tools for ./configure-based projects",
    authors = {"sunrisepeak"},
    maintainers = {"d2learn"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/openxlings/xim-pkgindex",

    type = "script",
    status = "stable",
    categories = {"tools", "build", "helper"},
    keywords = {"configure", "make", "build", "install"},

    programs = { "configure-project-installer" },

    xpm = {
        linux = {
            deps = { "xim:make", "xim:gcc", "xim:xpkg-helper" },
            ["latest"] = { ref = "0.0.1" },
            ["0.0.1"] = {}
        },
        macosx = { ref = "linux" },
    },
}

import("xim.libxpkg.log")
import("xim.libxpkg.utils")
import("xim.libxpkg.system")
import("xim.libxpkg.pkgmanager")

local __xscript_input = {
    ["--args"] = false,
    ["--project-dir"] = false,
    ["--project-url"] = false, -- TODO: support git clone from url
    ["--force"] = false,
    ["--xpkg-scode"] = false,
    ["--install-by-sudo"] = false
}

local tmp_project_dir = nil

function download_scode(cmds)

    local xpkg = "scode:" .. cmds["--xpkg-scode"]

    tmp_project_dir = utils.filepath_to_absolute(".configure-project-installer")

    pkgmanager.install(xpkg)

    os.tryrm(tmp_project_dir)
    system.exec(string.format(
        "xpkg-helper %s --export-path %s",
        xpkg, tmp_project_dir
    ))

    if not os.isdir(tmp_project_dir) then
        log.error("failed to download source code from xpkg: %s", xpkg)
        raise("configure-project-installer: failed to download source code")
    end

    return tmp_project_dir
end

function xpkg_main(installdir, ...)

    installdir = installdir or "configure-project-installer"
    installdir = utils.filepath_to_absolute(installdir)

    local _, cmds = utils.input_args_process(__xscript_input, {...})
    local configure_args = cmds["--args"] or ""
    local srcdir = cmds["--project-dir"] or "."
    local abs_srcdir = utils.filepath_to_absolute(srcdir)

    if cmds["--xpkg-scode"] then
        abs_srcdir = download_scode(cmds)
        log.warn("use [xpkg - scode:%s] project-dir: %s", cmds["--xpkg-scode"], abs_srcdir)
    end

    configure_args = string.format("%s --prefix=%s", configure_args, installdir)

    cprint("")
    cprint("\t ${bright}Configure Project Installer - 0.0.1${clear}")
    cprint("")
    cprint("xpkg-scode: ${dim green}" .. tostring(cmds["--xpkg-scode"]))
    cprint("project-dir: ${dim green}" .. abs_srcdir)
    cprint("install-dir: ${dim green}" .. installdir)
    cprint("args:   ${dim green}" .. configure_args)
    cprint("")

    os.cd(abs_srcdir)

    local configure_file = "configure"

    if not os.isfile(configure_file) then configure_file = "Configure" end
    if not os.isfile(configure_file) then configure_file = "configure.sh" end

    if not os.isfile(configure_file) then
        log.error("missing configure script in project directory")
        log.error("${red}error: missing or invalid project directory: ${clear}" .. abs_srcdir)
        cprint("")
        cprint("Usage: ${dim cyan}configure-project-installer <install-dir> [ --project-dir xx ] [--args xx] [--force]")
        cprint("")
        return
    end

    os.sleep(2000) -- wait for 2 seconds to let user cancel if needed

    -- run ./configure
    local configure_cmd = string.format("./%s %s", configure_file, configure_args)
    system.exec(configure_cmd)
    system.exec("make clean")
    system.exec("make -j20", { retry = 3 })

    local make_install_cmd = "make install"

    if cmds["--install-by-sudo"] then
        make_install_cmd = string.format("sudo %s/%s",
            system.bindir(),
            make_install_cmd
        )
    end

    system.exec(make_install_cmd)

    -- remove tmp project dir if any
    if tmp_project_dir and os.isdir(tmp_project_dir) then
        log.info("remove tmp project dir: %s", tmp_project_dir)
        os.tryrm(tmp_project_dir)
    end

    log.info("✅ installed to: ${green}%s", installdir)
end