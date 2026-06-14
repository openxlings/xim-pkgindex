package = {
    spec = "1",

    -- base info
    name = "virtualbox-ubuntu",
    description = "Provision a ready-to-use Ubuntu 24.04 VM in VirtualBox (unattended install)",
    homepage = "https://ubuntu.com",
    maintainers = {"Canonical"},
    licenses = {"GPL-3.0"},
    repo = "https://github.com/openxlings/xim-pkgindex",
    docs = "https://www.virtualbox.org/manual/topics/vboxmanage.html#vboxmanage-unattended",

    -- xim pkg info
    type = "package",
    namespace = "config",
    archs = {"x86_64"},
    status = "stable", -- dev, stable, deprecated
    categories = {"virtualization", "vm", "ubuntu"},
    keywords = {"virtualbox", "ubuntu", "24.04", "vm", "unattended"},

    xvm_enable = true,

    xpm = {
        windows = {
            deps = { "virtualbox" },
            ["latest"] = { ref = "24.04.4" },
            ["24.04.4"] = { },
        },
        linux = {
            deps = { "virtualbox" },
            ["latest"] = { ref = "24.04.4" },
            ["24.04.4"] = { },
        },
        ubuntu = { ref = "linux" },
        macosx = {
            deps = { "virtualbox" },
            ["latest"] = { ref = "24.04.4" },
            ["24.04.4"] = { },
        },
    },
}

import("xim.libxpkg.system")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.log")

local UBUNTU_VERSION = "24.04.4"
local ISO_FILE = "ubuntu-" .. UBUNTU_VERSION .. "-desktop-amd64.iso"
local ISO_URL  = "https://releases.ubuntu.com/24.04/" .. ISO_FILE

-- VM defaults (overridable through environment variables)
local function env(name, default)
    local v = os.getenv(name)
    if v == nil or v == "" then return default end
    return v
end

local function vm_settings()
    return {
        name     = env("VBOX_UBUNTU_VM_NAME", "ubuntu-24.04"),
        cpus     = env("VBOX_UBUNTU_CPUS", "2"),
        ram      = env("VBOX_UBUNTU_RAM_MB", "4096"),
        disk     = env("VBOX_UBUNTU_DISK_MB", "40000"),
        user     = env("VBOX_UBUNTU_USER", "xlings"),
        password = env("VBOX_UBUNTU_PASSWORD", "xlings"),
        headless = env("VBOX_UBUNTU_HEADLESS", "true"),
    }
end

function installed()
    local vm = env("VBOX_UBUNTU_VM_NAME", "ubuntu-24.04")
    local ok, output = pcall(os.iorun, "VBoxManage list vms")
    if ok and output and string.find(output, '"' .. vm .. '"', 1, true) then
        return true
    end
    return false
end

function install()
    local ok = pcall(os.iorun, "VBoxManage --version")
    if not ok then
        log.error("VBoxManage not found. Install the 'virtualbox' package first.")
        return false
    end

    local cfg = vm_settings()
    local workdir = pkginfo.install_dir()
    os.mkdir(workdir)

    local iso = path.join(workdir, ISO_FILE)
    if not os.isfile(iso) then
        log.info("Downloading Ubuntu %s desktop ISO (~6GB, this may take a while)...", UBUNTU_VERSION)
        system.exec(string.format([[curl -L -o "%s" "%s"]], iso, ISO_URL))
    else
        log.info("Reusing cached ISO: %s", iso)
    end

    local vdi = path.join(workdir, cfg.name .. ".vdi")

    log.info("Creating VM '%s' (%s vCPU, %s MB RAM, %s MB disk)...", cfg.name, cfg.cpus, cfg.ram, cfg.disk)
    system.exec(string.format([[VBoxManage createvm --name "%s" --ostype Ubuntu_64 --register]], cfg.name))
    system.exec(string.format([[VBoxManage modifyvm "%s" --cpus %s --memory %s --vram 16 --nic1 nat --graphicscontroller vmsvga]],
        cfg.name, cfg.cpus, cfg.ram))
    system.exec(string.format([[VBoxManage createmedium disk --filename "%s" --size %s --format VDI]], vdi, cfg.disk))
    system.exec(string.format([[VBoxManage storagectl "%s" --name SATA --add sata --controller IntelAhci]], cfg.name))
    system.exec(string.format([[VBoxManage storageattach "%s" --storagectl SATA --port 0 --device 0 --type hdd --medium "%s"]],
        cfg.name, vdi))

    local start_mode = (cfg.headless == "true") and "headless" or "gui"
    log.info("Starting unattended Ubuntu installation (mode: %s)...", start_mode)
    system.exec(string.format(
        [[VBoxManage unattended install "%s" --iso="%s" --user="%s" --password="%s" --full-user-name="%s" --hostname=ubuntu2404.local --install-additions --start-vm=%s]],
        cfg.name, iso, cfg.user, cfg.password, cfg.user, start_mode))

    log.info("VM '%s' is installing Ubuntu. Default login: %s / %s (change the password after first boot).",
        cfg.name, cfg.user, cfg.password)
    return true
end

function config()
    local cfg = vm_settings()
    log.info("Manage the VM with VBoxManage (alias 'vbox'):")
    log.info("  start:  VBoxManage startvm \"%s\" --type headless", cfg.name)
    log.info("  stop:   VBoxManage controlvm \"%s\" acpipowerbutton", cfg.name)
    log.info("  list:   VBoxManage list runningvms")
    return true
end

function uninstall()
    local cfg = vm_settings()
    log.info("Removing VM '%s'...", cfg.name)
    system.exec(string.format([[VBoxManage controlvm "%s" poweroff || true]], cfg.name))
    system.exec(string.format([[VBoxManage unregistervm "%s" --delete || true]], cfg.name))
    return true
end
