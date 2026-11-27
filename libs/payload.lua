-- Landing an archive's contents in the install directory, and asserting what
-- landed.
--
-- Loaded by package install() hooks via:
--     import("xim.pkgindex.payload")
--
--     function install()
--         payload.unpack{ extracted = { "nginx-" .. pkginfo.version(), "nginx" }, strip = 1 }
--         payload.require{ "conf/nginx.conf", "html/index.html" }
--         return true
--     end
--
--     function installed()
--         return payload.present{ "conf/nginx.conf", "html/index.html" }
--     end
--
-- A recipe of spec "3" does not call payload.unpack: the host has landed the
-- download in the install directory before install() runs, laid out by the
-- entry's `strip` (xpkg spec §4.6, §5.2). payload.require and payload.present
-- serve every spec.
--
-- payload.unpack answers, once, the questions five recipes each answered
-- their own way:
--
--   * WHERE the framework left the extraction: beside the archive, under the
--     archive's own top-level entry. `extracted` names that directory -- a
--     string, or a list tried in order, because the posix tarball and the
--     windows zip of one package rarely agree on the name.
--   * WHAT to do when it is not there: a .zip on Windows is extracted with
--     %SystemRoot%\System32\tar.exe, absolute because PATH may offer GNU tar
--     instead, which cannot read zip at all and reads "C:\..." as a host
--     spec. `strip` drops that many leading path components, for the zips
--     that carry one root directory; `extracted = nil` says the zip has no
--     root directory worth moving and only the tar branch applies.
--   * anything else is an error naming what was looked for -- never a silent
--     fallthrough into an empty install directory.
--
-- The tar branch reports that the COMMAND ran; whether anything landed is
-- answered by payload.require, which names each missing file. That division
-- is deliberate: only the recipe knows which files are its payload --
-- installed() and install()'s closing check share one list -- and a library
-- that guessed would be a second answer to that question.

import("xim.libxpkg.fs")
import("xim.libxpkg.log")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.pkgindex.winpath")

local payload = {}

function payload.unpack(opt)
    opt = opt or {}
    local archive = tostring(pkginfo.install_file())
    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local names = type(opt.extracted) == "table" and opt.extracted
                  or (opt.extracted ~= nil and { opt.extracted } or {})

    fs.remove(dir)

    for _, name in ipairs(names) do
        local src = parent .. "/" .. name
        if fs.is_dir(src) then
            local dst_parent = dir:match("^(.*)/[^/]+$")
            if dst_parent then fs.mkdir(dst_parent) end
            fs.move(src, dir)
            log.info("%s: moved %s into place", pkginfo.name(), name)
            return true, src
        end
    end

    if normalized:match("%.zip$") and pkginfo.platform() == "windows" then
        fs.mkdir(dir)
        local sysroot = winpath.native(os.getenv("SystemRoot") or "C:\\Windows"):gsub("\\+$", "")
        local systar = sysroot .. "\\System32\\tar.exe"
        local strip = (opt.strip and opt.strip > 0)
                      and (" --strip-components=" .. opt.strip) or ""
        -- exec-quoting-ok: the first token is the system's tar.exe, which cmd.exe must see unquoted
        system.exec(string.format('%s -xf "%s"%s -C "%s"',
                                  systar, winpath.native(archive), strip, winpath.native(dir)))
        log.info("%s: extracted the zip with the system tar", pkginfo.name())
        return true, dir
    end

    error(string.format(
        "%s: no extracted directory beside the archive (looked for %s in %s) and the archive is not a zip this module extracts on this host",
        pkginfo.name(), #names > 0 and table.concat(names, ", ") or "nothing", parent))
end

-- Every file the recipe's payload provides, asserted present. A missing file
-- is named, not counted: "2 wanted" makes the reader re-derive the list.
function payload.require(files)
    local dir = pkginfo.install_dir()
    local missing = {}
    for _, rel in ipairs(files) do
        if not fs.is_file(dir .. "/" .. rel) then missing[#missing + 1] = rel end
    end
    if #missing > 0 then
        error(string.format("%s: files missing from %s:\n    %s",
                            pkginfo.name(), dir, table.concat(missing, "\n    ")))
    end
    return true
end

-- The same list as a question, for installed(): true when every file is
-- there, false the moment one is not.
function payload.present(files)
    local dir = pkginfo.install_dir()
    for _, rel in ipairs(files) do
        if not fs.is_file(dir .. "/" .. rel) then return false end
    end
    return true
end

return payload
