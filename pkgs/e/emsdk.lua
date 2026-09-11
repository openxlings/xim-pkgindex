-- emsdk — Emscripten: a clang/LLVM-based C/C++ toolchain that targets
-- WebAssembly (wasm32-emscripten), built with a generated libc++ module
-- surface so `import std` compiles, links, and runs under node.
--
-- WHAT "emsdk" MEANS AS A PAYLOAD, AND WHAT WAS REJECTED
--
-- Upstream `emscripten-core/emsdk` is a BOOTSTRAPPER, not a toolchain: its
-- `emsdk.py` fetches the real compiler at install time from a second
-- location and has zero GitHub Releases of its own (verified:
-- `.../repos/emscripten-core/emsdk/releases` returns `[]`). Packaging the
-- bootstrapper would mean `install()` performs a network fetch, which this
-- index's own contract for a package forbids ("a build must never fetch").
--
-- What `emsdk.py` itself fetches is `emscripten-releases-builds` on Google
-- Cloud Storage, addressed by a git commit hash into the (separate)
-- `emscripten-releases` repository -- read directly out of
-- `emsdk.py`'s `emscripten_releases_download_url_template` and out of the
-- `"releases"` tool entry in `emsdk_manifest.json`:
--
--   https://storage.googleapis.com/webassembly/emscripten-releases-builds/
--       linux/<git-hash>/wasm-binaries.tar.xz            (x86_64)
--       linux/<git-hash>/wasm-binaries-arm64.tar.xz       (aarch64)
--
-- This is exactly the "one hashable download that needs no further network
-- access" the task requires: the hash names an immutable object, both
-- archs were downloaded and hashed for this recipe (see `xpm` below), and
-- the tarball needs nothing else to become a working toolchain -- verified
-- end to end (see PROOF below). This is the same shape `xim:llvm` already
-- uses for its own slim carve, and the numbered version (e.g. "6.0.9") is
-- resolved to its commit hash once, here, rather than at install time:
-- `emscripten-releases-tags.json`'s `latest` alias moves constantly
-- upstream (multiple releases a week), and baking the resolved hash into
-- the URL is what keeps this recipe's download byte-for-byte reproducible
-- regardless of what upstream ships next.
--
-- BOTH REGIONS. `storage.googleapis.com` for GLOBAL, and both archives
-- re-hosted on GitCode for CN (284 MB x86_64 + 263 MB aarch64, uploaded and
-- then downloaded back and hashed -- gtc has reported `uploaded` for an
-- object that was not what arrived). Emscripten is MIT / NCSA licensed, so
-- re-hosting it is legitimate; the size argument this replaces was a reason to
-- postpone the work, not a reason the work was wrong.
--
-- A version bump has to re-upload both arches. That is the cost, and it is
-- stated here so the next person bumping this knows the CN entry is not
-- self-maintaining: the URL is pinned to the tag, so a bump with no upload
-- leaves a CN entry pointing at nothing.
--
-- THE INSTALLED LAYOUT (relative to `pkginfo.install_dir()`; every path a
-- consumer -- including mcpp's toolchain registry -- hardcodes should be
-- one of these, all confirmed present after extraction):
--
--   bin/                            host-native LLVM/Binaryen tools this
--                                   build carries (clang, clang++, lld,
--                                   wasm-ld, wasm-opt, wasm2js, ...): the
--                                   COMPILER, not the entry point (see
--                                   below). LLVM_ROOT and BINARYEN_ROOT
--                                   both resolve here.
--   emscripten/                    the Python-driven Emscripten SDK proper
--     em++, emcc, emar, ...        shell-wrapper entry points; see EM++ IS
--                                   A WRAPPER below
--     .emscripten                  WRITTEN BY install() BELOW; absolute
--                                   paths baked in, never left to autodetect
--     emscripten-version.txt       "<version>-git"
--     cache/
--       sysroot/
--         include/c++/v1/          libc++ headers; __config's
--                                  `_LIBCPP_VERSION` is the number recorded
--                                  in EXPECTED_LIBCPP_VERSION below
--         lib/wasm32-emscripten/   target (wasm32) static libs
--         share/libc++/v1/         THE MODULE SURFACE -- see below
--
-- THE MODULE SURFACE NEEDS NO GENERATION HERE, UNLIKE xim:android-ndk.
--
-- The background measurement this package follows
-- (.agents/docs/2026-09-11-distribution-plugins-and-platform-decomposition.md
-- §3.1, in mcpp-community/mcpp) found the surface absent from Emscripten and
-- prescribed fetching `libcxx/modules/` from a matching `llvmorg-*` tag and
-- performing the `@LIBCXX_MODULE_STD_INCLUDE_SOURCES@` substitution by hand,
-- exactly as xim:android-ndk must. Re-measuring against the version this
-- recipe actually pins (a requirement of this task, not an assumption
-- carried over) found the opposite: this vendor's tarball already ships
-- `share/libc++/v1/std.cppm`, `std.compat.cppm`, and the 110 `std/*.inc` +
-- 21 `std.compat/*.inc` partitions the CMake substitution would otherwise
-- produce -- 134 files, 235497 bytes, with the substitution already
-- performed (`grep -c '@LIBCXX_MODULE_STD_INCLUDE_SOURCES@' std.cppm` is 0;
-- every one of the 110 `#include "std/*.inc"` lines names a file that is
-- actually there). It compiles against this same payload's own headers with
-- NO added flags, because both come from the one upstream build -- there is
-- no cross-version substitution step for this recipe to get wrong. So this
-- recipe neither generates the surface nor fetches or publishes it as a
-- separate asset: it is already inside the one archive `xpm` names, at the
-- path documented above, and install() below only verifies it is really
-- there and really compiles before letting the install succeed.
--
-- EM++ IS A WRAPPER, NOT A COMPILER BINARY.
--
-- `emscripten/em++` is a `#!/bin/sh` script (see `create_entry_points.py`
-- upstream) that execs `$EMSDK_PYTHON`, or failing that whatever `python3`
-- (then `python`) is first on PATH, to run `em++.py`. That the interpreter is
-- chosen by a shell wrapper before any config file is opened is a real and
-- unremovable property of upstream's design -- nothing this recipe writes into
-- `.emscripten` can substitute for it.
--
-- WHICH INTERPRETER IT FINDS IS THIS INDEX'S PROBLEM, AND DECLARING ONE IS
-- ONLY HALF OF IT. `xim:python` is a runtime dependency, so for a CONSUMER
-- `python3` on PATH is an xvm shim answering for the current SubOS rather than
-- whatever the machine happens to have.
--
-- INSIDE THIS INSTALL HOOK IT IS NOT. Shims are not on PATH there -- the same
-- property that made pkgs/a/android-system-image.lua's `debugfs` lookup fail
-- with the dependency correctly installed -- so install()'s own self-check
-- searched the MACHINE. On the Linux and macOS runners a system python3 exists
-- and it passed silently, which is a host fallthrough wearing an ecosystem
-- name. On Windows the archive bundles no python (measured: zero `python`
-- entries in its central directory) and the launcher found nothing it could
-- use. `__selfcheck_import_std` therefore resolves `xim:python` through
-- `dep_install_dir` and sets `EMSDK_PYTHON` explicitly. It was previously left undeclared with the argument that
-- `xim:python` covered x86_64 only -- true at the time, and an argument for
-- adding the missing payload rather than for depending on the host.
-- pkgs/p/python.lua now carries both arches (2026-09-11).
--
-- Once python3 is found, everything else is self-contained. `em++.py`
-- resolves `LLVM_ROOT`, `BINARYEN_ROOT` and `NODE_JS` from
-- `emscripten/.emscripten` -- found automatically beside `em++.py` itself
-- (`tools/config.py`'s `find_config_file()`, step 3, "Local .emscripten
-- file"), with NO `EM_CONFIG` environment variable required and WITHOUT
-- ever falling back to `~/.emscripten`. install() below writes this file
-- with absolute paths baked in, so `$HOME` plays no role at all: verified
-- by running `em++` with `HOME=/nonexistent` and a `PATH` containing only
-- `python3`, which resolved correctly and wrote nothing under `$HOME`.
--
-- NODE_JS IS MANDATORY FOR LINKING, NOT ONLY FOR RUNNING THE RESULT.
-- Measured: `emcc`'s own `read_config()` looks NODE_JS up unconditionally,
-- and a plain `-c` compile survives a broken NODE_JS, but the LINK step
-- fails outright --
--   em++: error: '<bad-path> .../tools/compiler.mjs -' failed: [Errno 2]
--   No such file or directory: '<bad-path>'
-- -- because linking itself runs Emscripten's own JS-side glue through
-- node. So this package declares `xim:node` as a real runtime dependency
-- (both linux archs it needs are covered there) and install() bakes the
-- dependency's own `bin/node` -- not a subos shim, not whatever `node`
-- happens to be on PATH -- into `NODE_JS`, so the toolchain does not depend
-- on the consumer's PATH for the one piece it cannot do without.
--
-- DO NOT RELOCATE THIS PAYLOAD AFTER INSTALL. Measured: `em++` records the
-- LLVM_ROOT it was configured with in `emscripten/cache/sanity.txt` on its
-- first run, and if a LATER run's `.emscripten` names a different LLVM_ROOT
-- (i.e. the directory was moved or copied elsewhere after that first run),
-- it prints "(Emscripten: config changed, clearing cache)" and DELETES
-- `emscripten/cache/sysroot` outright -- the module surface included. This
-- is why install() below writes `.emscripten` with the FINAL
-- `pkginfo.install_dir()`-based paths and only THEN invokes `em++` for the
-- first time ever: a pristine download carries no `sanity.txt` (verified:
-- absent from the archive), so there is nothing to conflict with and the
-- shipped, prebuilt sysroot is what every subsequent build actually uses.
-- (Separately measured, and recorded because it de-risks rather than
-- removes the warning: a wiped `cache/sysroot` self-heals from this same
-- payload's own bundled source, fully offline, in a few seconds -- it is
-- slow and pointless to trigger, not unrecoverable.)
--
-- `os.arch()` is not read anywhere in this recipe. Unlike node.lua /
-- jdk-zulu.lua, this archive's top-level directory is named `install` on
-- EVERY architecture this recipe declares (verified via `tar -tf` on both
-- the x86_64 and aarch64 archives), so there is no per-arch directory name
-- to recover from the downloaded filename in the first place.
package = {
    spec = "2",
    homepage = "https://emscripten.org",

    name = "emsdk",
    description = "Emscripten: a clang/LLVM C/C++ to WebAssembly toolchain, with a generated libc++ module surface for `import std`",

    maintainers = {"Emscripten authors"},
    licenses = {"MIT", "Apache-2.0 WITH LLVM-exception"},
    repo = "https://github.com/emscripten-core/emscripten",
    docs = "https://emscripten.org/docs/",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"compiler", "toolchain", "webassembly", "llvm"},
    keywords = {"emscripten", "emsdk", "wasm", "webassembly", "clang", "llvm", "em++", "emcc", "node"},

    programs = {"em++", "emcc"},
    xvm_enable = true,

    xpm = {
        linux = {
            -- Runtime deps, enumerated from the payload's own ELF closure
            -- (readelf -d over every file under bin/ and lib/; 30 ELF
            -- files, 8 external NEEDED entries total), not written from
            -- memory -- see contributing.md R7. glibc supplies libc, libm,
            -- libdl, librt, libpthread and the loader; gcc-runtime supplies
            -- libgcc_s (this build statically links its own libstdc++, so
            -- unlike xim:llvm's clang it needs no libstdc++.so.6 dep);
            -- zlib supplies libz. xim:node is not an ELF dependency of
            -- anything in this payload -- it is declared because linking
            -- through `em++` unconditionally shells out to it (see the
            -- NODE_JS header comment above), and install() below refuses
            -- rather than installing a toolchain that cannot link.
            deps = {
                runtime = {
                    "xim:glibc@>=2.39",
                    "xim:gcc-runtime@15.1.0",
                    "xim:zlib@1.3.1",
                    "xim:node@>=18",
                    -- THE INTERPRETER IS A DEPENDENCY, NOT A HOST ASSUMPTION.
                    --
                    -- `em++` is a `#!/bin/sh` wrapper that execs whatever
                    -- `python3` is first on PATH, so without this the whole
                    -- toolchain depended on a host interpreter -- which is the
                    -- one thing this index exists to avoid. It was left
                    -- undeclared because `xim:python` covered x86_64 only and
                    -- declaring it would have made this recipe's aarch64 half
                    -- uninstallable. That is now false: pkgs/p/python.lua
                    -- carries both arches (2026-09-11).
                    "xim:python@>=3.12",
                },
                -- A BUILD dep so install order is deterministic instead of
                -- trusting patchelf to already be on the shim PATH -- the
                -- same reason dpcpp.lua and libglvnd.lua declare it.
                -- Measured without this: elfpatch falls back to the HOST's
                -- /usr/bin/patchelf and warns rather than failing, so this
                -- is a determinism fix, not a functional one.
                build = { "xim:patchelf@0.18.0" },
            },
            -- The URL bakes in the emscripten-releases commit hash this
            -- version resolved to (see the header comment); `${arch_alias}`
            -- carries the "-arm64" suffix the aarch64 asset adds to the
            -- same path. Both archives were downloaded and hashed directly
            -- for this entry.
            ["latest"] = { ref = "6.0.9" },
            ["6.0.9"] = {
                url = {
                    GLOBAL = "https://storage.googleapis.com/webassembly/emscripten-releases-builds/linux/f04ea239d533260dd1db760dd2d668d5f9a88d6b/wasm-binaries${arch_alias}.tar.xz",
                    CN     = "https://gitcode.com/xlings-res/emsdk/releases/download/6.0.9/wasm-binaries${arch_alias}.tar.xz",
                },
                arch_alias = { x86_64 = "", aarch64 = "-arm64" },
                sha256 = {
                    x86_64 = "d5c6c2917fbc1cae1a7d1e581f1c0b2817369dd57f94c7a0d05921476f1a7287",
                    aarch64 = "04909913893cf83e5f40f27c2fca886b619b1d762f7ecc0945a1f2c9d453792c",
                },
            },
        },
        -- macOS AND WINDOWS, because upstream publishes them and a toolchain
        -- that exists for a host this index serves should be installable
        -- there. Measured 2026-09-11 with HEAD against the same commit hash
        -- the linux entry pins:
        --
        --   mac/<hash>/wasm-binaries.tar.xz        251 MB  x86_64
        --   mac/<hash>/wasm-binaries-arm64.tar.xz  262 MB  aarch64
        --   win/<hash>/wasm-binaries.zip           623 MB  x86_64
        --
        -- THE WINDOWS ARCHIVE IS A .zip AND NOT A .tar.xz, which is why the
        -- `${ext}` is spelled per platform rather than shared: probing
        -- `win/<hash>/wasm-binaries.tar.xz` returns 404, and a shared template
        -- would have produced exactly that URL.
        --
        -- THE EXECUTION EVIDENCE IS LINUX ONLY. install() was run end to end
        -- on linux-x86_64 -- `em++` compiled and linked an `import std`
        -- program and `node` ran it -- and the other three archives are
        -- declared with hashes taken from the downloads themselves. The
        -- index's own macos-install-test and windows-test are the measurement
        -- for those legs; stating the scope here rather than letting the
        -- table imply more than was checked.
        macosx = {
            deps = { runtime = { "xim:node@>=18", "xim:python@>=3.12" } },
            ["latest"] = { ref = "6.0.9" },
            ["6.0.9"] = {
                url = {
                    GLOBAL = "https://storage.googleapis.com/webassembly/emscripten-releases-builds/mac/f04ea239d533260dd1db760dd2d668d5f9a88d6b/wasm-binaries${arch_alias}.tar.xz",
                    CN     = "https://gitcode.com/xlings-res/emsdk/releases/download/6.0.9/wasm-binaries-mac${arch_alias}.tar.xz",
                },
                arch_alias = { x86_64 = "", aarch64 = "-arm64" },
                sha256 = {
                    x86_64  = "4d069a21f0527ae9e6decccb12933b0a68a0314d66253dee2f9b4a5c9c418613",
                    aarch64 = "b60514308507f64f4138d3c55bdb6979f20222288700fde603dced23b65dd533",
                },
            },
        },
        windows = {
            deps = { runtime = { "xim:node@>=18", "xim:python@>=3.12" } },
            ["latest"] = { ref = "6.0.9" },
            ["6.0.9"] = {
                -- NO CN ENTRY FOR THIS ONE ARCHIVE, AND THE REASON IS AN
                -- UPLOAD THAT WOULD NOT LAND rather than a licence or a
                -- decision. Three attempts on 2026-09-11, each answering
                --
                --   upload failed: {"message":"Fail to read response body,
                --   url:.../releases/6.0.9/obs_callback...,code:400,err:EOF"}
                --
                -- and each leaving a 128-byte error body served at the object's
                -- URL instead of the 624 MB archive.
                --
                -- THE ERROR ITSELF IS UNINFORMATIVE, which is why the check
                -- that caught this is the download-back: the two emsdk LINUX
                -- uploads reported the same `obs_callback 400` and both
                -- objects are correct, and `android-ndk-r30-darwin.zip` is
                -- 930 MB and uploaded cleanly -- so it is neither a size limit
                -- nor a reliable failure signal. Only re-fetching the object
                -- and hashing it separates the two.
                --
                -- A CN entry naming a 404 is worse than none: it would make
                -- every `--mirror CN` install of the Windows payload fail at
                -- the download with a hash mismatch on an error page. Left as
                -- GLOBAL-only until an upload verifies.
                url = "https://storage.googleapis.com/webassembly/emscripten-releases-builds/win/f04ea239d533260dd1db760dd2d668d5f9a88d6b/wasm-binaries.zip",
                sha256 = "f7512eab6e69ad9d7de5adbf39e68d7d6773b317b13e70ec5003ef1d10f92980",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

-- The `_LIBCPP_VERSION` (from `__config`: "LLVM XX.YY.ZZ" == "XXYYZZ") this
-- pinned version's libc++ -- and therefore its already-generated module
-- surface -- carries. Update alongside the version key above on every
-- bump; install() below refuses when the two disagree.
--
--   emsdk 6.0.9  ->  _LIBCPP_VERSION 220108  ->  llvm 22.1.8
--
-- This does NOT guard a cross-version substitution -- there isn't one, see
-- the header comment -- it guards against this comment going stale, and
-- against a future emsdk build reverting to the surface-less shape
-- xim:android-ndk's vendor still has, which install()'s later
-- `std.cppm` check is what would actually catch.
local EXPECTED_LIBCPP_VERSION = "220108"

-- The Python-wrapped entry points this package registers under their bare
-- upstream names. `em++`/`emcc` are load-bearing (config() fails without
-- both); the rest are best-effort. Deliberately excludes anything under
-- `bin/` -- those are host-native `clang`/`lld`/`wasm-opt` binaries, and
-- `xim:llvm` already owns the bare names `clang`/`clang++`; registering
-- this payload's copies under the same names would silently shadow one
-- toolchain with the other depending on install order.
local ENTRY_POINTS = {
    "em++", "emcc", "emar", "emranlib", "emconfigure", "emmake", "emcmake", "emrun", "em-config",
}
local REQUIRED_ENTRY_POINTS = { ["em++"] = true, ["emcc"] = true }

-- This package's own declared `xim:node` dependency's `bin/node`. Resolved
-- through `pkginfo.dep_install_dir`, i.e. the payload store root the
-- resolver actually chose -- never a subos shim or a bare PATH lookup (see
-- contributing.md R6 and llvm.lua's `__find_glibc_runtime`, which this
-- mirrors). Returns nil when the dependency did not resolve to a real
-- payload.
-- The declared `xim:python`'s interpreter, resolved through the dependency
-- rather than through PATH -- for the same reason `__find_node` is.
--
-- `em++` execs `$EMSDK_PYTHON`, or failing that whatever `python3` (then
-- `python`) is first on PATH. The header above argued that a declared
-- `xim:python` makes the PATH lookup an xvm shim, and that is true for a
-- CONSUMER and false inside this install hook: shims are not on PATH there.
-- So install()'s own self-check found whatever the MACHINE had, which on the
-- Linux and macOS runners is a system python3 -- a host fallthrough that
-- passed silently -- and on Windows is nothing the launcher accepts:
--
--   The filename, directory name, or volume label syntax is incorrect.
--   emsdk: could not precompile the shipped libc++ module surface (std.cppm)
--
-- The Windows archive bundles no python of its own (measured: zero `python`
-- entries in its central directory), so the interpreter has to come from the
-- dependency. Layouts differ: pkgs/p/python.lua registers `bin/python3` on
-- POSIX and on Windows registers nothing at all, installing `python.exe` at
-- the payload root.
local PYTHON_CANDIDATES = {
    path.join("bin", "python3"),
    path.join("bin", "python"),
    "python.exe",
    "python3.exe",
    path.join("bin", "python3.exe"),
    path.join("bin", "python.exe"),
    -- The CPython Windows installer's own layouts. `Scripts/` is where it puts
    -- pip and pythonw; `tools/` appears in some redistributable arrangements.
    path.join("Scripts", "python.exe"),
    path.join("tools", "python.exe"),
    path.join("python", "python.exe"),
}

-- Returns the interpreter, or nil plus a description of everything that was
-- examined.
--
-- THE SECOND RETURN EXISTS BECAUSE THE FIRST GUESS WAS WRONG AND THE MESSAGE
-- COULD NOT SAY WHY. `xim:python@3.12.6` installed on the Windows runner and
-- this function still answered nil, so the candidate list is wrong -- and the
-- refusal named neither the directory it looked in nor what it tried, which
-- makes the next attempt another guess. There is no precedent to copy:
-- `pkgs/m/meson.lua` is the only other consumer of this payload and it joins
-- `bin` unconditionally, while `vcstool.lua` and `rosdep.lua` use
-- `Scripts\python.exe` inside a VENV THEY CREATE, which is a different object.
--
-- `os.dirs` is bound inside an install hook and `os.files` is not (see
-- pkgs/l/libinput-quirks.lua), so the report lists SUBDIRECTORIES. That is
-- enough to tell "the payload is not where dep_install_dir says" from "it is
-- there and the interpreter has another name".
local function __find_python()
    local py_dir = pkginfo.dep_install_dir("xim:python")
    if not py_dir then
        return nil, "pkginfo.dep_install_dir(\"xim:python\") returned nothing"
    end
    for _, rel in ipairs(PYTHON_CANDIDATES) do
        local candidate = path.join(py_dir, rel)
        if os.isfile(candidate) then
            return candidate
        end
    end

    local report = "payload dir: " .. py_dir
        .. "\n       is a directory: " .. tostring(os.isdir(py_dir))
        .. "\n       tried:"
    for _, rel in ipairs(PYTHON_CANDIDATES) do
        report = report .. "\n         " .. rel
    end
    local subdirs = os.dirs(path.join(py_dir, "*")) or {}
    report = report .. "\n       subdirectories present (" .. #subdirs .. "):"
    for _, d in ipairs(subdirs) do
        report = report .. "\n         " .. path.filename(d)
    end
    return nil, report
end

local function __find_node()
    local node_dir = pkginfo.dep_install_dir("xim:node")
    if not node_dir then
        return nil
    end
    -- NODE'S OWN LAYOUT DIFFERS BY HOST, AND pkgs/n/node.lua IS WHERE THAT
    -- RULE LIVES. Its `config()` reads:
    --
    --   local bindir = pkginfo.install_dir()
    --   if os.host() ~= "windows" then
    --       bindir = path.join(pkginfo.install_dir(), "bin")
    --   end
    --
    -- so upstream's Windows archive puts `node.exe` at the root while the
    -- other two put `node` under `bin/`. This function hardcoded `bin/node`,
    -- which was every archive it had ever seen -- and the Windows install then
    -- failed at the config write, with `xim:node` already correctly declared
    -- AND installed:
    --
    --   emsdk: xim:node payload not found (this package's deps declare
    --   xim:node); refusing to write a NODE_JS-less emscripten config that
    --   cannot link anything
    --
    -- The message pointed at the declaration, which was the one thing that was
    -- right. Both candidates are tried rather than branching, so an archive
    -- that adopts the other layout keeps working.
    for _, rel in ipairs({
        path.join("bin", "node"),
        path.join("bin", "node.exe"),
        "node",
        "node.exe",
    }) do
        local candidate = path.join(node_dir, rel)
        if os.isfile(candidate) then
            return candidate
        end
    end
    return nil
end

-- Write `emscripten/.emscripten` with absolute paths baked in, so nothing
-- at build time depends on PATH, `EM_CONFIG`, or `$HOME` (see the EM++ IS A
-- WRAPPER header comment for what was measured). `CACHE`/`PORTS` are left
-- unset: they default to `<emscripten_root>/cache` via the SDK's own
-- `path_from_root`, which is already correct because it is relative to
-- `em++.py`'s own location rather than to anything this recipe computes.
local function __write_emscripten_config(dir, node_bin)
    -- `.emscripten` IS PYTHON SOURCE, AND A WINDOWS PATH IS NOT A PYTHON
    -- STRING LITERAL.
    --
    -- `em++.py` evaluates this file. On Windows the paths arrive with
    -- backslashes, so `C:\Users\...` puts `\U` inside a single-quoted Python
    -- literal and Python reads it as a unicode escape:
    --
    --   em++: error: error in evaluating config file (...\.emscripten):
    --     (unicode error) 'unicodeescape' codec can't decode bytes in position
    --     2-3: truncated \UXXXXXXXX escape
    --     text: LLVM_ROOT = 'C:\Users\runneradmin\...\6.0.9/bin'
    --
    -- Note the path in that message is MIXED -- `path.join` contributed a
    -- forward slash to an otherwise backslashed path -- which is the same
    -- mixed-separator property that breaks a cmd.exe command line, surfacing
    -- here as a different failure in a different language.
    --
    -- Forward slashes throughout. Python accepts them on Windows, emscripten's
    -- own tooling normalises them, and one spelling means the file reads the
    -- same on every host. Escaping the backslashes instead would work and
    -- would leave two spellings of every path in a file that is generated.
    --
    -- THIS WAS FOUND ONLY AFTER THE INVOCATION WAS FIXED. Three earlier shapes
    -- failed before `em++` ever started, so its own diagnostic never appeared
    -- and this defect sat behind them. A failure that prevents a program from
    -- running hides every failure that program would have reported.
    local function fwd(v) return (tostring(v):gsub("\\", "/")) end
    local cfg = "LLVM_ROOT = '" .. fwd(path.join(dir, "bin")) .. "'\n"
        .. "BINARYEN_ROOT = '" .. fwd(dir) .. "'\n"
        .. "NODE_JS = '" .. fwd(node_bin) .. "'\n"
    io.writefile(path.join(dir, "emscripten", ".emscripten"), cfg)
end

-- Assert on the artifact: `_LIBCPP_VERSION` read back out of the INSTALLED
-- payload's own header must match what this recipe's version claims (see
-- EXPECTED_LIBCPP_VERSION above).
local function __check_libcxx_version(dir)
    local cfgfile = path.join(dir, "emscripten", "cache", "sysroot", "include", "c++", "v1", "__config")
    local content = io.readfile(cfgfile)
    if not content then
        raise("emsdk: no libc++ __config header at " .. cfgfile)
    end
    local version = content:match("_LIBCPP_VERSION%s+(%d+)")
    if not version then
        raise("emsdk: could not read _LIBCPP_VERSION out of " .. cfgfile)
    end
    if version ~= EXPECTED_LIBCPP_VERSION then
        raise("emsdk: this payload's libc++ reports _LIBCPP_VERSION " .. version
            .. ", but this recipe (version " .. pkginfo.version() .. ") records "
            .. EXPECTED_LIBCPP_VERSION .. " in EXPECTED_LIBCPP_VERSION. The module"
            .. " surface still ships alongside whatever libc++ this build"
            .. " actually carries, so `import std` is not necessarily broken --"
            .. " but the recipe's comment is now stale and must be corrected"
            .. " before this version is trusted.")
    end
end

-- The end-to-end proof this whole package exists for, run for real at
-- install time rather than asserted from a version string (R4: assert on
-- the artifact, not the intent) -- precompile the SHIPPED module surface's
-- top-level unit to a BMI against this payload's own headers, compile and
-- link a probe translation unit against that BMI, then run the result
-- under the resolved `xim:node` payload and check its actual output. This
-- is also the one check that exercises NODE_JS end to end: the link step
-- is what calls out to node (see the header comment), so a wrong or
-- unusable NODE_JS fails HERE, not on a consumer's first real build.
-- Run one of this payload's own programs and capture its output.
--
-- GENERAL, BECAUSE THE THIRD CALLER PROVED IT HAD TO BE. This began as a
-- python-specific helper for the two `em++.py` invocations, and `node` was
-- left on a bare `os.iorun(string.format('"%s" "%s"', ...))` -- the same
-- construction, the same defect, one site further on. It surfaced only after
-- the first two were fixed and the probe reached the run: `node did not print
-- the expected "1-2-3" (got: )`, with the Windows message appearing twice and
-- no output at all.
--
-- ON WINDOWS: A SCRIPT FILE, RUN WITH `os.exec`, REDIRECTING ITS OWN OUTPUT.
-- Shapes that failed here, all on `os.iorun`:
--
--   "<exe>" "<arg>" ...
--   powershell -NoProfile -ExecutionPolicy Bypass -Command "& '<exe>' ..."
--   "<scratch>\run.bat"                          (one token, no quoting)
--
--   The filename, directory name, or volume label syntax is incorrect.
--
-- Every Windows invocation in this index that WORKS uses `os.exec` or
-- `system.exec` (pkgs/7/7zip.lua, pkgs/v/vcstool.lua). Three attempts varied
-- the command STRING while holding the CALL constant, and the call was wrong.
-- `os.iorun` was chosen because this function must return the output; a script
-- that redirects itself removes that requirement and frees the invocation to
-- be the proven form.
--
-- `cmd.exe /d /s /c "<bat>"` is the documented shape -- `/d` skips AutoRun,
-- `/s` fixes quote handling -- and a batch file is not an executable image, so
-- it needs cmd either way.
--
-- `scratch` is passed rather than derived from the last argument: the previous
-- version took `path.directory(argv[#argv])`, which happened to be right for
-- an `-o <path>` call and would silently write the script somewhere else for a
-- call whose last argument is not a path.
local function __run_captured(scratch, exe, argv)
    if is_host("windows") then
        local function w(v) return (tostring(v):gsub("/", "\\")) end
        local bat = w(path.join(scratch, "run-captured.bat"))
        local out = w(path.join(scratch, "run-captured.out"))

        local line = string.format('"%s"', w(exe))
        for _, a in ipairs(argv) do
            line = line .. string.format(' "%s"', w(a))
        end
        line = line .. string.format(' > "%s" 2>&1', out)

        io.writefile(bat, "@echo off\r\n" .. line .. "\r\n")

        -- os.exec raises on a non-zero exit; every caller decides by its own
        -- criterion (an artefact appearing, or the output matching), so a
        -- failure still has to return the log.
        try { function()
            os.exec(string.format('cmd.exe /d /s /c "%s"', bat))
        end }
        return os.isfile(out) and (io.readfile(out) or "") or ""
    end
    local parts = {}
    for _, a in ipairs(argv) do
        table.insert(parts, string.format('"%s"', tostring(a)))
    end
    return os.iorun(string.format('"%s" %s', exe, table.concat(parts, " ")))
end

local function __selfcheck_import_std(dir, node_bin)
    -- RUN THE INTERPRETER ON `em++.py`, NOT THE WRAPPER.
    --
    -- The wrapper's whole job is to find an interpreter, and inside an install
    -- hook it cannot find the declared one: xvm shims are not on PATH there.
    -- Naming the interpreter and the script removes the search instead of
    -- trying to steer it, and it is the same command on every host -- no
    -- `.exe`, no `$EMSDK_PYTHON`, no dependence on which `os` names this hook
    -- runtime happens to bind (`os.setenv` is not among the ones this index
    -- has verified; `os.files`, `os.exists` and `os.iorunv` are documented as
    -- absent in pkgs/l/libinput-quirks.lua).
    --
    -- `em++.py` is present in all three archives, measured in their central
    -- directories alongside `em++` / `em++.exe`.
    local py, why = __find_python()
    if not py then
        raise("emsdk: no interpreter in the xim:python payload. `em++` is a"
            .. " wrapper around `em++.py` and needs one, and inside an install"
            .. " hook the xvm shim for it is not on PATH -- so it has to be"
            .. " named explicitly.\n       " .. tostring(why))
    end
    local emxx_py = path.join(dir, "emscripten", "em++.py")
    if not os.isfile(emxx_py) then
        raise("emsdk: no emscripten/em++.py in the payload at " .. dir
            .. "; the self-check invokes the interpreter on the script rather"
            .. " than on the wrapper, so this file is required.")
    end

    local scratch = path.join(dir, ".selfcheck")
    os.tryrm(scratch)
    os.mkdir(scratch)

    local app_cpp = path.join(scratch, "app.cpp")
    io.writefile(app_cpp, [[
import std;
int main() {
  std::vector<int> v{3,1,2};
  std::ranges::sort(v);
  std::print("{}-{}-{}\n", v[0], v[1], v[2]);
}
]])

    -- Same host suffix the install probe applies; this is the call that
    -- actually EXECUTES the driver, so an unsuffixed path here fails on
    -- Windows after the probe has already passed.
    local stdcppm = path.join(dir, "emscripten", "cache", "sysroot", "share", "libc++", "v1", "std.cppm")
    local stdpcm = path.join(scratch, "std.pcm")
    local appjs = path.join(scratch, "app.js")

    -- No added flags: measured against this exact payload, `std.cppm`
    -- #includes this same payload's own headers and needs nothing else.
    local out1 = try { function()
        return __run_captured(scratch, py,
                              {emxx_py, "-std=c++23", "--precompile",
                               stdcppm, "-o", stdpcm})
    end }
    if not os.isfile(stdpcm) then
        raise("emsdk: could not precompile the shipped libc++ module surface"
            .. " (std.cppm) -- `import std` will not work with this install.\n"
            .. tostring(out1))
    end

    local out2 = try { function()
        return __run_captured(scratch, py,
                              {emxx_py, "-std=c++23",
                               "-fmodule-file=std=" .. stdpcm,
                               app_cpp, stdpcm, "-o", appjs})
    end }
    if not os.isfile(appjs) then
        raise("emsdk: compiling/linking the `import std` probe failed (this is"
            .. " the step that calls out to NODE_JS -- check that the resolved"
            .. " xim:node payload's node actually runs).\n" .. tostring(out2))
    end

    local ran = try { function()
        return __run_captured(scratch, node_bin, {appjs})
    end }
    if not ran or not ran:find("1-2-3", 1, true) then
        raise("emsdk: node did not print the expected \"1-2-3\" from the"
            .. " `import std` probe (got: " .. tostring(ran) .. ")")
    end

    os.tryrm(scratch)
    log.info("emsdk: import-std probe compiled, linked and ran under node (%s)", node_bin)
end

function install()
    local dir = pkginfo.install_dir()

    -- The archive's own top level is one directory literally named
    -- `install` (verified via `tar -tf` on both arch archives). xim
    -- extracts into a runtimedir shared with other packages' downloads
    -- (see dpcpp.lua's header comment), and that name is generic enough
    -- that trusting it without a completeness check would move whatever
    -- happens to already be sitting there. Assertions come first, before
    -- anything is moved out of that shared directory.
    local extracted = "install"
    -- THE EXECUTABLE NAMES CARRY THE HOST'S SUFFIX. The probe named `em++`
    -- and `bin/clang` unsuffixed, which is every archive this recipe served
    -- while it declared only `xpm.linux` -- and would refuse a correct
    -- Windows payload, where the compiler is `bin/clang.exe`. `std.cppm` has
    -- no suffix on any host.
    --
    -- THE SUFFIX IS `.exe`, NOT `.bat`. The first Windows version of this
    -- probe guessed `.bat` from how emscripten's own installer wraps these
    -- entry points on Windows, and the archive disagrees. Measured by reading
    -- the central directory of `wasm-binaries.zip` (12882 entries): all nine
    -- entry points this recipe registers ship as `<name>.exe` beside a
    -- `<name>.py`, and no `.bat` exists for any of them. One rule covers the
    -- whole set, which is why `exe` is computed once and applied uniformly
    -- rather than special-casing the driver.
    local exe = is_host("windows") and ".exe" or ""
    local required_probe = {
        path.join(extracted, "emscripten", "em++" .. exe),
        path.join(extracted, "bin", "clang" .. exe),
        path.join(extracted, "emscripten", "cache", "sysroot", "share", "libc++", "v1", "std.cppm"),
    }
    for _, p in ipairs(required_probe) do
        if not os.isfile(p) then
            raise("emsdk: the downloaded archive is missing " .. p
                .. "; refusing to move anything out of the shared download directory")
        end
    end

    os.tryrm(dir)
    os.mv(extracted, dir)

    __check_libcxx_version(dir)

    local node_bin = __find_node()
    if not node_bin then
        raise("emsdk: xim:node payload not found (this package's deps declare"
            .. " xim:node); refusing to write a NODE_JS-less emscripten config"
            .. " that cannot link anything")
    end

    -- Config must be written with the FINAL install path, and BEFORE the
    -- first-ever invocation of em++ below -- see the DO NOT RELOCATE header
    -- comment. A pristine download carries no sanity.txt, so this is that
    -- first invocation and there is nothing for it to conflict with.
    __write_emscripten_config(dir, node_bin)

    __selfcheck_import_std(dir, node_bin)

    return true
end

function config()
    local dir = pkginfo.install_dir()
    local bindir = path.join(dir, "emscripten")
    local binding = package.name .. "@" .. pkginfo.version()

    xvm.add(package.name)

    -- The FILE carries the host suffix; the SHIM does not. `xvm.add` is given
    -- the bare upstream name on every host (the idiom qemu-riscv.lua uses for
    -- `qemu-system-riscv64`), so a user types `em++` everywhere -- only the
    -- existence check has to spell the real file.
    local exe = is_host("windows") and ".exe" or ""
    local n = 0
    local required_hits = 0
    for _, prog in ipairs(ENTRY_POINTS) do
        if os.isfile(path.join(bindir, prog .. exe)) then
            xvm.add(prog, { bindir = bindir, alias = prog, binding = binding })
            n = n + 1
            if REQUIRED_ENTRY_POINTS[prog] then
                required_hits = required_hits + 1
            end
        else
            log.warn("emsdk: skip xvm add (not found): " .. prog)
        end
    end

    -- Same complement pair llvm.lua's config() uses: zero registrations is
    -- never correct, and registrations that miss every load-bearing name
    -- (em++/emcc) mean the payload does not look like this recipe's
    -- toolchain even though something got installed.
    if n == 0 then
        log.error("emsdk: no registerable programs found in " .. bindir)
        return false
    end
    if required_hits < 2 then
        log.error("emsdk: em++/emcc missing from " .. bindir
            .. "; the payload does not look like an emscripten install")
        return false
    end

    return true
end

function uninstall()
    local dir = pkginfo.install_dir()
    local bindir = path.join(dir, "emscripten")

    xvm.remove(package.name)
    for _, prog in ipairs(ENTRY_POINTS) do
        if os.isfile(path.join(bindir, prog)) then
            xvm.remove(prog)
        end
    end

    return true
end
