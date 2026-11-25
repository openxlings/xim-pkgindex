-- vcruntime - the Microsoft Visual C++ 2015-2022 runtime DLLs, as a package
-- a prebuilt program can depend on.
--
-- WHY THIS PACKAGE EXISTS
--
-- A prebuilt MSVC program's import tables name `VCRUNTIME140.dll`,
-- `MSVCP140.dll` and siblings, and the archive the program came in does not
-- carry them: upstreams assume the target machine ran the redistributable
-- installer. postgresql's `postgres.exe`/`psql.exe`/`initdb.exe` and mysql's
-- `mysqld.exe`/`mysql.exe` were measured to be exactly in this state (PE
-- import tables, archives without the DLLs), and the CI runners are green
-- only because GitHub's Windows images preinstall the redistributable.
-- Until this package, the index had no answer for a clean machine.
--
-- HOW A CONSUMER USES IT (app-local deployment -- Microsoft's own model for
-- exactly this situation: the loader looks beside the executable before any
-- system directory, so it works no matter how the process was started):
--
--     xpm = { windows = {
--         deps = { runtime = { "xim:vcruntime" } },
--         ...
--     } }
--
--     function install()
--         ... the program's payload lands in pkginfo.install_dir() ...
--         local crt = pkginfo.dep_install_dir("xim:vcruntime")
--         for _, dll in ipairs(fs.files(crt .. "/bin")) do
--             os.cp(dll, <the directory the executables live in>)
--         end
--         ... payload.require{ "bin/psql", ... }
--
-- The consumer copies the DLLs beside its executables at install time; it
-- never vendors them in its own archive. That is the line the repo rule
-- draws (tests/test_no_compiler_runtime_in_payloads.py): the runtime comes
-- from the redistributor -- the toolset, or now this package -- not from a
-- copy an upstream happened to include, which is the failure mode the rule
-- was written for (a stale copy beside images built by a newer toolset).
-- This package always ships the redistributable's LATEST version, which is
-- by construction at least as new as any toolset that built a consumer.
--
-- THE SOURCE, AND WHY THE URL LOOKS LIKE THAT
--
-- `https://aka.ms/vs/17/release/vc_redist.x64.exe` is the official
-- redistributable, but it is a MOVING alias: Microsoft replaces the bytes
-- under it, which no pinned sha256 survives. The versioned
-- `download.visualstudio.microsoft.com/download/pr/<guid>/<SHA256>/...`
-- URL behind it (the same form pkgs/m/msvc.lua pins its vsixes with) is
-- immutable, and its middle path segment IS the file's uppercase sha256 --
-- Microsoft built the pin into the URL. The value below was resolved from
-- the alias on 2026-11-23 and the download was hashed to match it.
--
-- NO CN MIRROR, deliberately: none is verified, and the docs' rule is to
-- declare GLOBAL only then. The URL's embedded digest makes tampering
-- detectable without one.
--
-- WHY EXTRACTION, NOT msiexec
--
-- The bundle is a WiX "burn" installer: a PE carrying a UX cab and, appended
-- after it, a payload CAB that holds every package's MSI and its files.
-- Nothing here installs anything machine-wide: the payload container is
-- located (the LAST `MSCF` CAB signature in the file -- the UX cab is the
-- first), unpacked with the xim:7zip build dependency, and the x64 CRT
-- package inside is identified by WHAT IT UNPACKS TO: its files carry an
-- `_amd64` suffix inside the MSI cab (`vcruntime140.dll_amd64`), while the
-- ARM64 and MFC packages in the same bundle use `_arm64` or no CRT set at
-- all. msiexec's administrative install could do part of this, but it hands
-- the machine's installer service a package for a user-scoped unpack; two
-- plain extractions ask nothing of the machine.
--
-- WHAT IS NOT HERE (yet): the ARM64 CRT (the bundle carries it; no consumer
-- needs it until a Windows-ARM64 install is actually validated) and MFC.
-- Windows x64 only, like every consumer this was measured against.

package = {
    spec = "2",

    name = "vcruntime",
    description = "Microsoft Visual C++ 2015-2022 runtime DLLs (vcruntime140, msvcp140, ...) for prebuilt MSVC programs",
    homepage = "https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist",
    authors = {"Microsoft"},
    maintainers = {"https://github.com/openxlings/xim-pkgindex"},
    licenses = {"Microsoft Software License Terms (Visual C++ Redistributable)"},
    repo = "https://github.com/openxlings/xim-pkgindex",
    docs = "https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"runtime", "library", "windows"},
    keywords = {"vcruntime", "msvcp140", "redistributable", "msvc", "crt"},

    -- Nothing callable: consumers copy the DLLs beside their executables at
    -- install time; a shim would name a program that does not exist.
    xvm_enable = true,

    xpm = {
        windows = {
            deps = { build = { "xim:7zip" } },
            ["latest"] = { ref = "14.44.35211" },
            ["14.44.35211"] = {
                url = "https://download.visualstudio.microsoft.com/download/pr/e9604e21-4b79-4096-a4b3-1b63d4b55b4d/CC0FF0EB1DC3F5188AE6300FAEF32BF5BEEBA4BDD6E8E445A9184072096B713B/VC_redist.x64.exe",
                sha256 = "cc0ff0eb1dc3f5188ae6300faef32bf5beeba4bdd6e8e445a9184072096b713b",
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.log")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")
import("xim.pkgindex.winpath")

-- The twelve DLLs the x64 "additional" CRT package provides, under the
-- names a program's import table asks for. Suffixes are stripped on the way
-- out of the MSI cab (msvcp140.dll_amd64 -> msvcp140.dll).
local CRT = {
    "vcruntime140.dll", "vcruntime140_1.dll", "vcruntime140_threads.dll",
    "msvcp140.dll", "msvcp140_1.dll", "msvcp140_2.dll",
    "msvcp140_atomic_wait.dll", "msvcp140_codecvt_ids.dll",
    "concrt140.dll", "vcamp140.dll", "vcomp140.dll", "vccorlib140.dll",
}

local function required_rel()
    local out = {}
    for _, name in ipairs(CRT) do out[#out + 1] = "bin/" .. name end
    return out
end

function installed()
    return payload.present(required_rel())
end

-- The byte offset of the LAST CAB signature in FILE: the burn bundle's
-- layout is [PE with the UX cab][payload container], so the last MSCF is the
-- payload container. Reading it is five lines of standard Lua -- no probe
-- that "cannot tell" is allowed to fall through to "looks fine".
local function payload_container_at(file)
    local f = assert(io.open(file, "rb"))
    local data = f:read("*a")
    f:close()
    local last, pos = nil, 1
    while true do
        local s = data:find("MSCF", pos, true)
        if not s then break end
        last, pos = s, s + 4
    end
    assert(last, "no CAB container found in " .. file)
    return data, last
end

-- Does PATH name a CAB? (the container unpacks to MSIs and cabs with no
-- extension to go by, so the magic is read, not the name)
local function is_cab(path)
    local f = io.open(path, "rb")
    if not f then return false end
    local magic = f:read(4)
    f:close()
    return magic == "MSCF"
end

function install()
    local exe = tostring(pkginfo.install_file())
    local dir = pkginfo.install_dir()
    local seven = winpath.native(assert(pkginfo.build_dep("7zip"),
            "xim:7zip (build dep) is not available").path) .. "\\7z.exe"

    os.tryrm(dir)

    -- 1. carve the payload container out of the bundle
    local data, at = payload_container_at(exe)
    local stage = exe .. ".vcruntime-stage"
    local container = stage .. ".cab"
    fs.mkdir_p(stage)
    local out = assert(io.open(container, "wb"))
    out:write(data:sub(at))
    out:close()

    -- exec-quoting-ok: the program path is quoted for cmd.exe; the values are paths in quotes
    system.exec(string.format('"%s" x -y -o"%s" "%s"',
                              seven, winpath.native(stage), winpath.native(container)))

    -- 2. find the x64 CRT package among the unpacked payloads: a CAB that
    --    unpacks to *_amd64 files. Tried, not assumed: the ARM64 package in
    --    the same container unpacks to *_arm64 and MFC to no CRT set.
    local crt_dir = nil
    for _, cab in ipairs(fs.files(stage)) do
        if is_cab(cab) then
            local sub = cab .. ".x"
            fs.mkdir_p(sub)
            system.exec(string.format('"%s" x -y -o"%s" "%s"',
                                      seven, winpath.native(sub), winpath.native(cab)))
            if os.isfile(sub .. "/vcruntime140.dll_amd64")
               and os.isfile(sub .. "/msvcp140.dll_amd64") then
                crt_dir = sub
                break
            end
        end
    end
    assert(crt_dir, "the x64 CRT package was not found inside the bundle")

    -- 3. land the DLLs under their canonical names
    fs.mkdir_p(dir .. "/bin")
    for _, f in ipairs(fs.files(crt_dir)) do
        local name = f:match("([^/\\]+)$")
        local canonical = name:match("^(.*)_amd64$")
        if canonical then
            os.mv(f, dir .. "/bin/" .. canonical)
        end
    end

    os.tryrm(stage)
    os.tryrm(container)

    -- 4. every DLL, named -- the extraction "ran" is not a payload
    payload.require(required_rel())
    log.info("vcruntime: %d DLLs from VC_redist 14.44.35211", #CRT)
    return true
end

function config()
    -- A group node: nothing of this package is callable, and a default
    -- program node would mint a shim that always fails (xlings#452). The
    -- node is the bookkeeping a `xlings list` reads; consumers reach the
    -- payload through pkginfo.dep_install_dir, not through a shim.
    xvm.add(package.name, { type = "group" })
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
