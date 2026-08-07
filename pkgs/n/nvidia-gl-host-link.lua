package = {
    spec = "2",

    homepage = "https://www.nvidia.com/en-us/drivers/",
    name = "nvidia-gl-host-link",
    description = "Sentinel: stable symlinks to the host's NVIDIA proprietary GL/EGL userspace",

    authors = {"xlings contributors"},
    -- The recipe. The libraries it links to are NVIDIA's and are neither
    -- copied nor redistributed by this package — see below.
    licenses = {"Apache-2.0"},
    repo = "https://github.com/openxlings/xim-pkgindex",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "gpu", "nvidia", "lib"},
    keywords = {"nvidia", "opengl", "egl", "glx", "host-link", "sentinel"},

    -- The self-check is a real program and has to be declared as one.
    --
    -- Measured: `xvm.add("xlings-gl-doctor", {...})` alone registers the node
    -- with the right kind, binding and filename -- and no shim appears in
    -- `<subos>/bin`. The declaration is what makes xlings materialise one, and it
    -- is also what the post-install check reads when it verifies that a package
    -- registered what it promised ("installed but registered none of the
    -- programs it declares"). Without it the node exists and nothing can run it.
    programs = {"xlings-gl-doctor"},
    xvm_enable = true,

    -- ─────────────────────────────────────────────────────────────────────
    -- The one userspace dependency the graphics stack keeps on the host.
    --
    -- Everything else in the stack is ours: mesa, libglvnd, the X11 client
    -- libraries, LLVM. This is the exception, and it is an exception for two
    -- reasons that no amount of packaging removes:
    --
    --   * The NVIDIA proprietary GL userspace is in lockstep with the kernel
    --     module. libGLX_nvidia 550.144.03 talks to nvidia.ko 550.144.03 and
    --     to nothing else. We do not own the kernel module, so we cannot own
    --     the userspace half either.
    --   * The NVIDIA driver EULA does not permit redistribution.
    --
    -- Design: xlings/.agents/docs/2026-08-05-graphics-stack-ecosystem-closure.md §6
    --
    -- WHAT THIS DOES
    --   Symlinks the host's NVIDIA userspace into <install_dir>/lib, and
    --   writes a glvnd vendor JSON pointing at that symlink.
    --
    -- WHAT IT DOES NOT DO
    --   Copy or redistribute any NVIDIA library. Every file it creates is a
    --   symlink to a file the host's own driver package installed.
    --
    -- WHY LINK THE WHOLE SET AND NOT JUST THE TWO VENDOR LIBRARIES
    --   libGLX_nvidia.so.0's DT_NEEDED reads, verbatim:
    --     libnvidia-glsi.so.550.144.03  libnvidia-tls.so.550.144.03
    --     libnvidia-glcore.so.550.144.03  libX11.so.6  libXext.so.6
    --   The private halves carry the driver version IN THE SONAME, so only a
    --   symlink of exactly that name resolves them. Linking the two vendor
    --   entry points alone produces a library that loads on the host (ld.so
    --   cache) and fails in a subos, which is the difference this package
    --   exists to erase. libX11/libXext are the two it needs from us, and
    --   they are declared as deps below.
    --
    -- WHEN THE HOST HAS NO NVIDIA DRIVER
    --   install() succeeds and links nothing. That is deliberate: this is a
    --   sentinel, and "no NVIDIA on this machine" is a normal state, not a
    --   failure. mesa's llvmpipe still renders, which is what glvnd falls
    --   back to when no NVIDIA vendor JSON is present.
    xpm = {
        linux = {
            -- What the host's vendor libraries link against and we supply:
            -- libX11/libXext by DT_NEEDED, glibc for libc/libpthread/libdl,
            -- and libglvnd because it is what dispatches to a vendor at all.
            -- install() links each of these into this package's own lib dir,
            -- so declaring them is not decoration — it is where they come
            -- from. glibc is pinned for the reason mesa's is; see that recipe.
            -- The SPLIT form, spelled out: `runtime = {...}, build = {...}`.
            --
            -- Not a positional list with `build` beside it. That mixed shape
            -- reads identically and every client before libxpkg 0.0.52 takes
            -- the legacy branch on it -- `build` is dropped and the runtime
            -- entries are copied into build_deps in its place. Nothing
            -- reports it; the install succeeds having done neither thing.
            -- The split form means the same thing on every client that has
            -- ever existed.
            deps = {
                runtime = {
                    "xim:libglvnd@>=1.7",
                    "xim:libX11@>=1.8",
                    "xim:libXext@>=1.3",
                    "xim:glibc@>=2.39",
                    -- The empty ELF object the interposer is built from.
                    -- There is no compiler at install time and patchelf edits
                    -- objects rather than creating them, so it is shipped
                    -- (AD-12).
                    "xim:interposer-stub@>=0.1",
                },
                -- patchelf is what BUILDS the interposer, not merely what
                -- tweaks an already-good object: without it there is no
                -- vendor entry point at all. libxpkg resolves it payload-
                -- first, but only if the payload is in this home's store;
                -- otherwise it falls back to the host's and says so.
                -- Declaring it is what makes the fallback unnecessary rather
                -- than merely reported.
                build = { "xim:patchelf@0.18.0" },
            },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "0.1.1" },
            -- No payload: everything this package installs is a symlink it
            -- creates at install time from what it finds on the host. The
            -- version is the recipe's, not the driver's — the driver version
            -- is whatever the host has, and pinning it here would make the
            -- package wrong on every machine but one.
            --
            -- 0.1.1: install() now also writes `.host-driver-version` and
            -- `bin/xlings-gl-doctor`, so what this package PUTS ON DISK changed
            -- even though nothing is downloaded. A recipe whose output changed
            -- has to be a new version for the ordinary reason -- but here it is
            -- also load-bearing for CI, which is how the need surfaced:
            --
            --   `graphics` depends on `xim:nvidia-gl-host-link`, and in CI that
            --   prefix resolves to the PUBLISHED 0.1.0. So installing `graphics`
            --   first put published-0.1.0 on disk under that exact name@version,
            --   and the later `local:nvidia-gl-host-link@0.1.0` step found it
            --   already installed, skipped install() entirely, and failed the
            --   `programs` check with no doctor script and no diagnostic --
            --   not even the "no NVIDIA driver" warning, because the hook never
            --   ran. A distinct version makes local and published different
            --   packages again.
            --
            -- And 0.1.0 is GONE rather than kept alongside, which is safe
            -- exactly because there is no payload: an old version of this
            -- package cannot be reproduced anyway -- it links whatever the host
            -- has today, so "0.1.0" names a recipe, not an artifact anyone can
            -- get back. Nothing pins it (`graphics` asks for `>=0.1`), and an
            -- existing install keeps its files untouched.
            --
            -- Keeping it was also what made the bump useless. `pkg_spec` in the
            -- install test carries no version, and the resolver prefers a
            -- version already installed over the index's newest
            -- (pin_target_to_active) -- so with `graphics` having already pulled
            -- the published 0.1.0, a bare `local:nvidia-gl-host-link` resolved
            -- straight back to 0.1.0 and skipped the hook again. Removing the
            -- entry leaves the local index with one answer.
            ["0.1.1"] = { },
        },
    },
}

import("xim.libxpkg.log")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.libxpkg.subos")
import("xim.libxpkg.elfpatch")
import("xim.pkgindex.sysroot")
import("xim.pkgindex.hostlib")
import("xim.pkgindex.graphics")

-- Where the host keeps its NVIDIA userspace.
--
-- Located by finding libGLX_nvidia.so.0 rather than by guessing a distro
-- layout: the two vendor entry points and their private dependencies are
-- always installed together in one directory, so one hit fixes the rest.
--
-- The probe itself now lives in `hostlib` -- it was written here first, and
-- three other places in this ecosystem asked the same question and answered it
-- differently, two of them wrongly (mcpp#352 is one). One of the three rules it
-- carries is new even here: hostlib ELF-class checks the FALLBACK paths too,
-- so Fedora's 32-bit /usr/lib is refused rather than merely searched last.
local function __probe_nvidia_dir()
    return hostlib.dir_of("libGLX_nvidia.so.0")
end

-- Single-quote for /bin/sh. The generated script embeds two values that come
-- from the filesystem and from /sys, so neither is a literal in this file.
local function __sh_quote(s)
    return "'" .. tostring(s or ""):gsub("'", [[''"'"'']]) .. "'"
end

-- Every NVIDIA userspace file in DIR, by name.
--
-- Enumerated rather than listed: the private libraries are named after the
-- driver version, so a fixed list would be a list of one driver release. The
-- prefixes are the stable part.
--
-- hostlib drops any 32-bit entry, which matters on a biarch host: Fedora
-- installs `libnvidia-glcore.so.<ver>` for both ABIs into two directories, and
-- a driver upgrade that leaves a stale 32-bit sibling in the 64-bit directory
-- would otherwise be linked into this payload and fail at load with
-- `wrong ELF class`.
local function __nvidia_entries(dir)
    return hostlib.entries_with_prefix(dir, {
        "^libnvidia%-",
        "^libGLX_nvidia%.",
        "^libEGL_nvidia%.",
        "^libGLESv1_CM_nvidia%.",
        "^libGLESv2_nvidia%.",
    })
end

-- The self-check, written as a shell script into the payload.
--
-- WHY A PROGRAM AND NOT A DOCTOR RULE
--
-- `xlings self doctor` is the obvious home for this and it is the wrong one:
-- the rule is specific to one package's relationship with one vendor's driver,
-- it changes when that relationship does, and this repo already has three
-- report/repair pairs that drifted because the check and the fix live in
-- different files. A program that ships WITH the package cannot drift from it.
--
-- Shell rather than a compiled probe: there is no compiler at install time, and
-- what it does is compare a file to a file.
local function __write_gl_doctor(dir, kver, done, present)
    local script = path.join(dir, "bin", "xlings-gl-doctor")
    os.mkdir(path.directory(script))
    io.writefile(script, string.format([[#!/usr/bin/env sh
# nvidia-gl-host-link self-check. Generated at install time; do not edit.
#
# Exit 0 when the payload still matches the host it was built against, 1 when it
# does not. "Does not" is not a crash -- GL usually keeps working by resolving
# the vendor's siblings from the host's ld.so cache -- which is exactly why it
# needs saying out loud.
PAYLOAD=%s
STAMP="$PAYLOAD/.host-driver-version"
INSTALLED=%s
INTERPOSED=%d
ENTRYPOINTS=%d
rc=0

live=""
[ -r /sys/module/nvidia/version ] && live=$(cat /sys/module/nvidia/version)
stamped=""
[ -r "$STAMP" ] && stamped=$(cat "$STAMP")

echo "nvidia-gl-host-link"
echo "  payload            $PAYLOAD"
echo "  built for driver   ${stamped:-unknown}"
echo "  host driver now    ${live:-none loaded}"
echo "  interposers        $INTERPOSED/$ENTRYPOINTS entry points"

if [ -z "$live" ]; then
    echo "  ! no NVIDIA kernel module loaded -- GL renders through mesa."
    echo "    That is a normal state; nothing to repair."
elif [ -z "$stamped" ]; then
    # Installed on a machine with no driver, and one has since appeared. Not
    # the same thing as a version change, and the fix is the same command but
    # the reason a user needs to hear is different: nothing is broken, there is
    # simply a GPU here now that this payload was never told about.
    echo "  x an NVIDIA driver ($live) appeared after this package was installed."
    echo "    It links nothing yet, so GL still renders through mesa. Repair:"
    echo "      xlings install graphics        # re-probes and links the driver"
    rc=1
elif [ "$live" != "$stamped" ]; then
    echo "  x host driver changed since install ($stamped -> $live)."
    echo "    The payload's version-named symlinks now dangle. Repair:"
    echo "      xlings install graphics        # re-probes and relinks"
    rc=1
fi

# Dangling links are the visible symptom of the above, and they are worth
# counting separately: a partial driver upgrade leaves some resolvable.
#
# The `[ -e "$f" ] || continue`-style guard on the glob itself is load-bearing:
# with an empty lib/ (the no-driver host, where this package links nothing) an
# unmatched glob stays LITERAL, so the loop body runs once on the pattern
# string, `[ -e ]` is false, and the script reports one dangling entry called
# `*` and exits 1 on a host that is in a perfectly normal state.
dangling=0
for f in "$PAYLOAD"/lib/*; do
    [ "$f" = "$PAYLOAD/lib/*" ] && break        # empty dir: glob did not expand
    [ -e "$f" ] || { dangling=$((dangling+1)); echo "  x dangling  $(basename "$f")"; }
done
[ "$dangling" -gt 0 ] && rc=1

if [ "$INTERPOSED" -lt "$ENTRYPOINTS" ]; then
    echo "  x $((ENTRYPOINTS-INTERPOSED)) entry point(s) were not interposed --"
    echo "    those resolve their dependencies from the HOST."
    rc=1
fi

[ "$rc" -eq 0 ] && echo "  ok"
exit $rc
]], __sh_quote(dir), __sh_quote(kver), done, present))
    system.exec(string.format([[chmod +x "%s"]], script))
end

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mkdir(path.join(dir, "lib"))

    local nvdir = __probe_nvidia_dir()
    if not nvdir then
        log.warn("no NVIDIA driver userspace on this host.")
        log.warn("  GL programs will render through mesa (llvmpipe or an")
        log.warn("  open driver). Install the NVIDIA driver with your distro")
        log.warn("  package manager and reinstall this package to use it.")
        -- The self-check STILL ships, and this early return is exactly why.
        --
        -- Declaring `programs = {"xlings-gl-doctor"}` makes xlings verify after
        -- install that the package registered what it promised. Returning here
        -- without writing the script failed that check on every host WITHOUT an
        -- NVIDIA driver -- which is most of them, including every CI runner --
        -- and took `graphics` and `godot` down with it, three failures from one
        -- cause. Measured on the first CI run this package ever had on a
        -- machine with no GPU; a local machine that HAS the driver cannot
        -- reproduce it, which is the whole reason that path needs a test.
        --
        -- The script already handles this state: no kernel module loaded is
        -- reported as normal, with nothing to repair. A sentinel's no-driver
        -- path must be a complete install, not a shorter one.
        io.writefile(path.join(dir, ".host-driver-version"), "\n")
        __write_gl_doctor(dir, "", 0, 0)
        return true
    end

    local linked = 0
    for _, name in ipairs(__nvidia_entries(nvdir)) do
        system.exec(string.format([[ln -sf "%s" "%s"]],
            path.join(nvdir, name), path.join(dir, "lib", name)))
        linked = linked + 1
    end

    -- What the vendor needs from OUR packages, in its own directory.
    --
    -- `lib/` above is the host's, and nothing of ours is mixed into it: a
    -- reader, a `ls`, and `exports.runtime.libdirs` can all tell the two
    -- apart, and only the host half is what consumers of this package are
    -- offered. This half exists for one reader, the dynamic loader.
    --
    -- Why it has to be gathered at all. glvnd dlopens libEGL_nvidia by
    -- absolute path, so the vendor's dependencies are searched against the
    -- process's paths — and the vendor is the host's file, so it cannot carry
    -- an RPATH we control the way every other library in this stack does. It
    -- needs a search path. A search path can name several directories, so the
    -- gathering is not for want of room; it is that `subos.env` can only
    -- resolve `${pkgdir}` for the package making the declaration, and there
    -- is no syntax for "a dependency's payload directory". The alternative —
    -- writing absolute paths into the value — gives up exactly the property
    -- the placeholders exist for, that a manifest describes more than the
    -- machine that wrote it.
    --
    -- And this package's directories, not `<subos>/lib`. Everything else in
    -- the stack resolves through payload directories, which the dependency
    -- graph pins; the subos lib directory holds whatever that subos happens
    -- to contain. Installed into a subos without libX11, `<subos>/lib` would
    -- be quietly short of it and the vendor would fail to load, three layers
    -- from the cause.
    --
    -- The interposer, in place of a gathered dependency directory.
    --
    -- What used to be here: a hand-written table of SONAMEs symlinked into
    -- `lib/xlings-deps/`, put on LD_LIBRARY_PATH so the vendor could find
    -- them. It worked, and it had two costs that could not be paid off by
    -- getting the table right.
    --
    -- The table was a list of what someone thought of, and it was missing
    -- libm, libdrm, libgbm, libgcc_s and libwayland-* -- all of which were
    -- therefore coming from the HOST, silently, which is the leak this
    -- package exists to close (R7).
    --
    -- And LD_LIBRARY_PATH has no scope. Every child of the subos shell
    -- inherits it, and most of them are host binaries on the host loader.
    -- That is how a libc in that directory once returned a /bin/bash that
    -- died of SIGSEGV before printing a character.
    --
    -- An interposer replaces both. It is ~9 KB of empty object with the
    -- vendor's SONAME, NEEDing the real vendor by absolute path so dlsym
    -- still reaches its entry points, and carrying DT_RPATH -- transitive
    -- along the load chain, where DT_RUNPATH is not -- naming the closure the
    -- RESOLVER computed. No table, and nothing on any global variable.
    --
    -- Measured on this host, 2026-08-06: with LD_LIBRARY_PATH carrying only
    -- the host driver directory, GL_RENDERER came back
    -- `NVIDIA GeForce RTX 4080/PCIe/SSE2` and the probe read back the pixel it
    -- drew. The same subos with neither mechanism renders on llvmpipe.
    --
    -- PRECONDITION: an interposer may only be loaded by a consumer whose
    -- INTERP points into our payload. That is why only OUR vendor JSON below
    -- names it -- the host's own glvnd keeps using the host's own vendor, and
    -- both rules hold at once. Handing one to a host binary fails as
    -- `librt.so.1: undefined symbol: __pointer_chk_guard, version
    -- GLIBC_PRIVATE`, which is the loader/libc split from the direction the
    -- same-source assertion cannot see.
    --
    -- EVERY entry point, not the one that was tested. glvnd dlopens each
    -- vendor library BY NAME, so each is the ROOT of its own load chain, and
    -- DT_RPATH is transitive only DOWN a chain -- never across to another
    -- root. Interposing libEGL alone left GLX, GLESv1 and GLESv2 as plain
    -- symlinks into /usr/lib, and an EGL probe could not see it: EGL passed
    -- while `glxinfo` still resolved the vendor's deps from the host.
    -- libGLX_nvidia.so.0 is also the Vulkan ICD, so that one root carries two
    -- APIs.
    local ENTRY_POINTS = {
        "libEGL_nvidia.so.0",
        "libGLX_nvidia.so.0",        -- GLX vendor AND Vulkan ICD: same file
        "libGLESv1_CM_nvidia.so.1",
        "libGLESv2_nvidia.so.2",
    }

    local has_interposer = type(elfpatch.host_link_interposer) == "function"
    local present, done = {}, {}
    for _, name in ipairs(ENTRY_POINTS) do
        local vendor_real = path.join(nvdir, name)
        if os.isfile(vendor_real) then
            table.insert(present, name)
            if has_interposer then
                elfpatch.host_link_interposer{
                    vendor = vendor_real,
                    out    = path.join(dir, "lib", name),
                    soname = name,
                }
                table.insert(done, name)
            end
        end
    end
    -- Total, or loud. An entry point the host HAS and we did not interpose is
    -- still sitting there as a symlink into /usr/lib -- it works, by resolving
    -- the vendor's dependencies from the host, which is the thing this package
    -- exists to stop. That must not be reported the same way as success.
    if #done < #present then
        local missed = {}
        for _, name in ipairs(present) do
            local ok = false
            for _, d in ipairs(done) do if d == name then ok = true end end
            if not ok then table.insert(missed, name) end
        end
        if not has_interposer then
            log.warn("this xlings is too old for elfpatch.host_link_interposer "
                     .. "(libxpkg 0.0.52); the NVIDIA vendor's dependencies "
                     .. "will resolve from the HOST. Run `xlings self update` "
                     .. "and reinstall this package.")
        end
        log.warn("not interposed: %s -- these resolve their dependencies from "
                 .. "the host", table.concat(missed, ", "))
    end
    if #present == 0 then
        log.warn("no NVIDIA vendor libraries under %s; GL will fall back to mesa", nvdir)
    end

    -- The glvnd vendor JSON, written rather than linked.
    --
    -- The host's own 10_nvidia.json says `"library_path": "libEGL_nvidia.so.0"`
    -- — a bare SONAME, which is correct on a host with an ld.so cache and
    -- wrong in a subos, where it would either fail to resolve or resolve
    -- against something else. Same rewrite mesa does to its 50_mesa.json, and
    -- for the same reason: a bare name here is a way for the host's stack to
    -- get back in through the door we closed.
    local egldir = path.join(dir, "share", "glvnd", "egl_vendor.d")
    os.mkdir(egldir)
    io.writefile(path.join(egldir, "10_nvidia.json"), string.format([[{
    "file_format_version" : "1.0.0",
    "ICD" : {
        "library_path" : "%s"
    }
}
]], path.join(dir, "lib", "libEGL_nvidia.so.0")))

    -- The driver version this payload was built against, recorded.
    --
    -- Everything above adapts to the host AT INSTALL TIME and is then never
    -- re-checked. When the host driver is upgraded, every `*.550.144.03`
    -- symlink in this payload dangles and the `4/4` printed below was computed
    -- for a driver that is gone -- and nothing says so, because a dangling
    -- entry on a search path is skipped in silence and the vendor's siblings
    -- are then resolved from the host's ld.so cache instead. It usually still
    -- renders; in a sandbox or an empty-host container it does not.
    --
    -- A distribution does not need this: the kernel module and its userspace
    -- are one package version there, and DKMS rebuilds on kernel upgrade, so
    -- the pair is an INSTALL-TIME INVARIANT. We do not own the kernel module,
    -- so the same invariant can only be a RUN-TIME CHECK -- which is what the
    -- stamp plus `xlings-gl-doctor` are. Flatpak reads the same file for the
    -- same reason (`enable-if: active-gl-driver`).
    local kver = ""
    if os.isfile("/sys/module/nvidia/version") then
        kver = (io.readfile("/sys/module/nvidia/version") or ""):gsub("%s+$", "")
    end
    io.writefile(path.join(dir, ".host-driver-version"), kver .. "\n")
    __write_gl_doctor(dir, kver, #done, #present)

    -- Both numbers, and the interposers as a FRACTION of the entry points the
    -- host actually has. Reporting only the symlink count would make "the
    -- vendor's dependencies resolve to our payloads" and "they resolve to the
    -- host's" produce identical output -- and the second one still renders,
    -- just on llvmpipe. A bare "yes" would do the same thing one level in:
    -- one interposer out of four reads as success, and the three uncovered
    -- roots are exactly the APIs nobody probed.
    --
    -- With the driver version, because the fraction is only true for the driver
    -- it was measured against.
    log.info("nvidia-gl-host-link → %s (driver %s, %d host libraries linked, "
             .. "interposers: %d/%d%s) ✓",
             nvdir, kver ~= "" and kver or "unknown", linked, #done, #present,
             #present > 0 and "" or " — no vendor, GL falls back to mesa")
    return true
end

function config()
    local dir = pkginfo.install_dir()
    local tag = package.name .. "@" .. pkginfo.version()

    xvm.add(package.name)

    -- Into `<subos>/lib` like every other library in the stack. Symlinking
    -- them under the payload is not enough: glvnd dlopens the vendor by
    -- absolute path, and the vendor's own dependencies are then searched
    -- against the process's paths, not the payload's. Without this the
    -- vendor fails to load on `libpthread.so.0` — which our glibc provides
    -- and the subos lib directory is where it lives.
    sysroot.declare_libs(dir, "lib", tag, pkginfo.version())

    -- The self-check, on PATH inside the subos.
    --
    -- Registered only when it exists: install() writes it unconditionally, but
    -- a payload from an older release will not have it and `xvm.add` on a
    -- missing file registers a program that fails to dispatch.
    if os.isfile(path.join(dir, "bin", "xlings-gl-doctor")) then
        xvm.add("xlings-gl-doctor", {
            bindir   = path.join(dir, "bin"),
            filename = "xlings-gl-doctor",
            binding  = tag,
        })
    end

    -- The vendor JSON into the ONE shared directory in the subos, not this
    -- payload's own.
    --
    -- What this fixes. libglvnd scans `__EGL_VENDOR_LIBRARY_DIRS` in list order
    -- and sorts files WITHIN a directory by name -- so with two directories the
    -- `10_nvidia` < `50_mesa` convention meant nothing, and NVIDIA-before-mesa
    -- held only because xlings sorts providers by binding string and
    -- `mesa@...` < `nvidia-gl-host-link@...`. Correct by alphabet. One shared
    -- directory puts the decision back on the filename, which is what the
    -- number in `10_nvidia.json` is for and how the host does it.
    graphics.declare_egl_vendor(dir,
        "share/glvnd/egl_vendor.d/10_nvidia.json", tag)

    -- Vendor directory only. This package has no driver modules and no
    -- `share/` tree, so declaring LIBGL_DRIVERS_PATH or XDG_DATA_DIRS from
    -- here would name paths it does not fill. mesa declares those.
    --
    -- prepend, and both packages declaring the same value is intended:
    -- `prepend` de-duplicates, and either package being absent must not remove
    -- the directory for the other.
    graphics.declare_subos_env(tag, graphics.EGL_VENDOR_ONLY)

    -- No LD_LIBRARY_PATH. It used to be here, and it was the one place
    -- in this stack that needed a library SEARCH PATH rather than an
    -- RPATH -- because the vendor is the host's file and a file we do not
    -- own is a file we cannot patch.
    --
    -- The interposer is a file we DO own, sitting between the loader and
    -- the vendor, so the RPATH goes there and the search path is not
    -- needed at all. What went away with it is the part that had no
    -- scope: LD_LIBRARY_PATH is inherited by every child of the subos
    -- shell, and most of them are host binaries on the host loader.
    --
    -- The host driver directory is NOT declared here either. The vendor
    -- dlopens its own siblings (libnvidia-glcore, libnvidia-eglcore, …)
    -- by bare SONAME at runtime, and those must come from the host to
    -- match its kernel module -- but the host loader finds them through
    -- its own ld.so cache, without help from us.
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
