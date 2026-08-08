package = {
    spec = "1",
    homepage = "https://mesonbuild.com",

    name = "meson",
    description = "The Meson build system",
    authors = {"The Meson development team"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/mesonbuild/meson",
    docs = "https://mesonbuild.com/Manual.html",

    type = "package",
    -- Architecture-independent content. `x86_64` is what this index publishes
    -- for; a second arch should be given this same tarball.
    archs = {"x86_64"},
    status = "stable",
    categories = {"build", "tool"},
    keywords = {"meson", "build", "ninja", "buildsystem"},

    programs = {"meson"},
    xvm_enable = true,

    -- WHY THIS PACKAGE EXISTS
    --
    -- There was no meson in this index, while
    -- `.agents/tools/graphics/build-in-subos.sh` called `$SUBOS/bin/meson`
    -- unconditionally -- a path present in no home. So every meson build in this
    -- tree, **mesa included**, was driven by whatever meson the developer's host
    -- happened to have, usually a `pip --user` install (#562).
    --
    -- The host-leakage audit could not catch it: that audit inspects what the
    -- build driver FOUND (meson-log.txt, build.ninja) and never the driver.

    xpm = {
        linux = {
            -- python, and nothing else. meson is pure Python -- the build script
            -- asserts no payload member has an ELF magic number -- so there is no
            -- loader, no libc and no C++ runtime in the picture.
            --
            -- A floor rather than a pin: meson 1.8 supports python >= 3.7, and
            -- pinning would make this package refuse a home that upgraded python
            -- for unrelated reasons.
            deps = { "xim:python@>=3.9" },
            ["latest"] = { ref = "1.8.2" },
            -- 1.8.2 is the version `build-in-subos.sh` already pins as its
            -- vendored fallback (MESON_PIN), so packaging it changes which COPY a
            -- build uses and not which VERSION -- one variable at a time.
            ["1.8.2"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/meson/releases/download/1.8.2/meson-1.8.2-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/meson/releases/download/1.8.2/meson-1.8.2-linux-x86_64.tar.gz",
                },
                sha256 = "6afe6e96f53771b2c3810a7861e5b80de034ee306242877846de470f520b44e6",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

function install()
    local src = pkginfo.install_file():replace(".tar.gz", "")
    if not os.isdir(src) then
        -- By content, not by name: the extraction directory is shared.
        local base = path.directory(src)
        local found = nil
        for _, d in ipairs(os.dirs(path.join(base, "*"))) do
            if os.isfile(path.join(d, "meson.py")) then found = d; break end
        end
        if not found then
            raise("cannot find the payload root under '" .. base
                  .. "': no extracted directory contains meson.py")
        end
        src = found
    end

    os.tryrm(pkginfo.install_dir())
    os.mv(src, pkginfo.install_dir())

    for _, f in ipairs({"meson.py", "mesonbuild/mesonmain.py"}) do
        if not os.isfile(path.join(pkginfo.install_dir(), f)) then
            raise("meson payload is missing " .. f)
        end
    end

    log.info("meson: " .. pkginfo.version() .. " in place (pure Python)")
    return true
end

-- An `alias` shim, not a generated launcher.
--
-- `alias` is a COMMAND LINE, not merely another name for the binary -- gcc.lua
-- appends `--sysroot=...` straight into it (`config.alias = prog .. alias_args`).
-- So `meson` can be a shim that execs python with meson.py as its first argument,
-- and this package ships no wrapper script at all.
--
-- The alternative, writing `bin/meson` at install time (the media-crawler
-- pattern), works too and is strictly worse here: a generated shell script is one
-- more artifact whose interpreter lookup nobody audits, and it would resolve
-- `python3` through the ambient PATH -- which is how a build ends up using the
-- host's interpreter, the very thing #562 is about.
--
-- `bindir` is python's OWN payload, found through pkginfo.dep_install_dir -- the
-- same helper gcc.lua uses to locate glibc's loader. That makes the interpreter
-- explicit and hermetic.
--
-- The trade-off, stated rather than discovered later: this resolves python once,
-- at meson-install time. Switch python afterwards and meson keeps using the
-- interpreter it was configured with. For a build driver that is the safer
-- direction -- a build should not change interpreter under you because something
-- else was switched -- but it does mean `xlings use python <other>` does not move
-- meson, and a python REMOVAL leaves this shim pointing at a gone payload.
function config()
    local py = pkginfo.dep_install_dir("python")
    if not py then
        raise("meson: cannot locate the python dependency's payload; "
              .. "the shim would have no interpreter to exec")
    end

    local bindir = path.join(py, "bin")
    -- Named explicitly, because the two spellings are not interchangeable on
    -- every payload and a missing one must fail here rather than at first use.
    local interp = nil
    for _, cand in ipairs({"python3", "python"}) do
        if os.isfile(path.join(bindir, cand)) then interp = cand; break end
    end
    if not interp then
        raise("meson: python payload at " .. bindir
              .. " has neither bin/python3 nor bin/python")
    end

    xvm.add("meson", {
        bindir = bindir,
        alias  = interp .. " " .. path.join(pkginfo.install_dir(), "meson.py"),
    })
    log.info("meson: shim execs " .. interp .. " " .. path.join(pkginfo.install_dir(), "meson.py"))
    return true
end

function uninstall()
    xvm.remove("meson")
    return true
end
