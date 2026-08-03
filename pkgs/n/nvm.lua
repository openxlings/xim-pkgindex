-- `nvm` is two unrelated upstreams wearing one name, and this file carries
-- both:
--
--   * linux / macosx -> nvm-sh/nvm. A *pure shell* project: the tag archive
--     holds nvm.sh, nvm-exec and bash_completion and nothing else. There is
--     no compiled artifact, so "static musl" has no meaning here, and one
--     archive serves every platform/arch -- hence a single url per platform
--     rather than a per-arch resource map.
--
--   * windows -> coreybutler/nvm-windows, a separate Go program on its own
--     1.x version line. We take `nvm-noinstall.zip` (the portable drop)
--     instead of `nvm-setup.exe`: the installer rewrites the user's PATH and
--     registry, which is exactly what subos isolation forbids. The portable
--     zip is configured entirely by a `settings.txt` we write into the
--     install dir plus two env vars carried on the shim.
--
-- Only linux/macosx opt into the version checker: both track `package.repo`
-- (nvm-sh/nvm) and agree on `latest`. Windows tracks a different repo on a
-- different version line, so it stays manual -- opting it in would make the
-- checker reject the whole package for "per-platform 'latest' refs disagree".

package = {
    spec = "2",
    name = "nvm",
    description = "Node Version Manager - POSIX-compliant node.js version manager",
    homepage = "https://github.com/nvm-sh/nvm",
    authors = {"Tim Caswell"},
    maintainers = {"https://github.com/nvm-sh/nvm?tab=readme-ov-file#maintainers"},
    licenses = {"MIT"},
    type = "package",
    repo = "https://github.com/nvm-sh/nvm",
    docs = "https://github.com/nvm-sh/nvm#installing-and-updating",

    -- xim pkg info
    archs = {"x86_64", "aarch64"},
    status = "stable", -- dev, stable, deprecated
    categories = {"tools", "nodejs"},
    keywords = {"nvm", "node", "nodejs", "version-manager"},

    -- `nvm-exec` is registered too (POSIX only), but it is deliberately not
    -- declared here: CI reads this list as "every name must have a shim on
    -- every platform", and windows ships no nvm-exec.
    programs = {"nvm"},
    xvm_enable = true,

    -- Windows tracks a different repo (coreybutler/nvm-windows) on a different
    -- version line, so both the version checker and the mirror stay on the
    -- linux/macosx pair -- opting windows in would trip "per-platform 'latest'
    -- refs disagree" the moment the two upstreams released independently.
    ci = { mirror = true, update = true, platforms = {"linux", "macosx"} },

    xpm = {
        linux = {
            url_template = "https://github.com/nvm-sh/nvm/archive/refs/tags/v{version}.tar.gz",

            ["latest"] = { ref = "0.40.6" },
            ["0.40.6"] = {
                url = "https://github.com/nvm-sh/nvm/archive/refs/tags/v0.40.6.tar.gz",
                sha256 = "17302cad7feedb1ad33ba738f93d2176a90970724f22de119603624fcbdec1a2",
            },
            -- Was `"XLINGS_RES"`, which resolved only to a linux-x86_64 and a
            -- macosx-arm64 asset -- so it could not serve the aarch64/x86_64
            -- halves this package now declares. The xlings-res asset was
            -- verified byte-identical to this upstream archive (same sha256),
            -- so pointing at upstream keeps the pin resolving and makes it
            -- arch-independent. `ci.mirror` re-publishes it for CN.
            ["0.40.4"] = {
                url = "https://github.com/nvm-sh/nvm/archive/refs/tags/v0.40.4.tar.gz",
                sha256 = "5949b50e4640f2be2263f963952673d7f1a8745a83f05365e99f032fe78307fd",
            },
        },
        macosx = {
            url_template = "https://github.com/nvm-sh/nvm/archive/refs/tags/v{version}.tar.gz",

            ["latest"] = { ref = "0.40.6" },
            ["0.40.6"] = {
                url = "https://github.com/nvm-sh/nvm/archive/refs/tags/v0.40.6.tar.gz",
                sha256 = "17302cad7feedb1ad33ba738f93d2176a90970724f22de119603624fcbdec1a2",
            },
            ["0.40.4"] = {
                url = "https://github.com/nvm-sh/nvm/archive/refs/tags/v0.40.4.tar.gz",
                sha256 = "5949b50e4640f2be2263f963952673d7f1a8745a83f05365e99f032fe78307fd",
            },
        },
        windows = {
            -- nvm-windows publishes an md5 sidecar, not sha256; the archive
            -- below was checked against nvm-noinstall.zip.checksum.txt
            -- (md5 d654c26a04e35a318d5939f8ceb09934) before its sha256 was
            -- recorded here.
            ["latest"] = { ref = "1.2.2" },
            ["1.2.2"] = {
                url = "https://github.com/coreybutler/nvm-windows/releases/download/1.2.2/nvm-noinstall.zip",
                sha256 = "74232ea51c060ecd44ecf2cebee314ed9e3f6da56e1f9484d8d46c4e8bb6ae0e",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

-- Why every launcher below hardcodes NVM_DIR instead of taking it from the
-- shim's `envs`: xvm merges env values PATH-style. `merge_shim_env_value`
-- prepends the declared value to whatever the process already exports and
-- joins them with the path separator, which is right for PATH-like lists and
-- wrong for every scalar. A user with `NVM_DIR=$HOME/.nvm` already exported
-- (anyone who ran upstream's install.sh, or an older revision of this
-- package) would get `NVM_DIR=<xpkg-dir>:/home/u/.nvm` and nvm.sh would fail
-- to source. So no `envs` here at all -- the launchers assign NVM_DIR
-- themselves, which also stops a stale NVM_DIR from dragging this install
-- back out to ~/.nvm.

-- The POSIX launcher.
--
-- nvm's entry point is a *shell function* created by sourcing nvm.sh, so
-- until we write one there is no executable for a shim to point at. This is
-- that executable: it sources nvm.sh in a bash subshell and forwards argv,
-- which covers every subcommand whose work happens in a child process --
-- install / uninstall / ls / ls-remote / which / exec / run / alias / ...
--
-- `use` and `deactivate` are the two that cannot work this way: by definition
-- they re-point PATH in the *calling* shell, and a shim is a child process.
-- Rather than let them exit 0 having changed nothing, say so on stderr and
-- name the two things that do work.
--
-- `--no-use` keeps sourcing from activating a default version on every call.
local function posix_launcher(nvm_dir)
    return string.format([[#!/usr/bin/env bash
# generated by xlings-xim from pkgs/n/nvm.lua -- do not edit
export NVM_DIR="%s"

case "$1" in
    use|deactivate)
        echo "xlings: 'nvm $1' re-points PATH in the shell that runs it, and this" >&2
        echo "        launcher is a child process -- the change is discarded on exit." >&2
        echo "        to switch interactively, source nvm into your own shell:" >&2
        echo "            export NVM_DIR=\"$NVM_DIR\"; . \"\$NVM_DIR/nvm.sh\"" >&2
        echo "        or let xlings route the node shim instead:" >&2
        echo "            xlings install node@<version> && xlings use node <version>" >&2
        ;;
esac

if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    echo "xlings: $NVM_DIR/nvm.sh is missing -- reinstall with 'xlings install nvm'" >&2
    exit 1
fi

# shellcheck source=/dev/null
. "$NVM_DIR/nvm.sh" --no-use

# Sourcing defines `nvm` as a shell function, and a function shadows the PATH
# lookup that would otherwise land back on this launcher's own shim. If it did
# not get defined, `nvm "$@"` below would re-enter the shim forever -- so fail
# loudly instead of recursing.
if [ "$(type -t nvm)" != "function" ]; then
    echo "xlings: sourcing nvm.sh did not define the nvm function" >&2
    exit 1
fi

nvm "$@"
]], nvm_dir)
end

-- Upstream's nvm-exec resolves its own directory from ${BASH_SOURCE[0]}, but
-- the nvm.sh it then sources still honours an inherited NVM_DIR. Pin it for
-- the same reason as above, then hand off.
local function posix_exec_launcher(nvm_dir)
    return string.format([[#!/usr/bin/env bash
# generated by xlings-xim from pkgs/n/nvm.lua -- do not edit
export NVM_DIR="%s"
exec "$NVM_DIR/nvm-exec" "$@"
]], nvm_dir)
end

-- The windows launcher. This one is load-bearing, not a convenience: nvm.exe
-- reads *only* the environment to find itself --
--
--   var home    = filepath.Clean(os.Getenv("NVM_HOME") + "\\settings.txt")
--   var symlink = filepath.Clean(os.Getenv("NVM_SYMLINK"))
--
-- (nvm-windows src/nvm.go). It never derives settings.txt from the exe's own
-- directory, so with NVM_HOME unset it looks for `\settings.txt` at the drive
-- root, and with NVM_HOME left over from a previous nvm-setup.exe run it would
-- drive that install instead of ours. `set` inside `setlocal` is process-local,
-- so both are pinned without touching the user's environment and without going
-- through the merging `envs` path.
local function windows_launcher(nvm_dir, symlink_dir)
    return string.format([[@echo off
rem generated by xlings-xim from pkgs/n/nvm.lua -- do not edit
setlocal
set "NVM_HOME=%s"
set "NVM_SYMLINK=%s"
"%s\nvm.exe" %%*
]], nvm_dir, symlink_dir, nvm_dir)
end

function install()
    local install_dir = pkginfo.install_dir()
    local download_dir = path.directory(pkginfo.install_file())
    os.tryrm(install_dir)

    if os.host() == "windows" then
        -- nvm-noinstall.zip is flat -- nvm.exe and friends land directly in
        -- the extraction dir with no enclosing folder to rename. Copy the
        -- three files nvm.exe actually uses (elevate.* is how it asks for the
        -- rights to create the version symlink) and leave the installer
        -- scripts, icons and the archive itself behind.
        os.mkdir(install_dir)
        for _, f in ipairs({"nvm.exe", "elevate.cmd", "elevate.vbs"}) do
            os.cp(path.join(download_dir, f), path.join(install_dir, f))
        end

        local win_dir = (install_dir:gsub("/", "\\"))
        -- The "active node" symlink deliberately sits *beside* the version dir
        -- rather than inside it: nvm-windows' own `nvm debug` reports nesting
        -- NVM_SYMLINK under NVM_HOME as "known to cause problems in many
        -- Windows environments". One level up is still inside this package's
        -- own xpkgs subtree (so still isolated, unlike the installer's
        -- C:\Program Files\nodejs) and it survives nvm upgrades. It must not
        -- be pre-created -- nvm.exe refuses a NVM_SYMLINK that already exists
        -- as a physical directory.
        local win_symlink = (path.join(path.directory(install_dir), "nodejs"):gsub("/", "\\"))

        -- settings.txt supplies `root`; `arch` is deliberately omitted so
        -- nvm.exe keeps its own default of PROCESSOR_ARCHITECTURE. Hardcoding
        -- `arch: 64` would pin x64 node on the arm64 windows hosts this
        -- package now declares. `path` is not read by nvm.go's setup() at all
        -- (NVM_SYMLINK is the operative value) but is written for parity with
        -- upstream's own install.cmd.
        io.writefile(path.join(install_dir, "settings.txt"), string.format(
            "root: %s\r\npath: %s\r\nproxy: none\r\n", win_dir, win_symlink
        ))

        io.writefile(path.join(install_dir, "nvm.cmd"),
                     windows_launcher(win_dir, win_symlink))
    else
        -- The tag archive's single top-level dir is `nvm-<version>`. xim
        -- extracts next to the download; probe both spellings rather than
        -- globbing, because `os.dirs` shells out to `ls`, which is not on the
        -- hook PATH in the C++ xim runtime.
        local extracted = "nvm-" .. pkginfo.version()
        if not os.isdir(extracted) then
            extracted = path.join(download_dir, extracted)
        end
        if not os.isdir(extracted) then
            log.error("extracted nvm dir not found (version %s)", pkginfo.version())
            return false
        end
        os.mv(extracted, install_dir)

        -- Both shims point at bin/, so upstream's own nvm-exec is wrapped
        -- rather than registered directly -- that is the only way to pin
        -- NVM_DIR for it too.
        local bindir = path.join(install_dir, "bin")
        os.mkdir(bindir)

        local launchers = {
            [path.join(bindir, "nvm")] = posix_launcher(install_dir),
            [path.join(bindir, "nvm-exec")] = posix_exec_launcher(install_dir),
        }
        for file, content in pairs(launchers) do
            io.writefile(file, content)
            os.execute('chmod +x "' .. file .. '"')
        end
        os.execute('chmod +x "' .. path.join(install_dir, "nvm-exec") .. '"')
    end

    return true
end

function config()
    local install_dir = pkginfo.install_dir()

    if os.host() == "windows" then
        xvm.add("nvm", { bindir = install_dir, alias = "nvm.cmd" })
    else
        local bindir = path.join(install_dir, "bin")

        xvm.add("nvm", { bindir = bindir })

        -- `nvm-exec node -v` resolves the version from .nvmrc / $NODE_VERSION.
        -- `binding` keeps it switching in lockstep with nvm itself.
        xvm.add("nvm-exec", {
            bindir = bindir,
            binding = "nvm@" .. pkginfo.version(),
        })

        -- Revisions of this package before 0.40.6 unpacked into ~/.nvm and
        -- appended a source snippet to the user's shell profile. Both are left
        -- alone -- that directory holds their installed node versions -- but
        -- the snippet defines a real `nvm` shell function, and a shell
        -- function beats a PATH shim every time. Say so once instead of
        -- letting the shim look broken.
        local home = os.getenv("HOME")
        if home and os.isdir(path.join(home, ".nvm")) then
            log.warn("legacy ~/.nvm found (left untouched -- it holds your installed node versions)")
            log.warn("  an older xlings nvm also wrote a '# nvm config by xlings-xim' block into")
            log.warn("  your shell profile; that block defines an nvm function that shadows this")
            log.warn("  shim. Remove the block to let `nvm` resolve to xlings.")
        end
    end

    return true
end

function uninstall()
    xvm.remove("nvm")
    if os.host() == "windows" then
        -- The active-node symlink lives beside the version dir, so xim's own
        -- removal of install_dir does not reach it.
        os.tryrm(path.join(path.directory(pkginfo.install_dir()), "nodejs"))
    else
        xvm.remove("nvm-exec")
    end
    return true
end
