package = {
    spec = "1",

    -- base info
    name = "virtualbox",
    description = "Oracle VM VirtualBox hypervisor + VBoxManage CLI (alias: vbox)",
    homepage = "https://www.virtualbox.org",
    maintainers = {"Oracle"},
    licenses = {"GPL-3.0"},
    repo = "https://www.virtualbox.org",
    docs = "https://docs.oracle.com/en/virtualization/virtualbox/",

    -- xim pkg info
    type = "package",
    namespace = "config",
    archs = {"x86_64"},
    status = "stable", -- dev, stable, deprecated
    categories = {"virtualization", "vm", "hypervisor"},
    keywords = {"virtualbox", "vbox", "vm", "virtualization"},

    xvm_enable = true,

    xpm = {
        windows = {
            ["latest"] = { ref = "7.2.8" },
            ["7.2.8"] = { },
        },
        linux = {
            ["latest"] = { ref = "7.2.8" },
            ["7.2.8"] = { },
        },
        ubuntu = { ref = "linux" },
        macosx = {
            ["latest"] = { ref = "7.2.8" },
            ["7.2.8"] = { },
        },
    },
}

import("xim.libxpkg.system")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

local VBOX_VERSION = "7.2.8"
local VBOX_BUILD   = "173730"
local VBOX_BASEURL = "https://download.virtualbox.org/virtualbox/" .. VBOX_VERSION .. "/"

local installer_file = {
    windows = "VirtualBox-" .. VBOX_VERSION .. "-" .. VBOX_BUILD .. "-Win.exe",
    linux   = "VirtualBox-" .. VBOX_VERSION .. "-" .. VBOX_BUILD .. "-Linux_amd64.run",
    macosx  = "VirtualBox-" .. VBOX_VERSION .. "-" .. VBOX_BUILD .. "-OSX.dmg",
}

-- directory that holds the VBoxManage executable after a system install
local vboxmanage_bindir = {
    windows = "C:/Program Files/Oracle/VirtualBox",
    linux   = "/usr/bin",
    macosx  = "/usr/local/bin",
}

function installed()
    local ok, output = pcall(os.iorun, "VBoxManage --version")
    if ok and output and string.find(output, "%d+%.%d+%.%d+") then
        return output:match("(%d+%.%d+%.%d+)") or true
    end
    return false
end

function install()
    local host = os.host()
    local url = VBOX_BASEURL .. installer_file[host]

    log.info("Downloading VirtualBox %s for %s ...", VBOX_VERSION, host)

    if host == "windows" then
        local out = installer_file[host]
        system.exec(string.format([[curl -L -o "%s" "%s"]], out, url))
        -- Oracle-supported silent install (installs hypervisor + drivers).
        log.warn("Installing VirtualBox silently (requires administrator privileges)...")
        system.exec(string.format([[%s --silent --ignore-reboot]], out))
    elseif host == "macosx" then
        local out = installer_file[host]
        system.exec(string.format([[curl -L -o "%s" "%s"]], out, url))
        system.exec(string.format([[hdiutil attach "%s" -mountpoint /Volumes/VirtualBox]], out))
        log.warn("Installing VirtualBox (requires sudo; approve the Oracle kernel extension in System Settings > Privacy & Security)...")
        system.exec([[sudo installer -pkg /Volumes/VirtualBox/VirtualBox.pkg -target /]])
        system.exec([[hdiutil detach /Volumes/VirtualBox]])
    else
        -- linux / ubuntu: the .run installer builds the vboxdrv kernel module.
        local out = installer_file[host]
        log.warn("Installing kernel-module build prerequisites (dkms, headers)...")
        system.exec([[sudo apt-get update]])
        system.exec([[sudo apt-get install -y dkms build-essential linux-headers-$(uname -r)]])
        system.exec(string.format([[curl -L -o "%s" "%s"]], out, url))
        system.exec(string.format([[chmod +x "%s"]], out))
        log.warn("Installing VirtualBox (requires sudo; builds the vboxdrv kernel module)...")
        system.exec(string.format([[sudo sh "%s"]], out))
        -- allow the current user to manage USB / VMs without root
        system.exec([[sudo usermod -aG vboxusers "$USER" || true]])
    end

    log.info("VirtualBox installed. Note: a reboot may be required for kernel drivers to load.")
    return true
end

function config()
    local host = os.host()
    local bindir = vboxmanage_bindir[host]

    -- expose the VirtualBox CLI through xvm, plus a short `vbox` alias
    xvm.add("VBoxManage", { bindir = bindir })
    xvm.add("vbox", { bindir = bindir, alias = "VBoxManage" })

    log.info("Registered 'VBoxManage' and alias 'vbox' to xvm.")
    return true
end

function uninstall()
    xvm.remove("VBoxManage")
    xvm.remove("vbox")

    local host = os.host()
    if host == "windows" then
        log.warn("Uninstall VirtualBox from 'Apps & features', or run the installer with --uninstall.")
    elseif host == "macosx" then
        log.warn("Run the VirtualBox_Uninstall.tool from the VirtualBox disk image to fully remove it.")
    else
        system.exec([[sudo /opt/VirtualBox/uninstall.sh || true]])
    end
    return true
end
