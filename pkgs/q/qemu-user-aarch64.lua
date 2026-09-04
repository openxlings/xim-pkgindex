package = {
    spec = "2",
    homepage = "https://github.com/multiarch/qemu-user-static",

    name = "qemu-user-aarch64",
    description = "qemu-aarch64-static - run aarch64 Linux binaries on an x86_64 host",

    maintainers = {"https://github.com/multiarch/qemu-user-static/graphs/contributors"},
    licenses = {"GPL-2.0-only"},
    repo = "https://github.com/multiarch/qemu-user-static",
    docs = "https://github.com/multiarch/qemu-user-static#readme",
    ci = { mirror = true, update = true },

    type = "package",
    -- x86_64 only, and that is the whole point rather than a gap: this is
    -- USER-MODE emulation, which exists to run a foreign-architecture binary
    -- on this host. On an aarch64 host an aarch64 binary just runs.
    archs = {"x86_64"},
    status = "stable",
    categories = {"emulator", "cross", "aarch64"},
    keywords = {"qemu", "user-mode", "aarch64", "cross", "binfmt", "static"},

    programs = {"qemu-aarch64-static"},
    xvm_enable = true,

    -- WHY THIS IS NOT `qemu-arm`, WHICH THIS INDEX ALREADY HAS.
    --
    -- `qemu-arm` is SYSTEM emulation: `qemu-system-aarch64` boots a machine --
    -- firmware, kernel, virtual devices -- which is what the bare-metal work
    -- needs. This is USER emulation: `qemu-aarch64-static` runs one Linux
    -- executable, translating instructions and forwarding syscalls to the
    -- host kernel. Neither substitutes for the other, and the names are close
    -- enough that the distinction is worth stating where somebody will read
    -- it.
    --
    -- What made it worth packaging: xlings' own aarch64 CI cross-builds a
    -- release candidate and then RUNS it, which needs exactly this. It got it
    -- from `apt-get install qemu-user-static`, and on 2026-08-27 that step
    -- failed on every job because the runner image ships Microsoft apt
    -- sources that answer 403 -- a repository nothing in that job installs
    -- from. An ecosystem that can supply its own toolchain should not have a
    -- test that cannot run because a distribution repository is unhappy.
    --
    -- STATIC, and that is why there are no `deps` here. Measured on the
    -- payload (2026-08-27): `readelf -d` reports zero DT_NEEDED entries --
    -- `ELF 64-bit LSB executable, x86-64, statically linked`. Nothing crosses
    -- the payload boundary, so there is no glibc edge to declare and no
    -- interpreter for elfpatch to rewrite. It is also what makes the binary
    -- usable as a binfmt_misc handler, which is the shape most callers want.
    --
    -- The asset is the HOST-PREFIXED one, `x86_64_qemu-aarch64-static.tar.gz`,
    -- not the bare `qemu-aarch64-static.tar.gz`. Both exist upstream and both
    -- are byte-identical today (sha256 b5dd968d…, verified against each other
    -- after download) -- the prefixed name says which host it is FOR, and a
    -- name that carries its own meaning is worth more than one that has to be
    -- remembered.
    --
    -- 7.2.0-1 is upstream's current release. The version here drops the `-1`
    -- packaging suffix so the key stays dotted digits: this index resolves
    -- ranges with select_best, which takes the MAXIMUM satisfying version, and
    -- an alpha segment sorts BELOW the plain one -- `2.44r1` was measured to
    -- be a pre-release of 2.44 to every range expression (see glibc.lua). The
    -- upstream tag is carried in `source` instead, where nothing sorts it.
    xpm = {
        linux = {
            ["latest"] = { ref = "7.2.0" },
            ["7.2.0"] = {
                url = "https://github.com/multiarch/qemu-user-static/releases/download/v7.2.0-1/x86_64_qemu-aarch64-static.tar.gz",
                sha256 = "b5dd968d522fd5d615d27c77fb1ca0847455d0b8badd7492647e7ab674339247",
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

    -- The archive is one file at its root, with no wrapping directory --
    -- verified with `tar tzf`, which lists exactly `qemu-aarch64-static`. So
    -- the extraction directory IS the payload, and there is no root to move.
    local base = path.directory(pkginfo.install_file())
    local src = path.join(base, "qemu-aarch64-static")
    if not os.isfile(src) then
        raise("qemu-user-aarch64 payload has no qemu-aarch64-static under '"
              .. base .. "'")
    end

    local dst = path.join(dir, "bin", "qemu-aarch64-static")
    os.cp(src, dst)
    -- `system.exec`, not `os.run`: the xim Lua sandbox does not expose the
    -- latter, and the failure is a nil-field call from inside the hook rather
    -- than anything that names chmod.
    system.exec("chmod +x " .. dst)

    -- Asserted, not assumed. A user-mode emulator that unpacks and then
    -- cannot run is the failure this package exists to remove, and finding
    -- that out at install time costs one exec; finding it out from a CI job
    -- costs a full build first.
    local out = try { function() return os.iorun(dst .. " --version") end }
    if not out or not out:find("qemu-aarch64", 1, true) then
        raise("qemu-user-aarch64: the installed binary does not run "
              .. "(`--version` said: " .. tostring(out) .. ")")
    end

    return true
end

function config()
    -- Umbrella node for the package name, then the program. `xlings use
    -- qemu-user-aarch64@<ver>` keys off the first; nobody types it otherwise.
    xvm.add(package.name)
    xvm.add("qemu-aarch64-static", {
        bindir = path.join(pkginfo.install_dir(), "bin"),
    })
    return true
end

function uninstall()
    xvm.remove("qemu-aarch64-static")
    xvm.remove(package.name)
    return true
end
