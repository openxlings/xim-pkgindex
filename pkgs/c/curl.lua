-- curl, packaged for Windows.
--
-- Windows only, and that is the whole point: on Linux and macOS curl is part
-- of the base system and packaging it would buy nothing. On Windows it also
-- ships with the OS (System32\curl.exe, since Windows 10 1803) -- but a
-- recipe that FETCHES things is a different consumer from a user typing curl.
-- windows-sdk and msvc download a pinned set of payloads and verify every
-- sha256; leaving the downloader itself to whatever the host happens to have
-- is the one host dependency left in an otherwise closed chain.
--
-- Upstream binaries from curl.se's own Windows page (the curl-for-win build
-- the project links from https://curl.se/windows/). The `_7` in the archive
-- name is that build's revision, not curl's -- the package version is curl's.
package = {
    spec = "1",

    name = "curl",
    description = "Command-line tool and library for transferring data with URLs",
    homepage = "https://curl.se/",
    maintainers = {"curl"},
    licenses = {"curl"},
    repo = "https://github.com/curl/curl",
    docs = "https://curl.se/docs/",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"cli", "network", "tools"},
    keywords = {"curl", "http", "download", "transfer", "network"},

    programs = {"curl"},
    xvm_enable = true,

    xpm = {
        windows = {
            ["latest"] = { ref = "8.21.0" },
            ["8.21.0"] = {
                url = "https://curl.se/windows/dl-8.21.0_7/curl-8.21.0_7-win64-mingw.zip",
                sha256 = "e469dcdb219d0eca9236b01c7e4bb34fe04af3d4036d350829178dc60f241ae4",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

-- The archive's single top-level directory, which is NOT the package version:
-- curl 8.21.0 ships as curl-8.21.0_7-win64-mingw. Spelled out rather than
-- derived, because the two are different facts that only look alike.
local ARCHIVE_DIR = "curl-8.21.0_7-win64-mingw"

function installed()
    return os.isfile(path.join(pkginfo.install_dir(), "bin", "curl.exe"))
end

function install()
    local idir = pkginfo.install_dir()
    os.tryrm(idir)

    -- The framework extracts the zip next to the download; its top-level
    -- directory becomes the package root.
    local extracted = path.join(path.directory(pkginfo.install_file()), ARCHIVE_DIR)
    if not os.isdir(extracted) then
        -- Older layouts extract in place; fall back to the sibling named after
        -- the archive itself before giving up.
        extracted = pkginfo.install_file():replace(".zip", "")
    end
    if not os.isdir(extracted) then
        log.error("curl: cannot find the extracted archive (expected " .. ARCHIVE_DIR .. ")")
        return false
    end
    os.mv(extracted, idir)

    if not installed() then
        log.error("curl: unpacked, but bin/curl.exe is not there")
        return false
    end
    return true
end

function config()
    -- bin/, not the package root: libcurl-x64.dll and curl-ca-bundle.crt live
    -- beside the executable and are found relative to it.
    xvm.add("curl", { bindir = path.join(pkginfo.install_dir(), "bin") })
    return true
end

function uninstall()
    xvm.remove("curl")
    return true
end
