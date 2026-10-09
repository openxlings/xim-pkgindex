package = {
    spec = "2",
    name = "agent-workspace-private",
    namespace = "config",
    description = "Configure an existing Luban rootfs for private Agent development from the owner side",
    type = "config",
    archs = {"x86_64"},
    status = "stable",
    licenses = {"Apache-2.0"},
    categories = {"subos", "security", "agent"},
    xpm = { linux = {
        ["latest"] = { ref = "0.1.0" },
        ["0.1.0"] = {},
    } },
}

import("xim.libxpkg.system")
import("xim.libxpkg.log")

local function quote(value)
    return "'" .. value:gsub("'", "'\\''") .. "'"
end

local function create_if_missing(file, content)
    if os.isfile(file) then return end
    local f = assert(io.open(file, "wb"))
    assert(f:write(content))
    assert(f:close())
end

function install()
    return true
end

function config()
    if os.getenv("XLINGS_SUBOS_MODE") == "sandbox" then
        error("Apply agent-workspace-private from the owner side, outside the sandbox")
    end
    local scope = system.subos_sysrootdir()
    local name = scope and scope:match("/subos/([%w_-]+)$")
    if not name or name == "default" or name == "current" then
        error("Select a named Luban rootfs scope before configuring Agent privacy")
    end
    local root = scope .. "/rootfs"
    if not os.isdir(root .. "/etc") then
        error("agent-workspace-private requires an existing rootfs instance")
    end
    local proxy = os.getenv("AGENT_PRIVATE_PROXY") or ""
    if not proxy:match("^socks5h://[%w%.%-]+:%d+$") then
        error("Set AGENT_PRIVATE_PROXY=socks5h://host:port (no credentials); direct networking is never substituted")
    end
    local ref = os.getenv("AGENT_PRIVATE_POLICY") or "xim:agent-private@0.1.0"
    if not ref:match("^[%w_-]+:agent%-private@0%.1%.0$") then
        error("AGENT_PRIVATE_POLICY must name agent-private@0.1.0 in a trusted index")
    end
    -- Resolve and lock the policy using the owner API, not a direct policy-file write.
    system.exec("xlings subos config " .. quote(name) .. " --sandbox " .. quote(ref)
        .. " --proxy " .. quote(proxy) .. " --no-degrade")
    local home = root .. "/root"
    for _, dir in ipairs({home, home .. "/workspace", home .. "/.cache",
        home .. "/.local/state", home .. "/.claude"}) do
        system.exec("mkdir -p " .. quote(dir) .. " && chmod 700 " .. quote(dir))
    end
    create_if_missing(home .. "/.claude/settings.json", "{}\n")
    system.exec("chmod 600 " .. quote(home .. "/.claude/settings.json"))
    create_if_missing(home .. "/workspace/PRIVACY.md", [[# Private Agent workspace
Credentials and Git identity must be configured explicitly inside this instance.
The proxy is enforced by xlings; proxy failure must never fall back to direct access.
Run `xlings subos status` and `xlings subos doctor` from the owner side before use.
Shared-kernel information and application accounts can still identify a user.
]])
    log.info("Private policy locked for %s; existing credentials and user files retained", name)
    return true
end

function uninstall()
    log.info("User data and the instance's locked security policy are retained")
    return true
end
