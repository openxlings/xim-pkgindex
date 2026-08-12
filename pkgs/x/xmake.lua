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

    -- v3.0.8 and everything after it deliberately skipped: although the v3.0.8
    -- release.yml says the Linux bundle is built with `xrepo env -b zig xmake f
    -- --embed=y --toolchain=zig --cross=x86_64-linux-musl`, the artifact actually
    -- uploaded to the v3.0.8 release page is *not* a musl-static binary —
    -- it's glibc-dynamic with INTERP=/lib64/ld-linux-x86-64.so.2 and
    -- DT_NEEDED libncurses.so.6 + libtinfo.so.6, breaking on Alpine /
    -- distroless / any host without those libs. v3.0.7 (and prior) are
    -- correctly musl-static, so we pin `latest = 3.0.7` until upstream
    -- re-uploads a corrected bundle. Tracking issue: TBD.
    --
    -- RE-CHECKED 2026-08-12 against v3.1.0 (the then-current stable, released
    -- 2026-08-08) — still not fixed, so the pin stays. Measured, not read off the
    -- release notes, on xmake-bundle-v3.1.0.linux.x86_64
    -- (sha256 1baab457f3bf11032e82c6210bc5bec04f5b902962da17dab53cae10783170de):
    --
    --     Type: DYN (PIE), has PT_INTERP
    --     NEEDED: libncurses.so.6, libtinfo.so.6, libm.so.6, libc.so.6
    --
    -- Bumping is not merely "less portable", it would REGRESS arch coverage: a
    -- dynamic bundle needs `xim:glibc` (+ ncurses) declared, xim resolves deps
    -- per-OS rather than per-arch, and glibc is `archs = {"x86_64"}` — so every
    -- linux/aarch64 install would start failing at dependency resolution. The
    -- static 3.0.7 bundle needs no deps at all and works on both arches. Record
    -- the measurement here so the next bump attempt costs one readelf, not a
    -- rediscovery.
    --
    -- Also considered and rejected: xmake-bundle-v3.1.0.cosmocc (Cosmopolitan
    -- APE). It genuinely has no ELF NEEDED, but it is a DOS/MBR-header hybrid
    -- that rewrites itself on first run — it trips binfmt_misc assumptions and
    -- noexec/read-only payload dirs, which is the opposite of what a package
    -- payload should do.
    xpm = {
        linux = {
            -- ncurses declared (2026-08-09), measured with readelf, and the
            -- measurement is version-split:
            --
            --   3.0.7 (the pinned latest)  static, no INTERP, no NEEDED —
            --                              needs nothing at runtime
            --   3.0.8 (skipped, see above) glibc-dynamic, NEEDED
            --                              libncurses.so.6 + libtinfo.so.6
            --
            -- So today this dep draws the D1 "declares X, but nothing in the
            -- payload names a soname it provides" WARNING against 3.0.7, and
            -- that is the accurate state: the declaration is for the moment
            -- the pin moves to any dynamic bundle (3.0.8's shape), and for
            -- form-X/subos consumers, where libtinfo must come from the index
            -- because our loader has no host fallback — mcpp#392 is exactly
            -- an xmake-adjacent binary crashing on that gap. The ecosystem-
            -- side fix is this edge (ncurses provides the sonames); the
            -- host-glibc side is C1's version floor in glibc.lua. Form H
            -- resolution today is unchanged either way: host SONAMEs keep
            -- working.
            --
            -- Bare name, not `xim:ncurses`, deliberately: ncurses is NEW in
            -- the index, and a new name cannot be served by CI's overlay
            -- (the compiled catalog has no entry; a miss triggers the
            -- auto-refresh that clobbers the overlay). The harness registers
            -- new packages under local:, and bare names prefer primary repos
            -- (local: in CI, xim: once published) over the scode sub-index —
            -- so the bare form resolves correctly in every state this recipe
            -- meets. posix-test.sh records the same rule: "a new package is
            -- referenced bare, a changed published one with xim:".
            deps = { "ncurses" },
            url_template = "https://github.com/xmake-io/xmake/releases/download/v{version}/xmake-bundle-v{version}.linux.x86_64",
            ["latest"] = { ref = "3.0.7" },
            ["3.0.7"] = {
                url = "https://github.com/xmake-io/xmake/releases/download/v3.0.7/xmake-bundle-v3.0.7.linux.x86_64",
                sha256 = nil,
            },
        },
        macosx = {
            url_template = "https://github.com/xmake-io/xmake/releases/download/v{version}/xmake-bundle-v{version}.macos.arm64",
            ["latest"] = { ref = "3.0.7" },
            ["3.0.7"] = {
                url = "https://github.com/xmake-io/xmake/releases/download/v3.0.7/xmake-bundle-v3.0.7.macos.arm64",
                sha256 = nil,
            },
        },
        windows = {
            url_template = "https://github.com/xmake-io/xmake/releases/download/v{version}/xmake-bundle-v{version}.win64.exe",
            ["latest"] = { ref = "3.0.7" },
            ["3.0.7"] = {
                url = "https://github.com/xmake-io/xmake/releases/download/v3.0.7/xmake-bundle-v3.0.7.win64.exe",
                sha256 = nil,
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
