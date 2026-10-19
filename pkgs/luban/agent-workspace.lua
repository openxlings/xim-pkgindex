-- Luban Agent Workspace (xlings: 2026-10-18 Luban OS distribution design §6.1): core and the tools coding agents use, private by its policy (agent-private): a proxy-only network, a persona of its own.
--
-- Luban's editions are in the luban: namespace from 2026.10.18.1; subos:luban-agent-workspace is
-- frozen (its published versions stay) and `luban upgrade` moves a system
-- made from it here (`replaces`). What it presets is in its manifest's
-- `luban.settings` and the root's usr/share/luban/settings.json.
-- A published version's output never changes (tests/fixtures/luban-published.json).
package = {
    spec = "2",
    name = "agent-workspace",
    namespace = "luban",
    description = "Luban Agent Workspace: core and the coding agents' tools, private by its policy",
    homepage = "https://github.com/openxlings/xlings",
    licenses = {"Apache-2.0"},
    type = "subos",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"subos", "distribution"},
    keywords = {"luban", "rootfs", "agent", "workspace", "private"},

    xpm = {
        linux = {
            ["latest"] = { ref = "2026.10.18.1" },
            ["2026.10.18.1"] = { min_client = "2026.10.18.1" },
        },
    },
}

import("xim.pkgindex.luban")

local MOTD = [[
Luban Agent Workspace -- private by its policy (agent-private):
  network     only the proxy it was given; nothing else, and no fallback
  identity    a persona of its own (`luban status <name>` on the host)
  host        none of its home, devices or sockets; credentials stay in here
Not hidden on a shared kernel: the kernel version, the CPU model, the host
paths of what is bound in -- `luban try <name> --proxy ...` runs it on its own.
Your accounts (an API key, a git identity) still say who you are.
]]

local versions = {
    ["2026.10.18.1"] = {
        files = { { "usr/share/factory/etc/motd", MOTD } },
        manifest = {
            subos_kind = "rootfs",
            min_client = "2026.10.18.1",
            from = "luban:core@2026.10.18.1",
            replaces = "subos:luban-agent-workspace",
            abi = { kernel = "linux", libc = "gnu" },
            -- The agents unpinned beside their set: each is recorded as it
            -- resolved at `new`, and `luban upgrade` moves it (they change weekly).
            packages = { "luban:tools-dev@2026.10.18.1", "luban:tools-agent@2026.10.18.1",
                         "xim:claude", "xim:codex", "xim:pi", "xim:opencode" },
            policy = "xim:agent-private@2026.10.11.1",
            luban = { settings = { enter = "console", login_shell = "/usr/bin/fish" } },
            workspace = {},
        },
    },
}

function install()
    return luban.edition({ id = "agent-workspace", variant = "Agent Workspace", versions = versions })
end
