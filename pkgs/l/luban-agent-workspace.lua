-- Luban Agent Workspace: a long-lived, private workspace for an AI agent
-- (Luban design §C) -- luban-core plus the agent's tools, private when it is
-- made: its declared policy (agent-private) is selected and locked by
-- `subos new` before anything enters it.
--
--   luban new agent agent-workspace --proxy socks5h://127.0.0.1:7897
--   luban run agent -- claude      # the claude current when it was made
--   luban upgrade agent            # a newer one (and the edition's other updates)
--   luban status agent            # its persona, its zone, what a shared kernel cannot hide
--
-- agent-private: the proxy is its only network (socks5h, failing closed), a
-- persona of its own (a host name and machine-id made once, the time zone of
-- the proxy's exit), nothing of the host's home, devices or sockets. Without
-- a proxy it refuses to enter and says how to give one. For an agent that may
-- use this machine's network: `luban config agent policy xim:agent-confined`.
-- On a kernel of its own (no shared-kernel fingerprints): `luban try agent --proxy ...`.
package = {
    spec = "2",
    name = "luban-agent-workspace",
    namespace = "subos",
    description = "Luban Agent Workspace: luban-core plus agent tools, private (proxy-only, a persona of its own) from the start",
    homepage = "https://github.com/openxlings/xlings",
    licenses = {"Apache-2.0"},
    type = "subos",
    archs = {"x86_64"},
    status = "stable",
    categories = {"subos", "distribution", "agent", "security"},
    keywords = {"luban", "agent", "privacy", "workspace", "claude"},

    xpm = {
        linux = {
            ["latest"] = { ref = "2026.10.10.1" },
            ["2026.10.10.1"] = {},
        },
    },
}

import("xim.pkgindex.luban")

-- The agent is the one package an edition does not pin: an agent changes
-- weekly. `subos new` installs the version current then and records it in the
-- instance (instance.json `edition.packages`); `luban upgrade` moves it.
local versions = {
    ["2026.10.10.1"] = { manifest = [[
{
  "subos_kind": "rootfs",
  "min_client": "2026.10.10.3",
  "from": "subos:luban-core@2026.10.10.1",
  "abi": "x86_64-linux-gnu",
  "packages": [
    "xim:claude"
  ],
  "policy": "xim:agent-private@2026.10.10.1",
  "workspace": {}
}
]], files = { { "usr/share/factory/etc/motd", [[
Luban Agent Workspace -- private by its policy (agent-private):
  network     only the proxy it was given; nothing else, and no fallback
  identity    a persona of its own (`luban status <name>` on the host)
  host        none of its home, devices or sockets; credentials stay in here
Not hidden on a shared kernel: the kernel version, the CPU model, the host
paths of what is bound in -- `luban try <name> --proxy ...` runs it on its own.
Your accounts (an API key, a git identity) still say who you are.
]] } } },
}

function install()
    return luban.edition({ id = "agent-workspace", variant = "Agent Workspace", versions = versions })
end
