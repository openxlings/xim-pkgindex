-- libinput-quirks — libinput's device quirks database, and nothing else.
--
-- The `.quirks` files are per-model tuning: a touchpad's real pressure range, a
-- mouse's wheel click angle, which trackpoint needs which sensitivity curve,
-- which keyboard lies about being a mouse. libinput works without them and
-- says so:
--
--     libinput error: failed to find data files
--     libinput error: Failed to load the device quirks from  and . This will
--                     negatively affect device behavior.
--
-- That message is the whole reason this package exists. Enumeration, events and
-- gestures all work on built-in defaults — what is lost is the tuning that
-- makes a specific touchpad feel right.
--
-- ─────────────────────────────────────────────────────────────────────────
-- WHY THIS IS AN xim PACKAGE, AND WHY IT IS SEPARATE FROM THE LIBRARY
--
-- On a distribution these files ship WITH the library: `libinput-bin` puts them
-- in `/usr/share/libinput` and `--prefix=/usr` bakes that path into the binary.
-- A distribution owns `/usr`, so a compile-time path is always right and no
-- variable is needed.
--
-- A relocatable ecosystem cannot do that — the compiled-in path would name the
-- HOST's dataset after relocation — so `compat.libinput` compiles
-- LIBINPUT_QUIRKS_DIR EMPTY and the path comes from the environment instead.
-- That is the same answer Nix, Flatpak and pressure-vessel reach for, and the
-- same one this stack already uses for GBM_BACKENDS_PATH and XKB_CONFIG_ROOT.
--
-- The library half is an mcpp-index descriptor (`compat.libinput`) because
-- mcpp-index packages CODE; the data half is here because mcpp-index has no way
-- for a package to publish a DIRECTORY. Identical split to
-- `freedesktop.libxkbcommon` / `xim:xkeyboard-config`.
--
-- ─────────────────────────────────────────────────────────────────────────
-- NO NEW TARBALL, DELIBERATELY
--
-- `xkeyboard-config` needed a republished archive because its data is BUILT —
-- upstream's meson runs a rules compiler. These files are not built: they are
-- checked into libinput's tree and `install_subdir`'d verbatim. So this package
-- downloads libinput's OWN release tarball — the same URL and the same sha256
-- `compat.libinput` already uses — and keeps `quirks/`.
--
-- That costs a few hundred KB of download for 240 KB of data, and buys: no
-- second archive to publish, no mirror to keep in sync, and a dataset that
-- provably matches libinput 1.31.3 because it IS libinput 1.31.3.
--
-- VERSIONED WITH THE LIBRARY, and that is not cosmetic: quirks files name
-- libinput features (`AttrPressureRange`, `ModelBouncingKeys`), so a dataset
-- newer than the library can carry keys it does not understand. Keeping the
-- versions equal makes the pairing checkable.
package = {
    spec = "3",

    homepage = "https://www.freedesktop.org/wiki/Software/libinput/",
    name = "libinput-quirks",
    description = "libinput device quirks database (per-model input tuning)",

    authors = {"libinput contributors"},
    licenses = {"MIT"},
    repo = "https://gitlab.freedesktop.org/libinput/libinput",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "lib"},
    keywords = {"libinput", "quirks", "input", "graphics"},

    xpm = {
        linux = {
            strip = 1,
            -- No deps: INI text files have no ABI. `compat.libinput` is the
            -- consumer and lives in mcpp-index, which xim does not resolve
            -- against — the two meet through LIBINPUT_QUIRKS_DIR, which is
            -- exactly what a discovery variable is for.
            deps = {},
            ["latest"] = { ref = "1.31.3" },
            ["1.31.3"] = {
                url = {
                    GLOBAL = "https://gitlab.freedesktop.org/libinput/libinput/-/archive/1.31.3/libinput-1.31.3.tar.gz",
                    CN     = "https://gitcode.com/mcpp-res/libinput/releases/download/1.31.3/libinput-1.31.3.tar.gz",
                },
                sha256 = { x86_64 = "b6749bf6f1890f6631c0a70a027c35fec9d2e096a39f720548896e41474a9854" },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.fs")
import("xim.libxpkg.path")
import("xim.pkgindex.graphics")

function install()
    -- The landing put libinput's source tree here (`strip = 1` drops its
    -- `libinput-<version>/`); this package is its quirks/ alone, at
    -- `share/libinput`, flat -- meson's `install_subdir('quirks', …,
    -- strip_directory : true)` drops the `quirks/` level, and `quirks.c`
    -- scandir()s the directory itself, so the layout is part of the interface
    -- rather than a choice.
    local dir = pkginfo.install_dir()
    for _, entry in ipairs(fs.list(dir)) do
        if entry.name ~= "quirks" then fs.remove(entry.path) end
    end
    local dst = path.join(dir, graphics.QUIRKS_DIR)
    fs.mkdir(path.directory(dst))
    fs.move(path.join(dir, "quirks"), dst)

    -- Upstream's own `exclude_files` — it is documentation, not a quirk, and
    -- `is_data_file` would skip it anyway. Removed so the directory contains
    -- only what it claims to.
    fs.remove(path.join(dst, "README.md"))

    -- `10-generic-keyboard.quirks` is the least version-sensitive name in the
    -- set: it predates every vendor file and is in libinput releases years
    -- apart. Without the quirks libinput runs on its built-in defaults, which
    -- is what this package exists to avoid.
    if not fs.is_file(path.join(dst, "10-generic-keyboard.quirks")) then
        error(string.format("libinput-%s's quirks/ has no 10-generic-keyboard.quirks: nothing usable landed in %s",
                            pkginfo.version(), graphics.QUIRKS_DIR))
    end
    return true
end

function config()
    local binding = package.name .. "@" .. pkginfo.version()

    xvm.add(package.name)

    -- Place, then declare. Two calls, because a declared variable naming a
    -- directory nothing filled is its own failure mode — see
    -- `graphics.declare_xkb` for the measurement that established this.
    graphics.declare_quirks(pkginfo.install_dir(), graphics.QUIRKS_DIR, binding)

    -- xlings warns that a declared variable can load CODE from our payload into
    -- processes we do not own, and asks for the reason in the recipe. It cannot
    -- here: `LIBINPUT_QUIRKS_DIR` leads to a flat directory of `.quirks` INI
    -- files read by libinput's own parser (`quirks.c`), with no dlopen along
    -- the path. RPATH is not an alternative because nothing is linked — the
    -- variable is upstream's own interface for locating this data
    -- (`libinput.c:1911`, getenv ahead of the compiled-in default).
    graphics.declare_subos_env(binding, graphics.QUIRKS_ONLY)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
