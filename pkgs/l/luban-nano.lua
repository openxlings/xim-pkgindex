-- Luban Nano: the Luban model itself (Luban design §A4) -- a root with
-- nothing in it but what every Luban root has: xlings (packages) and luban
-- (the system; stage-0 as luban-init), both static, no libc, no shell.
--
-- Everything above the kernel is a choice, and nano makes none: a libc, an
-- init, base tools, a shell are packages an edition `from` this one declares.
-- An edition of your own:
--
--   { "subos_kind": "rootfs", "from": "subos:luban-nano",
--     "abi": "x86_64-linux-gnu",
--     "packages": [ "xim:glibc@2.44.3", "xim:busybox@1.35.0" ],
--     "boot": { "init": "/sbin/init" } }
--
-- packed as an xpkg in your own index (`xlings subos pack`), it is a
-- distribution based on Luban: `luban new box your-index:your-os`.
package = {
    spec = "2",
    name = "luban-nano",
    namespace = "subos",
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
            ["latest"] = { ref = "2026.10.11.1" },
            ["2026.10.11.1"] = {},
        },
    },
}

import("xim.pkgindex.luban")

-- No packages: xlings and luban are in every root (its projection).
-- No libc: what they are needs none. No init: that is a choice.
local versions = {
    ["2026.10.11.1"] = { manifest = [[
{
  "subos_kind": "rootfs",
  "min_client": "2026.10.11.1",
  "abi": { "kernel": "linux", "libc": "none" },
  "packages": [],
  "boot": { "profile": "xim:luban-boot-generic@2026.10.11.1", "kernel": "xim:linux-kernel@6.8.0-71", "kernel_min": "5.10" },
  "workspace": {}
}
]] },
}

function install()
    return luban.edition({ id = "nano", variant = "Nano", versions = versions })
end
