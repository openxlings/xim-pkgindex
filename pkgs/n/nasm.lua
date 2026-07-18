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
    -- Version entries use `url = "XLINGS_RES"` + per-arch sha256 (the
    -- mcpp.lua idiom), NOT the bare `source = "xlings-res"` form
    -- (mcpp#232): deployed xlings engines don't parse a `source` key, so
    -- that form resolves to no URL at all — no download gets planned, the
    -- install hook no-ops, and the package lands "installed" but empty
    -- with dangling shims. The placeholder url is resolved at runtime to
    -- the arch-correct asset (with GLOBAL→CN resource-server fallback);
    -- the arch-keyed sha256 table is declared for engines that can verify
    -- it and harmlessly ignored by older ones.
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
        linux = {
            ["latest"] = { ref = "3.02" },
            ["3.02"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "77f2e098291212c32b40c32706e03371a6629e847724cecc6f8c03d56ba7c04c",
                    aarch64 = "a592df8b05c1b5552a90f22573f1132984788ec63bcae90d926573db27d0e407",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "3.02" },
            ["3.02"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "161d0bfaff53c2f9e9f3e69fd0672323ebabafd1268976a5cec11be92a19aee7",
                    x86 = "dca7d736580aafcf88a07838bb597a4f093fa157e56ce522891e86ab0a37c949",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "3.02" },
            ["3.02"] = {
                url = "XLINGS_RES",
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
    -- Idempotent across xim engines (mcpp#232): some stage the extracted
    -- payload into install_dir() before/without the hook, others leave it
    -- in the hook CWD for us to move. Never wipe install_dir before
    -- confirming a replacement payload exists, and never report success
    -- unless the binary is actually in place — a `return true` on an
    -- empty dir gets stamped as installed and leaves dangling xvm shims.
    local exe = is_host("windows") and "nasm.exe" or "nasm"
    local staged = path.join(pkginfo.install_dir(), exe)
    if os.isfile(staged) then return true end
    local payload = "nasm-" .. pkginfo.version()
    if os.isdir(payload) then
        os.tryrm(pkginfo.install_dir())
        os.mv(payload, pkginfo.install_dir())
    end
    return os.isfile(staged)
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
