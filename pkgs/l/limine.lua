package = {
    spec = "1",

    name = "limine",
    description = "Limine: the boot loader of Luban images (BIOS and UEFI; ISO, drives)",

    homepage = "https://limine-bootloader.org",
    repo = "https://github.com/limine-bootloader/limine",
    licenses = {"BSD-2-Clause"},

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"system", "boot"},
    keywords = {"limine", "bootloader", "uefi", "bios", "iso", "luban"},

    -- What `xlings subos export --iso / --drive` (`luban export x.iso / x.img`)
    -- boots with: upstream's prebuilt boot files (limine-bios-cd.bin,
    -- limine-bios.sys, limine-uefi-cd.bin, BOOT*.EFI) into share/limine, where
    -- xlings looks for them. The `limine` tool (bios-install: a drive or a
    -- hybrid ISO that a BIOS boots) is one C file, built here when a C
    -- compiler is; without it an export still boots on UEFI (and an ISO from
    -- a CD), and says so.
    programs = {"limine"},
    xvm_enable = true,

    xpm = {
        linux = {
            ["latest"] = { ref = "12.9.3" },
            ["12.9.3"] = {
                url = "https://github.com/limine-bootloader/limine/releases/download/v12.9.3/limine-binary.tar.gz",
                sha256 = "9f42fe9ea2e84d71056529969b1d5c24ba9a2287ffcc01bcce58b0ef8aa98b1d",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

local function q(s) return "'" .. s:gsub("'", "'\\''") .. "'" end

function install()
    local dir = pkginfo.install_dir()
    local src = "limine-binary"
    if not os.isdir(src) then error("limine: the release archive has no limine-binary/") end
    os.tryrm(dir)
    os.mkdir(path.join(dir, "share", "limine"))
    os.mkdir(path.join(dir, "bin"))
    for _, f in ipairs({"limine-bios-cd.bin", "limine-bios.sys", "limine-uefi-cd.bin", "limine-bios-pxe.bin",
                        "BOOTX64.EFI", "BOOTAA64.EFI", "BOOTIA32.EFI", "BOOTRISCV64.EFI", "LICENSE"}) do
        if os.isfile(path.join(src, f)) then os.cp(path.join(src, f), path.join(dir, "share", "limine", f)) end
    end
    -- The tool: static where the C library allows, else as it links here.
    local tool = path.join(dir, "bin", "limine")
    local c = path.join(src, "limine.c")
    local built = pcall(system.exec, "cc -O2 -std=gnu11 -static -o " .. q(tool) .. " " .. q(c))
        or pcall(system.exec, "cc -O2 -std=gnu11 -o " .. q(tool) .. " " .. q(c))
    if not built then
        log.warn("limine: no C compiler here -- the boot files are installed; `limine bios-install` is not "
                 .. "(drives boot with UEFI, ISOs from a CD)")
    end
    return os.isfile(path.join(dir, "share", "limine", "limine-bios-cd.bin"))
end

function config()
    if os.isfile(path.join(pkginfo.install_dir(), "bin", "limine")) then
        xvm.add("limine", { bindir = path.join(pkginfo.install_dir(), "bin") })
    end
    return true
end

function uninstall()
    xvm.remove("limine")
    return true
end
