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
    --   1. LIEF (Python) 从英文版 67 个 PE 文件 (DLL/PKG/EXE) 中
    --      提取 RT_STRING + RT_DIALOG + RT_MENU 共 9473 条资源
    --   2. LLM 批量翻译为简体中文 (保留格式符 %s/%d、快捷键 \tCtrl+X、
    --      热键标记 & 等), 共翻译 8638 条
    --   3. LIEF 将中文 UTF-16LE 回写: 5903 strings + 242 dialogs + 4 menus
    --   4. 打包为 zip 上传至 GitHub/Gitcode xlings-res/vc6@6.0-chs
    --   工具链: https://github.com/Sunrisepeak/vc6

    xpm = {
        windows = {
            deps = { "xim:shortcut-tool" },
            -- 默认安装简体中文版; 英文版: xlings install vc6@english
            ["latest"] = { ref = "chinese" },
            ["chinese"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/vc6/releases/download/6.0-chs/vc6-chinese-windows-x86_64.zip",
                    CN = "https://gitcode.com/xlings-res/vc6/releases/download/6.0-chs/vc6-chinese-windows-x86_64.zip",
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
    local extracted = pkginfo.install_file():replace(".zip", "")
    os.mv(extracted, pkginfo.install_dir())
    return true
end

-- Traced step by step, because this hook stalls on a CI runner and three
-- guesses at which call did it were all wrong.
--
-- What is known from the instrumented run (windows-test, #554): the harness
-- reported `pkgs\v\vc6.lua (install-timeout)` at 1200s, and the last output
-- before twenty minutes of silence was vc6's own payload tick -- so the stall
-- is in HERE, after install() returned, and not in the download.
--
-- Ruled out with evidence rather than intuition:
--   * `reg add` -- it uses /f, so no overwrite prompt, and earlier runs show it
--     printing "The operation completed successfully." before the stall.
--   * wscript in shortcut-tool -- real defect, fixed, and the job that hung had
--     the fix in it (head_sha 293a1a7b) and stalled identically.
--   * the state lock, for the nested xlings that `shortcut-tool` becomes -- the
--     lock detects an ancestor holding the same home and skips, and a genuine
--     wait errors out after 30s rather than hanging.
--
-- So the next run has to say which line it reached. These logs are the whole
-- point of the change; do not "tidy" them away until the cause is known.
function config()
    local msdev_path = path.join(pkginfo.install_dir(), MSDEV_REL)

    log.info("vc6 config 1/4: compat mode (reg add) for %s", msdev_path)
    __setup_compat_mode(msdev_path)

    log.info("vc6 config 2/4: xvm.add(%s)", package.name)
    xvm.add(package.name)

    log.info("vc6 config 3/4: xvm.add(msdev)")
    xvm.add("msdev", {
        bindir = path.join(pkginfo.install_dir(), "Common", "MSDev98", "BIN"),
        binding = package.name .. "@" .. pkginfo.version(),
    })

    -- Desktop + start menu shortcut, and NOT allowed to fail the install.
    --
    -- `shortcut-tool` is a script package with no payload of its own, so this
    -- line re-enters xlings through its shim. A cosmetic shortcut is not worth
    -- failing an install over, and pcall also means a non-zero exit here stops
    -- being indistinguishable from the stall while that is still open.
    log.info("vc6 config 4/4: shortcut-tool create (re-enters xlings)")
    local ok, err = pcall(system.exec, string.format(
        [[shortcut-tool create --name "%s" --target "%s" --icon "%s"]],
        __shortcut_name(), msdev_path, msdev_path
    ))
    if not ok then
        log.warn("shortcut creation failed (not fatal): %s", tostring(err))
    end

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
