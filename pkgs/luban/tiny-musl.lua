-- Luban Tiny (musl) (xlings: 2026-10-18 Luban OS distribution design §6.1): tiny with musl as its C library: for building and testing static, musl-linked programs.
--
-- Luban's editions are in the luban: namespace from 2026.10.18.1; subos:luban-tiny-musl is
-- frozen (its published versions stay) and `luban upgrade` moves a system
-- made from it here (`replaces`). What it presets is in its manifest's
-- `luban.settings` and the root's usr/share/luban/settings.json.
-- A published version's output never changes (tests/fixtures/luban-published.json).
package = {
    spec = "2",
    name = "tiny-musl",
    namespace = "luban",
    description = "Luban Tiny (musl): busybox and musl on nano",
    homepage = "https://github.com/openxlings/xlings",
    licenses = {"Apache-2.0"},
    type = "subos",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"subos", "distribution"},
    keywords = {"luban", "rootfs", "tiny", "busybox", "musl"},

    -- What a Luban OS card shows of it (xlings design 2026-10-19 §20; xpkg
    -- spec "extensions"): a few of its programs, names in every language.
    extensions = { luban = { highlights = { "busybox", "musl" } } },

    xpm = {
        linux = {
            ["latest"] = { ref = "2026.10.24.1" },
            ["2026.10.18.1"] = { min_client = "2026.10.18.1" },
            ["2026.10.24.1"] = { min_client = "2026.10.18.1" },
        },
    },
}

import("xim.pkgindex.luban")

local versions = {
    ["2026.10.18.1"] = {
        files = luban.with(luban.busybox_machine("luban-init"), luban.checks("tiny-musl", [[
{"checks": [
  {"id": "tiny-musl-shell", "what": "its shell runs a pipeline", "run": "echo luban | grep -q luban", "critical": true, "timeout": 10},
  {"id": "tiny-musl-terminfo", "what": "the usual terminals are described", "run": "for t in x/xterm-256color l/linux s/screen-256color t/tmux-256color; do test -f /usr/share/terminfo/$t || exit 1; done", "timeout": 10}
]}
]])),
        manifest = {
            subos_kind = "rootfs",
            min_client = "2026.10.18.1",
            from = "luban:nano@2026.10.18.1",
            replaces = "subos:luban-tiny-musl",
            abi = { kernel = "linux", libc = "musl" },
            packages = { "xim:busybox@1.35.0", "xim:musl@1.2.5", "xim:ca-certificates@2026.03.19", "xim:terminfo@6.6.20261010" },
            boot = { init = "/sbin/init", profile = "xim:luban-boot-generic@2026.10.11.1", kernel_min = "5.10" },
            luban = { settings = { enter = "console", login_shell = "/bin/sh" } },
            workspace = {},
        },
    },
}

-- 2026.10.24.1 (xlings design 2026-10-24 §7.1): 2026.10.18.1, carrying the kernel
-- it boots as a machine (boot.virt) -- a system's own, moved by luban upgrade
-- and back by luban rollback; a client before it reads nothing new.
versions["2026.10.24.1"] = {
    files = versions["2026.10.18.1"].files,
    manifest = {
        subos_kind = "rootfs",
        min_client = "2026.10.18.1",
        from = "luban:nano@2026.10.18.1",
        replaces = "subos:luban-tiny-musl",
        abi = { kernel = "linux", libc = "musl" },
        packages = { "xim:busybox@1.35.0", "xim:musl@1.2.5", "xim:ca-certificates@2026.03.19", "xim:terminfo@6.6.20261010" },
        boot = { init = "/sbin/init", profile = "xim:luban-boot-generic@2026.10.11.1", kernel_min = "5.10", virt = "xim:linux-kernel-virt@6.12.112-r3" },
        luban = { settings = { enter = "console", login_shell = "/bin/sh" } },
        workspace = {},
    },
}

function install()
    return luban.edition({ id = "tiny-musl", variant = "Tiny (musl)", versions = versions })
end
