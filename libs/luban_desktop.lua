-- What the desktop editions share (xlings: Luban OS desktop part 2 §3): the
-- environment that makes a desktop ready to use, its defaults, and the
-- manifest per architecture. luban-desktop (xdesk classic) and
-- luban-desktop-xdesk (xdesk canvas) differ only in the session they start.
--
--   luban_desktop.manifest(arch)   the manifest's JSON text for x86_64 / aarch64
--   luban_desktop.files(session)   the files every desktop edition writes

local M = {}

-- Pinned: what a version of the edition is made of. The agents are not
-- pinned: they change weekly and are wanted as they are now.
local common = {
    "xim:labwc-desktop@0.7.2",      -- foot, Xwayland, fonts; the labwc session too
    "xim:node@26.11.1",
    "xim:python@3.15.0",
    "xim:uv@0.12.7",
    "xim:bun@1.3.11",
    "xim:ripgrep@15.1.0",
    "xim:fd@10.5.0",
    "xim:fzf@0.74.3",
    "xim:jq@1.8.2",
    "xim:tmux@3.8",
    "xim:htop@3.5.3",
    "xim:claude",
    "xim:codex",
    "xim:pi",
    "xim:opencode",
}

-- x86_64 only, for now: xdesk (its aarch64 release is to come) and dsh
-- (upstream builds x86_64). aarch64 starts labwc until xdesk is there.
local x86_64_only = {
    "xim:xdesk@2026.10.13.1",
    "xim:dsh",
}

function M.packages(arch)
    local out = {}
    for _, p in ipairs(common) do table.insert(out, p) end
    if arch ~= "aarch64" then
        for _, p in ipairs(x86_64_only) do table.insert(out, p) end
    end
    return out
end

function M.manifest(arch, from)
    local lines = {}
    for _, p in ipairs(M.packages(arch)) do table.insert(lines, '    "' .. p .. '"') end
    return '{\n'
        .. '  "subos_kind": "rootfs",\n'
        .. '  "min_client": "2026.10.13.1",\n'
        .. '  "from": "' .. from .. '",\n'
        .. '  "abi": { "kernel": "linux", "libc": "gnu" },\n'
        .. '  "packages": [\n' .. table.concat(lines, ",\n") .. '\n  ],\n'
        .. '  "workspace": {}\n'
        .. '}\n'
end

-- npm, pip, uv and bun use registries near the person when xlings does (its
-- CN mirror): asked of xlings once a day, never baked in.
local registries = [[
# Package registries near you: when xlings uses its CN mirror, so do npm,
# pip, uv and bun (asked once a day; anything you set yourself wins).
_luban_mirror="${XDG_CACHE_HOME:-$HOME/.cache}/luban/mirror"
if [ -z "$(find "$_luban_mirror" -mmin -1440 2>/dev/null)" ] && command -v xlings >/dev/null 2>&1; then
    mkdir -p "${_luban_mirror%/*}" 2>/dev/null
    xlings config 2>/dev/null | awk '$1 == "mirror" { print $2 }' > "$_luban_mirror" 2>/dev/null
fi
if [ "$(cat "$_luban_mirror" 2>/dev/null)" = CN ]; then
    : "${NPM_CONFIG_REGISTRY:=https://registry.npmmirror.com}"; export NPM_CONFIG_REGISTRY
    : "${BUN_CONFIG_REGISTRY:=$NPM_CONFIG_REGISTRY}"; export BUN_CONFIG_REGISTRY
    : "${PIP_INDEX_URL:=https://mirrors.aliyun.com/pypi/simple/}"; export PIP_INDEX_URL
    : "${UV_DEFAULT_INDEX:=$PIP_INDEX_URL}"; export UV_DEFAULT_INDEX
fi
unset _luban_mirror
]]

local gitconfig = [[
[init]
	defaultBranch = main
[core]
	editor = nvim
[pull]
	rebase = false
]]

function M.files(session)
    return {
        -- Runs as a machine and starts this session (luban config <n> --desktop changes it).
        { "usr/share/luban/settings.json", '{ "mode": "machine", "desktop": "' .. session .. '" }\n' },
        { "usr/share/factory/etc/profile.d/luban-registries.sh", registries },
        { "usr/share/factory/etc/gitconfig", gitconfig },
    }
end

return M
