package = {
    spec = "1",
    -- base info
    name = "shortcut-tool",
    description = "Shortcut Tool: Create and manage shortcuts easily",

    authors = {"sunrisepeak"},
    maintainers = {"d2learn"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/openxlings/xim-pkgindex",

    -- xim pkg info
    type = "script",
    status = "stable", -- dev, stable, deprecated
    categories = {"tools", "shortcut"},
    keywords = {"shortcut", "link", "launcher"},
    programs = { "shortcut-tool" },

    xpm = {
        windows = { ["0.0.1"] = { } },
        linux = { ["0.0.1"] = { } },
        macosx = { ["0.0.1"] = { } },
    },
}

import("xim.libxpkg.log")
import("xim.libxpkg.utils")
import("xim.libxpkg.system")

local shortcut_template = {
    windows = [[
Set WshShell = WScript.CreateObject("WScript.Shell")
Set shortcut = WshShell.CreateShortcut("%s.lnk")
shortcut.TargetPath = "%s"
shortcut.IconLocation = "%s"
shortcut.WorkingDirectory = "%s"
shortcut.Arguments = "%s"
shortcut.Description = "Shortcut for %s"
shortcut.Save
    ]],
    linux = [[
[Desktop Entry]
Name=%s
Exec=%s
Icon=%s
Type=Application
Terminal=false
    ]]
}

local shortcut_dir = {
    linux = tostring(os.getenv("HOME")) .. "/.local/share/applications",
    windows = tostring(os.getenv("APPDATA")) .. "/Microsoft/Windows/Start Menu/Programs"
}

function create_linux_shortcut(name, target, icon)
    local filename = name:replace(" ", "-") .. ".xvm.desktop"
    local filepath = path.join(shortcut_dir[os.host()], filename)

    local content = string.format(
        shortcut_template.linux,
        name, target, icon
    )

    io.writefile(filepath, content)

    log.info("Shortcut created: " .. filepath)
end

function create_windows_shortcut(name, target, icon, args)
    -- 创建一个 .vbs 脚本的内容
    local vbs_content = string.format(
        shortcut_template.windows,
        name, target, icon, path.directory(target), args or "", name
    )

    -- 保存为一个临时 .vbs 文件
    local vbs_path = "shortcut-tool.xim.vbs"
    local file = io.open(vbs_path, "w")
    file:write(vbs_content)
    file:close()

    -- 执行 .vbs 文件以创建快捷方式
    --
    -- cscript, NOT wscript. wscript is the GUI-mode Windows Script Host: it
    -- needs a window station, and in a non-interactive session (CI, a service,
    -- WinRM, a scheduled task) it does not get one and never returns. The
    -- caller has no timeout, so the whole install hangs -- no error, nothing
    -- printed, indistinguishable from a slow download.
    --
    -- Measured on a windows-test runner: vc6's config() calls
    -- `shortcut-tool create`, the job stopped dead after the compat-mode
    -- `reg add` printed "The operation completed successfully.", and sat there
    -- until it was cancelled. vc6 had never been install-tested on Windows
    -- before -- the per-package test only runs recipes in a PR's changed set --
    -- so this had been latent since the recipe was written.
    --
    -- //Nologo drops the banner; //B is batch mode, which suppresses the
    -- script-level prompts and error dialogs that would block for the same
    -- reason one level down.
    system.exec("cscript //Nologo //B " .. vbs_path)

    -- 删除临时的 .vbs 文件
    os.tryrm(vbs_path)

    -- copy to desktop and move to start menu
    -- Use %USERPROFILE% so the Desktop resolves correctly on systems
    -- where the user profile is not under C:\Users\<name>\ (different
    -- drive letter, non-default profile path, non-ASCII user name).
    os.cp(name .. ".lnk", path.join(tostring(os.getenv("USERPROFILE")), "Desktop"))
    os.mv(name .. ".lnk", shortcut_dir[os.host()])

    log.info("Shortcut created: " .. name .. ".lnk")
end

function shortcut_remove(name)
    local filepath = nil
    if os.host() == "windows" then
        os.tryrm(path.join(tostring(os.getenv("USERPROFILE")), "Desktop", name .. ".lnk"))
        filepath = path.join(shortcut_dir[os.host()], name .. ".lnk")
    elseif os.host() == "linux" then
        local filename = name:replace(" ", "-") .. ".xvm.desktop"
        filepath = path.join(shortcut_dir[os.host()], filename)
    else
        log.error("not support yet on macosx")
    end

    if filepath and os.isfile(filepath) then
        log.info("removing desktop shortcut - %s", filepath)
        os.tryrm(filepath)
    else
        log.warn("shortcut not found - %s", filepath or "nil")
    end
end

local shortcut_create = {
    windows = create_windows_shortcut,
    linux = create_linux_shortcut,
    macosx = function(name, target, icon)
        log.error("not support yet on macosx")
    end
}

local __xscript_input = {
    ["--name"] = false,
    ["--target"] = false,
    ["--icon"] = false,
    ["--args"] = false,
}

function xpkg_main(action, ...)

    local _, cmds = utils.input_args_process(
        __xscript_input,
        { ... }
    )

    cmds["--target"] = utils.filepath_to_absolute(cmds["--target"] or "?")

    if action == "create" and cmds["--target"] and not os.isfile(cmds["--target"]) then
        log.error("target not found")
        cprint("shortcut-tool <action> <--target xx> [--name xx --icon xx]")
        return
    end

    cmds["--name"] = cmds["--name"] or path.filename(cmds["--target"])
    cmds["--icon"] = cmds["--icon"] or cmds["--target"]

    if action == "create" then
        shortcut_create[os.host()](cmds["--name"], cmds["--target"], cmds["--icon"], cmds["--args"])
    elseif action == "remove" then
        shortcut_remove(cmds["--name"])
    else
        cprint("shortcut-tool <action> <--target xx> [--name xx --icon xx]")
    end
end