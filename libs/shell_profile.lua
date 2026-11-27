-- Putting a package's shell integration into xlings' own shell profiles.
--
-- Loaded by package config()/uninstall() hooks via:
--     import("xim.pkgindex.shell_profile")
--
--     function config()
--         -- scripts the package generated under <XLINGS_HOME>/config/shell/completions/
--         shell_profile.add_completion("mcpp completion", {
--             bash = "completions/mcpp.bash", zsh = "completions/mcpp.zsh",
--             fish = "completions/mcpp.fish", powershell = "completions/mcpp.ps1",
--         })
--         return true
--     end
--
--     function uninstall()
--         shell_profile.remove("mcpp completion")
--         return true
--     end
--
-- The surface is xlings' OWN profile (`<XLINGS_HOME>/config/shell/xlings-profile.{sh,fish,ps1}`),
-- the one file per shell the xlings installer wires into the user's shell with a
-- single source line. A package never writes ~/.bashrc, config.fish or a PowerShell
-- profile (the subos isolation rule); it writes a marked block into the xlings one.
--
-- Why this exists instead of libxpkg's `system.unix_api().append_to_shell_profile`:
-- that call appends to `_RUNTIME.run_dir` (the directory xlings was invoked from, not
-- the profile directory), has no PowerShell branch, can only append (no replace, no
-- removal), and the isolation suite rejects its name in a recipe. This module is the
-- same capability aimed at the right directory:
--
--   * one marked block per `id`, `# >>> <id> (xlings xim) >>>` ... `# <<< <id> (xlings xim) <<<`;
--     `#` is a comment in sh, fish AND PowerShell, so one marker pair serves all three;
--   * `add` replaces the block in place (config() may run many times), `remove` cuts it;
--   * a profile file that does not exist is left alone: xlings owns the files, a package
--     never creates one;
--   * blocks refer to `$XLINGS_HOME` (every xlings profile sets it before our block runs),
--     never to an absolute path, so a moved home and Windows separators are not our problem;
--   * the file's own line endings (LF or CRLF) are kept.
--
-- Known limit, by xlings' design and not fixable here: `write_or_upgrade_profile_`
-- (xlings src/core/xself/init.cpp) rewrites a profile whose version marker is older than
-- the binary's, and the block goes with it. `xlings install <pkg>` / `--reconfig` runs
-- config() again and puts it back. A drop-in directory the profile sources
-- (config/shell/profile.d/) would remove the class; that is an xlings change, and only
-- the body of `add`/`remove` here would then change, not the recipes.

import("xim.libxpkg.pkginfo")

local M = {}

M.PROFILES = {
    sh   = "xlings-profile.sh",
    fish = "xlings-profile.fish",
    ps1  = "xlings-profile.ps1",
}

local function begin_marker(id) return "# >>> " .. id .. " (xlings xim) >>>" end
local function end_marker(id)   return "# <<< " .. id .. " (xlings xim) <<<" end

-- ── where ──────────────────────────────────────────────────────────────────

-- The xlings home that owns this install. XLINGS_HOME is exported to hooks; the
-- install_dir walk is the fallback for contexts that do not export it:
--   <home>/data/xpkgs/<ns>-x-<pkg>/<version>
function M.home()
    local home = os.getenv("XLINGS_HOME")
    if home and home ~= "" then
        return home
    end
    local dir = pkginfo.install_dir()
    if dir then
        -- version dir -> package dir -> xpkgs -> data -> home
        return path.directory(path.directory(path.directory(path.directory(dir))))
    end
    return nil
end

-- <home>/config/shell, or nil when this home has no shell layout (never created here).
function M.dir()
    local home = M.home()
    if not home then
        return nil
    end
    local dir = path.join(home, "config", "shell")
    if os.isdir(dir) then
        return dir
    end
    return nil
end

-- <home>/config/shell/<sub>, made if missing; nil when there is no shell layout.
function M.data_dir(sub)
    local dir = M.dir()
    if not dir then
        return nil
    end
    local d = path.join(dir, sub)
    os.mkdir(d)
    return d
end

-- ── the marked block (pure: no file access) ────────────────────────────────

local function split_lines(text)
    local lines = {}
    for line in text:gmatch("([^\n]*)\n") do
        lines[#lines + 1] = line
    end
    local tail = text:match("([^\n]+)$")
    if tail then
        lines[#lines + 1] = tail
    end
    return lines
end

local function bare(line)
    return (line:gsub("\r$", ""))
end

-- Replace the block `id` in `text` with `body` (a string, or nil to cut it) and
-- return the new text. The block is found by whole-line markers; a BEGIN without
-- a later END is not a block and is left as it is. No block yet: appended.
function M.splice(text, id, body)
    local b_mark, e_mark = begin_marker(id), end_marker(id)
    local lines = split_lines(text)
    local first, last
    for i, line in ipairs(lines) do
        if bare(line) == b_mark then
            for j = i + 1, #lines do
                if bare(lines[j]) == e_mark then
                    first, last = i, j
                    break
                end
            end
            if first then break end
        end
    end
    if not first and not body then
        return text
    end

    local eol = text:find("\r\n", 1, true) and "\r\n" or "\n"
    local block = { b_mark }
    if body then
        for _, l in ipairs(split_lines(body:gsub("\r\n", "\n") .. "\n")) do
            block[#block + 1] = l
        end
    end
    block[#block + 1] = e_mark

    local out = {}
    if first then
        for i = 1, first - 1 do out[#out + 1] = bare(lines[i]) end
        if body then
            for _, l in ipairs(block) do out[#out + 1] = l end
        end
        for i = last + 1, #lines do out[#out + 1] = bare(lines[i]) end
    else
        for _, l in ipairs(lines) do out[#out + 1] = bare(l) end
        for _, l in ipairs(block) do out[#out + 1] = l end
    end
    local ends_with_eol = (not first) or text:sub(-1) == "\n"
    return table.concat(out, eol) .. (ends_with_eol and eol or "")
end

-- ── the files ──────────────────────────────────────────────────────────────

local function update(kind, id, body)
    local dir = M.dir()
    if not dir then
        return false
    end
    local file = path.join(dir, M.PROFILES[kind])
    if not os.isfile(file) then
        return false
    end
    local text = io.readfile(file)
    if not text then
        return false
    end
    local new_text = M.splice(text, id, body)
    if new_text ~= text then
        io.writefile(file, new_text)
    end
    return true
end

-- Put `snippets.sh`, `.fish`, `.ps1` (each optional, each a string of that shell's
-- code) into the matching xlings profile as the block `id`. Returns a table
-- { sh = bool, fish = bool, ps1 = bool }: whether each profile was updated.
function M.add(id, snippets)
    local done = {}
    for kind in pairs(M.PROFILES) do
        if snippets[kind] then
            done[kind] = update(kind, id, snippets[kind])
        end
    end
    return done
end

-- Cut the block `id` out of every xlings profile. Nothing to cut is not an error.
function M.remove(id)
    for kind in pairs(M.PROFILES) do
        update(kind, id, nil)
    end
end

-- ── tab completion: the snippets for "source this script under that shell" ──

-- The scripts are paths RELATIVE to <home>/config/shell. The guards mirror the xlings
-- profile's own completion branch: bash's `complete` does not exist in zsh, `compdef`
-- does not exist in bash, and the bash/zsh scripts hold syntax a plain sh or dash must
-- not even parse (the profile is sourced by those too, and a parse error kills it all).
local function sq(s)            -- sh: single quotes keep every character literal
    return "'" .. s:gsub("'", "'\\''") .. "'"
end
local function fq(s)            -- fish: inside '' only \\ and \' are escapes
    return "'" .. s:gsub("\\", "\\\\"):gsub("'", "\\'") .. "'"
end
local function pq(s)            -- PowerShell: '' inside a single-quoted string
    return "'" .. s:gsub("'", "''") .. "'"
end
local function slashes(p) return (p:gsub("\\", "/")) end

function M.completion_snippets(files)
    local snippets = {}
    local sh = {}
    if files.bash then
        local p = sq(slashes(files.bash))
        sh[#sh + 1] = 'if [ -n "${BASH_VERSION-}" ] && command -v complete >/dev/null 2>&1; then'
        sh[#sh + 1] = '    [ -r "$XLINGS_HOME/config/shell/"' .. p .. ' ] && . "$XLINGS_HOME/config/shell/"' .. p
    end
    if files.zsh then
        local p = sq(slashes(files.zsh))
        sh[#sh + 1] = (files.bash and "elif" or "if")
            .. ' [ -n "${ZSH_VERSION-}" ] && typeset -f compdef >/dev/null 2>&1; then'
        sh[#sh + 1] = '    [ -r "$XLINGS_HOME/config/shell/"' .. p .. ' ] && . "$XLINGS_HOME/config/shell/"' .. p
    end
    if #sh > 0 then
        sh[#sh + 1] = "fi"
        snippets.sh = table.concat(sh, "\n")
    end
    if files.fish then
        local p = fq(slashes(files.fish))
        snippets.fish = table.concat({
            'if test -r "$XLINGS_HOME/config/shell/"' .. p,
            '    source "$XLINGS_HOME/config/shell/"' .. p,
            "end",
        }, "\n")
    end
    if files.powershell then
        local p = pq(files.powershell:gsub("/", "\\"))
        snippets.ps1 = table.concat({
            "$__xl_c = Join-Path (Join-Path (Join-Path $env:XLINGS_HOME 'config') 'shell') " .. p,
            "if (Test-Path -LiteralPath $__xl_c) { . $__xl_c }",
            "Remove-Variable __xl_c -ErrorAction SilentlyContinue",
        }, "\n")
    end
    return snippets
end

-- add() for the common case: register tab-completion scripts. `files` names the
-- script per shell (bash, zsh, fish, powershell), relative to <home>/config/shell.
function M.add_completion(id, files)
    return M.add(id, M.completion_snippets(files))
end

return M
