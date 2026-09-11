package = {
    spec = "1",

    -- base info
    name = "gitcode-hosts",
    description = "Config gitcode.com ip mapping-groups to hosts file",

    authors = {"sunrisepeak"},
    licenses = {"Apache-2.0"},

    -- xim pkg info
    type = "config",
    namespace = "config",

    xpm = {
        windows = { ["latest"] = { } },
        linux = { ["latest"] = { } },
        macosx = { ["latest"] = { } },
    },
}

import("xim.libxpkg.system")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.log")
import("xim.libxpkg.xvm")

local hosts_file = {
    windows = "C:/Windows/System32/drivers/etc/hosts",
    linux = "/etc/hosts",
    macosx = "/etc/hosts"
}


-- https://tools.ipip.net/newping.php
local gitcode_domain_to_ip = [[

116.205.2.91    gitcode.com
116.205.2.45    web-api.gitcode.com
58.20.209.162   cdn-static.gitcode.com
180.153.168.49  file-cdn.gitcode.com

]]

local powershell_script = [[
$source = "$env:SystemRoot\System32\drivers\etc\hosts"
$newHosts = "%s"  # 新 hosts 文件的位置

# 判断是否以管理员权限运行
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    # 重新以管理员身份运行自己
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# 检查新 hosts 文件是否存在
if (-Not (Test-Path $newHosts)) {
    Write-Error "❌ 新的 hosts 文件未找到: $newHosts"
    exit 1
}

# 覆盖原 hosts 文件
Copy-Item -Path $newHosts -Destination $source -Force
Write-Host "✅ Hosts file replaced with new content from $newHosts"
]]

local function read_hosts()
    return io.readfile(hosts_file[os.host()])
end

function installed()
    local hosts_content = read_hosts()
    if not string.find(hosts_content, "gitcode.com", 1, true) then return false end
    if not string.find(hosts_content, "web-api.gitcode.com", 1, true) then return false end
    if not string.find(hosts_content, "cdn-static.gitcode.com", 1, true) then return false end
    if not string.find(hosts_content, "file-cdn.gitcode.com", 1, true) then return false end

    return true
end

function install()
    local hosts_content = read_hosts()

    -- backup hosts file
    local backup_file = path.join(pkginfo.install_dir(), "hosts.bak")
    io.writefile(backup_file, hosts_content)

    hosts_content = hosts_content .. gitcode_domain_to_ip
    update_hosts(hosts_content)

    return true
end

function uninstall()
    local hosts_content = read_hosts()
    hosts_content = string.replace(
        hosts_content, gitcode_domain_to_ip:trim(), "",
        { plain = true }
    )
    update_hosts(hosts_content)
    return true
end

function update_hosts(new_hosts_content)
    if os.host() == "windows" then
        local new_hosts = path.join(pkginfo.install_dir(), "hosts")
        io.writefile(new_hosts, new_hosts_content)
        local tmp_script = path.join(pkginfo.install_dir(), "update_hosts.ps1")
        io.writefile(tmp_script, string.format(powershell_script, new_hosts))
        log.warn("Please to confirm the UAC dialog and waiting...")
        system.exec(string.format([[powershell -ExecutionPolicy Bypass -File "%s"]], tmp_script))
        os.sleep(1000) -- wait for the script to finish
        os.tryrm(new_hosts)
    else
        -- `stat -c` IS THE GNU FLAG, AND THIS PACKAGE DECLARES macosx.
        --
        -- macOS ships BSD stat, where the spelling is `-f%Lp` and `-c` is an
        -- error. The consequence here is worse than a failed read: the mode is
        -- captured, the file is opened up to 666 to be written, and then
        -- restored with the captured mode -- so an empty capture makes the
        -- restoring command `sudo chmod  /etc/hosts`, which fails, and the
        -- hosts file is left WORLD-WRITABLE. Found while fixing the identical
        -- flag in pkgs/a/android-ndk.lua.
        local target = hosts_file[os.host()]
        local stat_flag = is_host("macosx") and [[-f "%Lp"]] or [[-c "%a"]]
        local permission = os.iorun("stat " .. stat_flag .. " " .. target)
        permission = (permission or ""):match("%d+")
        -- AND THE MODE IS NOT OPTIONAL. Without this the failure above is
        -- silent; refusing before the file is opened up leaves it as it was.
        if not permission then
            raise("gitcode-hosts: could not read the current mode of "
                  .. target .. "; refusing to open it up for writing, because "
                  .. "the mode could not then be restored")
        end
        system.exec("sudo chmod 666 " .. target)
        io.writefile(target, new_hosts_content)
        system.exec("sudo chmod " .. permission .. " " .. target)
    end
end