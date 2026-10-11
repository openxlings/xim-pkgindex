-- curl, packaged for Windows and Linux.
--
-- Linux: a static build (OpenSSL, nghttp2, zlib; socks5h) made by this index
-- on each architecture (tools/res/build.sh curl). xlings asks a proxy's exit
-- where it is through it (identity tz = proxy), and what xlings runs comes
-- from the index, not from whatever the machine happens to have.
--
-- Windows: it also
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
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "network", "tools"},
    keywords = {"curl", "http", "download", "transfer", "network"},

    programs = {"curl"},
    xvm_enable = true,

    -- Platform version sets differ on purpose: Linux is this index's own
    -- static build, Windows curl.se's.
    platform_versions_diverge = true,

    xpm = {
        linux = {
            ["latest"] = { ref = "8.22.0" },
            ["8.22.0"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "5424e929cf8719bc3a15e186244452b0570f5d278d5d9dd1091137dc94007cee",
                    aarch64 = "94f4dcc5e302b7a887be563754a99c8bac362c194fb77d4c1ae61921d3d2eb6c",
                },
            },
        },
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

local function exe()
    return path.join(pkginfo.install_dir(), "bin", is_host("windows") and "curl.exe" or "curl")
end

function installed()
    return os.isfile(exe())
end

function install()
    local idir = pkginfo.install_dir()
    os.tryrm(idir)

    -- Windows: the framework extracts the zip next to the download; its
    -- top-level directory becomes the package root. Linux: the tarball's
    -- curl-<version>-linux-<arch>/.
    local extracted = is_host("windows")
        and path.join(path.directory(pkginfo.install_file()), ARCHIVE_DIR)
        or pkginfo.install_file():replace(".tar.gz", "")
    if not os.isdir(extracted) then
        -- Older layouts extract in place; fall back to the sibling named after
        -- the archive itself before giving up.
        extracted = pkginfo.install_file():replace(".zip", "")
    end
    if not os.isdir(extracted) then
        log.error("curl: cannot find the extracted archive")
        return false
    end
    os.mv(extracted, idir)

    if not installed() then
        log.error("curl: unpacked, but " .. exe() .. " is not there")
        return false
    end
    return true
end

function config()
    -- bin/, not the package root: on Windows libcurl-x64.dll and
    -- curl-ca-bundle.crt live beside the executable and are found relative
    -- to it.
    local config = { bindir = path.join(pkginfo.install_dir(), "bin") }
    if not is_host("windows") and not os.isfile("/etc/ssl/certs/ca-certificates.crt") then
        -- The static build looks where Debian, Ubuntu, Arch and Alpine keep
        -- the machine's CA bundle; elsewhere it is told (as git.lua does).
        for _, f in ipairs({"/etc/pki/tls/certs/ca-bundle.crt", "/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem",
                            "/etc/ssl/ca-bundle.pem", "/etc/ssl/cert.pem"}) do
            if os.isfile(f) then
                config.envs = { CURL_CA_BUNDLE = f }
                break
            end
        end
    end
    xvm.add("curl", config)
    return true
end

function uninstall()
    xvm.remove("curl")
    return true
end
