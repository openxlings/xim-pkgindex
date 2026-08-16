-- Windows SDK (Desktop x64 subset) as an xlings payload package.
--
-- Why this exists: the index had no Windows SDK at all, and an MSVC toolset
-- without one cannot compile a single translation unit -- the ucrt / um /
-- shared headers and the um libs are not part of the compiler.
--
-- Not the 530 MB full SDK. Eight MSIs and the thirty-five cabinets their
-- Media tables reference, 291 MB, enough to compile, link and rc a Win32
-- desktop program:
--
--   Universal CRT Headers Libraries and Sources   ucrt headers + libs
--   Windows SDK Desktop Libs x64                  365 um libs -- the LONG TAIL
--   Windows SDK Desktop Tools x64                 99 bin tools (NOT rc/mt)
--   Windows SDK Desktop Headers x64               3 Hyper-V headers, no more
--   Windows SDK for Windows Store Apps Libs       kernel32/user32/advapi32/
--                                                 ole32/oleaut32/uuid  <- core
--   Windows SDK for Windows Store Apps Headers    528 um headers: windows.h,
--                                                 winnt.h  <- core
--   ... Headers OnecoreUap                        shared/: windef.h, sal.h,
--                                                 winerror.h  <- core
--   Windows SDK for Windows Store Apps Tools      rc.exe, rcdll.dll, mt.exe
--
-- Read that list again: EVERY header and library and tool a Win32 program
-- actually needs comes from an MSI whose name says "Store Apps", and the
-- four whose names say "Desktop" contribute a long tail, some bin utilities
-- and three Hyper-V headers. The naming is not a hint -- it is an anti-hint.
-- Same trap as msvc.lua's CRT.x64.Store.base, now four layers deep.
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
            -- curl does the fetching below. Windows ships one since 10 1803,
            -- but a recipe that downloads and checksums a pinned payload set
            -- should not leave the downloader itself to the host -- that is
            -- the one open end in an otherwise closed chain.
            deps = { "xim:curl@8.21.0" },
            ["latest"] = { ref = "10.0.26100" },
            ["10.0.26100"] = { },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.log")
import("xim.libxpkg.xvm")
import("xim.libxpkg.subos")

-- The SDK version as it appears in the on-disk directory names. The package
-- version is the same triple without the servicing field; both are spelled
-- out rather than derived, so neither can drift into a guess.
local SDK_DIR_VERSION = "10.0.26100.0"

-- path.join mixes separators on Windows -- it keeps the backslashes already in
-- the store path and adds forward ones -- and msiexec rejects the result:
--
--   msiexec /a "...\10.0.26100/.installers/Universal CRT ....msi" /qn ...
--   exec failed after 1 attempt(s)
--
-- curl and tar do not care; msiexec does. Normalised at the call site rather
-- than globally, so nothing else has to know.
local function winpath(p)
    return (p:gsub("/", "\\"))
end

local PAYLOADS = {
    { name = "Universal CRT Headers Libraries and Sources-x86_en-us.msi", msi = true,
      sha256 = "F611CE8A9E576E3383917B04B6FBE5EE6BED8363C1A2A8E9D6F8335CBB422675",
      urls = { "https://gitcode.com/xlings-res/windows-sdk/releases/download/10.0.26100/Universal_CRT_Headers_Libraries_and_Sources-x86_en-us.msi",
               "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/d10da41a6ad6809f823ef4a92d4f6c56/universal%20crt%20headers%20libraries%20and%20sources-x86_en-us.msi" } },
    { name = "Windows SDK Desktop Headers x64-x86_en-us.msi", msi = true,
      sha256 = "D189CA50E5632B546795922E2262794C068D6FF301860FEB4522B8B93CBB3BA8",
      urls = { "https://gitcode.com/xlings-res/windows-sdk/releases/download/10.0.26100/Windows_SDK_Desktop_Headers_x64-x86_en-us.msi",
               "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/ed222baa6d1d1dc09fb45a1827e7892a/windows%20sdk%20desktop%20headers%20x64-x86_en-us.msi" } },
    { name = "Windows SDK Desktop Libs x64-x86_en-us.msi", msi = true,
      sha256 = "2E956CA1CF17800B0F9811A6249B945F045ADDF18EE85FFE7AEA99EC6C27243A",
      urls = { "https://gitcode.com/xlings-res/windows-sdk/releases/download/10.0.26100/Windows_SDK_Desktop_Libs_x64-x86_en-us.msi",
               "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/a7dce16da158fe456395566e2dafd23d/windows%20sdk%20desktop%20libs%20x64-x86_en-us.msi" } },
    { name = "Windows SDK Desktop Tools x64-x86_en-us.msi", msi = true,
      sha256 = "5AF8B39E5B8E40C7235B447E7D18CE4607209734F3C506006FADCDEB8931C136",
      urls = { "https://gitcode.com/xlings-res/windows-sdk/releases/download/10.0.26100/Windows_SDK_Desktop_Tools_x64-x86_en-us.msi",
               "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/2509ce9c6746f0629e5a4905b022be80/windows%20sdk%20desktop%20tools%20x64-x86_en-us.msi" } },
    { name = "16ab2ea2187acffa6435e334796c8c89.cab",
      sha256 = "D29E10BB5CE2E28957B5635B6EEB6A491FDB311C925B398443451F953F399BC2",
      urls = { "https://gitcode.com/xlings-res/windows-sdk/releases/download/10.0.26100/16ab2ea2187acffa6435e334796c8c89.cab.bin",
               "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/d56a87b40b1de33c2c39a1a3d009e148/16ab2ea2187acffa6435e334796c8c89.cab" } },
    { name = "19248fabbb2098a7b88c4a2786066bcc.cab",
      sha256 = "6CCBD0B699534B8CC24784E9FBBF242196332053313075C334C126E90C8A21E7",
      urls = { "https://gitcode.com/xlings-res/windows-sdk/releases/download/10.0.26100/19248fabbb2098a7b88c4a2786066bcc.cab.bin",
               "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/2e009aabfde2988589258b1c79f89411/19248fabbb2098a7b88c4a2786066bcc.cab" } },
    { name = "58314d0646d7e1a25e97c902166c3155.cab",
      sha256 = "EC209A224C9B2D31F3409208D30F5A6335C55217AD384D6212C833AC83360EBA",
      urls = { "https://gitcode.com/xlings-res/windows-sdk/releases/download/10.0.26100/58314d0646d7e1a25e97c902166c3155.cab.bin",
               "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/cb954f8bc3015e25cfd985a5fff3452a/58314d0646d7e1a25e97c902166c3155.cab" } },
    { name = "6ee7bbee8435130a869cf971694fd9e2.cab",
      sha256 = "04728E326214D8960A188614995B65A3E9E33F93EAF13DD3CA16FE513CDFF0DE",
      urls = { "https://gitcode.com/xlings-res/windows-sdk/releases/download/10.0.26100/6ee7bbee8435130a869cf971694fd9e2.cab.bin",
               "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/9a7bacb65de148f099902218ada3394b/6ee7bbee8435130a869cf971694fd9e2.cab" } },
    { name = "78fa3c824c2c48bd4a49ab5969adaaf7.cab",
      sha256 = "6F9096BC7C182383C22A947D1B2C994D78D1742CA25163FAD8FD8C2C848419C5",
      urls = { "https://gitcode.com/xlings-res/windows-sdk/releases/download/10.0.26100/78fa3c824c2c48bd4a49ab5969adaaf7.cab.bin",
               "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/721e7f21ddaab126788f6f8b5c3725b4/78fa3c824c2c48bd4a49ab5969adaaf7.cab" } },
    { name = "7afc7b670accd8e3cc94cfffd516f5cb.cab",
      sha256 = "1D99DC10063C05E8B34B82AF18DB61C080809456D471674D0272F071526DF0AB",
      urls = { "https://gitcode.com/xlings-res/windows-sdk/releases/download/10.0.26100/7afc7b670accd8e3cc94cfffd516f5cb.cab.bin",
               "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/fdde52f2c4a6db47e015e514a79c3454/7afc7b670accd8e3cc94cfffd516f5cb.cab" } },
    { name = "96076045170fe5db6d5dcf14b6f6688e.cab",
      sha256 = "82D970F5B628250EF72467D0826260C6A9F32252F42DAA3C31FED2A23170170E",
      urls = { "https://gitcode.com/xlings-res/windows-sdk/releases/download/10.0.26100/96076045170fe5db6d5dcf14b6f6688e.cab.bin",
               "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/510c03213f78beff83c9149c96da2ab6/96076045170fe5db6d5dcf14b6f6688e.cab" } },
    { name = "a1e2a83aa8a71c48c742eeaff6e71928.cab",
      sha256 = "29F8ED0537B49087321DFB7CCE60AAD7252900ECFBD81D6336FDB67056778A5D",
      urls = { "https://gitcode.com/xlings-res/windows-sdk/releases/download/10.0.26100/a1e2a83aa8a71c48c742eeaff6e71928.cab.bin",
               "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/87fede232add653343acc94dbdac4118/a1e2a83aa8a71c48c742eeaff6e71928.cab" } },
    { name = "b2f03f34ff83ec013b9e45c7cd8e8a73.cab",
      sha256 = "A17B9674B79AC4C8D9C4516C41D6F32FCDE041BDB07EC7F0758C16EE8A62ECAC",
      urls = { "https://gitcode.com/xlings-res/windows-sdk/releases/download/10.0.26100/b2f03f34ff83ec013b9e45c7cd8e8a73.cab.bin",
               "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/be7bcaf329bbeef873a874aee49456b7/b2f03f34ff83ec013b9e45c7cd8e8a73.cab" } },
    { name = "beb5360d2daaa3167dea7ad16c28f996.cab",
      sha256 = "6FEAABF4B1B09B4E3210ADDDB12C8C8D6702D731DA033784EF0330488F5BEF51",
      urls = { "https://gitcode.com/xlings-res/windows-sdk/releases/download/10.0.26100/beb5360d2daaa3167dea7ad16c28f996.cab.bin",
               "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/b0082c046bf17896e9730ca9f40200ac/beb5360d2daaa3167dea7ad16c28f996.cab" } },
    { name = "cdea5502a35d09ddfbcda12e3a391dc0.cab",
      sha256 = "76A16062CC9764CCEB9F0A4E1F43FDEA97AFFA70752C83542562FC1F30FB9E60",
      urls = { "https://gitcode.com/xlings-res/windows-sdk/releases/download/10.0.26100/cdea5502a35d09ddfbcda12e3a391dc0.cab.bin",
               "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/b2d1f784d9f524b43e107fcb420e7cad/cdea5502a35d09ddfbcda12e3a391dc0.cab" } },
    { name = "d1de88680a8e53fe75e01e94dc0ed767.cab",
      sha256 = "9D88FA269DC02FD3FDE50A056C04D6DFCC5B8A15739AE0F3E7AC51CC1C88F5B8",
      urls = { "https://gitcode.com/xlings-res/windows-sdk/releases/download/10.0.26100/d1de88680a8e53fe75e01e94dc0ed767.cab.bin",
               "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/f5ae8b50cc21a7ed5bcace1a38fe8fa3/d1de88680a8e53fe75e01e94dc0ed767.cab" } },
    { name = "d95da93904819b1f7e68adb98b49a9c7.cab",
      sha256 = "BC3BEABEBC0A9F161BBBE69DBCE0075019CA6E40F5DF5A8B2342A8A2AB25B22A",
      urls = { "https://gitcode.com/xlings-res/windows-sdk/releases/download/10.0.26100/d95da93904819b1f7e68adb98b49a9c7.cab.bin",
               "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/8528492e1ce2a653db74d3988d9ee96b/d95da93904819b1f7e68adb98b49a9c7.cab" } },
    { name = "eca0aa33de85194cd50ed6e0aae0156f.cab",
      sha256 = "C0C6CC329D2BE2DDBA902649C46EFB9064186C2185445451602C90D9C7EB3DD8",
      urls = { "https://gitcode.com/xlings-res/windows-sdk/releases/download/10.0.26100/eca0aa33de85194cd50ed6e0aae0156f.cab.bin",
               "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/827f1b56c1f9090dca62cf5bef23d094/eca0aa33de85194cd50ed6e0aae0156f.cab" } },
    { name = "f9ff50431335056fb4fbac05b8268204.cab",
      sha256 = "355CC1E65B9E5F02A0B3A4F32D02F9241B97030D3527166EFF6A372D5D0E1BAC",
      urls = { "https://gitcode.com/xlings-res/windows-sdk/releases/download/10.0.26100/f9ff50431335056fb4fbac05b8268204.cab.bin",
               "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/8383be7caac218b9afd6a3564dbb0984/f9ff50431335056fb4fbac05b8268204.cab" } },
    -- ⚠️ "Store Apps" is a misleading name -- the same trap as msvc.lua's
    -- CRT.x64.Store.base, one layer down. THIS is where the core Win32 import
    -- libraries live:
    --     kernel32.lib  user32.lib  advapi32.lib  ole32.lib  oleaut32.lib  uuid.lib
    -- "Windows SDK Desktop Libs x64" carries 341 um libs and NONE of those
    -- six; it is the long tail (sensorsapi, websocket, computestorage...).
    -- Without this MSI a link of `int main(){}` fails at
    --     LINK : fatal error LNK1104: cannot open file 'kernel32.lib'
    -- which is every program, so the SDK subset was unusable for its purpose.
    { name = "Windows SDK for Windows Store Apps Libs-x86_en-us.msi", msi = true,
      sha256 = "1381535D2F6B1894A092DA67F8A8FB048A4DFE8060CE75B3275AFFA81B02586E",
      urls = { "https://gitcode.com/xlings-res/windows-sdk/releases/download/10.0.26100/Windows_SDK_for_Windows_Store_Apps_Libs-x86_en-us.msi",
               "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/079ca63878193e064d8aa000670f0db3/windows%20sdk%20for%20windows%20store%20apps%20libs-x86_en-us.msi" } },
    { name = "05047a45609f311645eebcac2739fc4c.cab",
      sha256 = "902003E4976C7BC4BCDA9F31F1D835B8072235532412770F66B0BC9F0882CB7E",
      urls = { "https://gitcode.com/xlings-res/windows-sdk/releases/download/10.0.26100/05047a45609f311645eebcac2739fc4c.cab.bin",
               "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/67a9b258981565b78c46484efbed6945/05047a45609f311645eebcac2739fc4c.cab" } },
    { name = "13d68b8a7b6678a368e2d13ff4027521.cab",
      sha256 = "0B26EDE2D22EA531D921269DFFFCD14CC71D6932CAC0F2720FCEC37079286643",
      urls = { "https://gitcode.com/xlings-res/windows-sdk/releases/download/10.0.26100/13d68b8a7b6678a368e2d13ff4027521.cab.bin",
               "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/2160d8b73fe2e4fea3e2097084a081cd/13d68b8a7b6678a368e2d13ff4027521.cab" } },
    { name = "463ad1b0783ebda908fd6c16a4abfe93.cab",
      sha256 = "43C40559098A2C1EFBEF6AF16F97A44FD80B3BB9FE8AE117C4E6F9F3F852B8E8",
      urls = { "https://gitcode.com/xlings-res/windows-sdk/releases/download/10.0.26100/463ad1b0783ebda908fd6c16a4abfe93.cab.bin",
               "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/637a623c788980d4a7edf6d84e34ed70/463ad1b0783ebda908fd6c16a4abfe93.cab" } },
    { name = "5a22e5cde814b041749fb271547f4dd5.cab",
      sha256 = "57E7E309413D05B781AE76D1B5C54DC7AFF350B6A460920F1F358E8003AABDFB",
      urls = { "https://gitcode.com/xlings-res/windows-sdk/releases/download/10.0.26100/5a22e5cde814b041749fb271547f4dd5.cab.bin",
               "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/03cfd7ea3b3116d5d32d11df101dea24/5a22e5cde814b041749fb271547f4dd5.cab" } },
    { name = "e10768bb6e9d0ea730280336b697da66.cab",
      sha256 = "46E21578A4CFCE3BD6E4EACC10B92121A825CE443CC2F6CCE84B07E37B9D21BC",
      urls = { "https://gitcode.com/xlings-res/windows-sdk/releases/download/10.0.26100/e10768bb6e9d0ea730280336b697da66.cab.bin",
               "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/b2915dcb648d1087f4a5ef20f17c9825/e10768bb6e9d0ea730280336b697da66.cab" } },
    { name = "f9b24c8280986c0683fbceca5326d806.cab",
      sha256 = "154F4A24EC22EA0C932709F0E1A2C443946B42C14291A49A280AB4EA0EAA504D",
      urls = { "https://gitcode.com/xlings-res/windows-sdk/releases/download/10.0.26100/f9b24c8280986c0683fbceca5326d806.cab.bin",
               "https://download.visualstudio.microsoft.com/download/pr/6452c1f1-dc1e-413c-8b19-991b61870a8b/66f36d1686d2dde0cfa99a5160a9571d/f9b24c8280986c0683fbceca5326d806.cab" } },
    -- Three more, and the same trap a third and fourth time.
    --
    -- "Windows SDK Desktop Headers x64" sounds like the um/shared headers.
    -- It ships FOUR FILES: WinHvEmulation.h, WinHvPlatform.h,
    -- WinHvPlatformDefs.h and a catalog. Not windows.h. Not winnt.h.
    -- The 528 um headers are in "for Windows Store Apps Headers", the shared
    -- ones (windef.h, sal.h, winerror.h, basetsd.h, guiddef.h) are in
    -- "for Windows Store Apps Headers OnecoreUap", and rc.exe / rcdll.dll /
    -- mt.exe -- the two programs this package advertises -- are in
    -- "for Windows Store Apps Tools". Nothing named "Desktop" carries any of
    -- them.
    --
    -- This is not guesswork: each MSI's File + Component + Directory tables
    -- were decoded offline and the install path of every file resolved, so
    -- the four lines below are what the SDK actually puts on disk. The
    -- previous comment here claimed "Desktop Headers x64 -> um / shared
    -- headers" and was simply wrong; installed() only found out because it
    -- started asserting winnt.h instead of a directory.
    --
    -- The Tools MSI costs 99 MB to deliver a 200 KB resource compiler -- it
    -- carries x86/x64/arm64 and AccChecker besides. Paid, rather than
    -- shipping a package whose `programs = {"rc", "mt"}` names two files
    -- that are not there.
    { name = "Windows SDK for Windows Store Apps Headers-x86_en-us.msi", msi = true,
      sha256 = "48C953AD16CE986F724EA53A9FA5FE796DD92D77E6C1BFE8CFE2105760401425",
      urls = { "https://gitcode.com/xlings-res/windows-sdk/releases/download/10.0.26100/Windows_SDK_for_Windows_Store_Apps_Headers-x86_en-us.msi",
               "https://download.visualstudio.microsoft.com/download/pr/e690ed5c-a2c2-42aa-8cbb-4f3ea5f87edf/e4c6d39d87f5c255483cbed9a719379c/windows%20sdk%20for%20windows%20store%20apps%20headers-x86_en-us.msi" } },
    { name = "766c0ffd568bbb31bf7fb6793383e24a.cab",
      sha256 = "41577D34CB8972821710878DC2FF8C82ED0F218E79640792F27D2658958C1B1A",
      urls = { "https://gitcode.com/xlings-res/windows-sdk/releases/download/10.0.26100/766c0ffd568bbb31bf7fb6793383e24a.cab.bin",
               "https://download.visualstudio.microsoft.com/download/pr/e690ed5c-a2c2-42aa-8cbb-4f3ea5f87edf/9b55a3f3e88b71fd20d425b1675038bd/766c0ffd568bbb31bf7fb6793383e24a.cab" } },
    { name = "8125ee239710f33ea485965f76fae646.cab",
      sha256 = "AA6532B67AF8D1A302E963F08F2D0F8FFF734E6B0DCD4DB5C872F10B27F5F835",
      urls = { "https://gitcode.com/xlings-res/windows-sdk/releases/download/10.0.26100/8125ee239710f33ea485965f76fae646.cab.bin",
               "https://download.visualstudio.microsoft.com/download/pr/e690ed5c-a2c2-42aa-8cbb-4f3ea5f87edf/f4e1d09d1a4d70a82444fa4f1aac5d7b/8125ee239710f33ea485965f76fae646.cab" } },
    { name = "c0aa6d435b0851bf34365aadabd0c20f.cab",
      sha256 = "4CCBAABD756FCB9735D60BA545079DEAE4FFDCA1B8584D7CF8A28A871448F8FC",
      urls = { "https://gitcode.com/xlings-res/windows-sdk/releases/download/10.0.26100/c0aa6d435b0851bf34365aadabd0c20f.cab.bin",
               "https://download.visualstudio.microsoft.com/download/pr/e690ed5c-a2c2-42aa-8cbb-4f3ea5f87edf/b1889625df897934cc0b7d30a5620efd/c0aa6d435b0851bf34365aadabd0c20f.cab" } },
    { name = "Windows SDK for Windows Store Apps Headers OnecoreUap-x86_en-us.msi", msi = true,
      sha256 = "92DC37ACAC3D795CFCF62DDC9E7A8D689087EA711C7046341617549C45E659B8",
      urls = { "https://gitcode.com/xlings-res/windows-sdk/releases/download/10.0.26100/Windows_SDK_for_Windows_Store_Apps_Headers_OnecoreUap-x86_en-us.msi",
               "https://download.visualstudio.microsoft.com/download/pr/e690ed5c-a2c2-42aa-8cbb-4f3ea5f87edf/1bb87b77719e9bf0c77536f8aa8831c3/windows%20sdk%20for%20windows%20store%20apps%20headers%20onecoreuap-x86_en-us.msi" } },
    { name = "e89e3dcbb016928c7e426238337d69eb.cab",
      sha256 = "7AF28E97E8EF2FDE14DB0ECCC1E41B4AB332B3CFD3D65DDFA0CD7930FF3F97AD",
      urls = { "https://gitcode.com/xlings-res/windows-sdk/releases/download/10.0.26100/e89e3dcbb016928c7e426238337d69eb.cab.bin",
               "https://download.visualstudio.microsoft.com/download/pr/e690ed5c-a2c2-42aa-8cbb-4f3ea5f87edf/aa45855a2db781eba5367a90d9702991/e89e3dcbb016928c7e426238337d69eb.cab" } },
    { name = "Windows SDK for Windows Store Apps Tools-x86_en-us.msi", msi = true,
      sha256 = "59A8197DB4B7651625C810BF0A7D59480BC18250558AA6D3C99A05F80466EC78",
      urls = { "https://gitcode.com/xlings-res/windows-sdk/releases/download/10.0.26100/Windows_SDK_for_Windows_Store_Apps_Tools-x86_en-us.msi",
               "https://download.visualstudio.microsoft.com/download/pr/e690ed5c-a2c2-42aa-8cbb-4f3ea5f87edf/59ce2e4e7d12186bfba85c54f4026546/windows%20sdk%20for%20windows%20store%20apps%20tools-x86_en-us.msi" } },
    { name = "2630bae9681db6a9f6722366f47d055c.cab",
      sha256 = "55C9439C5477C9A8887880CCC57A2BDB71B712257119AF760864C18343F7FAD2",
      urls = { "https://gitcode.com/xlings-res/windows-sdk/releases/download/10.0.26100/2630bae9681db6a9f6722366f47d055c.cab.bin",
               "https://download.visualstudio.microsoft.com/download/pr/e690ed5c-a2c2-42aa-8cbb-4f3ea5f87edf/0a19221dcbcb5f7bf4b45cbc2932743a/2630bae9681db6a9f6722366f47d055c.cab" } },
    { name = "26ea25236f12b23db661acf268a70cfa.cab",
      sha256 = "47839E22AF08420476C9C48F50CA6463E89B6A2B5628C08FA27CC42FB1284C7C",
      urls = { "https://gitcode.com/xlings-res/windows-sdk/releases/download/10.0.26100/26ea25236f12b23db661acf268a70cfa.cab.bin",
               "https://download.visualstudio.microsoft.com/download/pr/e690ed5c-a2c2-42aa-8cbb-4f3ea5f87edf/c8301ed19c227741201abd4dea4d863d/26ea25236f12b23db661acf268a70cfa.cab" } },
    { name = "2a30b5d1115d515c6ddd8cd6b5173835.cab",
      sha256 = "01FC9DB99B11F5F8D771B9B07780100589B5FA7CDD719BF2B02EA076763168E5",
      urls = { "https://gitcode.com/xlings-res/windows-sdk/releases/download/10.0.26100/2a30b5d1115d515c6ddd8cd6b5173835.cab.bin",
               "https://download.visualstudio.microsoft.com/download/pr/e690ed5c-a2c2-42aa-8cbb-4f3ea5f87edf/05ef8fa52330fd13b117d61243efa9c7/2a30b5d1115d515c6ddd8cd6b5173835.cab" } },
    { name = "4a4c678668584fc994ead5b99ccf7f03.cab",
      sha256 = "8197D07538168AECB8E7DC469CEFCADF21EC610BF95E97527D2E7491168A8E65",
      urls = { "https://gitcode.com/xlings-res/windows-sdk/releases/download/10.0.26100/4a4c678668584fc994ead5b99ccf7f03.cab.bin",
               "https://download.visualstudio.microsoft.com/download/pr/e690ed5c-a2c2-42aa-8cbb-4f3ea5f87edf/7c629cca1649e7491d7eeb2a2622ea22/4a4c678668584fc994ead5b99ccf7f03.cab" } },
    { name = "61d57a7a82309cd161a854a6f4619e52.cab",
      sha256 = "A19984F4A105F783A3A510445FD2DDA33B2130141CA7AD402320BCEEE8541B1F",
      urls = { "https://gitcode.com/xlings-res/windows-sdk/releases/download/10.0.26100/61d57a7a82309cd161a854a6f4619e52.cab.bin",
               "https://download.visualstudio.microsoft.com/download/pr/e690ed5c-a2c2-42aa-8cbb-4f3ea5f87edf/9045f92e92095a4496e5fc55175f94ac/61d57a7a82309cd161a854a6f4619e52.cab" } },
    { name = "68de71e3e2fb9941ee5b7c77500c0508.cab",
      sha256 = "45D7480B178D37F39A088AD89048DCEB55068603B8C759690734E3298894A891",
      urls = { "https://gitcode.com/xlings-res/windows-sdk/releases/download/10.0.26100/68de71e3e2fb9941ee5b7c77500c0508.cab.bin",
               "https://download.visualstudio.microsoft.com/download/pr/e690ed5c-a2c2-42aa-8cbb-4f3ea5f87edf/e587157990ed8c5831cea0925c8a5191/68de71e3e2fb9941ee5b7c77500c0508.cab" } },
    { name = "69661e20556b3ca9456b946c2c881ddd.cab",
      sha256 = "1C56E5B107BFC4E2D35FF8BAAAE44037105A1C63964682D93E3C32C0D708433E",
      urls = { "https://gitcode.com/xlings-res/windows-sdk/releases/download/10.0.26100/69661e20556b3ca9456b946c2c881ddd.cab.bin",
               "https://download.visualstudio.microsoft.com/download/pr/e690ed5c-a2c2-42aa-8cbb-4f3ea5f87edf/1cd90b8646ccd10a91fa16927c94cb41/69661e20556b3ca9456b946c2c881ddd.cab" } },
    { name = "b82881a61b7477bd4eb5de2cd5037fe2.cab",
      sha256 = "706674A05487A82F149AA5F215709F2BDEF9D54888C933FE0C17C4272D0876AD",
      urls = { "https://gitcode.com/xlings-res/windows-sdk/releases/download/10.0.26100/b82881a61b7477bd4eb5de2cd5037fe2.cab.bin",
               "https://download.visualstudio.microsoft.com/download/pr/e690ed5c-a2c2-42aa-8cbb-4f3ea5f87edf/528c78f5c6e2e4ac979d3e2b8b3aedaf/b82881a61b7477bd4eb5de2cd5037fe2.cab" } },
    { name = "dcfb1aa345e349091a44e86ce1766566.cab",
      sha256 = "CF5E2CFF8CF9AAF59BCA0D57914DE2817B2E9D67225BEB4B16A91512E4F98CA3",
      urls = { "https://gitcode.com/xlings-res/windows-sdk/releases/download/10.0.26100/dcfb1aa345e349091a44e86ce1766566.cab.bin",
               "https://download.visualstudio.microsoft.com/download/pr/e690ed5c-a2c2-42aa-8cbb-4f3ea5f87edf/48cd16cda6085509cd03f709c85682a3/dcfb1aa345e349091a44e86ce1766566.cab" } },
    { name = "e3d1b35aecfccda1b4af6fe5988ac4be.cab",
      sha256 = "2BD0E59DEA945A4C276D9E8A6C6945AD955C9C3BE858E62F0B466925BC627E70",
      urls = { "https://gitcode.com/xlings-res/windows-sdk/releases/download/10.0.26100/e3d1b35aecfccda1b4af6fe5988ac4be.cab.bin",
               "https://download.visualstudio.microsoft.com/download/pr/e690ed5c-a2c2-42aa-8cbb-4f3ea5f87edf/2fe14e34e0ee1923777fd543e5b57902/e3d1b35aecfccda1b4af6fe5988ac4be.cab" } },
}

-- The addresses a payload can be fetched from, in order of preference.
--
-- An entry carries `url` (one address) or `urls` (several). With one address
-- the behaviour is byte-for-byte what it was, so adding a mirror to an entry
-- cannot change how an unmirrored one installs.
--
-- A mirror is not a second trust root -- it is a second ADDRESS for the same
-- bytes, and `entry.sha256` is checked whichever one answered. Same shape as
-- msvc.lua, deliberately: these two recipes fetch the same KIND of thing from
-- the same CDN, and one of them having a fallback while the other does not is
-- how half a toolchain becomes unobtainable.
--
-- ⚠️ THE MIRROR'S ASSET NAMES DIFFER, AND THAT IS FINE. gitcode rejects the
-- `.cab` extension outright and rejects spaces in an asset name, so the
-- mirrored assets are `<name with _ for spaces>` and `<name>.cab.bin`. The
-- file this recipe WRITES is always `entry.name` -- a URL is an address, not
-- an identity, and the sha256 is over content. Both were established by
-- probing the API (a `.bin` upload of identical bytes succeeded where the
-- `.cab` had failed), not assumed.
--
-- The mirrored bytes were verified by DOWNLOADING all 27 payloads back and
-- hashing them, because the upload tool reported failures for files that the
-- release listing then showed as present -- neither the exit code nor the
-- listing was the claim worth trusting.
local function sources(entry)
    if entry.urls and #entry.urls > 0 then return entry.urls end
    return { entry.url }
end

-- certutil, not PowerShell's Get-FileHash: both ship with Windows, but
-- Get-FileHash needs a quoted -LiteralPath nested inside a quoted -Command
-- inside a shell string, and these file names contain spaces. certutil takes
-- one quoted path and prints the digest on a line of its own.
--
-- Case is not compared: certutil prints uppercase, and the manifests are not
-- consistent either (the VC payloads carry lowercase digests while the SDK's
-- are uppercase). Comparing the bytes, not their spelling.
local function sha256_of(file)
    local out = os.iorun(string.format('certutil -hashfile "%s" SHA256', file)) or ""
    for line in out:gmatch("[^\r\n]+") do
        local hex = line:gsub("%s+", ""):lower()
        if #hex == 64 and hex:match("^%x+$") then return hex end
    end
    return nil
end

local function host_of(url)
    return (url:match("^%w+://([^/]+)")) or url
end

-- Download one payload and prove it is the file we asked for.
--
-- The check is the point, not the download: these bytes become a compiler's
-- headers, and "curl exited 0" says nothing about what arrived. Every address
-- is verified against the SAME sha256, and a mismatch drops the file and
-- moves on rather than letting a bad payload through.
local function fetch_verified(entry, dir)
    local dst  = path.join(dir, entry.name)
    local want = entry.sha256:lower()

    -- An already-present file still has to prove itself: a partial download
    -- from an interrupted run is also "a file that exists".
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
            log.warn("windows-sdk: " .. entry.name .. " -- falling back to " ..
                     host_of(url) .. " after: " .. table.concat(why, "; "))
        else
            log.info("windows-sdk: fetching " .. entry.name .. " from " .. host_of(url))
        end
        -- pcall: curl -f exits non-zero on a 404, and system.exec RAISES on a
        -- non-zero exit. Without this the first missing mirror would abort the
        -- install instead of falling through to the next address.
        pcall(system.exec, string.format(
            'curl -fsSL --retry 3 -o "%s" "%s"', dst, url))
        if os.isfile(dst) then
            local got = sha256_of(dst)
            if got == want then return true end
            table.insert(why, host_of(url) .. ": sha256 " .. tostring(got))
            os.tryrm(dst)
        else
            table.insert(why, host_of(url) .. ": no file")
        end
    end

    log.error("windows-sdk: could not obtain " .. entry.name ..
              "\n  expected sha256 " .. entry.sha256 ..
              "\n  tried:\n    " .. table.concat(why, "\n    "))
    return false
end

-- Walk down looking for the SDK root, bounded.
--
-- os.files is not in the xpkg sandbox (os.dirs is), so this recurses over
-- directories instead of globbing for the anchor file. Depth 4 covers every
-- prefix msiexec has been seen to produce ("Windows Kits/10", optionally under
-- a Program Files one); anything deeper would be a different installer.
local function find_sdk_root(base, depth)
    if os.isfile(path.join(base, "Include", SDK_DIR_VERSION, "ucrt", "corecrt.h")) then
        return base
    end
    if depth <= 0 then return nil end
    for _, d in ipairs(os.dirs(path.join(base, "*")) or {}) do
        local found = find_sdk_root(d, depth - 1)
        if found then return found end
    end
    return nil
end

-- One file per MSI that matters, chosen so a missing payload cannot pass.
--
-- Not a sample -- a cover. Each line below is the file that only ONE of the
-- eight payloads provides, so whichever one failed to download, extract or
-- merge, exactly this list names it. The last two are the `programs` this
-- package registers with xvm: a package that advertises rc and mt and then
-- ships neither is worse than one that admits it has no tools.
local function required_files()
    local d = pkginfo.install_dir()
    return {
        path.join(d, "Include", SDK_DIR_VERSION, "ucrt", "corecrt.h"),    -- UCRT
        path.join(d, "Include", SDK_DIR_VERSION, "um", "winnt.h"),        -- StoreApps Headers
        path.join(d, "Include", SDK_DIR_VERSION, "shared", "windef.h"),   -- ... OnecoreUap
        path.join(d, "Lib", SDK_DIR_VERSION, "um", "x64", "kernel32.lib"),-- StoreApps Libs
        path.join(d, "Lib", SDK_DIR_VERSION, "um", "x64", "gdi32.lib"),   -- Desktop Libs x64
        path.join(d, "bin", SDK_DIR_VERSION, "x64", "rc.exe"),            -- StoreApps Tools
        path.join(d, "bin", SDK_DIR_VERSION, "x64", "mt.exe"),            -- ... same
    }
end

function installed()
    -- Assert the FILES a link actually opens, not the directories they sit in.
    --
    -- This used to check `Lib/<ver>/um/x64` as a DIRECTORY, reasoning that the
    -- SDK spells its own names inconsistently --
    --
    --   AclUI.Lib  ActiveDS.Lib  advpack.Lib  ahadmin.lib  amsi.lib ...
    --
    -- -- so naming `kernel32.lib` was "a guess about casing". That reasoning
    -- is wrong: Windows filesystems are CASE-INSENSITIVE, so os.isfile on
    -- `kernel32.lib` matches `Kernel32.Lib` on disk. There was no hazard to
    -- avoid.
    --
    -- And the weakening is precisely what let a broken SDK ship. The subset
    -- was missing the MSI that CONTAINS kernel32.lib, the directory existed
    -- anyway (341 other um libs landed in it), `installed()` said yes,
    -- windows-test went green, and every link of every program failed with
    --
    --     LINK : fatal error LNK1104: cannot open file 'kernel32.lib'
    --
    -- One name per MSI, chosen so that MSI's absence cannot hide:
    --   corecrt.h    Universal CRT headers
    --   kernel32.lib Store Apps Libs   -- the core Win32 import libraries
    --   winnt.h      Desktop Headers x64
    --   rc.exe       Desktop Tools x64
    for _, f in ipairs(required_files()) do
        if not os.isfile(f) then return false end
    end
    return true
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
            -- idir straight in: pkginfo.install_dir() is already absolute,
            -- and path.absolute is not in the xpkg sandbox. /qn only -- it is
            -- the same switch as /quiet, and msiexec takes one of them.
            system.exec(string.format('msiexec /a "%s" /qn TARGETDIR="%s"',
                                     winpath(path.join(work, e.name)), winpath(idir)))
        end
    end

    -- Hoist the SDK root up to the package root, so that the payload dir IS
    -- WindowsSdkDir -- the shape every consumer expects.
    --
    -- FOUND, not assumed. msiexec /a reproduces the MSI's own directory table,
    -- and where that puts things ("Windows Kits/10/...", possibly under a
    -- "Program Files" prefix) is a property of the installer, not something to
    -- hardcode. Anchor on the one file that must exist and derive the root
    -- from it: <root>/Include/<ver>/ucrt/corecrt.h is four levels up.
    -- Merge with xcopy, not in Lua.
    --
    -- The four MSIs do not agree on a prefix: some lay their files straight
    -- into TARGETDIR and some under "Windows Kits/10", so the two trees have
    -- to be united. Doing it here is not an option -- os.trymv onto an
    -- existing directory fails (silently, being a "try"), and os.cp of a
    -- directory INTO an existing one of the same name nests it, which is how
    -- a previous run ended up with Include/<ver>/<ver>/. A recursive merge in
    -- Lua would need to walk files, and os.files is not in the sandbox.
    --
    -- xcopy does exactly this, ships with Windows, and unlike robocopy it
    -- returns 0 on success rather than a bitmask that reads as failure.
    local root = find_sdk_root(idir, 4)
    if root and root ~= idir then
        log.info("windows-sdk: merging SDK root from " .. root)
        system.exec(string.format('xcopy "%s\\*" "%s\\" /E /I /Y /Q',
                                  winpath(root), winpath(idir)))
        os.tryrm(path.join(idir, "Windows Kits"))
    end

    os.tryrm(work)

    if not installed() then
        -- Say WHAT is there. "not installed" after a clean extraction means the
        -- layout moved, and the next person needs the tree, not the verdict.
        local missing = {}
        for _, f in ipairs(required_files()) do
            if not os.isfile(f) then table.insert(missing, f) end
        end
        log.error("windows-sdk: extraction finished but the SDK tree is not where it should be." ..
                  "\n  missing:\n    " .. table.concat(missing, "\n    "))
        -- Two levels, not one. The top level looked correct for three runs
        -- running while the anchor files were not there, so the level that
        -- matters is the one below it: which version directories exist under
        -- Include/ and Lib/, and what is inside them.
        local function dump(base, prefix, depth)
            for _, d in ipairs(os.dirs(path.join(base, "*")) or {}) do
                log.error(prefix .. path.filename(d) .. "/")
                if depth > 0 then dump(d, prefix .. "  ", depth - 1) end
            end
        end
        -- File level. os.dirs only lists directories, and three rounds of
        -- correct-looking directory trees is enough to establish that the
        -- missing thing is a file, not a folder.
        local function probe(rel)
            local full = winpath(path.join(idir, rel))
            local out = os.iorun(string.format('cmd /c dir /b "%s" 2>&1', full)) or ""
            log.error("  dir " .. rel .. " -> " .. out:gsub("[\r\n]+", " "):sub(1, 300))
        end
        probe(path.join("Include", SDK_DIR_VERSION, "ucrt"))
        probe(path.join("Lib", SDK_DIR_VERSION, "um"))
        probe(path.join("Lib", SDK_DIR_VERSION, "um", "x64"))
        probe(path.join("bin", SDK_DIR_VERSION, "x64"))

        log.error("  present under " .. idir .. ":")
        dump(idir, "    ", 0)
        for _, sub in ipairs({"Include", "Lib", "bin"}) do
            if os.isdir(path.join(idir, sub)) then
                log.error("  " .. sub .. "/:")
                dump(path.join(idir, sub), "    ", 1)
            end
        end
        return false
    end
    return true
end

function config()
    local idir = pkginfo.install_dir()
    xvm.add("rc", { bindir = path.join(idir, "bin", SDK_DIR_VERSION, "x64") })
    xvm.add("mt", { bindir = path.join(idir, "bin", SDK_DIR_VERSION, "x64") })

    -- WindowsSdkDir / WindowsSdkVersion go in the SUBOS, for the same reason
    -- msvc.lua puts VSINSTALLDIR there: the processes that read them are
    -- BUILD SYSTEMS -- mcpp, cmake, xmake, meson -- and xlings never wraps
    -- those, so a per-shim env cannot reach them.
    --
    -- These two names are not an xlings invention: they are what vcvars
    -- exports and what every one of those build systems already looks for. So
    -- the package describes where it put itself in the vocabulary that
    -- already exists, instead of each consumer learning an xlings-specific
    -- path -- which is also why mcpp needed no version of this package
    -- hardcoded anywhere to find it.
    --
    -- The trailing separator on WindowsSdkVersion is vcvars' own convention
    -- ("10.0.26100.0\"). Reproduced rather than tidied up: consumers strip it
    -- because vcvars puts it there, and a value that differs from vcvars' is
    -- a value they have never been tested against.
    if type(subos.env) == "function" then
        local tag = package.name .. "@" .. pkginfo.version()
        subos.env{ var = "WindowsSdkDir", op = "set",
                   value = "${pkgdir}", binding = tag }
        subos.env{ var = "WindowsSdkVersion", op = "set",
                   value = SDK_DIR_VERSION .. "\\", binding = tag }
    end
    return true
end

function uninstall()
    xvm.remove("rc")
    xvm.remove("mt")
    return true
end
