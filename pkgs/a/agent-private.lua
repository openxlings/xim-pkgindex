-- agent-private: an agent's private environment (Luban design §C3-C5).
--
-- The private preset made strict for a long-lived agent workspace: the proxy is
-- the only network (socks5h -- names resolved by the proxy -- and no fallback
-- when it is down); a neutral identity that is a persona (one host name and
-- machine-id per instance; the time zone of the proxy's exit, asked through
-- the proxy); nothing passed from the host's environment; no grants; no nested
-- user namespaces; refuse rather than run with less. Fetching packages and
-- updating the index from inside ask the owner.
--
-- Data, not code: what xlings enforces. The proxy is the instance's
-- (`luban new <n> agent-workspace --proxy ...`, `luban config <n> proxy ...`).
package = {
    spec = "2",
    name = "agent-private",
    description = "Fail-closed agent isolation: the proxy as the only network, a persona of its own",
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
  "min_client": "2026.10.10.3",
  "isolation": {
    "net": "proxy",
    "identity": {},
    "env_pass": [],
    "grants": [],
    "grants_allowed": [],
    "disable_userns": true,
    "no_degrade": true,
    "needs": {"fs": "must", "pid": "must", "net": "must", "identity": "must", "terminal": "must"}
  },
  "mounts": [],
  "permissions": {"fetch": "ask", "index_update": "ask"},
  "observe": {"level": "standard"}
}
]]

function install()
    return luban.policy(policy)
end
