package = {
    spec = "1",

    name = "xmake",
    description = "A cross-platform build utility based on Lua",

    authors = {"ruki"},
    maintainers = {"ruki"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/xmake-io/xmake",
    ci = { update = true },
    homepage = "https://xmake.io",
    docs = "https://xmake.io/#/getting_started",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"build-system", "tools"},
    keywords = {"xmake", "build", "lua", "cross-platform"},

    programs = {"xmake"},
    xvm_enable = true,

    -- WHY `latest` TRACKS A GLIBC-DYNAMIC BUNDLE, AND WHY 3.0.7 IS KEPT
    --
    -- Upstream stopped shipping a musl-static Linux bundle at v3.0.8. The
    -- v3.0.8 release.yml says it is cross-built with `xrepo env -b zig xmake f
    -- --embed=y --toolchain=zig --cross=x86_64-linux-musl`, but the artifact
    -- actually uploaded is glibc-dynamic, and that has not been corrected
    -- since. RE-MEASURED 2026-08-13 on xmake-bundle-v3.1.0.linux.x86_64
    -- (sha256 1baab457f3bf11032e82c6210bc5bec04f5b902962da17dab53cae10783170de)
    -- with readelf, not read off the release notes:
    --
    --     Type:        DYN (PIE), has PT_INTERP
    --     NEEDED:      libncurses.so.6, libtinfo.so.6, libm.so.6, libc.so.6
    --     max GLIBC_:  2.38          <- the floor declared in linux deps below
    --
    -- The index pinned `latest = 3.0.7` over this until 2026-08-13, on the
    -- argument that a bump would REGRESS arch coverage: a dynamic bundle must
    -- declare `xim:glibc`, xim resolves deps per-OS rather than per-arch, and
    -- glibc is `archs = {"x86_64"}`, so linux/aarch64 would start failing at
    -- dependency resolution. That argument does not survive contact with this
    -- file, on two counts:
    --
    --   * this recipe ALREADY carries an x86_64-only linux dep. `ncurses` is
    --     `archs = {"x86_64"}` and has been in the linux block since
    --     2026-08-09, so adding glibc spends no coverage that is still unspent.
    --   * upstream publishes no linux-aarch64 bundle at all. The v3.1.0 assets
    --     are linux.x86_64, macos.arm64, macos.x86_64, win32/win64/arm64.exe
    --     and cosmocc — and the linux URL below is hardcoded `.linux.x86_64`.
    --     "3.0.7 is zero-dep and works on both arches" was never true of linux;
    --     the aarch64 in `archs` above is the macOS bundle.
    --
    -- So the dependency is declarable and xlings resolves it: in form X the
    -- closure installs glibc + ncurses from the index, in form H they come from
    -- the host. That is the same trade bazel.lua and cmake.lua already make, and
    -- it is why `latest` now tracks 3.1.0.
    --
    -- 3.0.7 is KEPT rather than deleted: it is the last musl-static bundle and
    -- the only entry that still runs on Alpine / distroless in form H, where
    -- 3.1.0 will not. Pin it explicitly (`xmake@3.0.7`) on such hosts.
    --
    -- Also considered and rejected: xmake-bundle-v3.1.0.cosmocc (Cosmopolitan
    -- APE). It genuinely has no ELF NEEDED, but it is a DOS/MBR-header hybrid
    -- that rewrites itself on first run — it trips binfmt_misc assumptions and
    -- noexec/read-only payload dirs, which is the opposite of what a package
    -- payload should do.
    --
    -- NEXT BUMP costs one readelf on the new linux bundle: if NEEDED or the max
    -- GLIBC_ reference move, update the linux deps; if upstream ever restores a
    -- musl-static bundle, the deps can be dropped entirely.
    xpm = {
        linux = {
            -- Both deps are read straight off the readelf measurement above,
            -- and as of `latest = 3.1.0` they are live requirements rather
            -- than anticipatory ones: glibc supplies libc.so.6 + libm.so.6 at
            -- GLIBC_2.38, ncurses supplies libncurses.so.6 + libtinfo.so.6.
            -- (While `latest` was the static 3.0.7 this block drew the D1
            -- "declares X, but nothing in the payload names a soname it
            -- provides" warning; the bump is what clears it.)
            --
            -- They bite in form X / subos, where there is no host fallback and
            -- libtinfo must come from the index — mcpp#392 is exactly an
            -- xmake-adjacent binary crashing on that gap. In form H both
            -- resolve from host SONAMEs and look redundant.
            --
            -- Bare name for ncurses, not `xim:ncurses`, deliberately: ncurses
            -- entered the index recently enough that check-dep-namespace.lua
            -- still carries it as a not-yet-published exemption, and a name the
            -- compiled catalog lacks cannot be served by CI's overlay (a miss
            -- triggers the auto-refresh that clobbers the overlay). The harness
            -- registers new packages under local:, and bare names prefer primary repos
            -- (local: in CI, xim: once published) over the scode sub-index —
            -- so the bare form resolves correctly in every state this recipe
            -- meets. posix-test.sh records the same rule: "a new package is
            -- referenced bare, a changed published one with xim:". glibc is
            -- long-published, so it takes the `xim:` form.
            deps = { "ncurses", "xim:glibc@>=2.38" },
            -- `source` map rather than `url_template`: it carries the CN leg,
            -- and version-check.py's bump appends `["<ver>"] = { sha256 }`
            -- against it, so the mirror survives future auto-bumps instead of
            -- being flattened back to a single GitHub URL.
            source = {
                GLOBAL = "https://github.com/xmake-io/xmake/releases/download/v${version}/xmake-bundle-v${version}.linux.x86_64",
                CN = "https://gitcode.com/xlings-res/xmake/releases/download/${version}/xmake-bundle-v${version}.linux.x86_64",
            },
            ["latest"] = { ref = "3.1.1" },
            ["3.1.1"] = {
                sha256 = "fe1da8861a5ee5845d4f6c84e499f6f9c6bf5b5a69c9b7b130930ee28355a6d5",
            },
            ["3.1.0"] = {
                sha256 = "1baab457f3bf11032e82c6210bc5bec04f5b902962da17dab53cae10783170de",
            },
            -- Last musl-static bundle (verified: `statically linked`, zero
            -- DT_NEEDED). Kept for Alpine / distroless form-H hosts; see the
            -- header comment. Its sha256 used to be nil — on the one package
            -- whose whole story is "upstream shipped something other than what
            -- the release notes claimed", an unpinned fallback was the wrong
            -- gap to leave open. Resolves through the `source` map above, so it
            -- gets the CN leg too.
            ["3.0.7"] = {
                sha256 = "59371d344722fd7f2883d1d5ce347a3bac0493d3e80e85a8e438603eaee9b958",
            },
        },
        macosx = {
            source = {
                GLOBAL = "https://github.com/xmake-io/xmake/releases/download/v${version}/xmake-bundle-v${version}.macos.arm64",
                CN = "https://gitcode.com/xlings-res/xmake/releases/download/${version}/xmake-bundle-v${version}.macos.arm64",
            },
            ["latest"] = { ref = "3.1.1" },
            ["3.1.1"] = {
                sha256 = "a614dedc4dd765209949350ce4a0449638542df8147837fb1ba1ce4e9a0ff8ac",
            },
            ["3.1.0"] = {
                sha256 = "296ee53b26e17adc2de5533e3695234c843089712c372db611293ad96ba8ab45",
            },
            ["3.0.7"] = {
                sha256 = "999093c3455d3537d6012a5d51a05d736275d55dfb43e59a4b84d519f3e97966",
            },
        },
        windows = {
            source = {
                GLOBAL = "https://github.com/xmake-io/xmake/releases/download/v${version}/xmake-bundle-v${version}.win64.exe",
                CN = "https://gitcode.com/xlings-res/xmake/releases/download/${version}/xmake-bundle-v${version}.win64.exe",
            },
            ["latest"] = { ref = "3.1.1" },
            ["3.1.1"] = {
                sha256 = "5de3d5167a8b5e8ad95af2fba9ab5a62a626d7e789350d0affc33af450c4a9ad",
            },
            ["3.1.0"] = {
                sha256 = "41f497ed71f076a9ecf14100e77af5509656a5e41dfd4da8d068b1319a8ef895",
            },
            ["3.0.7"] = {
                sha256 = "beb282f889357c7a6125ccf334c2476aebf26119a12e0cb86cf4e7d272192f68",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    local exe_name = "xmake"
    if os.host() == "windows" then
        exe_name = "xmake.exe"
    else
        os.exec("chmod +x " .. pkginfo.install_file())
    end

    os.mv(pkginfo.install_file(), path.join(pkginfo.install_dir(), exe_name))
    return true
end

function config()
    xvm.add("xmake")
    return true
end

function uninstall()
    xvm.remove("xmake")
    return true
end
