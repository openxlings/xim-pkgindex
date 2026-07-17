package = {
    spec = "2",

    name = "nasm",
    description = "NASM - the Netwide Assembler, an assembler targeting the x86/x86-64 CPU family",

    homepage = "https://www.nasm.us",
    maintainers = {"The NASM Development Team"},
    licenses = {"BSD-2-Clause"},
    repo = "https://github.com/netwide-assembler/nasm",
    docs = "https://www.nasm.us/docs.php",

    -- xim pkg info
    type = "package",
    archs = {"x86_64", "aarch64", "x86"},
    status = "stable",
    categories = {"assembler", "compiler", "toolchain"},
    keywords = {"nasm", "assembler", "asm", "x86", "x86_64", "ndisasm", "disassembler"},

    programs = {"nasm", "ndisasm"},
    xvm_enable = true,

    -- All assets live at xlings-res/nasm (GLOBAL → github, CN → gitcode),
    -- release tag = upstream version, xlings-res naming
    -- `nasm-<ver>-<os>-<arch>.<ext>` (zip on windows, tar.gz elsewhere).
    -- Every archive expands to a uniform top-level dir `nasm-<ver>/` with
    -- nasm(.exe) + ndisasm(.exe) at its root, so one install hook covers
    -- every platform.
    --
    -- Provenance (upstream = https://www.nasm.us/pub/nasm/releasebuilds/<ver>/):
    --   windows x86_64 / x86 — byte-identical upstream win64/win32 zips,
    --     only the archive filename is renamed.
    --   macosx x86_64 / aarch64 — the upstream macosx zip (an i386+x86_64
    --     universal binary; upstream ships no native arm64 build),
    --     repacked file-identical into tar.gz to match the res ext rule.
    --     Both arch assets are the same bytes: on Apple Silicon the
    --     x86_64 slice runs via Rosetta 2, upstream's only supported path.
    --   linux x86_64 / aarch64 — built from the upstream source tarball
    --     (nasm-<ver>.tar.xz) as fully-static musl binaries (musl-gcc /
    --     aarch64-linux-musl-gcc, `-O2 -static`, stripped), so they are
    --     portable across distributions with no glibc runtime dep.
    xpm = {
        source = "xlings-res",
        linux = {
            ["latest"] = { ref = "3.02" },
            ["3.02"] = {
                sha256 = {
                    x86_64 = "77f2e098291212c32b40c32706e03371a6629e847724cecc6f8c03d56ba7c04c",
                    aarch64 = "a592df8b05c1b5552a90f22573f1132984788ec63bcae90d926573db27d0e407",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "3.02" },
            ["3.02"] = {
                sha256 = {
                    x86_64 = "161d0bfaff53c2f9e9f3e69fd0672323ebabafd1268976a5cec11be92a19aee7",
                    x86 = "dca7d736580aafcf88a07838bb597a4f093fa157e56ce522891e86ab0a37c949",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "3.02" },
            ["3.02"] = {
                sha256 = {
                    -- same universal-binary tar.gz for both arches (see header note)
                    x86_64 = "440d2cf13e32b6bcce79a7d933c037bbd47b4c4ae12f030f6efda539c0e34bcd",
                    aarch64 = "440d2cf13e32b6bcce79a7d933c037bbd47b4c4ae12f030f6efda539c0e34bcd",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    os.tryrm(pkginfo.install_dir())
    os.mv("nasm-" .. pkginfo.version(), pkginfo.install_dir())
    return true
end

function config()
    -- nasm/ndisasm sit at the install root (no bin/ subdir in any archive)
    xvm.add("nasm", { bindir = pkginfo.install_dir() })
    xvm.add("ndisasm", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("nasm")
    xvm.remove("ndisasm")
    return true
end
