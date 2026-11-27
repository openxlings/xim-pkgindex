-- Exercise libs/shell_profile.lua in a plain-Lua sandbox, the way libxpkg runs a
-- hook: import() is a no-op, and the host, the environment and the filesystem
-- (profile files held in a table) are forged per case.

local LIB = assert(os.getenv("SHELL_PROFILE_LIB"), "SHELL_PROFILE_LIB required")
local SHELL_LIB = assert(os.getenv("SHELL_LIB"), "SHELL_LIB required")
local DUMP = os.getenv("SNIPPET_DIR")

local ENV, FILES, DIRS, WRITES = {}, {}, {}, 0
import = function() end
path = {
    join = function(...) return table.concat({ ... }, "/") end,
    directory = function(p) return (p:match("^(.*)/[^/]*$")) or "." end,
}
os.getenv = function(k) return ENV[k] end
os.isdir = function(p) return DIRS[p] == true end
os.isfile = function(p) return FILES[p] ~= nil end
os.mkdir = function(p) DIRS[p] = true end
io.readfile = function(p) return FILES[p] end
io.writefile = function(p, s) FILES[p] = s; WRITES = WRITES + 1 end
pkginfo = { install_dir = function() return "/h/data/xpkgs/xim-x-demo/1.0" end }
os.host = function() return "linux" end
os.tryrm = function(p) FILES[p] = nil end
LOGS = {}
local function logger(level) return function(fmt, ...) LOGS[#LOGS + 1] = level .. ": " .. string.format(fmt, ...) end end
log = { info = logger("info"), warn = logger("warn"), error = logger("error") }
-- system.exec forges the binary: `<bin> <args> > '<out>'`. BIN_MODE decides what it prints.
EXECS, BIN_MODE = {}, "ok"
system = { exec = function(cmd)
    EXECS[#EXECS + 1] = cmd
    local out = assert(cmd:match(" > '([^']*)'$"), "redirect to a quoted file: " .. cmd)
    if BIN_MODE == "old" then error("exit 2") end
    if BIN_MODE == "empty" then FILES[out] = ""; return end
    if BIN_MODE == "foreign" then FILES[out] = string.rep("# a script for another program\n", 4); return end
    local sh = cmd:match("completion '([a-z]+)'") or "?"
    FILES[out] = "# " .. sh .. " completion for demo\n_demo_complete() { :; }\n# padding padding padding\n"
end }
shell = assert(loadfile(SHELL_LIB))()

local sp = assert(loadfile(LIB))()

local n = 0
local function check(cond, msg)
    if not cond then error("FAIL: " .. msg, 2) end
    n = n + 1
end
local function has(hay, needle) return hay:find(needle, 1, true) ~= nil end
local function count(hay, needle)
    local c, i = 0, 1
    while true do
        local s, e = hay:find(needle, i, true)
        if not s then return c end
        c, i = c + 1, e + 1
    end
end
local function reset()
    ENV = { XLINGS_HOME = "/h" }
    FILES, DIRS, WRITES = {}, { ["/h/config/shell"] = true }, 0
    FILES["/h/config/shell/xlings-profile.sh"]   = "# xlings-profile-version: 13\nexport A=1\n"
    FILES["/h/config/shell/xlings-profile.fish"] = "# xlings-profile-version: 13\nset -gx A 1\n"
    FILES["/h/config/shell/xlings-profile.ps1"]  = "# xlings-profile-version: 13\r\n$env:A = 1\r\n"
end
local ID = "demo completion"
local B = "# >>> demo completion (xlings xim) >>>"
local E = "# <<< demo completion (xlings xim) <<<"

-- 1. splice: append, replace in place, cut -- and the text around it is untouched
local t = "head\nmid\ntail\n"
local a = sp.splice(t, ID, "one")
check(a == "head\nmid\ntail\n" .. B .. "\none\n" .. E .. "\n", "appended after the existing text")
local r = sp.splice("x\n" .. B .. "\nold\n" .. E .. "\ny\n", ID, "new")
check(r == "x\n" .. B .. "\nnew\n" .. E .. "\ny\n", "replaced in place, neighbours kept")
check(sp.splice(r, ID, nil) == "x\ny\n", "cut leaves the neighbours")
check(sp.splice(t, ID, nil) == t, "nothing to cut: the text is returned as it was")
check(sp.splice(a, ID, "one") == a, "same body again: byte-identical")

-- 2. a file without a final newline gets one only when a block is appended
check(sp.splice("no-eol", ID, "b") == "no-eol\n" .. B .. "\nb\n" .. E .. "\n", "appended to a file without a final newline")
check(sp.splice("no-eol", ID, nil) == "no-eol", "cut of nothing leaves it without a final newline")

-- 3. CRLF files stay CRLF
local c = sp.splice("a\r\nb\r\n", ID, "l1\nl2")
check(c == "a\r\nb\r\n" .. B .. "\r\nl1\r\nl2\r\n" .. E .. "\r\n", "CRLF kept for the block")
check(sp.splice(c, ID, nil) == "a\r\nb\r\n", "CRLF block cut whole")
check(sp.splice(c, ID, "z") == "a\r\nb\r\n" .. B .. "\r\nz\r\n" .. E .. "\r\n", "CRLF block replaced")

-- 4. markers are whole lines; an unterminated BEGIN is not a block
local orphan = B .. "\nuser text that is not ours\n"
local o = sp.splice(orphan, ID, "x")
check(has(o, "user text that is not ours"), "an unterminated BEGIN never swallows the rest of the file")
check(count(o, E) == 1, "and a fresh block is appended")
local inline = "echo '" .. B .. "'\n"
check(sp.splice(inline, ID, nil) == inline, "a marker inside another line is not ours")

-- 5. two ids do not touch each other
local two = sp.splice(sp.splice("", "a one", "A"), "b two", "B")
check(sp.splice(two, "a one", nil) == "# >>> b two (xlings xim) >>>\nB\n# <<< b two (xlings xim) <<<\n", "another id's block survives")

-- 6. add / remove on the files
reset()
local done = sp.add(ID, { sh = "echo sh", fish = "echo fish", ps1 = "Write-Host ps" })
check(done.sh and done.fish and done.ps1, "all three profiles updated")
check(has(FILES["/h/config/shell/xlings-profile.sh"], "echo sh"), "sh block written")
check(has(FILES["/h/config/shell/xlings-profile.ps1"], B .. "\r\nWrite-Host ps\r\n" .. E .. "\r\n"), "ps1 keeps its CRLF")
local w = WRITES
sp.add(ID, { sh = "echo sh", fish = "echo fish", ps1 = "Write-Host ps" })
check(WRITES == w, "an unchanged block rewrites nothing")
sp.add(ID, { sh = "echo sh2" })
check(count(FILES["/h/config/shell/xlings-profile.sh"], B) == 1 and has(FILES["/h/config/shell/xlings-profile.sh"], "echo sh2"), "re-add replaces, never accumulates")
check(has(FILES["/h/config/shell/xlings-profile.fish"], "echo fish"), "a shell not named in add() keeps its block")
sp.remove(ID)
check(FILES["/h/config/shell/xlings-profile.sh"] == "# xlings-profile-version: 13\nexport A=1\n", "remove restores the sh profile exactly")
check(FILES["/h/config/shell/xlings-profile.ps1"] == "# xlings-profile-version: 13\r\n$env:A = 1\r\n", "remove restores the ps1 profile exactly")
sp.remove(ID)

-- 7. no shell layout / a missing profile: nothing is created
reset(); DIRS["/h/config/shell"] = nil
local none = sp.add(ID, { sh = "x" })
check(none.sh == false and next(FILES, nil) ~= nil and FILES["/h/config/shell/xlings-profile.sh"] == "# xlings-profile-version: 13\nexport A=1\n", "no config/shell: nothing written")
reset(); FILES["/h/config/shell/xlings-profile.fish"] = nil
local part = sp.add(ID, { sh = "x", fish = "y" })
check(part.sh == true and part.fish == false and FILES["/h/config/shell/xlings-profile.fish"] == nil, "a missing profile is not created")

-- 8. home: XLINGS_HOME first, the install_dir walk as the fallback
reset(); check(sp.home() == "/h", "XLINGS_HOME wins")
ENV.XLINGS_HOME = nil
check(sp.home() == "/h", "fallback walks <home>/data/xpkgs/<ns>-x-<pkg>/<version>")
reset(); check(sp.data_dir("completions") == "/h/config/shell/completions" and DIRS["/h/config/shell/completions"], "data_dir makes the directory")

-- 9. completion snippets
local s = sp.completion_snippets({ bash = "completions/demo.bash", zsh = "completions/demo.zsh",
                                   fish = "completions/demo.fish", powershell = "completions/demo.ps1" })
check(has(s.sh, "BASH_VERSION") and has(s.sh, "ZSH_VERSION") and has(s.sh, "typeset -f compdef"), "sh guards")
check(has(s.sh, '$XLINGS_HOME/config/shell/') and not has(s.sh, "/h/"), "relative to $XLINGS_HOME, no absolute path")
check(has(s.fish, "source") and has(s.fish, "$XLINGS_HOME"), "fish sources it")
check(has(s.ps1, "$env:XLINGS_HOME") and has(s.ps1, "completions\\demo.ps1"), "PowerShell path uses backslashes under $env:XLINGS_HOME")
local only = sp.completion_snippets({ zsh = "z" })
check(only.sh:find("^if %[ %-n \"%${ZSH_VERSION") ~= nil and only.fish == nil and only.ps1 == nil, "a lone zsh script opens with `if`, not `elif`")
local odd = sp.completion_snippets({ bash = "it's/odd.bash", fish = "it's/odd.fish", powershell = "it's/odd.ps1" })
check(has(odd.sh, "it'\\''s") and has(odd.fish, "it\\'s") and has(odd.ps1, "it''s"), "a quote in a name is escaped per shell")

-- 10. register_completion: the declarative path
local SPEC = { name = "demo", bin = "/h/data/xpkgs/xim-x-demo/1.0/bin/demo", args = { "self", "completion", "{shell}", "--print" } }
local P = "/h/config/shell/"
local function prof(k) return FILES[P .. "xlings-profile." .. k] end
reset(); EXECS, BIN_MODE = {}, "ok"
local okr, why = sp.register_completion(SPEC)
check(okr == true and why == nil, "registered")
check(#EXECS == 4 and has(EXECS[1], "'self' 'completion' 'bash' '--print' > '/h/config/shell/completions/demo.bash'"), "one quoted run per shell, {shell} replaced, stdout parked in completions/")
check(FILES[P .. "completions/demo.zsh"] and FILES[P .. "completions/demo.fish"] and FILES[P .. "completions/demo.ps1"], "four scripts")
check(has(prof("sh"), "# >>> demo completion (xlings xim) >>>") and has(prof("fish"), "demo.fish") and has(prof("ps1"), "demo.ps1"), "a block in each profile")
local snap = { prof("sh"), prof("fish"), prof("ps1") }
sp.register_completion(SPEC)
check(prof("sh") == snap[1] and prof("fish") == snap[2] and prof("ps1") == snap[3], "registering again changes nothing")
check(sp.unregister_completion("demo") == true, "unregister answers true")
check(prof("sh") == "# xlings-profile-version: 13\nexport A=1\n" and prof("ps1") == "# xlings-profile-version: 13\r\n$env:A = 1\r\n", "profiles restored exactly")
check(FILES[P .. "completions/demo.bash"] == nil and FILES[P .. "completions/demo.ps1"] == nil, "scripts deleted")
check(sp.unregister_completion("demo") == true, "unregister twice is fine")

-- an older binary: one probe, no profile touched, an earlier block cut, never an error
reset(); BIN_MODE = "ok"; sp.register_completion(SPEC)
EXECS, BIN_MODE, LOGS = {}, "old", {}
local okold, whyold = sp.register_completion(SPEC)
check(okold == false and has(whyold, "prints no completion script"), "old binary: false, reason")
check(#EXECS == 1, "old binary: only the first shell is probed")
check(not has(prof("sh"), "demo completion") and not has(prof("ps1"), "demo completion"), "old binary: the block an earlier version left is cut")
check(#LOGS == 1 and LOGS[1]:find("^warn:") ~= nil, "old binary: exactly one warning")
for _, mode in ipairs({ "empty", "foreign" }) do
    reset(); EXECS, BIN_MODE = {}, mode
    local okm = sp.register_completion(SPEC)
    check(okm == false and prof("sh") == "# xlings-profile-version: 13\nexport A=1\n", mode .. " output is not a script: nothing registered")
    check(FILES[P .. "completions/demo.bash"] == nil, mode .. " output is not left on disk")
end

-- no shell layout, bad specs: false and a warning, never an exception
reset(); DIRS["/h/config/shell"] = nil; EXECS, BIN_MODE = {}, "ok"
local okn, whyn = sp.register_completion(SPEC)
check(okn == false and has(whyn, "no xlings shell config dir") and #EXECS == 0, "no shell layout: nothing run")
local okb = sp.register_completion({ name = "demo" })
check(okb == false, "an incomplete spec is answered, not raised")
check(sp.register_completion(nil) == false, "nil spec is answered, not raised")

-- shells = {...} limits the run; a partial result still registers what worked
reset(); EXECS, BIN_MODE = {}, "ok"
sp.register_completion({ name = "demo", bin = SPEC.bin, args = SPEC.args, shells = { "fish" } })
check(#EXECS == 1 and has(prof("fish"), "demo.fish") and not has(prof("sh"), "demo completion"), "shells = { fish }: only fish")

if DUMP then
    for kind, text in pairs(s) do
        local f = assert(io.open(DUMP .. "/snippet." .. kind, "wb")); f:write(text, "\n"); f:close()
    end
end
print("PASS: " .. n .. " checks")
