package = {
    spec = "1",
    -- base info
    name = "wsl-ubuntu",
    description = "Windows Subsystem for Linux (WSL) Ubuntu",
    repo = "https://github.com/openxlings/xim-pkgindex",

    -- xim pkg info
    type = "config",
    archs = {"x86_64"},
    status = "stable", -- dev, stable, deprecated
    categories = {"windows", "subsystem", "ubuntu"},
    keywords = {"linux", "subsystem", "ubuntu"},

    xpm = {
        windows = {
            deps = { "wsl@winget" },
            ["latest"] = { },
        },
    },
}

function installed()
    local output = os.iorun("wsl --list --verbose")
    return string.find(output, "Ubuntu", 1, true) ~= nil
end

function install()
    os.exec("wsl --install -d Ubuntu")

    log.debug("\n\n  ${yellow}Note${clear}: maybe need to restart your computer to complete WSL installation")
    log.debug("  ${yellow}注意${clear}: 可能需要重启让WSL安装和配置生效\n\n")

    guide_wsl_setup()

    return true
end

function uninstall()
    os.exec("wsl --unregister Ubuntu")
    return true
end

import("xim.libxpkg.log")

function guide_wsl_setup()
    log.debug([[

[xlings]: WSL Ubuntu 初步指导:

    0. 运行wsl: 点击命令行窗口顶部的下拉菜单 v 按钮选择ubuntu
    1. 等待 Ubuntu 初始化完成
    2. 创建一个新的 UNIX 用户名（不需要跟 Windows 用户名相同）
    3. 设置密码（输入时不会显示）
    4. 确认密码

注意:
- 首次安装需要重启电脑才能生效
- 用户名只能使用小写字母
- 密码输入时屏幕上不会显示任何内容
- 请记住您设置的密码，后续会用到

    ]])
end