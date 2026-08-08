package = {
    spec = "2",

    homepage = "https://www.alsa-project.org",
    name = "alsa-lib",
    description = "ALSA userspace library (libasound) — required by the JDK's javax.sound",

    authors = {"ALSA project"},
    licenses = {"LGPL-2.1"},
    repo = "https://github.com/alsa-project/alsa-lib",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"audio", "lib"},
    keywords = {"alsa", "libasound", "audio", "sound", "jdk"},

    -- WHY THIS IS PACKAGED
    --
    -- The other half of what blocks the JDK loader migration:
    --
    --   libjsound.so NEEDED: libasound.so.2 libc.so.6
    --
    -- Switching a JDK's PT_INTERP to our loader removes all host fallback (our
    -- glibc's compiled-in cache path exists on no machine), so every library in
    -- the JDK's closure has to be ours before the switch can happen. `libXtst`
    -- covers AWT; this covers javax.sound.sampled.
    --
    -- See openxlings/xim-pkgindex#568.

    xpm = {
        linux = {
            -- Just glibc, and measured rather than assumed:
            --
            --   objdump -p lib/libasound.so.2.0.0 | grep NEEDED
            --     libm.so.6  libc.so.6  ld-linux-x86-64.so.2
            --
            -- All three are glibc's. There is no second-level dependency here
            -- despite alsa-lib's reputation, because the parts that would bring
            -- one (python bindings, topology, UCM) are configured out.
            deps = { "xim:glibc@>=2.38" },
            exports = {
                runtime = { libdirs = { "lib" } },
            },
            ["latest"] = { ref = "1.2.11" },
            ["1.2.11"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/alsa-lib/releases/download/1.2.11/alsa-lib-1.2.11-linux-x86_64.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/alsa-lib/releases/download/1.2.11/alsa-lib-1.2.11-linux-x86_64.tar.gz",
                },
                sha256 = "c95f1535f267608378d115a820e6b4aa29df408df0f8a1d45a866371957fb4e8",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")
import("xim.pkgindex.sysroot")
import("xim.pkgindex.selfcontain")

function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    os.mv("alsa-lib-1.2.11", dir)

    -- The SONAME libjsound.so asks for. The `.so` dev symlink existing says
    -- nothing about whether the runtime name resolves.
    if not os.isfile(path.join(dir, "lib", "libasound.so.2")) then
        raise("alsa-lib payload has no lib/libasound.so.2 -- that is the SONAME "
              .. "libjsound.so has a DT_NEEDED on")
    end

    -- Built with --disable-python --disable-topology --disable-ucm: only the ELF
    -- is wanted here. The Python bindings, the topology parser and the UCM
    -- configuration manager are separate concerns that would enlarge both the
    -- payload and its closure for something the JDK never calls.
    --
    -- Consequence worth stating: this package is NOT a general-purpose alsa-lib.
    -- A consumer that needs UCM (PulseAudio/PipeWire config, embedded audio
    -- profiles) needs a differently-configured build, and should get its own
    -- version rather than silently inheriting this one.
    selfcontain.seal(dir)
    log.info("alsa-lib: libasound in place (no python/topology/ucm)")
    return true
end

function config()
    local binding = package.name .. "@" .. pkginfo.version()

    xvm.add(package.name)

    sysroot.declare_libs(pkginfo.install_dir(), "lib", binding, pkginfo.version())

    if not sysroot.declare_headers_tree(pkginfo.install_dir(), "include",
                                        "usr/include", binding) then
        sysroot.install_headers_tree(
            path.join(pkginfo.install_dir(), "include"),
            path.join(system.subos_sysrootdir(), "usr", "include"))
    end
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
