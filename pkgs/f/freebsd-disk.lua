package = {
    spec = "2",
    homepage = "https://www.freebsd.org/",

    name = "freebsd-disk",
    description = "FreeBSD 14.5-RELEASE boot disk (x86_64 qcow2, zstd-compressed clusters, serial console) that a virtual-machine runner boots to run x86_64-freebsd artifacts",

    maintainers = {"https://github.com/xlings-res/freebsd-disk"},
    licenses = {"BSD-2-Clause", "BSD-3-Clause"},
    repo = "https://github.com/xlings-res/freebsd-disk",
    docs = "https://github.com/mcpplibs/openkal-freebsd",

    type = "package",
    -- Host arches, not target ones: the disk boots under qemu-system-x86_64
    -- wherever that runs.
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"runner", "freebsd"},
    keywords = {"freebsd", "disk", "qcow2", "runner", "mcpp"},

    xvm_enable = true,

    -- UPSTREAM: The FreeBSD Project's 14.5-RELEASE, installed from the
    -- official installer disc (disc1.iso of
    -- download.freebsd.org/releases/amd64/amd64/ISO-IMAGES/14.5/) into one
    -- qcow2 disk, then configured for a machine with no display: the
    -- loader's console moves to comconsole and getty answers on ttyu0, so a
    -- driver script that speaks to the serial line can log in and run
    -- commands. The disk is not bootable on physical hardware as shipped --
    -- it is the base a virtual-machine runner copies, read-only, under a
    -- per-run overlay (qemu-img create -b <disk>). No programs: a disk, not
    -- a tool; the entry a runner declaration names lives in the
    -- openkal-freebsd repository (tools/vm-runner), and that entry boots
    -- this disk. The version is FreeBSD's; the clusters are
    -- zstd-compressed (2.5 GiB of base squeezed under 900 MiB on this tag).

    xpm = {
        source = {
            GLOBAL = "https://github.com/xlings-res/freebsd-disk/releases/download/${version}/freebsd-disk-${version}.tar.xz",
            CN = "https://gitcode.com/xlings-res/freebsd-disk/releases/download/${version}/freebsd-disk-${version}.tar.xz",
        },
        linux = {
            ["latest"] = { ref = "14.5" },
            ["14.5"] = { sha256 = "7844bcb147fc988c26193d6c91b5db9077edae5d64d63f523e97c9d681f58a49" },
        },
        macosx = {
            ["latest"] = { ref = "14.5" },
            ["14.5"] = { sha256 = "7844bcb147fc988c26193d6c91b5db9077edae5d64d63f523e97c9d681f58a49" },
        },
        -- qemu-system-x86_64 of a Windows host is not a measured consumer
        -- here; the table stays absent rather than guessed at.
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function config()
    xvm.add(package.name)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
