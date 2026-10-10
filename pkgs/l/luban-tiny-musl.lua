-- Luban Tiny (musl): luban-tiny with musl instead of glibc (xlings: Luban OS
-- design part 2 §2.3) -- the proof that a Luban root's libc is a choice.
-- BusyBox (static), musl, CA certificates, busybox init, over luban-nano.
--
--   luban new box luban-tiny-musl
--
-- A program built against glibc does not run here: install musl builds
-- (or bring glibc: `xlings install glibc --subos box`).
package = {
    spec = "2",
    name = "luban-tiny-musl",
    namespace = "subos",
    description = "Luban Tiny on musl: BusyBox, musl and CA certificates",
    homepage = "https://github.com/openxlings/xlings",
    licenses = {"Apache-2.0"},
    type = "subos",
    archs = {"x86_64"},
    status = "stable",
    categories = {"subos", "distribution"},
    keywords = {"luban", "rootfs", "distribution", "busybox", "tiny", "musl"},

    xpm = {
        linux = {
            ["latest"] = { ref = "2026.10.10.1" },
            ["2026.10.10.1"] = {},
        },
    },
}

import("xim.pkgindex.luban")

local versions = {
    ["2026.10.10.1"] = { files = luban.busybox_machine("luban-init"), manifest = [[
{
  "subos_kind": "rootfs",
  "min_client": "2026.10.10.3",
  "from": "subos:luban-nano@2026.10.10.1",
  "abi": { "kernel": "linux", "libc": "musl" },
  "packages": [
    "xim:busybox@1.35.0",
    "xim:musl@1.2.5",
    "xim:ca-certificates@2026.03.19"
  ],
  "boot": { "init": "/sbin/init", "profile": "xim:luban-boot-generic@2026.10.10.1", "kernel_min": "5.10" },
  "workspace": {}
}
]] },
}

function install()
    return luban.edition({ id = "tiny-musl", variant = "Tiny (musl)", versions = versions })
end
