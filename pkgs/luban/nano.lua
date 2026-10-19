-- Luban Nano (xlings: 2026-10-18 Luban OS distribution design §6.1): xlings and luban only -- the base an edition of your own is built on; no libc, no shell, no init.
--
-- Luban's editions are in the luban: namespace from 2026.10.18.1; subos:luban-nano is
-- frozen (its published versions stay) and `luban upgrade` moves a system
-- made from it here (`replaces`). What it presets is in its manifest's
-- `luban.settings` and the root's usr/share/luban/settings.json.
-- A published version's output never changes (tests/fixtures/luban-published.json).
package = {
    spec = "2",
    name = "nano",
    namespace = "luban",
    description = "Luban Nano: xlings and luban only -- the base every Luban edition builds on",
    homepage = "https://github.com/openxlings/xlings",
    licenses = {"Apache-2.0"},
    type = "subos",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"subos", "distribution"},
    keywords = {"luban", "rootfs", "nano", "minimal", "embedded"},

    xpm = {
        linux = {
            ["latest"] = { ref = "2026.10.18.1" },
            ["2026.10.18.1"] = { min_client = "2026.10.18.1" },
        },
    },
}

import("xim.pkgindex.luban")

local versions = {
    ["2026.10.18.1"] = { manifest = {
        subos_kind = "rootfs",
        min_client = "2026.10.18.1",
        replaces = "subos:luban-nano",
        abi = { kernel = "linux", libc = "none" },
        packages = {},
        boot = { profile = "xim:luban-boot-generic@2026.10.11.1", kernel = "xim:linux-kernel@6.8.0-71", kernel_min = "5.10" },
        luban = { settings = { enter = "console" } },
        workspace = {},
    } },
}

function install()
    return luban.edition({ id = "nano", variant = "Nano", versions = versions })
end
