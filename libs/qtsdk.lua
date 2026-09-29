-- The shared half of the Qt SDK recipes (pkgs/q/qt.lua, qt-base.lua,
-- qt-addons.lua): host detection, the Qt repository's mirrors, a verified
-- download, 7-Zip extraction with its symlink repair, and the marker each
-- recipe's `installed()` reads. A recipe keeps what is its own -- the archive
-- table, the sentinel files, `config()` -- and calls these.
--
-- Loaded by package hooks via:
--     import("xim.pkgindex.qtsdk")
--
-- An archive entry is `{ module, name, sha256, path | urls }`: `path` is
-- relative to the Qt repository root and is fetched from every mirror below
-- in order; `urls` lists an archive's own full addresses, for one this index
-- publishes itself (xlings-res). Whichever address answers, the same sha256
-- is required.

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.log")
import("xim.libxpkg.fs")

local qtsdk = {}

-- Mirrors of https://download.qt.io/online/qtsdkrepository/, in preference
-- order. Every `path` in BASE below is relative to this root on every one of
-- them -- verified reachable, not verified byte-for-byte against every other
-- mirror (Qt's own tree, unlike xlings-res, carries no independent per-file
-- signature this recipe can cross-check beyond the sha256 pinned below,
-- which every mirror is still required to answer for its bytes to be
-- accepted -- see fetch_verified()).
local MIRRORS = {
    "https://download.qt.io/online/qtsdkrepository/",
    "https://mirrors.tuna.tsinghua.edu.cn/qt/online/qtsdkrepository/",
    "https://mirrors.aliyun.com/qt/online/qtsdkrepository/",
    "https://mirrors.ustc.edu.cn/qtproject/online/qtsdkrepository/",
}

-- path.join mixes separators on Windows -- keep the store path's existing
-- backslashes and turn any forward slashes this recipe adds into backslashes
-- too, matching msvc.lua's winpath() (7z.exe and its arguments both need it).
local function winpath(p)
    return (p:gsub("/", "\\"))
end

-- "https://host/a/b" -> "host", for log lines that say WHICH mirror answered.
local function host_of(url)
    return (url:match("^%w+://([^/]+)")) or url
end

-- windows: certutil, exactly as msvc.lua uses it (ships with every Windows,
-- prints the digest on its own line -- no quoting gymnastics like
-- Get-FileHash needs).
local function sha256_of_windows(file)
    local ok, out = pcall(os.iorun, string.format('certutil -hashfile "%s" SHA256', file))
    if not ok or not out then return nil end
    for line in out:gmatch("[^\r\n]+") do
        local hex = line:gsub("%s+", ""):lower()
        if #hex == 64 and hex:match("^%x+$") then return hex end
    end
    return nil
end

-- linux/macosx: sha256sum first (coreutils, every Linux), shasum second
-- (macOS's own, no sha256sum by default). Whichever answers wins; a missing
-- command is just a pcall failure, not a hook crash.
local function sha256_of_posix(file)
    local ok, out = pcall(os.iorun, string.format('sha256sum "%s"', file))
    if ok and out then
        local hex = out:match("(%x+)")
        if hex and #hex == 64 then return hex:lower() end
    end
    ok, out = pcall(os.iorun, string.format('shasum -a 256 "%s"', file))
    if ok and out then
        local hex = out:match("(%x+)")
        if hex and #hex == 64 then return hex:lower() end
    end
    return nil
end

local function sha256_of(file)
    if os.host() == "windows" then return sha256_of_windows(file) end
    return sha256_of_posix(file)
end

-- Host platform key into a recipe's archive table ("windows-x86_64", "linux-aarch64",
-- "macosx", ...). Fails closed (returns nil) rather than guessing -- see the
-- header comment for why os.arch() cannot be used here.
function qtsdk.host_key()
    local osname = os.host()
    if osname == "macosx" then
        -- one universal payload serves both Apple arches -- no branch needed
        return "macosx"
    end
    local arch
    if osname == "windows" then
        local pa = (os.getenv("PROCESSOR_ARCHITECTURE") or ""):upper()
        if pa == "ARM64" then
            arch = "aarch64"
        elseif pa == "AMD64" or pa == "X86" then
            arch = "x86_64"
        end
    elseif osname == "linux" then
        local ok, out = pcall(os.iorun, "uname -m")
        local m = ok and (out or ""):gsub("%s+$", "") or ""
        if m == "aarch64" or m == "arm64" then
            arch = "aarch64"
        elseif m == "x86_64" then
            arch = "x86_64"
        end
    end
    if not arch then return nil end
    return osname .. "-" .. arch
end

-- xim:7zip's program: `7zz` on linux/macosx (pkgs/7/7zip.lua moves it
-- straight to the install root), `7z.exe` on windows (the SFX installer's
-- own name, also at the install root).
--
-- 7-Zip is a BUILD dependency of every recipe that calls this: it is needed
-- only while install() unpacks archives, and a runtime dependency would put
-- `7z` and `7zz` on the user's PATH for good. A build dep is placed in the
-- store and not activated, so the program is reached by its payload path.
--
-- Asked for by the BARE name, on purpose. xlings exports the payload as
-- XLINGS_BUILDDEP_7ZIP_PATH -- namespace stripped -- while libxpkg 0.0.59 and
-- earlier build the key from the string they are given, so "xim:7zip" looks up
-- XLINGS_BUILDDEP_XIM_7ZIP_PATH, misses, falls back to dep_install_dir, and
-- that has no record for a build dep (xlings records resolved_deps for runtime
-- deps only). The bare name is the spelling that answers on every client.
local function sevenzip_bin()
    if type(pkginfo.build_dep) ~= "function" then return nil end
    local bd = pkginfo.build_dep("7zip")
    if not bd or not bd.path then return nil end
    local rel = os.host() == "windows" and "7z.exe" or "7zz"
    local p = path.join(bd.path, rel)
    if os.isfile(p) then return p end
    return nil
end

-- Download one archive and prove it is the file this recipe pinned --
-- msvc.lua's fetch_verified(), generalized from ONE address per payload to a
-- shared mirror list every archive uses (see MIRRORS above).
local function fetch_verified(e, dst, tag)
    local want = e.sha256:lower()
    local label = e.name
    -- An entry names either a path under the Qt repository, fetched from
    -- every mirror in MIRRORS, or its own full addresses (`urls`), for an
    -- archive this index publishes itself.
    local urls = {}
    if e.urls then
        for _, u in ipairs(e.urls) do table.insert(urls, u) end
    else
        for _, m in ipairs(MIRRORS) do table.insert(urls, m .. e.path) end
    end
    if os.isfile(dst) then
        if sha256_of(dst) == want then return true end
        os.tryrm(dst)
    end
    local why = {}
    for i, url in ipairs(urls) do
        if i > 1 then
            log.warn(tag .. ": falling back to " .. host_of(url) .. " for " .. label ..
                      " after: " .. table.concat(why, "; "))
        else
            log.info(tag .. ": fetching " .. label .. " from " .. host_of(url))
        end
        -- pcall: curl -f exits non-zero on a 404 and system.exec RAISES on a
        -- non-zero exit -- without this the first missing mirror would abort
        -- the whole install instead of falling through to the next one.
        pcall(system.exec, string.format('curl -fsSL --retry 3 -o "%s" "%s"', dst, url))
        if os.isfile(dst) then
            local got = sha256_of(dst)
            if got == want then return true end
            table.insert(why, host_of(url) .. ": sha256 " .. tostring(got))
            os.tryrm(dst)
        else
            table.insert(why, host_of(url) .. ": no file")
        end
    end
    log.error(tag .. ": could not obtain " .. label ..
              "\n  expected sha256 " .. want ..
              "\n  tried:\n    " .. table.concat(why, "\n    "))
    return false
end

-- 7-Zip 21+ refuses to write a symlink whose target is ITSELF another
-- symlink from the same archive ("Dangerous link via another link was
-- ignored"), and exits non-zero even though every real payload extracted
-- fine -- it just leaves a 0-byte REGULAR FILE where the first-hop symlink
-- belongs. MEASURED (2026-09-26) against qtbase's own
-- lib/libQt6DBus.so -> libQt6DBus.so.6 -> libQt6DBus.so.6.11.1 chain: exit
-- code 2, both real payloads (`.so.6`, the versioned `.so.6.11.1`) land
-- correctly, only `libQt6DBus.so` itself comes out as an empty file instead
-- of a symlink. The fix recreates that one symlink from its already-correct
-- sibling (`ln -sf libFoo.so.<N> libFoo.so`) rather than fail the whole
-- archive over a placeholder any linker step needs anyway.
--
-- POSIX only. Checked against a real 7zz extraction of the macOS qtbase
-- archive too (2026-09-26): framework bundles ARE internally symlink chains
-- (Versions/Current -> A, QtCore -> Versions/Current/QtCore, ...), but each
-- symlink's target is a MULTI-COMPONENT path through a real directory, not
-- another symlink's bare name in the same directory -- 7-Zip's check does
-- not fire there (exit 0, every framework symlink came out correct). So this
-- is a linux-only repair, and rightly so: there was nothing to repair on
-- macOS to begin with.
--
-- `dest_dir` is where extract_7z() just unpacked ONE archive, and where the
-- broken placeholder ends up differs by archive shape (see
-- FLAT_MODULE_SUBDIR below): a normal Qt module archive is prefix-rooted, so
-- its `.so` files land in `dest_dir/lib`; a FLAT archive (icu) is instead
-- extracted directly into what is already install_dir/lib, so its `.so`
-- files land in `dest_dir` itself. Trying both candidates once is cheaper
-- than threading "which shape was this" through two more functions, and a
-- candidate that does not exist is just skipped.
local function so_repair_dirs(dest_dir)
    return { dest_dir, path.join(dest_dir, "lib") }
end

local function repair_broken_so_symlinks(dest_dir)
    if os.host() == "windows" then return end
    for _, libdir in ipairs(so_repair_dirs(dest_dir)) do
        if os.isdir(libdir) then
            pcall(system.exec, string.format(
                [[sh -c 'cd "%s" && for f in *.so; do [ -f "$f" ] || continue; [ -s "$f" ] && continue; cand=$(ls -1 "$f".* 2>/dev/null | grep -E "\.so\.[0-9]+$" | sort -V | head -1); [ -n "$cand" ] && ln -sf "$(basename "$cand")" "$f"; done']],
                libdir))
        end
    end
end

-- How many 0-byte "*.so" placeholders sit in the candidate dirs. Zero after
-- repair_broken_so_symlinks() is the signal that it actually resolved
-- everything extract_7z()'s non-zero exit could have meant, as opposed to a
-- real failure (truncated download, corrupt archive, full disk, ...) that
-- happens to share a non-zero exit code with this one specific case.
local function count_broken_so_placeholders(dest_dir)
    local n = 0
    for _, libdir in ipairs(so_repair_dirs(dest_dir)) do
        if os.isdir(libdir) then
            local ok, out = pcall(os.iorun, string.format(
                'find "%s" -maxdepth 1 -name "*.so" -size 0 -type f', libdir))
            if ok and out then
                for line in out:gmatch("[^\r\n]+") do
                    if line:match("%S") then n = n + 1 end
                end
            end
        end
    end
    return n
end

local function no_broken_so_placeholders(dest_dir)
    return count_broken_so_placeholders(dest_dir) == 0
end

-- The last `max` bytes of `text`, for an error message that has to carry a
-- tool's whole output without being able to bound it.
local function tail_of(text, max)
    if #text <= max then return text end
    return "[... " .. (#text - max) .. " bytes omitted]\n" .. text:sub(-max)
end

-- Extract one .7z into dest_dir via the xim:7zip binary.
--
-- `-bso0 -bsp0` silence 7-Zip's banner, file list and progress, which a hook
-- would otherwise write straight onto the installer's screen; its errors stay
-- on stderr. On POSIX both streams go to a file beside the archive, because a
-- non-zero exit is not always a failure here (see above) and the output is
-- what a real failure must show: the chained-link case is reported in ONE
-- line, anything else prints what 7-Zip said.
--
-- Windows: exe left UNQUOTED, arguments quoted -- msvc.lua's measured cmd /c
-- quoting gotcha (quoting the exe when more quoted args follow makes cmd
-- strip the outer quotes and mangle the line). `-o<dir>` is one token, no
-- space, so the quote sits right after `-o`. Every path is winpath()'d.
-- POSIX: no such hazard, quote everything normally.
local function extract_7z(zbin, archive, dest_dir, tag)
    if os.host() == "windows" then
        return pcall(system.exec, string.format('%s x -y -bso0 -bsp0 "-o%s" "%s"',
            winpath(zbin), winpath(dest_dir), winpath(archive)))
    end
    local out_file = archive .. ".out"
    local ok = pcall(system.exec, string.format('"%s" x -y -bso0 -bsp0 "-o%s" "%s" >"%s" 2>&1',
        zbin, dest_dir, archive, out_file))
    local said = os.isfile(out_file) and (io.readfile(out_file) or "") or ""
    os.tryrm(out_file)
    if ok then return true end
    -- See repair_broken_so_symlinks() above for what this is and is not.
    local refused = count_broken_so_placeholders(dest_dir)
    repair_broken_so_symlinks(dest_dir)
    if not no_broken_so_placeholders(dest_dir) then
        log.error(tag .. ": 7-Zip failed on " .. path.filename(archive) ..
                  " and its .so links could not be recreated:\n" .. tail_of(said, 8192))
        return false
    end
    if refused > 0 then
        log.info(string.format("%s: 7-Zip refused %d chained .so links; recreated", tag, refused))
    end
    -- Whatever 7-Zip said that is not the link message this repaired is not
    -- hidden. (A non-zero exit with no placeholder at all is treated as it
    -- always has been -- there is nothing to repair -- but it is no longer
    -- silent.)
    local other = {}
    for line in said:gmatch("[^\r\n]+") do
        if line:match("%S") and not line:match("^ERROR: Dangerous link via another link was ignored : .*%.so ") then
            table.insert(other, line)
        end
    end
    if #other > 0 then
        log.warn(tag .. ": 7-Zip reported on " .. path.filename(archive) .. ":\n  " ..
                 tail_of(table.concat(other, "\n  "), 8192))
    end
    return true
end

-- A HANDFUL of archives in this repository are NOT laid out from the
-- install prefix root the way every Qt module archive is (qtbase, qtsvg,
-- qtcharts, ... all extract straight into install_dir with their own
-- include/, lib/, ... at the top). These three are flat single/few-file
-- redistributables Qt's own installer places into a SPECIFIC subdirectory
-- of the prefix, and this table is that mapping -- MEASURED by listing each
-- archive (`7zz l`) rather than assumed:
--   icu             -- linux/linux-aarch64 base: 12 files, ALL at archive
--                      root (libicu*.so.73[.2]), belongs under lib/
--   d3dcompiler_47  -- windows-x86_64 base: ONE file (d3dcompiler_47.dll)
--                      at archive root, belongs under bin/ (deployed beside
--                      an app's own Qt DLLs, Qt's documented convention)
--   opengl32sw      -- windows-x86_64 base: ONE file (opengl32sw.dll),
--                      same shape and reason as d3dcompiler_47
-- Every other module in BASE/ADDONS is prefix-rooted and needs no entry
-- here -- extracting an addon module straight into install_dir is correct.
local FLAT_MODULE_SUBDIR = {
    icu = "lib",
    d3dcompiler_47 = "bin",
    opengl32sw = "bin",
}

-- The names of the regular files directly in `dir`. libxpkg's prelude has
-- `os.dirs` and no `os.files`, so the listing is the shell's, as os.dirs does.
local function files_in(dir)
    local names = {}
    local cmd = os.host() == "windows"
        and ('dir /B /A-D "' .. winpath(dir) .. '" 2>nul')
        or  ('ls -1 "' .. dir .. '" 2>/dev/null')
    local f = io.popen(cmd)
    if not f then return names end
    for line in f:lines() do
        local name = line:gsub("[\r\n]+$", "")
        if name ~= "" and os.isfile(path.join(dir, name)) then table.insert(names, name) end
    end
    f:close()
    return names
end

-- Fetch+verify+extract every archive in `list` into install_dir, recording
-- each one into `marker` AS SOON AS it lands -- not the whole list up front
-- -- so a mid-run failure leaves the marker naming only what actually made
-- it in (xpackage-spec.md rule R4: assert on the artifact, not the intent).
-- installed() below treats the marker as authoritative and checks it
-- against THIS recipe's current list, module by module and sha256 by
-- sha256, plus a few sentinel files.
function qtsdk.fetch_and_extract(list, install_dir, marker, tag)
    local zbin = sevenzip_bin()
    if not zbin then
        log.error(tag .. ": no 7-Zip binary found under the xim:7zip payload " ..
                  "(declared build dependency; this is a broken installation)")
        return false
    end
    local work = path.join(install_dir, ".dl")
    fs.mkdir_p(work)
    fs.mkdir_p(install_dir)

    local marker_lines = {}
    for _, e in ipairs(list) do
        local dst = path.join(work, e.name)
        if not fetch_verified(e, dst, tag) then
            return false
        end
        local dest = install_dir
        local sub = FLAT_MODULE_SUBDIR[e.module]
        if sub then
            dest = path.join(install_dir, sub)
            fs.mkdir_p(dest)
        end
        if e.pick then
            -- An archive of which one directory's files are wanted (the VC++
            -- redistributable): extracted beside the download, the files of
            -- `pick.from` copied into `pick.to`, the rest discarded.
            local scratch = path.join(work, "x-" .. e.module)
            fs.mkdir_p(scratch)
            if not extract_7z(zbin, dst, scratch, tag) then
                log.error(tag .. ": 7zip extraction failed for " .. e.name)
                return false
            end
            local from = path.join(scratch, e.pick.from)
            local into = path.join(install_dir, e.pick.to)
            fs.mkdir_p(into)
            local picked = files_in(from)
            if #picked == 0 then
                log.error(tag .. ": " .. e.name .. " has no files under " .. e.pick.from)
                return false
            end
            for _, name in ipairs(picked) do
                if not os.cp(path.join(from, name), path.join(into, name)) then
                    log.error(tag .. ": could not copy " .. name .. " into " .. into)
                    return false
                end
            end
            os.tryrm(scratch)
        elseif not extract_7z(zbin, dst, dest, tag) then
            log.error(tag .. ": 7zip extraction failed for " .. e.name)
            return false
        end
        os.tryrm(dst)
        table.insert(marker_lines, e.module .. " " .. e.sha256)
        -- Written after EVERY archive, not just at the end -- a hook that
        -- dies partway through still leaves a marker naming what is really
        -- there.
        io.writefile(marker, table.concat(marker_lines, "\n") .. "\n")
    end
    os.tryrm(work)
    return true
end

-- Parses the marker `fetch_and_extract` wrote: "<module> <sha256>" per line.
function qtsdk.read_marker(marker)
    if not os.isfile(marker) then return nil end
    local content = io.readfile(marker) or ""
    local map = {}
    for line in content:gmatch("[^\n]+") do
        local mod, sha = line:match("^(%S+)%s+(%x+)$")
        if mod then map[mod] = sha end
    end
    return map
end

-- THE RUNTIME CLOSURE. A recipe states what its payload loads and does not
-- carry, per platform:
--   linux    the libraries Qt names by SONAME, declared as deps together with
--            xim:glibc; xlings then patches the payload after install() --
--            each executable's interpreter and each ELF file's RUNPATH -- so
--            the tools and the programs linked against Qt share one loader
--            and libc (libxpkg elfpatch, the loader-provider predicate);
--   windows  nothing: a library payload does not carry the compiler's C++
--            runtime (docs/contributing.md §5.3). The program's build places
--            the toolset's runtime, and mcpp puts it first on the PATH of the
--            actions that run the tools in bin/.
-- `mark_runtime` records `runtime <RUNTIME_REV>` in the marker once install()
-- has laid the payload out, and `runtime_current` answers false for a payload
-- without it. xlings consults installed() for a payload it is installing, not
-- for one already on disk (openxlings/xlings#620), so a machine that holds a
-- payload laid out by an earlier RUNTIME_REV keeps it until it is removed. A
-- revision reaches such machines only under a new version key once the
-- package has consumers; before that, the key stays and caches are cleared.
local RUNTIME_REV = "1"

function qtsdk.mark_runtime(marker)
    local text = os.isfile(marker) and (io.readfile(marker) or "") or ""
    io.writefile(marker, text .. "runtime " .. RUNTIME_REV .. "\n")
end

function qtsdk.runtime_current(marker_map)
    return marker_map ~= nil and marker_map.runtime == RUNTIME_REV
end

-- Removes the listed files, relative to install_dir. An entry ending in `*`
-- removes every file of its directory whose name starts with the rest (a
-- library's .so, .so.6 and .so.6.x.y); a missing file is not an error.
function qtsdk.prune(install_dir, list)
    for _, rel in ipairs(list) do
        if rel:sub(-1) == "*" then
            local dir = path.join(install_dir, path.directory(rel))
            local stem = path.filename(rel):sub(1, -2)
            for _, name in ipairs(files_in(dir)) do
                if name:sub(1, #stem) == stem then os.tryrm(path.join(dir, name)) end
            end
        else
            os.tryrm(path.join(install_dir, rel))
        end
    end
end

-- Written by qt.conf's own docs: relocatable installs need this file so
-- qmake/qtpaths report the right prefix after the tree is moved (which is
-- exactly what os.mv into install_dir just did). Some archives already ship
-- one (upstream's own qtbase payload sometimes does); never overwrite an
-- existing one.
function qtsdk.ensure_qt_conf(install_dir)
    local conf = path.join(install_dir, "bin", "qt.conf")
    if os.isfile(conf) then return end
    fs.mkdir_p(path.join(install_dir, "bin"))
    io.writefile(conf, "[Paths]\nPrefix = ..\n")
end

return qtsdk
