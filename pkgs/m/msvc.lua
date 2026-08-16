-- MSVC toolset as an xlings payload package.
--
-- Replaces a `type = "config"` recipe that shelled out to vs_BuildTools.exe.
-- That one installed to C:\Program Files (x86), needed a GUI (--passive) and
-- elevation, could not express a version finer than "2022", and returned true
-- without checking whether anything had been installed.
--
-- This one downloads the toolset the way Visual Studio itself does and unpacks
-- it into the xlings payload store. No installer, no elevation, no registry,
-- no reboot -- and several toolsets can coexist, exactly like gcc.
--
-- ── Where the payloads come from ──────────────────────────────────────────
--
-- Visual Studio's distribution is manifest-driven, which is the only reason a
-- specific compiler build can be pinned at all (the bootstrapper always serves
-- whatever is current):
--
--   1. https://aka.ms/vs/17/release/channel        -> channel manifest (JSON)
--   2. its Microsoft.VisualStudio.Manifests.VisualStudio item
--                                                  -> package manifest (JSON)
--   3. each package carries payloads with an exact url + sha256
--
-- A `.vsix` payload is a zip whose contents sit under `Contents/`, and for the
-- toolset that content is already `VC/Tools/MSVC/<ver>/...` -- so unpacking is
-- "unzip, drop one path component", and the result is the layout every
-- consumer already knows how to read.
--
-- Retention was checked before depending on it: the VS 2019 channel manifest
-- and its payloads still resolve today, so release-channel URLs are good for
-- years. Insider-channel payloads rotate and are deliberately NOT offered here.
--
-- ── Versioning ────────────────────────────────────────────────────────────
--
-- The version is the toolset's own directory name (14.44.35207), not the
-- product year and not the manifest's package version -- those differ from it
-- and from each other (Tools 14.44.35228, Headers 14.44.35220, CRT 14.44.35226
-- all unpack into 14.44.35207). The directory name is what `-vcvars_ver` takes,
-- what build systems report, and what a second toolset would have to differ in.
package = {
    spec = "1",

    name = "msvc",
    description = "Microsoft Visual C++ compiler toolset (portable, pinned to a toolset build)",

    maintainers = {"Microsoft"},
    licenses = {"Proprietary"},
    homepage = "https://visualstudio.microsoft.com/downloads/",
    docs = "https://learn.microsoft.com/cpp/",

    type = "package",
    archs = {"x86_64"},
    status = "dev",
    categories = {"toolchain", "compiler", "c++", "c"},
    keywords = {"msvc", "cl", "c++", "c", "compiler", "windows"},

    programs = {"cl", "link", "lib", "ml64", "dumpbin"},

    xvm_enable = true,

    xpm = {
        windows = {
            -- The compiler is useless without the ucrt/um headers and libs,
            -- and those are a separate product. curl does the fetching. Both
            -- declared, neither assumed to be on the host.
            deps = { "xim:windows-sdk@10.0.26100", "xim:curl@8.21.0" },

            -- `latest` stays on the release channel deliberately. 14.52 is an
            -- Insiders toolset; asking for it should be a choice, not what a
            -- bare `xlings install msvc` hands you.
            ["latest"] = { ref = "14.44.35207" },

            -- Empty resources: this package fetches a SET of payloads and the
            -- framework's single-url download cannot express that. install()
            -- does it and checks every sha256 itself.
            ["14.44.35207"] = { },   -- release channel, VS 2022 17.14
            ["14.52.36629"] = { },   -- Insiders, VS 2026 -- see TOOLSETS below
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.log")
import("xim.libxpkg.xvm")
import("xim.libxpkg.subos")

local SDK_DIR_VERSION = "10.0.26100.0"

-- The package version IS the toolset's directory name -- that is why the
-- version is spelled the way it is. Verified per entry rather than assumed:
-- for 14.44 the payloads carry 35228 / 35220 / 35226 and all unpack into
-- 14.44.35207, while 14.52's payloads and directory agree at 36629. Getting
-- this wrong is not subtle; nothing lands where the recipe looks for it.
local function toolset()
    return pkginfo.version()
end

-- path.join mixes separators on Windows -- it keeps the backslashes already in
-- the store path and adds forward ones. tar does not care; xcopy does.
local function winpath(p)
    return (p:gsub("/", "\\"))
end

-- One payload set per toolset, keyed by that toolset's directory version.
--
-- 14.44 comes from the release channel (aka.ms/vs/17/release/channel), 14.52
-- from Insiders (aka.ms/vs/18/insiders/channel) -- two manifests, and the
-- package ids are not spelled alike either: Microsoft.VC.14.44.17.14.* against
-- Microsoft.VC.14.52.*.
--
-- The Insiders entry carried a risk the release one does not: Microsoft
-- rotates those payloads, and when 14.52.36629 goes away its CDN URL 404s.
-- That is now survivable rather than terminal -- every entry lists a mirror
-- first and the CDN as the fallback, so the pin outlives the address. The
-- sha256 is unchanged and still pinned, so a rotated build can never be
-- served in place of the one named here, from either address.
--
-- `latest` still stays on the release channel: an Insiders toolset should be
-- a choice, not what a bare `xlings install msvc` hands you.
local TOOLSETS = {
    ["14.44.35207"] = {
        { name = "Microsoft.VC.14.44.17.14.Tools.HostX64.TargetX64.base.vsix",
          sha256 = "ee0baaa3a112d255f19f6c27dcc0ff6e496949eb9f1f37be0ac908c562a7076c",
          urls = { "https://gitcode.com/xlings-res/msvc/releases/download/14.44.35207/Microsoft.VC.14.44.17.14.Tools.HostX64.TargetX64.base.vsix",
                   "https://download.visualstudio.microsoft.com/download/pr/bbc72d8e-2acd-4229-8f6a-85e23c5e3456/ee0baaa3a112d255f19f6c27dcc0ff6e496949eb9f1f37be0ac908c562a7076c/Microsoft.VC.14.44.17.14.Tools.HostX64.TargetX64.base.vsix" } },
        { name = "Microsoft.VC.14.44.17.14.CRT.Headers.base.vsix",
          sha256 = "852382a9aa73502b7849c1bcadfb603ba7175c4e8b60e6aba03c7de711d4ece5",
          urls = { "https://gitcode.com/xlings-res/msvc/releases/download/14.44.35207/Microsoft.VC.14.44.17.14.CRT.Headers.base.vsix",
                   "https://download.visualstudio.microsoft.com/download/pr/c610cd8c-801b-44b8-a80a-82cc382aeb43/852382a9aa73502b7849c1bcadfb603ba7175c4e8b60e6aba03c7de711d4ece5/Microsoft.VC.14.44.17.14.CRT.Headers.base.vsix" } },
        { name = "Microsoft.VC.14.44.17.14.CRT.x64.Desktop.base.vsix",
          sha256 = "f01f701a7bcd9587a340898c851424f6a52bb913a70c185ff0d5bf0288c5831a",
          urls = { "https://gitcode.com/xlings-res/msvc/releases/download/14.44.35207/Microsoft.VC.14.44.17.14.CRT.x64.Desktop.base.vsix",
                   "https://download.visualstudio.microsoft.com/download/pr/67cf767c-5e71-47c2-a54a-cd5631e28942/f01f701a7bcd9587a340898c851424f6a52bb913a70c185ff0d5bf0288c5831a/Microsoft.VC.14.44.17.14.CRT.x64.Desktop.base.vsix" } },
        { name = "Microsoft.VC.14.44.17.14.CRT.Redist.X64.base.vsix",
          sha256 = "4aaf54db0bfc9435f7c3660e1a00237a4b556042bfeea64bde44c2e0194e6ee5",
          urls = { "https://gitcode.com/xlings-res/msvc/releases/download/14.44.35207/Microsoft.VC.14.44.17.14.CRT.Redist.X64.base.vsix",
                   "https://download.visualstudio.microsoft.com/download/pr/45d3b8dd-bced-4b37-9974-142f748d710c/4aaf54db0bfc9435f7c3660e1a00237a4b556042bfeea64bde44c2e0194e6ee5/Microsoft.VC.14.44.17.14.CRT.Redist.X64.base.vsix" } },
        -- ⚠️ "Store" is a misleading name, and skipping it on that basis is
        -- exactly what happened. THIS is the payload that puts the DYNAMIC
        -- CRT import libraries in lib/x64:
        --   msvcprt.lib  msvcrt.lib  vcruntime.lib  oldnames.lib (+ d variants)
        -- The uwp/ and store/ subdirectories it also carries are the parts the
        -- name refers to; the desktop libs sit at the top of lib/x64.
        --
        -- Without it the toolset can only link /MT. `.Desktop.base` holds the
        -- STATIC halves (libcmt/libcpmt/libvcruntime) and nothing else, and
        -- use_ansi.h picks between them by _DLL:
        --     #if defined(_DLL) && !defined(_STATIC_CPPLIB)
        --     #define _LIB_STEM "msvcprt"      // /MD  <- was absent
        --     #else
        --     #define _LIB_STEM "libcpmt"      // /MT
        -- so every default (/MD) build failed at link with an unresolved
        -- msvcprt.lib -- while cl.exe, the headers and std.ixx were all
        -- present and `installed()` said yes. See installed() below, which no
        -- longer accepts that state.
        { name = "Microsoft.VC.14.44.17.14.CRT.x64.Store.base.vsix",
          sha256 = "9135b03c0df53c7a0aa9bef7230a1c2ff4263a0ee7baa7e419d034f484f6bb56",
          urls = { "https://gitcode.com/xlings-res/msvc/releases/download/14.44.35207/Microsoft.VC.14.44.17.14.CRT.x64.Store.base.vsix",
                   "https://download.visualstudio.microsoft.com/download/pr/67cf767c-5e71-47c2-a54a-cd5631e28942/9135b03c0df53c7a0aa9bef7230a1c2ff4263a0ee7baa7e419d034f484f6bb56/Microsoft.VC.14.44.17.14.CRT.x64.Store.base.vsix" } },
    },
    ["14.52.36629"] = {
        { name = "Microsoft.VC.14.52.Tools.HostX64.TargetX64.base.vsix",
          sha256 = "3cf795636cf47b91a3583baa45df8cf7e7448c551a6d2f7f65a015cc1b858930",
          urls = { "https://gitcode.com/xlings-res/msvc/releases/download/14.52.36629/Microsoft.VC.14.52.Tools.HostX64.TargetX64.base.vsix",
                   "https://download.visualstudio.microsoft.com/download/pr/0fdca428-6677-4d0e-a19d-65f175edc108/3cf795636cf47b91a3583baa45df8cf7e7448c551a6d2f7f65a015cc1b858930/Microsoft.VC.14.52.Tools.HostX64.TargetX64.base.vsix" } },
        { name = "Microsoft.VC.14.52.CRT.Headers.base.vsix",
          sha256 = "26c7797d7408b565c0a6bdc0862391bc69efc8aff14560dde854a86b32d8720c",
          urls = { "https://gitcode.com/xlings-res/msvc/releases/download/14.52.36629/Microsoft.VC.14.52.CRT.Headers.base.vsix",
                   "https://download.visualstudio.microsoft.com/download/pr/0fdca428-6677-4d0e-a19d-65f175edc108/26c7797d7408b565c0a6bdc0862391bc69efc8aff14560dde854a86b32d8720c/Microsoft.VC.14.52.CRT.Headers.base.vsix" } },
        { name = "Microsoft.VC.14.52.CRT.x64.Desktop.base.vsix",
          sha256 = "ff89fd2b115c6a08dff82a6ce9cc90ef6f4aeb4704c29a5b77d16f063ad33524",
          urls = { "https://gitcode.com/xlings-res/msvc/releases/download/14.52.36629/Microsoft.VC.14.52.CRT.x64.Desktop.base.vsix",
                   "https://download.visualstudio.microsoft.com/download/pr/0fdca428-6677-4d0e-a19d-65f175edc108/ff89fd2b115c6a08dff82a6ce9cc90ef6f4aeb4704c29a5b77d16f063ad33524/Microsoft.VC.14.52.CRT.x64.Desktop.base.vsix" } },
        { name = "Microsoft.VC.14.52.CRT.Redist.X64.base.vsix",
          sha256 = "da122e4f50a1d3328dd09954ed81ccf3012a32c23abac215872cc74272eee1f3",
          urls = { "https://gitcode.com/xlings-res/msvc/releases/download/14.52.36629/Microsoft.VC.14.52.CRT.Redist.X64.base.vsix",
                   "https://download.visualstudio.microsoft.com/download/pr/0fdca428-6677-4d0e-a19d-65f175edc108/da122e4f50a1d3328dd09954ed81ccf3012a32c23abac215872cc74272eee1f3/Microsoft.VC.14.52.CRT.Redist.X64.base.vsix" } },
        -- The dynamic CRT import libs -- see the 14.44 entry above for why a
        -- payload named "Store" is the one a desktop /MD build needs.
        { name = "Microsoft.VC.14.52.CRT.x64.Store.base.vsix",
          sha256 = "54113449899bee687e3d9bd3dc77d5ebbdfce499e5f44b5f35349b010fffa34c",
          urls = { "https://gitcode.com/xlings-res/msvc/releases/download/14.52.36629/Microsoft.VC.14.52.CRT.x64.Store.base.vsix",
                   "https://download.visualstudio.microsoft.com/download/pr/0fdca428-6677-4d0e-a19d-65f175edc108/54113449899bee687e3d9bd3dc77d5ebbdfce499e5f44b5f35349b010fffa34c/Microsoft.VC.14.52.CRT.x64.Store.base.vsix" } },
    },
}

-- After TOOLSETS, not before it: a function that closes over a local must be
-- defined below that local, or the name it captures is a global -- which reads
-- as `attempt to index a nil value (global 'TOOLSETS')` at install time.
local function payloads()
    local set = TOOLSETS[toolset()]
    if not set then
        log.error("msvc: no payload set for toolset " .. tostring(toolset()))
    end
    return set or {}
end

local function toolsdir()
    return path.join(pkginfo.install_dir(), "VC", "Tools", "MSVC", toolset())
end

local function bindir()
    return path.join(toolsdir(), "bin", "Hostx64", "x64")
end

-- The addresses a payload can be fetched from, in order of preference.
--
-- An entry carries `url` (one address) or `urls` (several). With one address
-- the behaviour is byte-for-byte what it was, so adding a mirror to an entry
-- cannot change how an unmirrored one installs.
--
-- WHY A LIST IS ENOUGH. A mirror is not a second trust root here -- it is a
-- second ADDRESS for the same bytes, and `entry.sha256` is checked whichever
-- one answered. That is the whole reason the fallback can be silent: there is
-- no source-dependent outcome to report. Microsoft's CDN is itself just one
-- of the addresses, and an Insiders payload rotating off it stops being a
-- dead end the moment a second one exists.
--
-- The mirrored bytes were verified by DOWNLOADING every payload back from
-- gitcode and hashing it against the pins below -- not by trusting that the
-- upload succeeded, which for some files it reported both ways.
local function sources(entry)
    if entry.urls and #entry.urls > 0 then return entry.urls end
    return { entry.url }
end

-- certutil, not PowerShell's Get-FileHash: both ship with Windows, but
-- Get-FileHash needs a quoted -LiteralPath nested inside a quoted -Command
-- inside a shell string. certutil takes one quoted path and prints the digest
-- on a line of its own.
local function sha256_of(file)
    local out = os.iorun(string.format('certutil -hashfile "%s" SHA256', file)) or ""
    for line in out:gmatch("[^\r\n]+") do
        local hex = line:gsub("%s+", ""):lower()
        if #hex == 64 and hex:match("^%x+$") then return hex end
    end
    return nil
end

-- "https://gitcode.com/a/b/c" -> "gitcode.com", for log lines that say WHICH
-- address answered. Without it a mirror is invisible in a build log, and an
-- invisible fallback is indistinguishable from no fallback.
local function host_of(url)
    return (url:match("^%w+://([^/]+)")) or url
end

-- Download one payload and prove it is the file we asked for.
--
-- The check is the point, not the download: these bytes become a compiler,
-- and "curl exited 0" says nothing about what arrived. Every address is
-- verified against the SAME sha256, and a mismatch drops the file and moves
-- on rather than letting a bad payload through.
local function fetch_verified(entry, dir)
    local dst  = path.join(dir, entry.name)
    local want = entry.sha256:lower()

    -- An already-present file still has to prove itself. A partial download
    -- from an interrupted run is also "a file that exists", and accepting it
    -- would turn a network blip into a corrupt compiler.
    if os.isfile(dst) then
        if sha256_of(dst) == want then return true end
        os.tryrm(dst)
    end

    local why = {}
    for i, url in ipairs(sources(entry)) do
        -- The FIRST address is the expected one; reaching a later one means
        -- something is wrong upstream even though the install still succeeds.
        -- That has to be louder than an info line, or "the mirror served it"
        -- and "the mirror is dead and the CDN saved us" look identical from
        -- outside -- and the second one is how a fallback rots unnoticed
        -- until the day both addresses are gone.
        if i > 1 then
            log.warn("msvc: " .. entry.name .. " -- falling back to " ..
                     host_of(url) .. " after: " .. table.concat(why, "; "))
        else
            log.info("msvc: fetching " .. entry.name .. " from " .. host_of(url))
        end
        -- pcall: curl -f exits non-zero on a 404, and system.exec RAISES on a
        -- non-zero exit. Without this the first missing mirror would abort the
        -- install instead of falling through to the next address.
        pcall(system.exec, string.format(
            'curl -fsSL --retry 3 -o "%s" "%s"', dst, url))
        if os.isfile(dst) then
            local got = sha256_of(dst)
            if got == want then return true end
            -- Same address, wrong bytes. Say so per address: "the mirror is
            -- stale" and "the CDN is down" need different fixes.
            table.insert(why, host_of(url) .. ": sha256 " .. tostring(got))
            os.tryrm(dst)
        else
            table.insert(why, host_of(url) .. ": no file")
        end
    end

    log.error("msvc: could not obtain " .. entry.name ..
              "\n  expected sha256 " .. entry.sha256 ..
              "\n  tried:\n    " .. table.concat(why, "\n    "))
    return false
end

-- What a build actually needs, not merely what unpacked.
--
-- The first two were here from the start. `msvcprt.lib` was not, and its
-- absence was invisible for exactly that reason: cl.exe and std.ixx were
-- present, `installed()` said yes, the index's windows-test went green, and
-- every DEFAULT (/MD) build then failed at link on a library nothing had
-- noticed was missing. `.Desktop.base` ships only the static halves; the
-- dynamic import libs come from the `.x64.Store.base` payload added above.
--
-- Both CRT models are asserted, because each alone leaves the other free to
-- go missing the same silent way:
--   libcpmt.lib  -- /MT, from CRT.x64.Desktop.base
--   msvcprt.lib  -- /MD, from CRT.x64.Store.base  (the DEFAULT model)
local function required_files()
    return {
        path.join(bindir(), "cl.exe"),
        path.join(toolsdir(), "modules", "std.ixx"),
        path.join(toolsdir(), "lib", "x64", "libcpmt.lib"),
        path.join(toolsdir(), "lib", "x64", "msvcprt.lib"),
    }
end

function installed()
    for _, f in ipairs(required_files()) do
        if not os.isfile(f) then return false end
    end
    return true
end

function install()
    local idir = pkginfo.install_dir()
    local work = path.join(idir, ".payloads")
    os.tryrm(idir)
    os.mkdir(work)

    for _, e in ipairs(payloads()) do
        if not fetch_verified(e, work) then return false end
    end

    -- A .vsix is a ZIP, and that decides WHICH tar -- not just which path.
    --
    -- Windows 10 1803+ ships bsdtar at System32\tar.exe, and libarchive reads
    -- zip. GNU tar does not read zip AT ALL. So on a runner where Git for
    -- Windows is on PATH ahead of System32, a bare `tar` is a coin flip
    -- between "works" and:
    --
    --     tar: This does not look like a tar archive
    --
    -- Two runs on the SAME GitHub image proved it: the index's own
    -- windows-test resolved bsdtar and passed; mcpp's e2e resolved GNU tar
    -- and failed. Same recipe, same image, different PATH -- so the recipe
    -- must not let PATH pick.
    --
    -- ABSOLUTE paths for everything, and NO `os.cd`.
    --
    -- The drive-colon hazard was GNU tar's alone; pinning bsdtar removes it,
    -- so the relative-name workaround it needed goes away with it. That
    -- workaround also depended on `system.exec` inheriting a cwd set by
    -- `os.cd` -- which it does not. 7zip.lua's cd-then-relative-name shape
    -- uses `os.exec`, and I copied the shape without checking that one
    -- difference: the command came out perfectly formed and still could not
    -- find its archive.
    --
    -- winpath() on every path, because path.join mixes separators and both
    -- the executable and its arguments care:
    --
    --     "C:\\Windows/System32/tar.exe" -xf "...": exec failed
    --
    -- Fewer moving parts than the version this replaces: no cwd to change, no
    -- cwd to restore, and nothing that depends on which tar runs it.
    local systar = winpath(path.join(os.getenv("SystemRoot") or "C:\\Windows",
                                     "System32", "tar.exe"))
    local stage = path.join(work, "x")

    -- pcall so a raising `system.exec` becomes a named error and `false`,
    -- rather than propagating out of a hook whose contract is true/false --
    -- which is how the first failure here read as the unhelpful
    -- "install hook failed: install hook returned false".
    local ok, err = pcall(function()
        for _, e in ipairs(payloads()) do
            log.info("msvc: unpacking " .. e.name)
            os.mkdir(stage)
            -- The EXE IS NOT QUOTED, and that is not an oversight.
            --
            -- `cmd /c` mangles a line whose first token is quoted when more
            -- quoted arguments follow -- it strips the outermost pair and
            -- answers:
            --
            --     The filename, directory name, or volume label syntax is incorrect.
            --
            -- The evidence is clean: with a bare `tar` the program RAN and
            -- complained itself ("does not look like a tar archive"); with
            -- `"C:\...\tar.exe"` nothing ran at all. vc6.lua has the same
            -- shape -- unquoted command, quoted arguments.
            --
            -- Safe because %SystemRoot% has no spaces; the ARGUMENTS keep
            -- their quotes, and they are the ones that can.
            system.exec(string.format('%s -xf "%s" -C "%s"',
                                      systar,
                                      winpath(path.join(work, e.name)),
                                      winpath(stage)))
            -- Everything useful lives under Contents/; the rest is vsix metadata.
            local contents = path.join(stage, "Contents")
            if os.isdir(contents) then
                -- All the payloads unpack into the SAME VC/ tree, so this is a
                -- merge, not a move. os.cp of a directory INTO an existing one
                -- of the same name nests it -- measured on windows-sdk, which
                -- ended up with Include/<ver>/<ver>/ that way -- and a
                -- recursive merge in Lua would need os.files, which is not in
                -- the sandbox.
                -- xcopy merges, ships with Windows, and returns 0 on success.
                system.exec(string.format('xcopy "%s\\*" "%s\\" /E /I /Y /Q',
                                          winpath(contents), winpath(idir)))
            end
            os.tryrm(stage)
        end
    end)
    if not ok then
        log.error("msvc: unpacking failed: " .. tostring(err))
        return false
    end
    os.tryrm(work)

    if not installed() then
        -- Name the MISSING file, not the category. "cl.exe / std.ixx are not
        -- where they should be" was true and useless when the missing thing
        -- was neither of them.
        local missing = {}
        for _, f in ipairs(required_files()) do
            if not os.isfile(f) then table.insert(missing, f) end
        end
        log.error("msvc: unpacked, but these are not where they should be:\n    " ..
                  table.concat(missing, "\n    ") ..
                  "\n  (expected under VC/Tools/MSVC/" .. toolset() .. ")")
        return false
    end
    return true
end

function config()
    local idir = pkginfo.install_dir()
    local sdk = pkginfo.dep_install_dir("xim:windows-sdk")

    -- INCLUDE / LIB go on the SHIMS, not into the subos.
    --
    -- They are the compiler's own business: cl and link are the processes that
    -- read them, and they are exactly the processes xlings wraps. Putting them
    -- in the subos instead would export a Windows-SDK include path to every
    -- other compiler in the same subos, which is a real way to break an
    -- unrelated build.
    local inc = { path.join(idir, "VC", "Tools", "MSVC", toolset(), "include") }
    local lib = { path.join(idir, "VC", "Tools", "MSVC", toolset(), "lib", "x64") }
    if sdk then
        for _, part in ipairs({"ucrt", "um", "shared"}) do
            table.insert(inc, path.join(sdk, "Include", SDK_DIR_VERSION, part))
        end
        for _, part in ipairs({"ucrt", "um"}) do
            table.insert(lib, path.join(sdk, "Lib", SDK_DIR_VERSION, part, "x64"))
        end
    else
        log.warn("msvc: windows-sdk did not resolve; cl will not find ucrt/um headers")
    end

    local envs = {
        INCLUDE = table.concat(inc, ";"),
        LIB     = table.concat(lib, ";"),
    }
    for _, prog in ipairs(package.programs) do
        xvm.add(prog, { bindir = bindir(), envs = envs })
    end

    -- VSINSTALLDIR goes in the SUBOS, because the processes that need it are
    -- build systems -- mcpp, xmake, cmake -- and xlings never wraps those, so
    -- a per-shim env cannot reach them. They use it to DISCOVER the toolchain:
    -- mcpp, for one, accepts any directory that has VC/Tools/MSVC under it.
    --
    -- This is a compatibility hook, not the record of which toolchain a build
    -- used. That record belongs in the project's own manifest.
    if type(subos.env) == "function" then
        local tag = package.name .. "@" .. pkginfo.version()
        subos.env{ var = "VSINSTALLDIR", op = "set", value = "${pkgdir}", binding = tag }
    end
    return true
end

function uninstall()
    for _, prog in ipairs(package.programs) do
        xvm.remove(prog)
    end
    return true
end
