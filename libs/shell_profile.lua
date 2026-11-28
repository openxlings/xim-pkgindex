-- Putting a package's shell integration into xlings' own shell profiles.
--
-- Loaded by package hooks via:
--     local lib = import("xim.pkgindex.shell_profile")      -- INSIDE the hook, see below
--
--     function config()
--         local lib = import("xim.pkgindex.shell_profile")
--         -- the binary prints the script for each shell; one probe, one call, never raises
--         lib.register_completion{ name = "mcpp", bin = mcpp_bin(),
--                                  args = { "self", "completion", "{shell}", "--print" } }
--         return true
--     end
--
--     function uninstall()
--         local lib = import("xim.pkgindex.shell_profile")
--         lib.unregister_completion("mcpp")
--         return true
--     end
--
-- register_completion{ name, bin, args, shells? } -> true | false, reason
--   Runs `bin` with `args` (`{shell}` becomes bash, zsh, fish, powershell) with stdout parked
--   in <XLINGS_HOME>/config/shell/completions/<name>.{bash,zsh,fish,ps1}, accepts a script
--   that is non-empty and names the package, then puts the guarded `source` into the xlings
--   profiles. Idempotent. Best-effort by contract: a binary without the command (an older
--   release), a home without a shell layout, any error -> `false, reason` and one warning,
--   never an exception, so the install it runs in never fails. Only the FIRST shell is
--   probed on failure: if it produces nothing the binary has no such command and the other
--   three are not run. A block an earlier, newer version left behind is cut in that case.
-- unregister_completion(name)
--   Cuts the block from every profile and deletes the scripts. Nothing to cut is not an error.
--
-- The lower level (add / remove / add_completion / splice) is public for a package whose
-- integration is not a completion script; the recipes above need none of it.
--
-- Import it INSIDE the hook, not at the top of the recipe. xlings runs uninstall() from a
-- snapshot of the recipe in the install directory, where no index libs/ is visible while
-- the file loads, and a top-level import("xim.pkgindex.*") of a missing module answers
-- with a silent stub (every call a no-op, nothing logged): openxlings/xlings#743. An
-- import made when the hook runs resolves through the index the package came from.
-- A recipe should refuse a stub: `type(lib.add) ~= "function"`.
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
-- Known limits, by xlings' design and not fixable here (openxlings/xlings#744):
--   * `write_or_upgrade_profile_` (xlings src/core/xself/init.cpp) rewrites a profile whose
--     version marker is older than the binary's, and the blocks go with it.
--     `xlings install <pkg> --reconfig` runs config() again and puts them back.
--   * the scripts live at a version-stable path and belong to whichever version ran
--     config() last: `xlings use <pkg>@<other>` does not regenerate them, and removing one
--     of several installed versions removes what the others still use.
-- A drop-in directory the profiles source (config/shell/profile.d/), with xlings owning
-- the per-version part, removes both; then only the bodies of `add`/`remove` change, not
-- the recipes. libxpkg's own `append_to_shell_profile` is unusable meanwhile
-- (openxlings/libxpkg#55).

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.log")
import("xim.libxpkg.system")
import("xim.pkgindex.shell")

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

-- ── register_completion: generate, validate, place, register ──────────────

local COMPLETION_SHELLS = {
    { shell = "bash",       ext = "bash" },
    { shell = "zsh",        ext = "zsh"  },
    { shell = "fish",       ext = "fish" },
    { shell = "powershell", ext = "ps1"  },
}

local function completion_id(name) return name .. " completion" end

-- The script `bin` prints for one shell, parked in `out`; true when it is one.
local function generate(spec, entry, out)
    local argv = { spec.bin }
    for _, a in ipairs(spec.args) do
        argv[#argv + 1] = (tostring(a):gsub("{shell}", entry.shell))
    end
    local cmd = shell.join(argv) .. " > " .. shell.quote(out)
    -- A failing binary must not abort the shells that still work, and the redirect can
    -- leave an empty file behind: remove it either way.
    if not pcall(system.exec, cmd) then
        os.tryrm(out)
        return false
    end
    local content = io.readfile(out)
    if not content or #content < 40 or not content:find(spec.name, 1, true) then
        os.tryrm(out)
        return false
    end
    return true
end

local function register(spec)
    assert(type(spec) == "table" and type(spec.name) == "string" and spec.name ~= "", "name required")
    assert(type(spec.bin) == "string" and type(spec.args) == "table", "bin and args required")
    local dir = M.data_dir("completions")
    if not dir then
        return false, "no xlings shell config dir in this home"
    end
    local want = {}
    for _, s in ipairs(spec.shells or {}) do want[s] = true end
    local files, tried = {}, 0
    for _, entry in ipairs(COMPLETION_SHELLS) do
        if not spec.shells or want[entry.shell] then
            tried = tried + 1
            local out = path.join(dir, spec.name .. "." .. entry.ext)
            if generate(spec, entry, out) then
                files[entry.shell] = "completions/" .. spec.name .. "." .. entry.ext
            elseif tried == 1 then
                -- The first shell gave nothing: the binary has no such command. One
                -- probe, not four failing runs; and drop what an earlier version left.
                M.remove(completion_id(spec.name))
                return false, "this version of " .. spec.name .. " prints no completion script"
            end
        end
    end
    if next(files) == nil then
        M.remove(completion_id(spec.name))
        return false, "no shell produced a completion script"
    end
    M.add_completion(completion_id(spec.name), files)
    return true
end

function M.register_completion(spec)
    local ok, res, why = pcall(register, spec)
    if not ok then
        res, why = false, tostring(res)
    end
    if not res then
        log.warn("%s: tab completion not registered: %s", tostring(type(spec) == "table" and spec.name), tostring(why))
        return false, why
    end
    log.info("%s: tab completion registered; restart the shell or re-source the xlings profile", spec.name)
    return true
end

function M.unregister_completion(name)
    local ok, err = pcall(function()
        M.remove(completion_id(name))
        local dir = M.dir()
        if dir then
            for _, entry in ipairs(COMPLETION_SHELLS) do
                os.tryrm(path.join(dir, "completions", name .. "." .. entry.ext))
            end
        end
    end)
    if not ok then
        log.warn("%s: tab completion not cleaned up: %s", tostring(name), tostring(err))
    end
    return ok
end

return M
