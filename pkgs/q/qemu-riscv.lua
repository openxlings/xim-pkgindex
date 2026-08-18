package = {
    spec = "2",
    homepage = "https://xpack-dev-tools.github.io/qemu-riscv-xpack/",

    name = "qemu-riscv",
    description = "QEMU RISC-V system emulator (xPack build) - run bare-metal riscv32/riscv64 firmware",

    maintainers = {"https://github.com/xpack-dev-tools/qemu-riscv-xpack/graphs/contributors"},
    licenses = {"GPL-2.0-only"},
    repo = "https://github.com/xpack-dev-tools/qemu-riscv-xpack",
    docs = "https://xpack-dev-tools.github.io/qemu-riscv-xpack/",
    ci = { mirror = true, update = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"emulator", "embedded", "riscv"},
    keywords = {"qemu", "riscv", "riscv64", "emulator", "baremetal", "freestanding", "firmware"},

    -- Only the two system emulators are registered. The payload's bin/ also
    -- carries the runtime DLLs on Windows, and libexec/ carries 51 shared
    -- objects on Linux; neither is a program a user types.
    programs = {"qemu-system-riscv64", "qemu-system-riscv32"},
    xvm_enable = true,

    -- Why xPack rather than a distro qemu: it is the only upstream that
    -- publishes qemu-system-riscv* prebuilts for all five host targets this
    -- index serves (linux x64/arm64, darwin x64/arm64, win32 x64) from one
    -- versioned release, with a per-asset .sha sidecar. Every hash below was
    -- taken from that sidecar, not recomputed from a local download.
    --
    -- Two irregularities are handled by platform-scope `source` overrides:
    --   * the release TAG carries a `v` prefix (`v9.2.4-1`) while the FILE
    --     name does not (`xpack-qemu-riscv-9.2.4-1-...`);
    --   * xlings spells the platforms `macosx`/`windows`, xPack spells them
    --     `darwin`/`win32`.
    -- The arch spelling difference (x86_64 -> x64) is an `arch_alias`;
    -- `${ext}` already resolves to `zip` on windows and `tar.gz` elsewhere,
    -- which matches xPack exactly.
    --
    -- GLOBAL is xpack-dev-tools, the authoritative upstream. CN is
    -- gitcode.com/xlings-res/qemu-riscv, a byte-identical copy of the same
    -- bytes (all five archives plus their .sha256 sidecars, published
    -- 2026-08-19 and verified from both mirrors). GLOBAL must stay upstream:
    -- both the version updater and the mirror materializer read `GLOBAL` as
    -- the source of truth, so pointing it at the mirror would make the mirror
    -- mirror itself. The mirror TAG has no `v` prefix -- xlings-res tags are
    -- the plain version -- while upstream's does; that is the one difference
    -- between the two templates besides the host.
    xpm = {
        linux = {
            -- `deps` is deliberately EMPTY, and that is load-bearing.
            --
            -- Measured DT_NEEDED closure of bin/qemu-system-riscv64 (not a
            -- guessed list): 26 of the 32 objects it loads come from inside
            -- the payload, reached through its own `RPATH=$ORIGIN/../libexec`.
            -- Only core glibc crosses the payload boundary --
            -- libc/libm/libdl/librt/libutil/libpthread plus the interpreter.
            --
            -- Declaring `xim:glibc@...` hands xlings' predicate-driven
            -- elfpatch a loader provider to key off, and elfpatch REPLACES
            -- DT_RPATH rather than prepending to it. Measured 2026-08-19 on
            -- this payload:
            --
            --   upstream:  [$ORIGIN/../libexec]
            --   installed: [<install>/lib:<glibc>/lib64:<subos farm>/lib]
            --
            -- All 51 bundled libraries go out of reach, and the install still
            -- reports success -- the break only surfaces on first run, as
            -- `libpixman-1.so.0: cannot open shared object file`. Every
            -- file-existence check passes; the files are all still there.
            --
            -- Preserving `$ORIGIN` would not make the dep right either: the
            -- payload bundles `libresolv.so.2` from glibc 2.28 (xPack builds
            -- on Debian 10 for reach), so a private glibc would put a 2.28
            -- libresolv and a 2.39 libc in one process -- the two-glibcs
            -- shape the index's own contract text names as a SIGSEGV source.
            --
            -- With no dep the predicate never fires, the binary keeps its own
            -- INTERP and `$ORIGIN/../libexec`, and it runs against the host
            -- glibc, which is what xPack builds it to do (floor: 2.28).
            -- Compare claude.lua and aarch64-linux-musl-gcc.lua -- the same
            -- conclusion reached from the other two directions.
            source = {
                GLOBAL = "https://github.com/xpack-dev-tools/qemu-riscv-xpack/releases/download/v${version}/xpack-qemu-riscv-${version}-linux-${arch_alias}.${ext}",
                CN = "https://gitcode.com/xlings-res/qemu-riscv/releases/download/${version}/xpack-qemu-riscv-${version}-linux-${arch_alias}.${ext}",
            },
            ["latest"] = { ref = "9.2.4-1" },
            ["9.2.4-1"] = {
                arch_alias = { x86_64 = "x64", aarch64 = "arm64" },
                sha256 = {
                    x86_64  = "7cd69277dcf32bb024351ea225d549577713302cc5141444bad12836d5967b8c",
                    aarch64 = "b90f76ebff7ecfa50e77c61a750534bdd0eb41deb793c0253fb3f583002a4aed",
                },
            },
        },
        macosx = {
            source = {
                GLOBAL = "https://github.com/xpack-dev-tools/qemu-riscv-xpack/releases/download/v${version}/xpack-qemu-riscv-${version}-darwin-${arch_alias}.${ext}",
                CN = "https://gitcode.com/xlings-res/qemu-riscv/releases/download/${version}/xpack-qemu-riscv-${version}-darwin-${arch_alias}.${ext}",
            },
            ["latest"] = { ref = "9.2.4-1" },
            ["9.2.4-1"] = {
                arch_alias = { x86_64 = "x64", aarch64 = "arm64" },
                sha256 = {
                    x86_64  = "138554dd3c18d0663deec33a548a3ea73387d3b46382049f03bbc397cbdfba00",
                    aarch64 = "afe4910a2ccf023fee1ce01fb3cf497563fd5e92d786b7fff08cb139da1ac281",
                },
            },
        },
        windows = {
            -- x86_64 only: xPack publishes no win32-arm64 asset. `archs` above
            -- is the union across platforms, and arch resolution is
            -- fail-closed, so an arm64 Windows host is told the arch is
            -- unavailable instead of being handed the x64 archive.
            source = {
                GLOBAL = "https://github.com/xpack-dev-tools/qemu-riscv-xpack/releases/download/v${version}/xpack-qemu-riscv-${version}-win32-${arch_alias}.${ext}",
                CN = "https://gitcode.com/xlings-res/qemu-riscv/releases/download/${version}/xpack-qemu-riscv-${version}-win32-${arch_alias}.${ext}",
            },
            ["latest"] = { ref = "9.2.4-1" },
            ["9.2.4-1"] = {
                arch_alias = { x86_64 = "x64" },
                sha256 = {
                    x86_64 = "05df8a50c2109605c7ab382667aa4680d41cb262383053e5bb07d29de616eb1f",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

-- Both archive kinds extract to the same `xpack-qemu-riscv-<version>/` root,
-- verified on the linux tar.gz and the win32 zip. Derived from the archive
-- name rather than hard-coded so a repackaged mirror asset keeps working.
local function payload_root()
    local named = pkginfo.install_file()
        :replace(".tar.gz", "")
        :replace(".zip", "")
    if os.isdir(named) then
        return named
    end

    local base = path.directory(pkginfo.install_file())
    local guess = path.join(base, "xpack-qemu-riscv-" .. pkginfo.version())
    if os.isdir(guess) then
        return guess
    end

    -- Defensive: the extraction directory can be shared, so also look for
    -- whichever sibling actually carries the emulator.
    local exe = is_host("windows") and "qemu-system-riscv64.exe" or "qemu-system-riscv64"
    for _, d in ipairs(os.dirs(path.join(base, "*"))) do
        if os.isfile(path.join(d, "bin", exe)) then
            return d
        end
    end

    raise("cannot find the qemu-riscv payload under '" .. base
          .. "': no directory contains bin/" .. exe)
end

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv(payload_root(), dir)

    -- The tree must stay whole, not just the two executables: qemu resolves
    -- its OpenSBI firmware (the default -bios for `-machine virt`) relative to
    -- the executable, and on Linux its shared libraries through
    -- `RPATH=$ORIGIN/../libexec`. Moving the binaries alone would produce an
    -- emulator that answers `--version` and then fails to boot anything -- so
    -- assert both, here, where the fault is legible.
    local exe = is_host("windows") and ".exe" or ""
    for _, prog in ipairs({"qemu-system-riscv64", "qemu-system-riscv32"}) do
        if not os.isfile(path.join(dir, "bin", prog .. exe)) then
            raise("qemu-riscv payload is missing bin/" .. prog .. exe)
        end
    end

    -- The firmware's datadir is NOT the same on every platform, and the
    -- difference is upstream's, not ours (verified against all three archives,
    -- 2026-08-19):
    --
    --   linux / macosx  ->  share/qemu/opensbi-riscv64-generic-fw_dynamic.bin
    --   windows         ->  share/opensbi-riscv64-generic-fw_dynamic.bin
    --
    -- Hard-coding the Linux layout made the Windows install abort here, which
    -- is how the difference was found -- exactly the intended outcome, and the
    -- reason this check exists rather than trusting the archive. Accept either
    -- layout; require one of them.
    local fw = "opensbi-riscv64-generic-fw_dynamic.bin"
    local candidates = {
        path.join(dir, "share", "qemu", fw),   -- linux / macosx
        path.join(dir, "share", fw),           -- windows
    }
    local found = false
    for _, p in ipairs(candidates) do
        if os.isfile(p) then found = true end
    end
    if not found then
        raise("qemu-riscv payload has no " .. fw
              .. " under share/qemu/ or share/ -- `-machine virt` cannot boot "
              .. "without it")
    end

    return true
end

function config()
    local bindir = path.join(pkginfo.install_dir(), "bin")

    -- Umbrella node for the package name itself. Nobody types `qemu-riscv` --
    -- the programs are the two emulators -- but `xlings use qemu-riscv@<ver>`
    -- and Spec D1 both key off it. Same idiom as llvm/llvm-tools, which
    -- likewise ship programs whose names are not the package's.
    xvm.add(package.name)

    xvm.add("qemu-system-riscv64", { bindir = bindir })
    xvm.add("qemu-system-riscv32", { bindir = bindir })
    return true
end

function uninstall()
    xvm.remove("qemu-system-riscv64")
    xvm.remove("qemu-system-riscv32")
    xvm.remove(package.name)
    return true
end
