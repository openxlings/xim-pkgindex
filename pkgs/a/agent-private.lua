package = {
    spec = "2",
    name = "agent-private",
    description = "Fail-closed Agent isolation policy with a SOCKS5h-only network",
    type = "subos-policy",
    archs = {"x86_64"},
    status = "stable",
    licenses = {"Apache-2.0"},
    categories = {"subos", "security"},
    xpm = { linux = {
        ["latest"] = { ref = "0.1.0" },
        ["0.1.0"] = {},
    } },
}

import("xim.libxpkg.pkginfo")

local policy = [[
{
  "extends": "private",
  "min_client": "2026.10.9.2",
  "isolation": {
    "net": "proxy",
    "identity": {"tz": "UTC"},
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
    local dir = pkginfo.install_dir()
    os.mkdir(dir)
    local f = assert(io.open(dir .. "/policy.json", "wb"))
    assert(f:write(policy))
    assert(f:close())
    return os.isfile(dir .. "/policy.json")
end
