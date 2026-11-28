-- yt-dlp - A feature-rich command-line audio/video downloader (yt-dlp/yt-dlp).
--
-- Platform and architecture coverage (verified against yt-dlp/yt-dlp 2026.11.23):
--   linux    x86_64, aarch64   yt-dlp_linux, yt-dlp_linux_aarch64
--                              (dynamic ELF; DT_NEEDED: libdl.so.2, libz.so.1, libpthread.so.0, libc.so.6;
--                               declares xim:glibc@>=2.39 and xim:zlib runtime deps)
--   macosx   x86_64, aarch64   yt-dlp_macos.zip (universal archive containing yt-dlp_macos + _internal/)
--   windows  x86_64, aarch64   yt-dlp.exe, yt-dlp_arm64.exe (PE32+ console executables)

package = {
    spec = "2",

    name = "yt-dlp",
    description = "A feature-rich command-line audio/video downloader",
    homepage = "https://github.com/yt-dlp/yt-dlp",
    authors = {"yt-dlp contributors"},
    maintainers = {"https://github.com/yt-dlp/yt-dlp/graphs/contributors"},
    licenses = {"Unlicense"},
    repo = "https://github.com/yt-dlp/yt-dlp",
    docs = "https://github.com/yt-dlp/yt-dlp#readme",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"media", "video", "audio", "cli", "tools"},
    keywords = {"yt-dlp", "youtube-dl", "video", "audio", "downloader", "media"},

    programs = {"yt-dlp"},
    xvm_enable = true,

    -- Verified upstream release assets; no CN mirror has been verified.
    extensions = {
        autoupdate = {
            source = "https://github.com/yt-dlp/yt-dlp/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/yt-dlp/yt-dlp/releases/download/${tag}/yt-dlp_linux",
                            aarch64 = "https://github.com/yt-dlp/yt-dlp/releases/download/${tag}/yt-dlp_linux_aarch64",
                        },
                        macosx = {
                            x86_64 = "https://github.com/yt-dlp/yt-dlp/releases/download/${tag}/yt-dlp_macos.zip",
                            aarch64 = "https://github.com/yt-dlp/yt-dlp/releases/download/${tag}/yt-dlp_macos.zip",
                        },
                        windows = {
                            x86_64 = "https://github.com/yt-dlp/yt-dlp/releases/download/${tag}/yt-dlp.exe",
                            aarch64 = "https://github.com/yt-dlp/yt-dlp/releases/download/${tag}/yt-dlp_arm64.exe",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            deps = {
                runtime = { "xim:glibc@>=2.39", "xim:zlib" },
            },
            ["latest"] = { ref = "2026.11.23" },
            ["2026.11.23"] = {
                url = {
                    x86_64 = "https://github.com/yt-dlp/yt-dlp/releases/download/2026.11.23/yt-dlp_linux",
                    aarch64 = "https://github.com/yt-dlp/yt-dlp/releases/download/2026.11.23/yt-dlp_linux_aarch64",
                },
                sha256 = {
                    x86_64 = "249ddb058234276bc449b9cd9492aad9f133bda5923c61a9e39983ae114ef17d",
                    aarch64 = "fb847a2e4a9ddc8cf5fcfb4bb7f42ba8969ecf72068def0278074f9d300bd13c",
                },
            },
        },
        macosx = {
            source = "https://github.com/yt-dlp/yt-dlp/releases/download/${version}/yt-dlp_macos.zip",
            ["latest"] = { ref = "2026.11.23" },
            ["2026.11.23"] = {
                sha256 = {
                    x86_64 = "43fc87fc581f64b48c366ce20b9cacb9c2949cc1ac4b9eca56fe25ac52dbb63b",
                    aarch64 = "43fc87fc581f64b48c366ce20b9cacb9c2949cc1ac4b9eca56fe25ac52dbb63b",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "2026.11.23" },
            ["2026.11.23"] = {
                url = {
                    x86_64 = "https://github.com/yt-dlp/yt-dlp/releases/download/2026.11.23/yt-dlp.exe",
                    aarch64 = "https://github.com/yt-dlp/yt-dlp/releases/download/2026.11.23/yt-dlp_arm64.exe",
                },
                sha256 = {
                    x86_64 = "622ed48023cac1daa52a3bf3a6ac38f03514de214b5f0fa069389fd0f6d17e5c",
                    aarch64 = "9bb324203d02970b70dab6c9f6a48bd5ff185db7859d562cdacd1dc655ccb72a",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

local function _is_windows_payload(file)
    return tostring(file):lower():match("%.exe$") ~= nil
end

function installed()
    local dir = pkginfo.install_dir()
    return os.isfile(dir .. "/yt-dlp") or os.isfile(dir .. "/yt-dlp.exe")
end

function install()
    local src = pkginfo.install_file()
    local dir = pkginfo.install_dir()
    local is_win = _is_windows_payload(src)

    os.tryrm(dir)
    fs.mkdir_p(dir)

    if tostring(src):lower():match("%.zip$") then
        system.exec(string.format([[unzip -q -o "%s" -d "%s"]], src, dir))
        local mac_bin = dir .. "/yt-dlp_macos"
        local target = dir .. "/yt-dlp"
        if os.isfile(mac_bin) then
            os.mv(mac_bin, target)
        end
        system.exec(string.format([[chmod +x "%s"]], target))
        if not os.isfile(target) then
            error("yt-dlp: executable missing after install at " .. target)
        end
        return true
    end

    local target = dir .. (is_win and "/yt-dlp.exe" or "/yt-dlp")
    os.mv(src, target)
    if not is_win then
        system.exec(string.format([[chmod +x "%s"]], target))
    end
    if not os.isfile(target) then
        error("yt-dlp: executable missing after install at " .. target)
    end
    return true
end

function config()
    xvm.add("yt-dlp", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("yt-dlp")
    return true
end
