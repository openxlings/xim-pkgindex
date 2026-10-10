-- agent-confined: an agent kept off the host, not hidden (Luban design §C3).
--
-- What agent-private does for the host -- none of its home, devices, sockets
-- or environment; no grants; no nested user namespaces; fetching asks the
-- owner -- with this machine's own network. It does not hide who or where the
-- machine is: for that, agent-private.
package = {
    spec = "2",
    name = "agent-confined",
    description = "Agent isolation from the host, with this machine's network (not private)",
    type = "subos-policy",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    licenses = {"Apache-2.0"},
    categories = {"subos", "security", "agent"},
    xpm = {
        linux = { ["latest"] = { ref = "2026.10.10.1" }, ["2026.10.10.1"] = {} },
        macosx = { ["latest"] = { ref = "2026.10.10.1" }, ["2026.10.10.1"] = {} },
        windows = { ["latest"] = { ref = "2026.10.10.1" }, ["2026.10.10.1"] = {} },
    },
}

import("xim.pkgindex.luban")

local policy = [[
{
  "extends": "private",
  "min_client": "2026.10.10.1",
  "isolation": {
    "net": "host",
    "identity": "host",
    "env_pass": [],
    "grants": [],
    "grants_allowed": [],
    "disable_userns": true,
    "needs": {"fs": "must", "pid": "must"}
  },
  "mounts": [],
  "permissions": {"fetch": "ask", "index_update": "ask"},
  "observe": {"level": "standard"}
}
]]

function install()
    return luban.policy(policy)
end
