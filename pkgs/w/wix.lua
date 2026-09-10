-- WiX Toolset v5 as an xlings payload package.
--
-- Three NuGet packages rather than one, because that is how WiX ships and
-- because a consumer usually wants only the first:
--
--   wix                                  the `wix` command -- builds .msi and
--                                        bundle .exe from .wxs sources
--   WixToolset.BootstrapperApplicationApi headers + balutil.lib + mbanative.dll
--   WixToolset.DUtil                     headers + dutil.lib
--
-- The last two are for projects that build their OWN bootstrapper application
-- (a custom installer UI) rather than using WiX's stock one. They are here
-- because a project that needs them needs them at the same version as the
-- tool, and splitting the three into separate packages would make that
-- somebody's job to remember.
--
-- WHY NOT `dotnet tool install wix`: that is the documented route and it
-- resolves a version range against nuget.org at install time, which is the
-- opposite of what a pinned payload is for. The .nupkg addresses below are the
-- same bytes that route would fetch, pinned by sha256.
--
-- The tool is a .NET 6 executable: `wix.exe` needs a Microsoft.NETCore.App 6.0
-- or newer runtime on the machine. That is deliberately NOT a dependency here
-- -- it is a Windows component with its own installer, and a package that
-- pretended to own it would be lying about what it installs. `wix --version`
-- says so clearly when it is missing.
package = {
    spec = "2",

    name = "wix",
    description = "WiX Toolset v5 — build Windows .msi packages and bundles from .wxs sources",

    maintainers = {"WiX Toolset Team"},
    licenses = {"MS-RL"},
    homepage = "https://wixtoolset.org",
    repo = "https://github.com/wixtoolset/wix",
    docs = "https://docs.firegiant.com/wix/",

    type = "package",
    -- x86_64 only, and the reason is in the payload rather than the tool:
    -- balutil.lib and dutil.lib are shipped under `build/native/v14/x64/`,
    -- so a custom bootstrapper can only be linked for x64. `wix.exe` itself
    -- is managed code and would run anywhere.
    archs = {"x86_64"},
    status = "dev",
    categories = {"tools", "packaging", "windows"},
    keywords = {"wix", "msi", "installer", "windows", "bundle", "wxs"},

    programs = {"wix"},

    xvm_enable = true,

    xpm = {
        windows = {
            -- Empty resource: this package fetches a SET of payloads and the
            -- framework's single-url download cannot express that. install()
            -- does it and checks every sha256 itself.
            --
            -- curl is a dependency for the same reason windows-sdk declares
            -- it: Windows has shipped one since 10 1803, but a recipe that
            -- downloads a pinned payload set should not leave the downloader
            -- itself to the host.
            deps = { "xim:curl@8.21.0" },
            ["latest"] = { ref = "5.0.2" },
            ["5.0.2"] = { },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.log")
import("xim.libxpkg.xvm")

-- id: the nuget package id, lowercased -- which is also how the flat container
-- addresses it and how the .nupkg is named.
-- into: subdirectory of the install dir, mirroring the layout a consumer sees.
local PAYLOADS = {
    {
        id = "wix",
        into = "tool",
        sha256 = "f30ef0c74e2a986126539c5780be93ac24e8136eaf723b1937b26272703ae173",
        -- One file per payload, checked after extraction. Not a manifest --
        -- an anchor: an archive that extracted to nothing still leaves a
        -- directory behind, and "the directory exists" is not "the tool is
        -- there".
        anchor = "tools/net6.0/any/wix.exe",
    },
    {
        id = "wixtoolset.bootstrapperapplicationapi",
        into = "bootstrapper",
        sha256 = "6e0d3c68a68dcedde4a3a68de896f124a7b19c4a823fac49856e2ee77cb16256",
        anchor = "build/native/v14/x64/balutil.lib",
    },
    {
        id = "wixtoolset.dutil",
        into = "dutil",
        sha256 = "aa4f0668044318820e6c31ffef9f4141830c9fd8ebbe038281329423916547fe",
        anchor = "build/native/v14/x64/dutil.lib",
    },
}

local VERSION = "5.0.2"

local function url_of(entry)
    return string.format(
        "https://api.nuget.org/v3-flatcontainer/%s/%s/%s.%s.nupkg",
        entry.id, VERSION, entry.id, VERSION)
end

local function winpath(p)
    return (p:gsub("/", "\\"))
end

local function sha256_of(file)
    local out = os.iorun(string.format('certutil -hashfile "%s" SHA256', file)) or ""
    for line in out:gmatch("[^\r\n]+") do
        local hex = line:gsub("%s+", ""):lower()
        if #hex == 64 and hex:match("^%x+$") then return hex end
    end
    return nil
end

local function fetch_verified(entry, dir)
    local dst = path.join(dir, entry.id .. ".nupkg")
    local want = entry.sha256:lower()

    -- An already-present file still has to prove itself: a partial download
    -- from an interrupted run is also "a file that exists".
    if os.isfile(dst) then
        if sha256_of(dst) == want then return true end
        os.tryrm(dst)
    end

    log.info("wix: fetching " .. entry.id .. " " .. VERSION)
    -- pcall: curl -f exits non-zero on a 404 and system.exec raises on a
    -- non-zero exit, so without this a missing payload aborts with a stack
    -- trace instead of the message below.
    pcall(system.exec, string.format('curl -fsSL --retry 3 -o "%s" "%s"', dst, url_of(entry)))
    if not os.isfile(dst) then
        log.error("wix: " .. entry.id .. " did not download")
        return false
    end
    local got = sha256_of(dst)
    if got ~= want then
        log.error("wix: " .. entry.id .. " sha256 is " .. tostring(got) .. ", expected " .. want)
        os.tryrm(dst)
        return false
    end
    return true
end

-- A .nupkg IS a zip, and Windows can open one two ways.
--
-- bsdtar (`tar.exe`, in System32 since Windows 10 1803) is the fast one, and
-- unlike Expand-Archive it does not insist on a `.zip` extension -- which is
-- why this hook used it alone. But it is a HOST tool, and a host tool that is
-- merely "usually there" is exactly what this package already declined to
-- accept for the downloader: `xim:curl` is a declared dependency for that
-- reason, and `tests/w/test_wix.py::test_declares_the_downloader` guards it.
-- tar was the one exception, and nothing had ever exercised it -- test_wix.py
-- is static-only, and until now no package in either index pulled wix, so its
-- install hook had never run in CI at all.
--
-- The first consumer found it. Building `huxerui.huxerui` from source
-- provisions wix (upstream declares it in `[xlings.workspace]`), and on a
-- clean windows-latest runner:
--
--     E_INTERNAL: [wix] failed: install hook failed:
--     exec failed after 1 attempt(s): tar -xf "...\\wix.nupkg" -C "...\\tool"
--     ; wix installed but registered none of its declared programs
--
-- So tar stays as the fast path and PowerShell's Expand-Archive becomes the
-- fallback -- every supported Windows has it, and the `.zip` name it wants is
-- one copy away. `code.lua` and `ollama.lua` already extract exactly this way.
-- The anchor check below still runs either way: "the archive opened" and "the
-- tool is there" are different claims.
local function extract(nupkg, dest)
    local ok, err = pcall(system.exec, string.format('tar -xf "%s" -C "%s"',
                                                     winpath(nupkg), winpath(dest)))
    if ok then return true end
    log.warn("wix: tar could not read " .. path.filename(nupkg)
             .. " (" .. tostring(err) .. "); falling back to Expand-Archive")

    local zip = path.join(path.directory(nupkg), path.basename(nupkg) .. ".zip")
    os.tryrm(zip)
    os.cp(nupkg, zip)
    local ok2, err2 = pcall(system.exec, string.format(
        [[powershell -NoProfile -ExecutionPolicy Bypass -Command ]]
        .. [["Expand-Archive -Path '%s' -DestinationPath '%s' -Force"]],
        winpath(zip), winpath(dest)))
    os.tryrm(zip)
    if not ok2 then
        log.error("wix: Expand-Archive also failed (" .. tostring(err2) .. ")")
        return false
    end
    return true
end

function installed()
    local idir = pkginfo.install_dir()
    for _, entry in ipairs(PAYLOADS) do
        if not os.isfile(path.join(idir, entry.into, entry.anchor)) then
            return false
        end
    end
    return true
end

function install()
    local idir = pkginfo.install_dir()
    local work = path.join(idir, ".nupkg")
    os.tryrm(idir)
    fs.mkdir_p(work)

    for _, entry in ipairs(PAYLOADS) do
        if not fetch_verified(entry, work) then return false end
    end

    for _, entry in ipairs(PAYLOADS) do
        local dest = path.join(idir, entry.into)
        fs.mkdir_p(dest)
        if not extract(path.join(work, entry.id .. ".nupkg"), dest) then
            log.error("wix: " .. entry.id .. " could not be extracted")
            return false
        end
        if not os.isfile(path.join(dest, entry.anchor)) then
            log.error("wix: " .. entry.id .. " extracted without " .. entry.anchor)
            return false
        end
    end

    os.tryrm(work)
    return installed()
end

function config()
    -- wix.exe is not alone in its directory: it loads runtimes/win-x64/native
    -- and x64/burn.exe from beside itself, so the bindir is that directory
    -- rather than a copy of the executable somewhere tidier.
    xvm.add("wix", {
        bindir = path.join(pkginfo.install_dir(), "tool", "tools", "net6.0", "any"),
    })
    return true
end

function uninstall()
    xvm.remove("wix")
    return true
end
