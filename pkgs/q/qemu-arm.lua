package = {
    spec = "2",
    homepage = "https://xpack-dev-tools.github.io/qemu-arm-xpack/",

    name = "qemu-arm",
    description = "QEMU Arm system emulator (xPack build) - run bare-metal aarch64/arm firmware",

    maintainers = {"https://github.com/xpack-dev-tools/qemu-arm-xpack/graphs/contributors"},
    licenses = {"GPL-2.0-only"},
    repo = "https://github.com/xpack-dev-tools/qemu-arm-xpack",
    docs = "https://xpack-dev-tools.github.io/qemu-arm-xpack/",
    ci = { mirror = true, update = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"emulator", "embedded", "arm"},
    keywords = {"qemu", "arm", "aarch64", "emulator", "baremetal", "freestanding", "firmware"},

    -- Only the two system emulators are registered. The Windows payload also
    -- carries `qemu-system-aarch64w.exe` and `qemu-system-armw.exe` -- the
    -- windowed variants, which differ only in not allocating a console -- and
    -- on Linux libexec/ carries 51 shared objects; neither is a program a user
    -- types.
    programs = {"qemu-system-aarch64", "qemu-system-arm"},
    xvm_enable = true,

    -- Why xPack, and why this is the SECOND qemu package rather than a wider
    -- one: xPack builds QEMU per target family, so the payload of
    -- `xim:qemu-riscv` contains exactly `qemu-system-riscv32` and
    -- `qemu-system-riscv64` and nothing else -- measured, and worth stating
    -- because a QEMU built from source does support many architectures at
    -- once, and the expectation carried over from that is wrong here.
    --
    -- xPack publishes two QEMU packages in total, arm and riscv. Both meet the
    -- bar this index applies: prebuilts for all five host targets it serves
    -- (linux x64/arm64, darwin x64/arm64, win32 x64) from one versioned
    -- release, each with a per-asset .sha sidecar. Every hash below was taken
    -- from that sidecar and re-verified against the downloaded bytes; none was
    -- copied from the sibling descriptor.
    --
    -- There is no x86 entry for the same reason there is no third xPack
    -- package: qemu.org publishes a Windows installer, and macOS and Linux are
    -- served by distribution packages, so no upstream clears the bar. That gap
    -- is recorded rather than filled with something weaker.
    --
    -- The two irregularities handled by platform-scope `source` overrides are
    -- the same ones the riscv descriptor documents: the release TAG carries a
    -- `v` prefix while the FILE name does not, and xlings spells the platforms
    -- `macosx`/`windows` where xPack spells them `darwin`/`win32`.
    --
    -- GLOBAL is xpack-dev-tools, the authoritative upstream. CN is
    -- gitcode.com/xlings-res/qemu-arm, a byte-identical copy published
    -- 2026-08-20: all five archives plus their .sha256 sidecars and a
    -- manifest.json, each fetched back from both mirrors and compared by
    -- sha256 against the local file, 10 of 10 identical.
    xpm = {
        linux = {
            -- `deps` is deliberately EMPTY, and the measurement behind that is
            -- this payload's, not the riscv one's.
            --
            -- Measured DT_NEEDED closure of bin/qemu-system-aarch64
            -- (2026-08-20): 26 entries, against 51 shared objects bundled in
            -- libexec/ and reached through the binary's own
            -- `RPATH=$ORIGIN/../libexec`. Exactly five cross the payload
            -- boundary, and all five are core glibc:
            --
            --     librt.so.1  libutil.so.1  libm.so.6  libpthread.so.0  libc.so.6
            --
            -- Declaring `xim:glibc@...` would hand xlings' predicate-driven
            -- elfpatch a loader provider to key off, and elfpatch REPLACES
            -- DT_RPATH rather than prepending to it -- so all 51 bundled
            -- libraries would go out of reach while the install still reported
            -- success, the break surfacing only on first run. With no dep the
            -- predicate never fires, the binary keeps its own INTERP and
            -- `$ORIGIN/../libexec`, and it runs against the host glibc, which
            -- is what xPack builds it to do.
            source = {
                GLOBAL = "https://github.com/xpack-dev-tools/qemu-arm-xpack/releases/download/v${version}/xpack-qemu-arm-${version}-linux-${arch_alias}.${ext}",
                CN = "https://gitcode.com/xlings-res/qemu-arm/releases/download/${version}/xpack-qemu-arm-${version}-linux-${arch_alias}.${ext}",
            },
            ["latest"] = { ref = "9.2.4-1" },
            ["9.2.4-1"] = {
                arch_alias = { x86_64 = "x64", aarch64 = "arm64" },
                sha256 = {
                    x86_64  = "203dc2c71e25fcf97b95181328e9b888cc8092ff404bffd4d267b9defabcb698",
                    aarch64 = "50fc7ccace24982bcf964a1b5286a05b63f185421f5e1018fb6cbaf78b42277b",
                },
            },
        },
        macosx = {
            source = {
                GLOBAL = "https://github.com/xpack-dev-tools/qemu-arm-xpack/releases/download/v${version}/xpack-qemu-arm-${version}-darwin-${arch_alias}.${ext}",
                CN = "https://gitcode.com/xlings-res/qemu-arm/releases/download/${version}/xpack-qemu-arm-${version}-darwin-${arch_alias}.${ext}",
            },
            ["latest"] = { ref = "9.2.4-1" },
            ["9.2.4-1"] = {
                arch_alias = { x86_64 = "x64", aarch64 = "arm64" },
                sha256 = {
                    x86_64  = "c8be02219b4328624f696942aff8d6d5b98dbf07c6f2eb61adca12b7a120a140",
                    aarch64 = "2752ae3bdff112a8574373157ef1e0eb51fd50b1ee8554275f2ff20ba1ff1b6d",
                },
            },
        },
        windows = {
            -- x86_64 only: xPack publishes no win32-arm64 asset. `archs` above
            -- is the union across platforms, and arch resolution is
            -- fail-closed, so an arm64 Windows host is told the arch is
            -- unavailable instead of being handed the x64 archive.
            source = {
                GLOBAL = "https://github.com/xpack-dev-tools/qemu-arm-xpack/releases/download/v${version}/xpack-qemu-arm-${version}-win32-${arch_alias}.${ext}",
                CN = "https://gitcode.com/xlings-res/qemu-arm/releases/download/${version}/xpack-qemu-arm-${version}-win32-${arch_alias}.${ext}",
            },
            ["latest"] = { ref = "9.2.4-1" },
            ["9.2.4-1"] = {
                arch_alias = { x86_64 = "x64" },
                sha256 = {
                    x86_64 = "f029d6549fabe5b0ddce07921832bb97a20f56d54b63c8f4d3d5e82c3c8eae33",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

-- Both archive kinds extract to the same `xpack-qemu-arm-<version>/` root,
-- verified on the linux tar.gz, the darwin tar.gz and the win32 zip. Derived
-- from the archive name rather than hard-coded so a repackaged mirror asset
-- keeps working.
local function payload_root()
    local named = pkginfo.install_file()
        :replace(".tar.gz", "")
        :replace(".zip", "")
    if os.isdir(named) then
        return named
    end

    local base = path.directory(pkginfo.install_file())
    local guess = path.join(base, "xpack-qemu-arm-" .. pkginfo.version())
    if os.isdir(guess) then
        return guess
    end

    -- Defensive: the extraction directory can be shared, so also look for
    -- whichever sibling actually carries the emulator.
    local exe = is_host("windows") and "qemu-system-aarch64.exe" or "qemu-system-aarch64"
    for _, d in ipairs(os.dirs(path.join(base, "*"))) do
        if os.isfile(path.join(d, "bin", exe)) then
            return d
        end
    end

    raise("cannot find the qemu-arm payload under '" .. base
          .. "': no directory contains bin/" .. exe)
end

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv(payload_root(), dir)

    -- The tree must stay whole, not just the two executables: qemu resolves
    -- its firmware images relative to the executable, and on Linux its shared
    -- libraries through `RPATH=$ORIGIN/../libexec`. Moving the binaries alone
    -- would produce an emulator that answers `--version` and then fails to
    -- boot anything -- so assert both, here, where the fault is legible.
    local exe = is_host("windows") and ".exe" or ""
    for _, prog in ipairs({"qemu-system-aarch64", "qemu-system-arm"}) do
        if not os.isfile(path.join(dir, "bin", prog .. exe)) then
            raise("qemu-arm payload is missing bin/" .. prog .. exe)
        end
    end

    -- The datadir is NOT at the same place on every platform, and the
    -- difference is upstream's (verified against all three archive kinds,
    -- 2026-08-20):
    --
    --   linux / macosx  ->  share/qemu/edk2-aarch64-code.fd
    --   windows         ->  share/edk2-aarch64-code.fd
    --
    -- The riscv descriptor found the same split by asserting the Linux layout
    -- and having the Windows install abort; the check is written to accept
    -- either from the start here, having been measured rather than
    -- rediscovered. `-machine virt -kernel <elf>` needs no firmware, but
    -- `-bios` and the UEFI paths do, and a partial extraction that broke them
    -- would otherwise surface much later.
    local fw = "edk2-aarch64-code.fd"
    local candidates = {
        path.join(dir, "share", "qemu", fw),   -- linux / macosx
        path.join(dir, "share", fw),           -- windows
    }
    local found = false
    for _, p in ipairs(candidates) do
        if os.isfile(p) then found = true end
    end
    if not found then
        raise("qemu-arm payload has no " .. fw
              .. " under share/qemu/ or share/ -- the firmware-backed machine "
              .. "types cannot boot without it")
    end

    return true
end

function config()
    local bindir = path.join(pkginfo.install_dir(), "bin")

    -- Umbrella node for the package name itself. Nobody types `qemu-arm` --
    -- the programs are the two emulators -- but `xlings use qemu-arm@<ver>`
    -- and Spec D1 both key off it.
    xvm.add(package.name)

    xvm.add("qemu-system-aarch64", { bindir = bindir })
    xvm.add("qemu-system-arm", { bindir = bindir })
    return true
end

function uninstall()
    xvm.remove("qemu-system-aarch64")
    xvm.remove("qemu-system-arm")
    xvm.remove(package.name)
    return true
end
