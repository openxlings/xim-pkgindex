package = {
    spec = "1",

    -- base info
    name = "virtualbox",
    description = "Oracle VM VirtualBox userspace + VBoxManage CLI (portable, alias: vbox)",
    homepage = "https://www.virtualbox.org",
    maintainers = {"Oracle"},
    licenses = {"GPL-3.0"},
    repo = "https://www.virtualbox.org",
    docs = "https://docs.oracle.com/en/virtualization/virtualbox/",

    -- xim pkg info
    type = "package",
    archs = {"x86_64"},
    status = "stable", -- dev, stable, deprecated
    categories = {"virtualization", "vm", "hypervisor"},
    keywords = {"virtualbox", "vbox", "vm", "virtualization"},

    xvm_enable = true,

    -- Portable userspace: a repackaged, relocatable ($ORIGIN RPATH) build of
    -- the VirtualBox Linux userspace, hosted on the xlings-res mirror. It
    -- installs entirely under the xpkgs dir (no system clash, xvm-managed,
    -- version-switchable). Windows/macOS use a different installer layout and
    -- still need on-device validation, so only linux is declared for now.
    xpm = {
        linux = {
            ["latest"] = { ref = "7.2.8" },
            ["7.2.8"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/vbox/releases/download/7.2.8/virtualbox-7.2.8-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/vbox/releases/download/7.2.8/virtualbox-7.2.8-linux-x86_64.tar.gz",
                },
                sha256 = "803e7b6b5bb20a7b99cf19613fabf08ed3c5252fc1da629d4684ea8868f39ffc",
            },
        },
        ubuntu = { ref = "linux" },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

function installed()
    -- Check OUR xpkgs install only — never a system/distro VirtualBox on PATH
    -- (e.g. /usr/bin/VBoxManage), so install() always provisions the portable
    -- userspace and the two never get confused.
    return os.isfile(path.join(pkginfo.install_dir(), "VBoxManage"))
end

function install()
    local idir = pkginfo.install_dir()
    os.tryrm(idir)

    -- Prefer moving the framework-extracted tree (builtin os.mv is reliable);
    -- fall back to self-extracting the tarball, stripping the top-level
    -- virtualbox-<ver>-linux-x86_64/ wrapper.
    local srcdir = pkginfo.install_file():gsub("%.tar%.gz$", "")
    if os.isdir(srcdir) then
        os.mv(srcdir, idir)
    else
        os.mkdir(idir)
        os.exec(string.format([[tar xzf "%s" -C "%s" --strip-components=1]], pkginfo.install_file(), idir))
    end
    return true
end

function config()
    local idir = pkginfo.install_dir()

    -- VBOX_APP_HOME tells VirtualBox where its components live so the
    -- relocated userspace finds XPCOM components / unattended templates.
    xvm.add("VBoxManage", { bindir = idir, envs = { VBOX_APP_HOME = idir } })
    xvm.add("VBoxHeadless", { bindir = idir, envs = { VBOX_APP_HOME = idir } })
    xvm.add("vbox", { bindir = idir, alias = "VBoxManage", envs = { VBOX_APP_HOME = idir } })

    log.info("Registered VBoxManage / VBoxHeadless to xvm (alias 'vbox').")
    log.warn("Booting a VM still needs the host kernel driver (vboxdrv): one-time")
    log.warn("  sudo %s/vboxdrv.sh setup   (system-wide; needs dkms + kernel headers)", idir)
    return true
end

function uninstall()
    xvm.remove("VBoxManage")
    xvm.remove("VBoxHeadless")
    xvm.remove("vbox")
    -- userspace lives entirely under the xpkgs install dir; the framework
    -- removes it. The shared kernel driver (if set up) is left untouched.
    return true
end
