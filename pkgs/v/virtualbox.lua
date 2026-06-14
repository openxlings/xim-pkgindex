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
            ["7.2.8"] = {
                url = {
                    GLOBAL = "https://download.virtualbox.org/virtualbox/7.2.8/VirtualBox-7.2.8-173730-Win.exe",
                    CN     = "https://gitcode.com/xlings-res/vbox/releases/download/7.2.8/VirtualBox-7.2.8-173730-Win.exe",
                },
                sha256 = "ae5415cc968c0e8acddd99358c21d267a2c31ac4ff5182861aab9e6931001606",
            },
        },
        linux = {
            ["latest"] = { ref = "7.2.8" },
            ["7.2.8"] = {
                url = {
                    GLOBAL = "https://download.virtualbox.org/virtualbox/7.2.8/VirtualBox-7.2.8-173730-Linux_amd64.run",
                    CN     = "https://gitcode.com/xlings-res/vbox/releases/download/7.2.8/VirtualBox-7.2.8-173730-Linux_amd64.run",
                },
                sha256 = "c878868d9b9e849d051c6248fc5b2d5b75411365840c5a7857b09f112629cb57",
            },
        },
        ubuntu = { ref = "linux" },
        macosx = {
            ["latest"] = { ref = "7.2.8" },
            ["7.2.8"] = {
                url = {
                    GLOBAL = "https://download.virtualbox.org/virtualbox/7.2.8/VirtualBox-7.2.8-173730-OSX.dmg",
                    CN     = "https://gitcode.com/xlings-res/vbox/releases/download/7.2.8/VirtualBox-7.2.8-173730-OSX.dmg",
                },
                sha256 = "77a7deef70f4e68b261856eda43650335f4db5fbf7223320ebd1c78e5cddc473",
            },
        },
    },
}

import("xim.libxpkg.system")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

-- directory that holds the VBoxManage executable after a system install.
-- VirtualBox ships a kernel driver (vboxdrv) and must be installed
-- system-side; the official installer places VBoxManage here. The xvm
-- shim below just routes to wherever VBoxManage actually lands.
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
    -- installer is fetched by the framework via the xpm multi-mirror url
    -- (GLOBAL=download.virtualbox.org, CN=gitcode xlings-res/vbox);
    -- pkginfo.install_file() is the downloaded, sha256-verified installer.
    local installer = pkginfo.install_file()
    log.info("Installing VirtualBox from %s ...", installer)

    if host == "windows" then
        -- Oracle-supported silent install (installs hypervisor + drivers).
        log.warn("Installing VirtualBox silently (requires administrator privileges)...")
        system.exec(string.format([["%s" --silent --ignore-reboot]], installer))
    elseif host == "macosx" then
        system.exec(string.format([[hdiutil attach "%s" -mountpoint /Volumes/VirtualBox]], installer))
        log.warn("Installing VirtualBox (requires sudo; approve the Oracle kernel extension in System Settings > Privacy & Security)...")
        system.exec([[sudo installer -pkg /Volumes/VirtualBox/VirtualBox.pkg -target /]])
        system.exec([[hdiutil detach /Volumes/VirtualBox]])
    else
        -- linux / ubuntu: the .run installer builds the vboxdrv kernel module.
        log.warn("Installing kernel-module build prerequisites (dkms, headers)...")
        system.exec([[sudo apt-get update]])
        system.exec([[sudo apt-get install -y dkms build-essential linux-headers-$(uname -r)]])
        system.exec(string.format([[chmod +x "%s"]], installer))
        log.warn("Installing VirtualBox (requires sudo; builds the vboxdrv kernel module)...")
        system.exec(string.format([[sudo sh "%s"]], installer))
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
