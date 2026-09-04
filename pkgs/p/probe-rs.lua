package = {
    spec = "2",
    homepage = "https://probe.rs/",

    name = "probe-rs",
    description = "probe-rs: flash, run and debug embedded targets over a debug probe (CMSIS-DAP, ST-Link, J-Link)",

    maintainers = {"https://github.com/probe-rs/probe-rs/graphs/contributors"},
    licenses = {"Apache-2.0", "MIT"},
    repo = "https://github.com/probe-rs/probe-rs",
    docs = "https://probe.rs/docs/",
    ci = { mirror = true, update = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"embedded", "debugger", "arm", "riscv"},
    keywords = {"probe-rs", "swd", "jtag", "cmsis-dap", "stlink", "jlink",
                "flash", "debug", "embedded", "cortex-m", "riscv"},

    -- ⭐ WHY THIS PACKAGE EXISTS, AND WHAT IT IS THE OTHER HALF OF.
    --
    -- `xim:qemu-arm` is how a Cortex-M image is RUN without hardware. This is
    -- how the same image is run WITH it, and the two are deliberately shaped
    -- alike: `probe-rs run` flashes the target, resets it, streams its
    -- RTT/semihosting output and exits with the program's own status — the same
    -- four things `qemu-system-arm -kernel` does. That is what lets a board
    -- package name ONE default runner for both environments, and what keeps the
    -- command a developer types the same when the board arrives on the desk.
    --
    -- ⚠️ ONLY `probe-rs` IS REGISTERED. The archive also carries `cargo-embed`
    -- and `cargo-flash`, which are Cargo subcommands: they are useful to a Rust
    -- project and are not programs a user of this index types. Registering them
    -- would put two `cargo-*` names on PATH that nothing here can drive.
    programs = {"probe-rs"},
    xvm_enable = true,

    -- Upstream publishes prebuilt `probe-rs-tools` archives for all five host
    -- targets this index serves, from one versioned release, each with a
    -- per-asset `.sha256` sidecar. Every hash below was taken from that sidecar
    -- and re-verified against the downloaded bytes.
    --
    -- ⚠️ THE ASSET NAMES ARE RUST TARGET TRIPLES, NOT xlings PLATFORM NAMES.
    -- `x86_64-unknown-linux-gnu`, `aarch64-apple-darwin`,
    -- `x86_64-pc-windows-msvc` — a vocabulary with no overlap with the
    -- `linux`/`macosx`/`windows` one this index speaks. So the whole triple
    -- rides in `arch_alias`, and each platform carries its own `source` because
    -- the archive extension changes with it too.
    --
    -- ⚠️ NO win32-arm64 ASSET. `archs` above is the union across platforms and
    -- arch resolution is fail-closed, so an arm64 Windows host is told the arch
    -- is unavailable rather than handed the x64 archive.
    xpm = {
        linux = {
            -- `deps` is deliberately EMPTY. The binary is a Rust build against
            -- the host glibc, and declaring a glibc dep would hand xlings'
            -- predicate-driven elfpatch a loader provider to key off — which
            -- REPLACES DT_RPATH rather than prepending to it. With no dep the
            -- predicate never fires and the binary keeps its own INTERP, which
            -- is what upstream builds it to use.
            --
            -- ⚠️ udev RULES ARE NOT INSTALLED AND CANNOT BE. Reaching a probe as
            -- a non-root user needs a rule under /etc/udev/rules.d, a system
            -- file this index does not write. probe-rs says so itself when a
            -- device is present but unopenable, and its message names the file
            -- — a better diagnostic than anything an installer could print at a
            -- moment when no probe is attached.
            source = {
                GLOBAL = "https://github.com/probe-rs/probe-rs/releases/download/v${version}/probe-rs-tools-${arch_alias}.tar.xz",
                CN = "https://gitcode.com/xlings-res/probe-rs/releases/download/${version}/probe-rs-tools-${arch_alias}.tar.xz",
            },
            ["latest"] = { ref = "0.32.0" },
            ["0.32.0"] = {
                arch_alias = { x86_64  = "x86_64-unknown-linux-gnu",
                               aarch64 = "aarch64-unknown-linux-gnu" },
                sha256 = {
                    x86_64  = "c2ccc46049e52a5d403ef212078cd637ecda55b662708327960558f83e851ff5",
                    aarch64 = "7c818cfd77808e806bf8f4d108c9137910b4fb28e0fe5c464d39782dbbc8af31",
                },
            },
        },
        macosx = {
            source = {
                GLOBAL = "https://github.com/probe-rs/probe-rs/releases/download/v${version}/probe-rs-tools-${arch_alias}.tar.xz",
                CN = "https://gitcode.com/xlings-res/probe-rs/releases/download/${version}/probe-rs-tools-${arch_alias}.tar.xz",
            },
            ["latest"] = { ref = "0.32.0" },
            ["0.32.0"] = {
                arch_alias = { x86_64  = "x86_64-apple-darwin",
                               aarch64 = "aarch64-apple-darwin" },
                sha256 = {
                    x86_64  = "e23d117a29909a389c92234ac3ebafcc5ec24d8969d1ec5d70eece622827f778",
                    aarch64 = "c39631679b83d0c94dc442d05cc4ca974a87c02907a6ddbfce46746ed503152c",
                },
            },
        },
        windows = {
            source = {
                GLOBAL = "https://github.com/probe-rs/probe-rs/releases/download/v${version}/probe-rs-tools-${arch_alias}.zip",
                CN = "https://gitcode.com/xlings-res/probe-rs/releases/download/${version}/probe-rs-tools-${arch_alias}.zip",
            },
            ["latest"] = { ref = "0.32.0" },
            ["0.32.0"] = {
                arch_alias = { x86_64 = "x86_64-pc-windows-msvc" },
                sha256 = {
                    x86_64 = "56fc0564cc23d604b27dc2d57606194159c49f951999f3e47bd2cbffcba64103",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

-- ⚠️⚠️ THE TWO ARCHIVES DO NOT HAVE THE SAME SHAPE, AND ONLY ONE HOST SHOWS IT.
--
-- The `.tar.xz` assets extract to `probe-rs-tools-<triple>/` with the programs
-- at its root. The Windows `.zip` is FLAT: `probe-rs.exe` and its siblings sit
-- directly in the extraction directory, with no wrap directory at all.
--
-- Measured: an install written for the tar shape configured, downloaded and
-- then died on Windows with
--
--     cannot find the probe-rs payload under '...\runtimedir':
--     no directory contains probe-rs.exe
--
-- and only the Windows runner could see it. So this function answers "which
-- directory CONTAINS the program", which is a question both shapes have an
-- answer to, and the install moves files rather than the directory — because
-- in the flat case that directory is the shared extraction root and moving it
-- would take other packages' files with it.
local function payload_root()
    local exe = is_host("windows") and "probe-rs.exe" or "probe-rs"

    local named = pkginfo.install_file()
        :replace(".tar.xz", "")
        :replace(".zip", "")
    if os.isfile(path.join(named, exe)) then
        return named
    end

    -- The flat shape: the program is directly beside the archive.
    local base = path.directory(pkginfo.install_file())
    if os.isfile(path.join(base, exe)) then
        return base
    end

    -- Defensive: the extraction directory can be shared, so also look for
    -- whichever sibling actually carries the program.
    for _, d in ipairs(os.dirs(path.join(base, "*"))) do
        if os.isfile(path.join(d, exe)) then
            return d
        end
    end

    raise("cannot find the probe-rs payload under '" .. base
          .. "': nothing there contains " .. exe)
end

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)

    local src = payload_root()
    local exe = is_host("windows") and ".exe" or ""
    local bindir = path.join(dir, "bin")
    os.mkdir(bindir)

    -- ⚠️⚠️ THE PROGRAMS GO INTO `bin/`, AND THAT IS NOT TIDINESS.
    --
    -- mcpp's runner lookup searches `<payload>/bin` for a program named by bare
    -- name, and only then PATH. A board package that writes
    -- `mcpp::runner("probe-rs")` therefore resolves it out of THIS payload —
    -- which is the whole point of naming a program instead of computing a path.
    -- Upstream puts the executables at the archive root, so a payload left as
    -- extracted would silently fall through to PATH and pick up whatever shim
    -- or system copy happened to be there.
    --
    -- `cargo-embed` and `cargo-flash` move with it: they are not registered,
    -- but leaving them behind would make the payload's layout depend on which
    -- names this index chose to expose.
    for _, prog in ipairs({"probe-rs", "cargo-embed", "cargo-flash"}) do
        local from = path.join(src, prog .. exe)
        if os.isfile(from) then
            os.mv(from, path.join(bindir, prog .. exe))
        end
    end
    for _, f in ipairs({"README.md", "CHANGELOG.md",
                        "LICENSE-APACHE", "LICENSE-MIT"}) do
        local from = path.join(src, f)
        if os.isfile(from) then
            os.mv(from, path.join(dir, f))
        end
    end

    -- Asserted here, where the fault is legible. A payload that extracted
    -- partially, or whose layout upstream changed, would otherwise surface much
    -- later as "runner not found" pointing at a directory that exists.
    if not os.isfile(path.join(bindir, "probe-rs" .. exe)) then
        raise("probe-rs payload is missing bin/probe-rs" .. exe)
    end

    return true
end

function config()
    xvm.add(package.name, { bindir = path.join(pkginfo.install_dir(), "bin") })
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
