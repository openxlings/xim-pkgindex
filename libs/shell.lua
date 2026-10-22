-- Shell quoting for the commands a recipe runs (mcpp#832).
--
-- Loaded by package hooks via:
--     import("xim.pkgindex.shell")
--
--     shell.exec({ specs_config, gcc_bin, "--dynamic-linker", loader })
--     system.exec("cp -a " .. shell.quote(src) .. "/. " .. shell.quote(dst))
--
-- `system.exec` hands its string to a shell, and a value interpolated into it
-- unquoted is split at every space. A home under `/tmp/mc probe` turned gcc's
-- specs rewrite into a command that named `/tmp/mc` and passed `probe/...` on
-- (mcpp#832). Every value a recipe interpolates is a path or may become one,
-- so it goes through `quote`, or the command is an argv for `exec`.
-- `tools/lint_exec_quoting.sh` holds the index to it.
--
-- POSIX hosts quote with single quotes, which leave every character literal;
-- Windows quotes for the MSVCRT argument rules cmd.exe passes on.

import("xim.libxpkg.system")

local shell = {}

function shell.quote(s)
    s = tostring(s)
    if os.host() == "windows" then
        return '"' .. s:gsub('(\\*)"', '%1%1\\"'):gsub('(\\+)$', '%1%1') .. '"'
    end
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

-- The command line of an argument vector, every element quoted.
function shell.join(argv)
    local out = {}
    for i, a in ipairs(argv) do out[i] = shell.quote(a) end
    return table.concat(out, " ")
end

-- Run an argument vector through `system.exec`.
function shell.exec(argv)
    return system.exec(shell.join(argv))
end

return shell
