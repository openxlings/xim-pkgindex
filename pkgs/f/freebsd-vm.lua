package = {
    spec = "2",
    homepage = "https://www.freebsd.org/",

    name = "freebsd-vm",
    description = "FreeBSD 14.5-RELEASE base VM image (x86_64, qcow2 with zstd-compressed clusters, serial console) for running x86_64-freebsd artifacts under qemu",

    maintainers = {"https://github.com/xlings-res/freebsd-vm"},
    licenses = {"BSD-2-Clause", "BSD-3-Clause"},
    repo = "https://github.com/xlings-res/freebsd-vm",
    docs = "https://github.com/mcpplibs/openkal-freebsd",

    type = "package",
    -- Host arches, not target ones: the image boots under qemu-system-x86_64
    -- wherever that runs.
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"runner", "vm", "freebsd"},
    keywords = {"freebsd", "vm", "qcow2", "runner", "mcpp"},

    xvm_enable = true,

    -- No programs: an image, not a tool. The entry a runner declaration
    -- names lives in the openkal-freebsd repository (tools/vm-runner); this
    -- package is the image it boots -- one qcow2 whose clusters are
    -- zstd-compressed (2.5 GiB of base squeezed to 877 MiB on this tag), of
    -- a minimal base configured for serial-console use: the loader's console
    -- moves to comconsole and getty answers on ttyu0, so a driver script
    -- that speaks to the serial line can log in and run commands. The
    -- consumer's own overlay (qemu-img create -b <image>) keeps this file
    -- read-only across runs, the same discipline openkal-freebsd's vm-run
    -- applies. The version is FreeBSD's.

    xpm = {
        source = {
            GLOBAL = "https://github.com/xlings-res/freebsd-vm/releases/download/${version}/freebsd-vm-${version}.tar.xz",
            CN = "https://gitcode.com/xlings-res/freebsd-vm/releases/download/${version}/freebsd-vm-${version}.tar.xz",
        },
        linux = {
            ["latest"] = { ref = "14.5" },
            ["14.5"] = { sha256 = "b4316fabafa6f664599b61050c02b35c4e6bac9832266d796aca707261bbc735" },
        },
        macosx = {
            ["latest"] = { ref = "14.5" },
            ["14.5"] = { sha256 = "b4316fabafa6f664599b61050c02b35c4e6bac9832266d796aca707261bbc735" },
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
