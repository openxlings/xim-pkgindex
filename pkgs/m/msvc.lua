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
-- The Insiders entry carries a risk the release one does not: Microsoft rotates
-- those payloads. When 14.52.36629 goes away the URLs 404 -- loudly, and with
-- the sha256 still pinned, so a rotated build cannot be served in its place.
-- That is the failure mode worth having; it is also why `latest` is not it.
local function payloads()
    local set = TOOLSETS[toolset()]
    if not set then
        log.error("msvc: no payload set for toolset " .. tostring(toolset()))
    end
    return set or {}
end

local TOOLSETS = {
    ["14.44.35207"] = {
        { name = "Microsoft.VC.14.44.17.14.Tools.HostX64.TargetX64.base.vsix",
          sha256 = "ee0baaa3a112d255f19f6c27dcc0ff6e496949eb9f1f37be0ac908c562a7076c",
          url = "https://download.visualstudio.microsoft.com/download/pr/bbc72d8e-2acd-4229-8f6a-85e23c5e3456/ee0baaa3a112d255f19f6c27dcc0ff6e496949eb9f1f37be0ac908c562a7076c/Microsoft.VC.14.44.17.14.Tools.HostX64.TargetX64.base.vsix" },
        { name = "Microsoft.VC.14.44.17.14.CRT.Headers.base.vsix",
          sha256 = "852382a9aa73502b7849c1bcadfb603ba7175c4e8b60e6aba03c7de711d4ece5",
          url = "https://download.visualstudio.microsoft.com/download/pr/c610cd8c-801b-44b8-a80a-82cc382aeb43/852382a9aa73502b7849c1bcadfb603ba7175c4e8b60e6aba03c7de711d4ece5/Microsoft.VC.14.44.17.14.CRT.Headers.base.vsix" },
        { name = "Microsoft.VC.14.44.17.14.CRT.x64.Desktop.base.vsix",
          sha256 = "f01f701a7bcd9587a340898c851424f6a52bb913a70c185ff0d5bf0288c5831a",
          url = "https://download.visualstudio.microsoft.com/download/pr/67cf767c-5e71-47c2-a54a-cd5631e28942/f01f701a7bcd9587a340898c851424f6a52bb913a70c185ff0d5bf0288c5831a/Microsoft.VC.14.44.17.14.CRT.x64.Desktop.base.vsix" },
        { name = "Microsoft.VC.14.44.17.14.CRT.Redist.X64.base.vsix",
          sha256 = "4aaf54db0bfc9435f7c3660e1a00237a4b556042bfeea64bde44c2e0194e6ee5",
          url = "https://download.visualstudio.microsoft.com/download/pr/45d3b8dd-bced-4b37-9974-142f748d710c/4aaf54db0bfc9435f7c3660e1a00237a4b556042bfeea64bde44c2e0194e6ee5/Microsoft.VC.14.44.17.14.CRT.Redist.X64.base.vsix" },
    },
    ["14.52.36629"] = {
        { name = "Microsoft.VC.14.52.Tools.HostX64.TargetX64.base.vsix",
          sha256 = "3cf795636cf47b91a3583baa45df8cf7e7448c551a6d2f7f65a015cc1b858930",
          url = "https://download.visualstudio.microsoft.com/download/pr/0fdca428-6677-4d0e-a19d-65f175edc108/3cf795636cf47b91a3583baa45df8cf7e7448c551a6d2f7f65a015cc1b858930/Microsoft.VC.14.52.Tools.HostX64.TargetX64.base.vsix" },
        { name = "Microsoft.VC.14.52.CRT.Headers.base.vsix",
          sha256 = "26c7797d7408b565c0a6bdc0862391bc69efc8aff14560dde854a86b32d8720c",
          url = "https://download.visualstudio.microsoft.com/download/pr/0fdca428-6677-4d0e-a19d-65f175edc108/26c7797d7408b565c0a6bdc0862391bc69efc8aff14560dde854a86b32d8720c/Microsoft.VC.14.52.CRT.Headers.base.vsix" },
        { name = "Microsoft.VC.14.52.CRT.x64.Desktop.base.vsix",
          sha256 = "ff89fd2b115c6a08dff82a6ce9cc90ef6f4aeb4704c29a5b77d16f063ad33524",
          url = "https://download.visualstudio.microsoft.com/download/pr/0fdca428-6677-4d0e-a19d-65f175edc108/ff89fd2b115c6a08dff82a6ce9cc90ef6f4aeb4704c29a5b77d16f063ad33524/Microsoft.VC.14.52.CRT.x64.Desktop.base.vsix" },
        { name = "Microsoft.VC.14.52.CRT.Redist.X64.base.vsix",
          sha256 = "da122e4f50a1d3328dd09954ed81ccf3012a32c23abac215872cc74272eee1f3",
          url = "https://download.visualstudio.microsoft.com/download/pr/0fdca428-6677-4d0e-a19d-65f175edc108/da122e4f50a1d3328dd09954ed81ccf3012a32c23abac215872cc74272eee1f3/Microsoft.VC.14.52.CRT.Redist.X64.base.vsix" },
    },
}

local function toolsdir()
    return path.join(pkginfo.install_dir(), "VC", "Tools", "MSVC", toolset())
end

local function bindir()
    return path.join(toolsdir(), "bin", "Hostx64", "x64")
end

-- Download one payload and prove it is the file we asked for.
--
-- The check is the point, not the download: these bytes become a compiler, and
-- "curl exited 0" says nothing about what arrived. Returns false on any
-- mismatch rather than letting a bad payload through.
--
-- certutil, not PowerShell's Get-FileHash: both ship with Windows, but
-- Get-FileHash needs a quoted -LiteralPath nested inside a quoted -Command
-- inside a shell string. certutil takes one quoted path and prints the digest
-- on a line of its own.
local function fetch_verified(entry, dir)
    local dst = path.join(dir, entry.name)
    if not os.isfile(dst) then
        log.info("msvc: fetching " .. entry.name)
        system.exec(string.format('curl -fsSL --retry 3 -o "%s" "%s"', dst, entry.url))
    end
    if not os.isfile(dst) then
        log.error("msvc: download produced no file: " .. entry.name)
        return false
    end
    local out = os.iorun(string.format('certutil -hashfile "%s" SHA256', dst)) or ""
    local got = nil
    for line in out:gmatch("[^\r\n]+") do
        local hex = line:gsub("%s+", ""):lower()
        if #hex == 64 and hex:match("^%x+$") then got = hex break end
    end
    -- Case-insensitive: certutil prints uppercase, and the manifest is not
    -- consistent either -- the VC payloads carry lowercase digests while the
    -- SDK's are uppercase. Comparing the bytes, not their spelling.
    if got ~= entry.sha256:lower() then
        log.error("msvc: sha256 mismatch for " .. entry.name ..
                  "\n  expected " .. entry.sha256 .. "\n  got      " .. tostring(got))
        os.tryrm(dst)
        return false
    end
    return true
end

function installed()
    -- The compiler itself and the STL's std.ixx: the two things whose absence
    -- turns into a confusing failure much later.
    return os.isfile(path.join(bindir(), "cl.exe"))
       and os.isfile(path.join(toolsdir(), "modules", "std.ixx"))
end

function install()
    local idir = pkginfo.install_dir()
    local work = path.join(idir, ".payloads")
    os.tryrm(idir)
    os.mkdir(work)

    for _, e in ipairs(payloads()) do
        if not fetch_verified(e, work) then return false end
    end

    -- A .vsix is a zip. Windows 10 1803+ ships tar.exe, which reads zip and
    -- needs no PowerShell module and no temp COM object.
    local stage = path.join(work, "x")
    for _, e in ipairs(payloads()) do
        log.info("msvc: unpacking " .. e.name)
        os.mkdir(stage)
        system.exec(string.format('tar -xf "%s" -C "%s"', path.join(work, e.name), stage))
        -- Everything useful lives under Contents/; the rest is vsix metadata.
        local contents = path.join(stage, "Contents")
        if os.isdir(contents) then
            -- All four payloads unpack into the SAME VC/ tree, so this is a
            -- merge, not a move. os.cp of a directory INTO an existing one of
            -- the same name nests it -- measured on windows-sdk, which ended
            -- up with Include/<ver>/<ver>/ that way -- and a recursive merge
            -- in Lua would need os.files, which is not in the sandbox.
            -- xcopy merges, ships with Windows, and returns 0 on success.
            system.exec(string.format('xcopy "%s\\*" "%s\\" /E /I /Y /Q',
                                      winpath(contents), winpath(idir)))
        end
        os.tryrm(stage)
    end
    os.tryrm(work)

    if not installed() then
        log.error("msvc: unpacked, but cl.exe / std.ixx are not where they should be " ..
                  "(expected under VC/Tools/MSVC/" .. toolset() .. ")")
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
