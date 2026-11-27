package = {
    spec = "1",
    -- base info
    name = "linux-sysroot-create",
    description = "XScript: Linux Sysroot Create Tool",

    authors = {"sunrisepeak"},
    maintainers = {"d2learn"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/openxlings/xim-pkgindex",

    -- xim pkg info
    type = "script",
    status = "stable", -- dev, stable, deprecated
    categories = {"sysroot", "linux", "xpkg", "helper" },
    keywords = {"xpackage", "helper", "xscript"},

    xpm = {
        windows = { ["0.0.1"] = { } },
        linux = { ["0.0.1"] = { } },
        macosx = { ["0.0.1"] = { } },
    },
}

import("xim.libxpkg.log")
import("xim.libxpkg.utils")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.libxpkg.pkgmanager")

local __xscript_input = {
    ["--glibc"] = false,
    ["--linux-headers"] = false,
    ["--output"] = false,
    ["--force"] = false,
}

function xpkg_main(...)

    local _, cmds = utils.input_args_process(
        __xscript_input,
        { ... }
    )

    cmds["--linux-headers"] = cmds["--linux-headers"] or "5.11.1"
    cmds["--output"] = cmds["--output"] or "linux-sysroot"

    if cmds["--force"] then
        cmds["--force"] = true
    end

    cmds["--output"] = utils.filepath_to_absolute(cmds["--output"])


    -- printinfo
    cprint("\tlinux-sysroot-create - 0.0.1")
    cprint("")
    cprint("---")
    cprint("glibc version: ${green}%s${clear}", tostring(cmds["--glibc"]))
    cprint("linux-headers version: ${green}%s${clear}", cmds["--linux-headers"])
    cprint("output path: ${green}%s${clear}", cmds["--output"])
    cprint("---")
    cprint("")

    if not cmds["--glibc"] then
        cprint("${red}error: --glibc is required!${clear}")
        return
    end

    local xpk_glibc = "glibc@" .. cmds["--glibc"]
    local xpk_linux_header = "linux-headers@" .. cmds["--linux-headers"]

    log.info("1 - installing dependencies ...")

    pkgmanager.install(xpk_glibc)
    pkgmanager.install(xpk_linux_header)

    log.info("2 - checking dependencies ...")
    if not xvm.has("glibc", cmds["--glibc"]) then
        log.error("missing glibc: " .. xpk_glibc)
        return
    end

    if not xvm.has("linux-headers", cmds["--linux-headers"]) then
        log.error("missing linux-headers: " .. xpk_linux_header)
        return
    end

    log.info("3 - creating sysroot ...")

    if os.isdir(cmds["--output"]) then
        if cmds["--force"] then
            os.tryrm(cmds["--output"])
        else
            log.warn("output dir already exists: " .. cmds["--output"])
            return
        end
    end

    log.info("add glibc ...")
    system.exec("xpkg-helper fromsource:glibc@2.39 --export-path " .. cmds["--output"])

    os.cd(cmds["--output"])

    log.info("add usr/include ...")
    os.cp("include", "usr/include", { force = true, symlink = true })

    log.info("add linux-headers...")

    local linuxheader_info = xvm.info("linux-headers", cmds["--linux-headers"])
    local linuxheader_dir = path.directory(linuxheader_info["SPath"])

    os.cp(path.join(linuxheader_dir, "include"), "usr", { force = true, symlink = true })

    log.info("3 - relocate glibc path...")

    local relocate_files = {
        "lib/libc.so",
        "lib/libm.so",
        "lib/libm.a",

        "bin/ldd",
        "bin/tzselect",
        "bin/xtrace",
        "bin/sotruss",
    }

    local glibc_info = xvm.info("glibc", "2.39")
    local glibc_dir = path.directory(glibc_info["SPath"])

    for _, f in ipairs(relocate_files) do
        if os.isfile(f) then
            log.info("relocate file: " .. f)
            local content = io.readfile(f)
            content = content:replace(
                glibc_dir, "", -- sysroot
                { plain = true }
            )
            io.writefile(f, content)
        end
    end

    log.info("create sysroot - ok")
end