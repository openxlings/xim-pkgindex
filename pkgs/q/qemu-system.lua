package = {
    spec = "2",
    homepage = "https://www.qemu.org/",

    name = "qemu-system",
    description = "qemu-system-x86_64 and qemu-system-aarch64, static, with user networking and their firmware",

    licenses = {"GPL-2.0-only"},
    repo = "https://gitlab.com/qemu-project/qemu",
    docs = "https://www.qemu.org/docs/master/",

    programs = {"qemu-system-x86_64", "qemu-system-aarch64"},

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"emulator", "virtualization"},
    keywords = {"qemu", "x86_64", "aarch64", "emulator", "virtual machine", "luban"},

    xvm_enable = true,

    -- What `luban try` boots an image with, on either machine (xlings: the
    -- aarch64 design §12.3). Built by tools/res/build.sh qemu-system: static
    -- (musl), both system targets, user networking from libslirp built static
    -- -- `-nic user,restrict=on,guestfwd=...` is how a private machine reaches
    -- only its proxy, and neither qemu-x86 nor xPack's qemu-arm has the `user`
    -- backend -- and the firmware (SeaBIOS, EDK II for x86_64 and aarch64)
    -- decompressed in share/qemu, found relative to the executable.
    --
    -- Static, so `deps` is empty: nothing for elfpatch to relocate, and no
    -- loader to hand it.
    xpm = {
        linux = {
            ["latest"] = { ref = "9.2.4" },
            ["9.2.4"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/qemu-system/releases/download/9.2.4-r1/qemu-system-9.2.4-r1-linux-x86_64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/qemu-system/releases/download/9.2.4-r1/qemu-system-9.2.4-r1-linux-x86_64.tar.gz",
                    },
                    sha256 = "e274e596559a75b158e320655c020ed5a001c6656161ab90163a183a9672a7cc",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/qemu-system/releases/download/9.2.4-r1/qemu-system-9.2.4-r1-linux-aarch64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/qemu-system/releases/download/9.2.4-r1/qemu-system-9.2.4-r1-linux-aarch64.tar.gz",
                    },
                    sha256 = "bd089b44af0b1287f47e5345f7683b7a2fbcb8797520f685405e9475a001c2a5",
                },
                -- r1: built with prefix /usr, so qemu finds share/qemu beside
                -- itself (r0's looked in /share/qemu and had no option ROMs).
                -- r2: the emulators bind to the package's release.
                revision = 2,
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    local dir = pkginfo.install_dir()
    -- The archive's root is its own name: qemu-system-<version>-linux-<arch>/.
    local payload = pkginfo.install_file():replace(".tar.gz", "")
    if os.isdir(payload) then
        os.tryrm(dir)
        os.mv(payload, dir)
    end
    -- Both emulators and the firmware they boot with, or it is not the payload:
    -- qemu finds share/qemu relative to itself, and an emulator without it
    -- answers --version and boots nothing.
    for _, f in ipairs({"bin/qemu-system-x86_64", "bin/qemu-system-aarch64",
                        "share/qemu/bios-256k.bin", "share/qemu/edk2-x86_64-code.fd",
                        "share/qemu/edk2-aarch64-code.fd"}) do
        if not os.isfile(path.join(dir, f)) then
            raise("qemu-system payload is missing " .. f)
        end
    end
    return true
end

function config()
    -- The package name anchors the release; both emulators bind to it, so
    -- `xlings use qemu-system@<v>` moves them together.
    local bindir = path.join(pkginfo.install_dir(), "bin")
    local release = package.name .. "@" .. pkginfo.version()
    xvm.add(package.name)
    xvm.add("qemu-system-x86_64", { bindir = bindir, binding = release })
    xvm.add("qemu-system-aarch64", { bindir = bindir, binding = release })
    return true
end

function uninstall()
    xvm.remove("qemu-system-x86_64")
    xvm.remove("qemu-system-aarch64")
    xvm.remove(package.name)
    return true
end
