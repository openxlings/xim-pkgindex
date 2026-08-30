-- xkeyboard-config — the keyboard layout dataset, and nothing else.
--
-- libxkbcommon COMPILES keymaps; it contains none. `xkb_keymap_new_from_names`
-- takes rules/model/layout/variant/options — the RMLVO tuple a compositor
-- actually has — and reads the answer off disk. This package is that disk
-- content: 151 layouts, the symbol/keycode/type/compat tables they are built
-- from, and the `evdev` rules file that maps a tuple onto them.
--
-- Without it a subos's libxkbcommon falls through to the HOST's
-- /usr/share/X11/xkb, which is the same silent host edge that gave Vulkan an
-- llvmpipe device instead of the GPU — and it fails outright rather than
-- degrading on a host that has no X11 data at all.
--
-- ─────────────────────────────────────────────────────────────────────────
-- WHY THIS IS AN xim PACKAGE AND NOT AN mcpp-index ONE
--
-- Every other piece of this stack — libxkbcommon, libinput, libevdev, wayland —
-- is an mcpp-index descriptor, because mcpp-index packages CODE. This one is
-- pure data, and mcpp-index has no mechanism for a package to publish a
-- directory: a descriptor contributes headers, objects and libraries, and there
-- is no `[runtime]` shape that says "and place this tree somewhere a consumer
-- can find at run time" (checked against all thirteen packages that use
-- `[runtime]`).
--
-- xim does have that mechanism, and it is the same one mesa's DRI modules and
-- the glvnd vendor JSONs already use: install a tree, declare the variable that
-- names it. So the split is not a workaround — it is each index doing the thing
-- it models.
--
-- ─────────────────────────────────────────────────────────────────────────
-- WHAT WAS PRE-GENERATED, AND WHY THE TARBALL IS NOT UPSTREAM'S
--
-- Upstream ships a meson build whose only real job is to RUN THE RULES
-- COMPILER: `rules/evdev` is assembled from ~40 fragments at build time. A
-- consumer of this package needs the result, not the recipe, and building it
-- would put meson, python and a merge script into the dependency closure of a
-- package that ships no code.
--
-- So the tree is generated once, checked against upstream's own output, and
-- published as a data archive from mcpplibs/xkeyboard-config. 322 entries,
-- 505143 bytes, and the CN mirror is byte-identical (verified by sha256, not by
-- reachability — see mcpp-index's `mirror-cn-reachable` job for why that
-- distinction was worth making).
package = {
    spec = "2",

    homepage = "https://www.freedesktop.org/wiki/Software/XKeyboardConfig/",
    name = "xkeyboard-config",
    description = "Keyboard layout data for libxkbcommon (X11 xkb tree)",

    authors = {"X.Org Foundation"},
    licenses = {"MIT"},
    repo = "https://gitlab.freedesktop.org/xkeyboard-config/xkeyboard-config",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"graphics", "lib"},
    keywords = {"xkeyboard-config", "xkb", "keyboard", "graphics", "x11"},

    xpm = {
        linux = {
            -- No deps, and that is the whole point: text files have no ABI.
            -- The same tree serves any libxkbcommon, which is why it is
            -- versioned by the dataset rather than by a consumer.
            deps = {},
            ["latest"] = { ref = "2.48" },
            ["2.48"] = {
                url = {
                    GLOBAL = "https://github.com/mcpplibs/xkeyboard-config/releases/download/2.48/xkeyboard-config-2.48-data.tar.gz",
                    CN     = "https://gitcode.com/mcpp-res/xkeyboard-config/releases/download/2.48/xkeyboard-config-2.48-data.tar.gz",
                },
                sha256 = "7368528012f9756ba96ec5fc347b452dfd809770a9d59fbd10da6a8b6e52165f",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.log")
import("xim.libxpkg.xvm")
import("xim.pkgindex.graphics")

function install()
    local dir = pkginfo.install_dir()

    -- The archive has NO top-level directory — it unpacks straight to
    -- `share/X11/xkb/...`, so there is no `os.mv("xkeyboard-config-2.48", dir)`
    -- to write. That shape is deliberate: the payload IS the install prefix,
    -- so what lands in `install_dir` is exactly what a `share/` tree looks
    -- like everywhere else in this index, and `graphics.XKB_DIR` is one
    -- relative path with no version in it.
    os.tryrm(dir)
    os.mkdir(dir)
    os.mv("share", path.join(dir, "share"))

    -- The five directories `xkb_keymap_new_from_names` needs. Checked because
    -- an install that silently produced four of them would fail much later, as
    -- "keymap compilation failed" from inside a compositor — the failure would
    -- name libxkbcommon and the cause would be here.
    local root = path.join(dir, graphics.XKB_DIR)
    for _, sub in ipairs({"rules", "symbols", "keycodes", "types", "compat"}) do
        if not os.isdir(path.join(root, sub)) then
            log.warn("xkb dataset is missing %s/ -- keymap compilation will fail", sub)
            return false
        end
    end
    if not os.isfile(path.join(root, "rules", "evdev")) then
        log.warn("xkb dataset has no rules/evdev -- the RMLVO tuple every "
                 .. "Linux compositor uses cannot be resolved")
        return false
    end
    return true
end

function config()
    local binding = package.name .. "@" .. pkginfo.version()

    xvm.add(package.name)

    -- Two calls, and both are needed — declaring without placing gives a subos
    -- whose XKB_CONFIG_ROOT reads correctly and names nothing. See
    -- `graphics.declare_xkb` for the measurement that says so.
    graphics.declare_xkb(pkginfo.install_dir(), graphics.XKB_DIR, binding)

    -- XKB_CONFIG_ROOT, and only that. See `graphics.XKB_ONLY` for why a
    -- data-only package must not declare the other four rows.
    --
    -- xlings warns that a declared variable can load CODE from our payload
    -- into processes we do not own, and asks for the reason in the recipe.
    -- The reason is that this one cannot: the path leads to text files —
    -- rules, symbols, keycodes, types, compat — parsed by libxkbcommon's own
    -- parser. There is no dlopen at the end of it, and the worst a bad tree
    -- can do is fail to compile a keymap. RPATH is not an alternative here
    -- because nothing is being linked; the variable is how libxkbcommon is
    -- told where its DATA lives, and it is upstream's own interface for that
    -- (xkbcomp/rules.c, and `getenv("XKB_CONFIG_ROOT")` ahead of the
    -- compiled-in default).
    graphics.declare_subos_env(binding, graphics.XKB_ONLY)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
