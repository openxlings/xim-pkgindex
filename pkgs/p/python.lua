package = {

    -- Platform version sets differ ON PURPOSE:
    -- windows stays on its own `latest` (3.12.6); linux carries 3.12.13/3.13.12.
    -- Declared so `tests/check_platform_version_parity.lua` can tell this
    -- apart from a bump that landed in one section and was forgotten in the
    -- others -- which reads as `<pkg>@<ver> not found` on the platforms that
    -- lack it, against a file that contains the version string.
    platform_versions_diverge = true,
    spec = "1",
    homepage = "https://www.python.org",
    name = "python",
    description = "The Python programming language",
    maintainers = {"Python Software Foundation"},
    licenses = {"PSF-License", "GPL-compatible"},
    type = "package",
    repo = "https://github.com/python/cpython",
    docs = "https://docs.python.org/3",

    -- xim pkg info
    archs = {"x86_64", "aarch64"},
    status = "stable", -- dev, stable, deprecated
    categories = {"python", "plang", "interpreter"},
    keywords = {"python", "programming", "scripting", "language"},

    xvm_enable = true,

    xpm = {
        linux = {
            -- glibc, so elfpatch has a loader provider to key off. Without a
            -- dep declaring exports.runtime.loader the predicate never fires
            -- and the payload keeps python-build-standalone's INTERP, which is
            -- the HOST's /lib64/ld-linux-x86-64.so.2.
            deps = { "xim:glibc@>=2.39" },
            -- BOTH ARCHES, AND BOTH REGIONS.
            --
            -- The single-arch table was the reason `xim:emsdk` could not
            -- declare a Python dependency: `em++` is a `#!/bin/sh` wrapper
            -- that execs whatever `python3` is first on PATH, so without an
            -- aarch64 payload here the only way emsdk could run at all on
            -- aarch64 was a HOST interpreter -- which is the leak this index
            -- exists to close. python-build-standalone publishes the aarch64
            -- Linux build alongside the x86_64 one; it is the same upstream
            -- release, downloaded and hashed here (2026-09-11).
            --
            -- The GLOBAL URL is upstream's own. It was absent -- the table
            -- named only the GitCode object, so a `--mirror GLOBAL` install
            -- still went through the CN host. Safe to add because the mirror
            -- is byte-identical: the x86_64 object's sha256 fetched from
            -- github.com/astral-sh/python-build-standalone matches this
            -- recipe's recorded hash exactly, which is what says the two
            -- hosts serve the same artifact rather than merely the same name.
            --
            -- No `arch_alias`: upstream's asset names are literally `x86_64`
            -- and `aarch64`, so the canonical arch names substitute directly.
            source = {
                GLOBAL = "https://github.com/astral-sh/python-build-standalone/releases/download/20260310/cpython-${version}%2B20260310-${arch}-unknown-linux-gnu-install_only.tar.gz",
                CN     = "https://gitcode.com/xlings-res/mirror-cn/releases/download/python/cpython-${version}%2B20260310-${arch}-unknown-linux-gnu-install_only.tar.gz",
            },
            ["latest"] = { ref = "3.13.12" },
            ["3.13.12"] = {
                sha256 = {
                    x86_64  = "a1d58266fede23e795b1b7d1dee3cc77470538fd14292a46cc96e735af030fec",
                    aarch64 = "563bf262875fc0c6a22dbbb35ab7df3082184f5a587c16c534b8712e4e05c7c2",
                },
            },
            -- 3.12.13 stays x86_64-only and unhashed, as it was: nothing
            -- consumes it, and mirroring a second aarch64 payload for a
            -- version with no consumer would be work with no reader.
            ["3.12.13"] = {
                url = "https://gitcode.com/xlings-res/mirror-cn/releases/download/python/cpython-3.12.13%2B20260310-x86_64-unknown-linux-gnu-install_only.tar.gz",
                sha256 = nil,
            }
        },
        -- macOS, ADDED BECAUSE A DEP CHECK REFUSED THE OMISSION, and the
        -- refusal was right:
        --
        --   dep `xim:python@>=3.12` is declared under xpm.macosx, but `python`
        --   has sections for [linux, windows] only -- it cannot be resolved on
        --   macosx.
        --
        -- `xim:emsdk` declares that dep on all three hosts because `em++` is a
        -- shell wrapper that execs `python3` on every one of them. So the
        -- omission here was not a scope decision, it was a hole one platform
        -- wide -- and the index's own dep check is what found it rather than a
        -- macOS user discovering emsdk unusable.
        --
        -- Same upstream release as the linux entry, and the same install():
        -- python-build-standalone's macOS archives extract to `python/` too.
        -- Downloaded and hashed 2026-09-11; not executed, since no macOS host
        -- was involved -- the index's macos-install-test is that measurement.
        macosx = {
            ["latest"] = { ref = "3.13.12" },
            ["3.13.12"] = {
                url = "https://github.com/astral-sh/python-build-standalone/releases/download/20260310/cpython-3.13.12%2B20260310-${arch}-apple-darwin-install_only.tar.gz",
                sha256 = {
                    x86_64  = "d778d46b49c640a54a13dc2bd356561b4d4f85466a2d21bc0ab1483a209bb05c",
                    aarch64 = "8b49181b776a9ebc8323a645dc55126b389d62c50a0b9f072e37811a9391244d",
                },
            },
        },
        -- WINDOWS WAS AN INSTALLER INVOCATION, NOT A PAYLOAD, AND THE
        -- DIFFERENCE IS INVISIBLE UNTIL SOMETHING ASKS FOR THE PAYLOAD.
        --
        -- The old entry was `python-3.12.6-amd64.exe`, driven with
        -- `/passive InstallAllUsers=1 PrependPath=1 TargetDir=<install_dir>`.
        -- On a Windows runner that left `<install_dir>` EXISTING AND EMPTY, and
        -- `xim` reported the package installed -- so the package's own
        -- post-install check passed on a directory-existence test, and anything
        -- reading `pkginfo.dep_install_dir("xim:python")` got a directory with
        -- nothing in it. Measured through pkgs/e/emsdk.lua, whose diagnostic
        -- reported:
        --
        --   payload dir: C:\Users\runneradmin\.xlings\data\xpkgs\xim-x-python\3.12.6
        --   is a directory: true
        --   subdirectories present (0):
        --
        -- `InstallAllUsers=1` needs elevation and `/passive` cannot ask for it,
        -- which is the likeliest reason; either way the payload was empty while
        -- the install reported success.
        --
        -- python-build-standalone publishes Windows, which is what the other
        -- two platform tables already use. Measured 2026-09-11: the archive
        -- extracts to `python/` exactly as the Linux and macOS ones do, so
        -- install() needs no host branch at all, and the interpreter lands at
        -- `<install_dir>/python.exe`. No installer, no elevation, and a real
        -- relocatable payload that `dep_install_dir` can point at.
        --
        -- `Scripts/` ships EMPTY -- this distribution carries no pip -- so
        -- config() bootstraps it with `python -m ensurepip`, which keeps the
        -- `pip`/`pip3` shims this package has always registered.
        windows = {
            ["latest"] = { ref = "3.13.12" },
            ["3.13.12"] = {
                url = {
                    GLOBAL = "https://github.com/astral-sh/python-build-standalone/releases/download/20260310/cpython-3.13.12%2B20260310-x86_64-pc-windows-msvc-install_only.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/mirror-cn/releases/download/python/cpython-3.13.12%2B20260310-x86_64-pc-windows-msvc-install_only.tar.gz",
                },
                sha256 = "6204052c096536f9fa926f8312a1dcd5ac0846dc182a0c05ee0011d580546af0",
            },
            -- Kept alongside for the same reason the linux table keeps one:
            -- `xim:emsdk` declares `xim:python@>=3.12`, and a consumer pinning
            -- the 3.12 line must resolve to something on every host.
            ["3.12.13"] = {
                url = {
                    GLOBAL = "https://github.com/astral-sh/python-build-standalone/releases/download/20260310/cpython-3.12.13%2B20260310-x86_64-pc-windows-msvc-install_only.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/mirror-cn/releases/download/python/cpython-3.12.13%2B20260310-x86_64-pc-windows-msvc-install_only.tar.gz",
                },
                sha256 = "b9f9d17a11944c13a3a2798c8b48ec861b2f10710dc345094f567beed4271427",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")
import("xim.pkgindex.sysroot")

function install()
    -- ONE PATH FOR EVERY HOST. All three platform tables now name a
    -- python-build-standalone tarball and all three extract to `python/`, so
    -- the host branch that used to drive the Windows installer is gone (see
    -- the note on the windows table for what it left behind).
    os.tryrm(pkginfo.install_dir())
    os.mv("python", pkginfo.install_dir())

    -- AND THE OUTCOME IS CHECKED, BECAUSE THE OLD PATH DID NOT CHECK ITS OWN.
    -- An install that reports success with an empty payload is worse than one
    -- that fails: every consumer downstream then reads a directory with
    -- nothing in it and reports its own unrelated-looking error.
    local interpreter = os.host() == "windows"
        and path.join(pkginfo.install_dir(), "python.exe")
        or  path.join(pkginfo.install_dir(), "bin", "python3")
    if not os.isfile(interpreter) then
        raise("python: the payload has no interpreter at " .. interpreter
              .. " after extraction; refusing to report an install that a"
              .. " consumer would read as an empty directory")
    end
    return true
end

function config()
    if os.host() == "windows" then
        -- SHIMS ON WINDOWS TOO, WHICH THIS PACKAGE COULD NOT REGISTER BEFORE.
        --
        -- The old path drove the official installer with `PrependPath=1`, so
        -- the interpreter reached a user through WINDOWS' PATH rather than
        -- through xvm -- which is why this branch only said "restart the
        -- terminal" and registered nothing. The consequence was not only a
        -- missing shim: `xlings use python <v>` could not select between
        -- versions there, and `dep_install_dir` pointed at an empty directory.
        --
        -- The payload is relocatable now, so the same registrations the other
        -- hosts get apply. The interpreter is `python.exe` at the payload root
        -- (measured), and there is no `python3.exe` -- so `python` is the real
        -- name and `python3` is the alias, which is the inverse of the POSIX
        -- branch below.
        local bindir = pkginfo.install_dir()

        -- pip IS NOT IN THIS DISTRIBUTION. `Scripts/` ships empty (measured),
        -- and the installer this replaced supplied pip through
        -- `Include_pip=1`. `ensurepip` is the documented way to get it and the
        -- module is present in the payload, so the shims this package has
        -- always registered keep working.
        local py = path.join(bindir, "python.exe")
        local ensured = try { function()
            return os.iorun(string.format('"%s" -m ensurepip --upgrade', py))
        end }
        if not ensured then
            log.warn("python: `ensurepip` did not complete; the pip shims are "
                     .. "skipped and `python -m ensurepip` can be run by hand")
        end

        xvm.add("python", { bindir = bindir })
        xvm.add("python3", { bindir = bindir, alias = "python" })

        local scripts = path.join(bindir, "Scripts")
        if os.isfile(path.join(scripts, "pip.exe")) then
            xvm.add("pip", { bindir = scripts,
                             binding = "python@" .. pkginfo.version() })
            xvm.add("pip3", { bindir = scripts, alias = "pip",
                              binding = "python@" .. pkginfo.version() })
        else
            log.warn("python: no Scripts/pip.exe after ensurepip; pip shims "
                     .. "not registered")
        end
        log.info("Please restart the terminal to take effect.")
    else
        local bindir = path.join(pkginfo.install_dir(), "bin")

        xvm.add("python3", { bindir = bindir })
        xvm.add("python", { bindir = bindir, alias = "python3" })
        xvm.add("pip3", { bindir = bindir, binding = "python@" .. pkginfo.version() })
        xvm.add("pip", { version = "python-" .. pkginfo.version(), bindir = bindir, alias = "pip3", binding = "python@" .. pkginfo.version() })

        -- Install Python dev headers into subos sysroot so that the subos GCC
        -- can compile C extensions (e.g. evdev, mujoco) without missing pyconfig.h
        local includedir = path.join(pkginfo.install_dir(), "include")
        local sysrootdir = system.subos_sysrootdir()
        if sysrootdir and os.isdir(includedir) then
            -- Declared where the client supports it, so the headers follow
            -- `xlings use` between python versions instead of being
            -- whichever version was installed last -- which matters here,
            -- because the directory name carries the version
            -- (include/python3.13) and two of them can coexist.
            log.info("Linking Python dev headers into subos sysroot ...")
            if not sysroot.declare_headers(pkginfo.install_dir(), "include",
                                           "usr/include",
                                           "python@" .. pkginfo.version()) then
                local sysroot_usrdir = path.join(sysrootdir, "usr")
                if not os.isdir(sysroot_usrdir) then os.mkdir(sysroot_usrdir) end
                sysroot.install_headers(includedir, path.join(sysroot_usrdir, "include"))
            end
        end
    end
    return true
end

function uninstall()
    -- THE MSI BRANCH IS GONE WITH THE MSI. It ran
    -- `<installer>.exe /uninstall /passive`, and carried a workaround for the
    -- installer file not being on disk when uninstall fires -- a whole branch
    -- whose subject no longer exists now that Windows extracts a tarball like
    -- the other two hosts.
    --
    -- What remains is what the POSIX branch already did, and it is correct on
    -- every host: withdraw the registrations. The payload directory itself is
    -- xim's to remove.
    xvm.remove("python", pkginfo.version())
    xvm.remove("pip", "python-" .. pkginfo.version())

    return true
end