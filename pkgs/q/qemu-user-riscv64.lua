package = {
    spec = "2",
    homepage = "https://github.com/multiarch/qemu-user-static",

    name = "qemu-user-riscv64",
    description = "qemu-riscv64-static - run riscv64 Linux binaries on an x86_64 host",

    maintainers = {"https://github.com/multiarch/qemu-user-static/graphs/contributors"},
    licenses = {"GPL-2.0-only"},
    repo = "https://github.com/multiarch/qemu-user-static",
    docs = "https://github.com/multiarch/qemu-user-static#readme",
    ci = { mirror = true },

    type = "package",
    -- User-mode emulation runs one foreign Linux executable on this host; the
    -- payload is published for x86_64 hosts. It is the runner of mcpp's
    -- riscv64-linux-musl row, whose programs are static, so no `-L` sysroot is
    -- needed. The shape, and the reasons for it, are qemu-user-aarch64's.
    archs = {"x86_64"},
    status = "stable",
    categories = {"emulator", "cross", "riscv64"},
    keywords = {"qemu", "user-mode", "riscv64", "cross", "binfmt", "static"},

    programs = {"qemu-riscv64-static"},
    xvm_enable = true,

    -- Measured on the payload: one statically linked x86_64 ELF at the
    -- archive's root (`tar tzf` lists exactly `qemu-riscv64-static`), no
    -- DT_NEEDED entries. The version drops upstream's `-1` packaging suffix,
    -- as qemu-user-aarch64 does; the tag carries it.
    extensions = {
        autoupdate = {
            source = "https://github.com/multiarch/qemu-user-static/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = "https://github.com/multiarch/qemu-user-static/releases/download/v${version}-1/x86_64_qemu-riscv64-static.tar.gz",
                    },
                    required = true,
                },
            },
            tag = "v${version}-1",
        },
    },

    xpm = {
        linux = {
            ["latest"] = { ref = "7.2.0" },
            ["7.2.0"] = {
                url = "https://github.com/multiarch/qemu-user-static/releases/download/v7.2.0-1/x86_64_qemu-riscv64-static.tar.gz",
                sha256 = "893b536c8a5c31d8b10c7e13b8a63a836260387ca88d1007da670ce495f1191a",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mkdir(path.join(dir, "bin"))

    local base = path.directory(pkginfo.install_file())
    local src = path.join(base, "qemu-riscv64-static")
    if not os.isfile(src) then
        raise("qemu-user-riscv64 payload has no qemu-riscv64-static under '"
              .. base .. "'")
    end

    local dst = path.join(dir, "bin", "qemu-riscv64-static")
    os.cp(src, dst)
    system.exec("chmod +x " .. dst)

    -- An emulator that unpacks and cannot run is found here, not by the first
    -- program it should have started.
    local out = try { function() return os.iorun(dst .. " --version") end }
    if not out or not out:find("qemu-riscv64", 1, true) then
        raise("qemu-user-riscv64: the installed binary does not run "
              .. "(`--version` said: " .. tostring(out) .. ")")
    end

    return true
end

function config()
    xvm.add(package.name)
    xvm.add("qemu-riscv64-static", {
        bindir = path.join(pkginfo.install_dir(), "bin"),
    })
    return true
end

function uninstall()
    xvm.remove("qemu-riscv64-static")
    xvm.remove(package.name)
    return true
end
