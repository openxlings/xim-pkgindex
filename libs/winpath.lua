-- A path in the form a Windows program receives on its command line.
--
-- Loaded by package hooks via:
--     import("xim.pkgindex.winpath")
--
--     local seven_zip = winpath.native(dep.path) .. "\\7z.exe"
--
-- `path.join` keeps the separators it is given, so a path assembled from an
-- install root and relative parts arrives mixed ("C:\xlings/data/..."), and
-- the programs it is handed to -- cmd.exe, msiexec, PowerShell -- do not all
-- accept the mix. Fifteen recipes carried a private copy of this gsub when
-- this module was written; this is the one copy (the same rule the index
-- holds `shell.quote` to, one door away in this directory).
--
-- Only the separators change. A relative path stays relative, a drive-rooted
-- or UNC path stays what it is, and the reverse direction is deliberately not
-- offered: a path Windows printed may contain a forward slash that was
-- meaningful to it, and "converting back" would be a second answer to the
-- same question.

local winpath = {}

function winpath.native(p)
    return (tostring(p):gsub("/", "\\"))
end

return winpath
