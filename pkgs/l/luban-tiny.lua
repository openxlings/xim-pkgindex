-- Luban Tiny: the smallest Luban userland -- BusyBox, glibc, CA certificates,
-- busybox init -- over luban-nano's xlings and luban (Luban design §A4, §6).
--
-- An edition is a SubOS template: the packages its root is made of, its ABI,
-- its init, the factory /etc it starts with, and the boot profile an image of
-- it uses. Nothing to download -- install() writes the template (data here,
-- the writing in libs/luban.lua).
--
--   luban new box tiny                   # (xlings subos new box --from subos:luban-tiny)
--   luban enter box
--   luban export box box.iso             # a live ISO; box.img: a drive
--
-- Its ABI names no architecture: every package it declares is published for
-- x86_64 and aarch64. Images boot by its boot profile (luban-boot-generic;
-- `--boot virt` in a VM -- and on aarch64, where generic has no kernel).
--
-- The kernel is the machine's, not the edition's (§A6). 0.1.0 carried it in
-- the root, was published so, and stays so: a published version's output
-- never changes (tests/fixtures/luban-published.json).
package = {
    spec = "2",
    name = "luban-tiny",
    namespace = "subos",
    description = "Luban Tiny: a minimal xlings-managed userland of BusyBox, glibc and CA certificates",
    homepage = "https://github.com/openxlings/xlings",
    licenses = {"Apache-2.0"},
    type = "subos",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"subos", "distribution"},
    keywords = {"luban", "rootfs", "distribution", "busybox", "tiny"},

    xpm = {
        linux = {
            ["latest"] = { ref = "2026.10.10.1" },
            ["0.1.0"] = {},
            ["2026.10.10.1"] = {},
        },
    },
}

import("xim.pkgindex.luban")


local versions = {
    ["0.1.0"] = { files = luban.busybox_machine("xlings-init"), manifest = [[
{
  "subos_kind": "rootfs",
  "packages": [
    "xim:busybox@1.35.0",
    "xim:glibc@2.44.3",
    "xim:patchelf@0.18.0",
    "xim:ca-certificates@2026.03.19",
    "xim:linux-kernel@6.8.0-71"
  ],
  "boot": { "init": "/sbin/init" },
  "workspace": {}
}
]] },
    ["2026.10.10.1"] = { files = luban.busybox_machine("luban-init"), manifest = [[
{
  "subos_kind": "rootfs",
  "min_client": "2026.10.10.3",
  "from": "subos:luban-nano@2026.10.10.1",
  "abi": { "kernel": "linux", "libc": "gnu" },
  "packages": [
    "xim:busybox@1.35.0",
    "xim:glibc@2.44.3",
    "xim:patchelf@0.18.0",
    "xim:ca-certificates@2026.03.19"
  ],
  "boot": { "init": "/sbin/init", "profile": "xim:luban-boot-generic@2026.10.10.1",
            "kernel": "xim:linux-kernel@6.8.0-71", "kernel_min": "5.10" },
  "workspace": {}
}
]] },
}

function install()
    return luban.edition({ id = "tiny", variant = "Tiny", versions = versions })
end
