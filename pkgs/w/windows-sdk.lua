-- Windows SDK (Desktop x64 subset) as an xlings payload package.
--
-- Why this exists: the index had no Windows SDK at all, and an MSVC toolset
-- without one cannot compile a single translation unit -- the ucrt / um /
-- shared headers and the um libs are not part of the compiler.
--
-- Not the 530 MB full SDK. Four MSIs and the fifteen cabinets their Media
-- tables reference, 139 MB, enough to compile and link x64 desktop C++:
--
--   Universal CRT Headers Libraries and Sources   ucrt headers + libs
--   Windows SDK Desktop Headers x64               um / shared headers
--   Windows SDK Desktop Libs x64                  um libs
--   Windows SDK Desktop Tools x64                 rc.exe, mt.exe
--
-- Every payload below is pinned by URL + sha256, both taken from the VS
-- channel manifest (see the msvc recipe's header for how that is resolved).
-- The MSI -> cabinet mapping is NOT discoverable from the manifest: cabinet
-- file names are opaque hashes, and the mapping lives in each MSI's Media
-- table. It was extracted once, offline, and is recorded here as static data
-- -- so an install performs no discovery and can be reproduced byte for byte.
--
-- Extraction is `msiexec /a`, an administrative install: it unpacks the MSI's
-- file tree to a directory without registering anything and without needing
-- elevation. The cabinets must sit next to their MSI, which is why everything
-- lands in one directory first.
package = {
    spec = "1",

    name = "windows-sdk",
    description = "Windows SDK (Desktop x64 subset: ucrt/um/shared headers, um libs, rc/mt)",

    maintainers = {"Microsoft"},
    licenses = {"Proprietary"},
    homepage = "https://developer.microsoft.com/windows/downloads/windows-sdk/",
    docs = "https://learn.microsoft.com/windows/win32/",

    type = "package",
    archs = {"x86_64"},
    status = "dev",
    categories = {"toolchain", "sdk", "windows"},
    keywords = {"windows", "sdk", "ucrt", "win32", "msvc"},

    programs = {"rc", "mt"},

    xvm_enable = true,

    xpm = {
        windows = {
            -- Empty resource: this package fetches a SET of payloads, and the
            -- framework's single-url download cannot express that. install()
            -- does it, and checks every sha256 itself.
            ["latest"] = { ref = "10.0.26100" },
            ["10.0.26100"] = { },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.log")
import("xim.libxpkg.xvm")

-- The SDK version as it appears in the on-disk directory names. The package
-- version is the same triple without the servicing field; both are spelled
-- out rather than derived, so neither can drift into a guess.
local SDK_DIR_VERSION = "10.0.26100.0"

local PAYLOADS = {
    { name = "Universal CRT Headers Libraries and Sources-x86_en-us.msi", msi = true,
      sha256 = "F611CE8A9E576E3383917B04B6FBE5EE6BED8363C1A2A8E9D6F8335CBB422675",
      url = "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/d10da41a6ad6809f823ef4a92d4f6c56/universal%20crt%20headers%20libraries%20and%20sources-x86_en-us.msi" },
    { name = "Windows SDK Desktop Headers x64-x86_en-us.msi", msi = true,
      sha256 = "D189CA50E5632B546795922E2262794C068D6FF301860FEB4522B8B93CBB3BA8",
      url = "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/ed222baa6d1d1dc09fb45a1827e7892a/windows%20sdk%20desktop%20headers%20x64-x86_en-us.msi" },
    { name = "Windows SDK Desktop Libs x64-x86_en-us.msi", msi = true,
      sha256 = "2E956CA1CF17800B0F9811A6249B945F045ADDF18EE85FFE7AEA99EC6C27243A",
      url = "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/a7dce16da158fe456395566e2dafd23d/windows%20sdk%20desktop%20libs%20x64-x86_en-us.msi" },
    { name = "Windows SDK Desktop Tools x64-x86_en-us.msi", msi = true,
      sha256 = "5AF8B39E5B8E40C7235B447E7D18CE4607209734F3C506006FADCDEB8931C136",
      url = "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/2509ce9c6746f0629e5a4905b022be80/windows%20sdk%20desktop%20tools%20x64-x86_en-us.msi" },
    { name = "16ab2ea2187acffa6435e334796c8c89.cab",
      sha256 = "D29E10BB5CE2E28957B5635B6EEB6A491FDB311C925B398443451F953F399BC2",
      url = "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/d56a87b40b1de33c2c39a1a3d009e148/16ab2ea2187acffa6435e334796c8c89.cab" },
    { name = "19248fabbb2098a7b88c4a2786066bcc.cab",
      sha256 = "6CCBD0B699534B8CC24784E9FBBF242196332053313075C334C126E90C8A21E7",
      url = "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/2e009aabfde2988589258b1c79f89411/19248fabbb2098a7b88c4a2786066bcc.cab" },
    { name = "58314d0646d7e1a25e97c902166c3155.cab",
      sha256 = "EC209A224C9B2D31F3409208D30F5A6335C55217AD384D6212C833AC83360EBA",
      url = "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/cb954f8bc3015e25cfd985a5fff3452a/58314d0646d7e1a25e97c902166c3155.cab" },
    { name = "6ee7bbee8435130a869cf971694fd9e2.cab",
      sha256 = "04728E326214D8960A188614995B65A3E9E33F93EAF13DD3CA16FE513CDFF0DE",
      url = "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/9a7bacb65de148f099902218ada3394b/6ee7bbee8435130a869cf971694fd9e2.cab" },
    { name = "78fa3c824c2c48bd4a49ab5969adaaf7.cab",
      sha256 = "6F9096BC7C182383C22A947D1B2C994D78D1742CA25163FAD8FD8C2C848419C5",
      url = "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/721e7f21ddaab126788f6f8b5c3725b4/78fa3c824c2c48bd4a49ab5969adaaf7.cab" },
    { name = "7afc7b670accd8e3cc94cfffd516f5cb.cab",
      sha256 = "1D99DC10063C05E8B34B82AF18DB61C080809456D471674D0272F071526DF0AB",
      url = "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/fdde52f2c4a6db47e015e514a79c3454/7afc7b670accd8e3cc94cfffd516f5cb.cab" },
    { name = "96076045170fe5db6d5dcf14b6f6688e.cab",
      sha256 = "82D970F5B628250EF72467D0826260C6A9F32252F42DAA3C31FED2A23170170E",
      url = "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/510c03213f78beff83c9149c96da2ab6/96076045170fe5db6d5dcf14b6f6688e.cab" },
    { name = "a1e2a83aa8a71c48c742eeaff6e71928.cab",
      sha256 = "29F8ED0537B49087321DFB7CCE60AAD7252900ECFBD81D6336FDB67056778A5D",
      url = "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/87fede232add653343acc94dbdac4118/a1e2a83aa8a71c48c742eeaff6e71928.cab" },
    { name = "b2f03f34ff83ec013b9e45c7cd8e8a73.cab",
      sha256 = "A17B9674B79AC4C8D9C4516C41D6F32FCDE041BDB07EC7F0758C16EE8A62ECAC",
      url = "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/be7bcaf329bbeef873a874aee49456b7/b2f03f34ff83ec013b9e45c7cd8e8a73.cab" },
    { name = "beb5360d2daaa3167dea7ad16c28f996.cab",
      sha256 = "6FEAABF4B1B09B4E3210ADDDB12C8C8D6702D731DA033784EF0330488F5BEF51",
      url = "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/b0082c046bf17896e9730ca9f40200ac/beb5360d2daaa3167dea7ad16c28f996.cab" },
    { name = "cdea5502a35d09ddfbcda12e3a391dc0.cab",
      sha256 = "76A16062CC9764CCEB9F0A4E1F43FDEA97AFFA70752C83542562FC1F30FB9E60",
      url = "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/b2d1f784d9f524b43e107fcb420e7cad/cdea5502a35d09ddfbcda12e3a391dc0.cab" },
    { name = "d1de88680a8e53fe75e01e94dc0ed767.cab",
      sha256 = "9D88FA269DC02FD3FDE50A056C04D6DFCC5B8A15739AE0F3E7AC51CC1C88F5B8",
      url = "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/f5ae8b50cc21a7ed5bcace1a38fe8fa3/d1de88680a8e53fe75e01e94dc0ed767.cab" },
    { name = "d95da93904819b1f7e68adb98b49a9c7.cab",
      sha256 = "BC3BEABEBC0A9F161BBBE69DBCE0075019CA6E40F5DF5A8B2342A8A2AB25B22A",
      url = "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/8528492e1ce2a653db74d3988d9ee96b/d95da93904819b1f7e68adb98b49a9c7.cab" },
    { name = "eca0aa33de85194cd50ed6e0aae0156f.cab",
      sha256 = "C0C6CC329D2BE2DDBA902649C46EFB9064186C2185445451602C90D9C7EB3DD8",
      url = "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/827f1b56c1f9090dca62cf5bef23d094/eca0aa33de85194cd50ed6e0aae0156f.cab" },
    { name = "f9ff50431335056fb4fbac05b8268204.cab",
      sha256 = "355CC1E65B9E5F02A0B3A4F32D02F9241B97030D3527166EFF6A372D5D0E1BAC",
      url = "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/8383be7caac218b9afd6a3564dbb0984/f9ff50431335056fb4fbac05b8268204.cab" },
}

-- Download one payload and prove it is the file we asked for.
--
-- The check is the point, not the download: these bytes become a compiler's headers, and
-- "curl exited 0" says nothing about what arrived. Returns false on any
-- mismatch rather than letting a bad payload through.
--
-- certutil, not PowerShell's Get-FileHash: both ship with Windows, but
-- Get-FileHash needs a quoted -LiteralPath nested inside a quoted -Command
-- inside a shell string, and these file names contain spaces. certutil takes
-- one quoted path and prints the digest on a line of its own.
local function fetch_verified(entry, dir)
    local dst = path.join(dir, entry.name)
    if not os.isfile(dst) then
        log.info("windows-sdk: fetching " .. entry.name)
        system.exec(string.format('curl -fsSL --retry 3 -o "%s" "%s"', dst, entry.url))
    end
    if not os.isfile(dst) then
        log.error("windows-sdk: download produced no file: " .. entry.name)
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
        log.error("windows-sdk: sha256 mismatch for " .. entry.name ..
                  "\n  expected " .. entry.sha256 .. "\n  got      " .. tostring(got))
        os.tryrm(dst)
        return false
    end
    return true
end

function installed()
    -- Assert on the artifact: a header and a lib that a compile actually
    -- consumes, not on the directory existing.
    local d = pkginfo.install_dir()
    return os.isfile(path.join(d, "Include", SDK_DIR_VERSION, "ucrt", "corecrt.h"))
       and os.isfile(path.join(d, "Lib", SDK_DIR_VERSION, "um", "x64", "kernel32.lib"))
end

function install()
    local idir = pkginfo.install_dir()
    local work = path.join(idir, ".installers")
    os.tryrm(idir)
    os.mkdir(work)

    for _, e in ipairs(PAYLOADS) do
        if not fetch_verified(e, work) then return false end
    end

    -- msiexec /a: administrative install. Unpacks the file tree, registers
    -- nothing, needs no elevation. TARGETDIR must be absolute.
    for _, e in ipairs(PAYLOADS) do
        if e.msi then
            log.info("windows-sdk: extracting " .. e.name)
            system.exec(string.format('msiexec /a "%s" /quiet /qn TARGETDIR="%s"',
                                     path.join(work, e.name), path.absolute(idir)))
        end
    end

    -- The MSIs lay their payload under "Windows Kits/10/..."; hoist it so the
    -- package root IS the SDK root, which is the shape every consumer expects
    -- (WindowsSdkDir points at it directly).
    local kits = path.join(idir, "Windows Kits", "10")
    if os.isdir(kits) then
        for _, sub in ipairs(os.dirs(path.join(kits, "*"))) do
            os.mv(sub, path.join(idir, path.filename(sub)))
        end
        os.tryrm(path.join(idir, "Windows Kits"))
    end

    os.tryrm(work)

    if not installed() then
        log.error("windows-sdk: extraction finished but the SDK tree is not there " ..
                  "(expected Include/" .. SDK_DIR_VERSION .. "/ucrt/corecrt.h)")
        return false
    end
    return true
end

function config()
    local idir = pkginfo.install_dir()
    xvm.add("rc", { bindir = path.join(idir, "bin", SDK_DIR_VERSION, "x64") })
    xvm.add("mt", { bindir = path.join(idir, "bin", SDK_DIR_VERSION, "x64") })
    return true
end

function uninstall()
    xvm.remove("rc")
    xvm.remove("mt")
    return true
end
