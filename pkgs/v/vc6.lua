package = {
    spec = "1",

    name = "vc6",
    description = "Visual C++ 6.0: Classic C/C++ IDE (portable for Windows 10/11)",
    homepage = "https://en.wikipedia.org/wiki/Visual_C%2B%2B#32-bit_versions",
    licenses = {"Proprietary"},

    -- xim pkg info
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"ide", "c", "c++"},
    keywords = {"visual-c++", "vc6", "msvc6", "vc++6.0"},

    programs = { "msdev" },

    -- 中文版制作流程 (基于英文版 6.0 自动生成):
    --   1. LIEF (Python) 从英文版 14 个 PE 文件 (DLL/PKG/EXE) 中
    --      提取 RT_STRING 资源段的 3528 条 String Table 字符串
    --   2. LLM 批量翻译为简体中文 (保留格式符 %s/%d、快捷键 \tCtrl+X、
    --      热键标记 & 等), 共翻译 3024 条
    --   3. LIEF 将中文 UTF-16LE 字符串回写到 PE 资源段
    --   4. 打包为 zip 上传至 GitHub/Gitcode xlings-res/vc6@6.0-chs
    --
    -- 涉及的 PE 文件: DEVSHL.DLL, MSDEV.EXE, DEVEDIT.PKG,
    --   IDE/DEVRES.PKG, IDE/DEVBLD.PKG, IDE/DEVDBG.PKG, IDE/DEVCPP.PKG,
    --   IDE/DEVCLVW.PKG, IDE/DEVDTG.PKG, IDE/DEVAUT1.PKG, IDE/DEVGAL.PKG,
    --   IDE/DEVTOOL.PKG, IDE/DEVBIED.PKG, IDE/DEVHTMX.PKG

    xpm = {
        windows = {
            deps = { "shortcut-tool" },
            -- 默认安装简体中文版; 英文版: xlings install vc6@english
            ["latest"] = { ref = "chinese" },
            ["chinese"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/vc6/releases/download/6.0-chs/vc6-6.0-chinese-windows-x86_64.zip",
                    CN = "https://gitcode.com/xlings-res/vc6/releases/download/6.0-chs/vc6-6.0-chinese-windows-x86_64.zip",
                },
            },
            ["english"] = "XLINGS_RES",
            -- "6.0" 作为英文版别名 (向后兼容)
            ["6.0"] = "XLINGS_RES",
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.system")
import("xim.libxpkg.log")

local function __shortcut_name()
    if pkginfo.version() == "english" or pkginfo.version() == "6.0" then
        return "Visual C++ 6.0"
    end
    return "Visual C++ 6.0 中文版"
end
local MSDEV_REL = path.join("Common", "MSDev98", "BIN", "MSDEV.EXE")

function installed()
    local msdev = path.join(pkginfo.install_dir(), MSDEV_REL)
    if os.isfile(msdev) then
        return pkginfo.version()
    end
    return nil
end

function install()
    os.tryrm(pkginfo.install_dir())
    -- xlings may rename the downloaded file, so the extracted folder name
    -- (from zip internal structure) may not match install_file():replace(".zip","").
    -- Scan for the extracted folder containing MSDEV.EXE instead.
    local install_file = pkginfo.install_file()
    local extract_dir = path.directory(install_file)

    -- Try direct name match first (works for XLINGS_RES convention)
    local guessed = install_file:replace(".zip", "")
    if os.isdir(guessed) then
        os.mv(guessed, pkginfo.install_dir())
        return true
    end

    -- Fallback: find the extracted folder by looking for MSDEV.EXE
    for _, entry in ipairs(os.dirs(path.join(extract_dir, "vc6-*"))) do
        if os.isfile(path.join(entry, MSDEV_REL)) then
            os.mv(entry, pkginfo.install_dir())
            return true
        end
    end

    -- Last resort: try any directory starting with "vc6"
    for _, entry in ipairs(os.dirs(path.join(extract_dir, "vc6*"))) do
        os.mv(entry, pkginfo.install_dir())
        return true
    end

    log.error("install failed: could not find extracted VC6 directory")
    return false
end

function config()
    local msdev_path = path.join(pkginfo.install_dir(), MSDEV_REL)

    -- Set Windows XP SP3 compatibility mode + RunAsAdmin via registry
    __setup_compat_mode(msdev_path)

    -- Register package.name as binding root
    xvm.add(package.name)

    -- Register IDE launcher to xvm
    xvm.add("msdev", {
        bindir = path.join(pkginfo.install_dir(), "Common", "MSDev98", "BIN"),
        binding = package.name .. "@" .. pkginfo.version(),
    })

    -- Create desktop + start menu shortcut
    system.exec(string.format(
        [[shortcut-tool create --name "%s" --target "%s" --icon "%s"]],
        __shortcut_name(), msdev_path, msdev_path
    ))

    log.info("VC++ 6.0 installed with Windows XP SP3 compatibility mode")

    return true
end

function uninstall()
    -- Remove shortcut (try both names in case version changed)
    pcall(system.exec, string.format(
        [[shortcut-tool remove --name "%s"]], "Visual C++ 6.0 中文版"
    ))
    pcall(system.exec, string.format(
        [[shortcut-tool remove --name "%s"]], "Visual C++ 6.0"
    ))

    -- Unregister from xvm
    xvm.remove(package.name)
    xvm.remove("msdev")

    -- Clean up compatibility registry entry
    local msdev_path = path.join(pkginfo.install_dir(), MSDEV_REL)
    __cleanup_compat_mode(msdev_path)

    -- Remove install directory
    os.tryrm(pkginfo.install_dir())

    return true
end

function __setup_compat_mode(exe_path)
    local cmd = string.format(
        [[reg add "HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" /v "%s" /d "~ WINXPSP3 RUNASADMIN" /f]],
        exe_path
    )
    local ok, err = pcall(system.exec, cmd)
    if not ok then
        log.warn("Failed to set compat mode: %s", tostring(err))
    end
end

function __cleanup_compat_mode(exe_path)
    local cmd = string.format(
        [[reg delete "HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" /v "%s" /f]],
        exe_path
    )
    local ok, err = pcall(system.exec, cmd)
    if not ok then
        log.warn("Failed to clean compat registry: %s", tostring(err))
    end
end
