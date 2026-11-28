-- doggo - Command-line DNS client for humans.
--
-- Verified against mr-karan/doggo release v1.4.2 (SHA-256 verified against
-- upstream `doggo_1.4.2_checksums.txt`):
--   linux/x86_64    doggo-linux-x86_64.tar.gz   (static Go ELF, no .dynamic section)
--   linux/aarch64   doggo-linux-aarch64.tar.gz  (static Go ELF, no .dynamic section)
--   macosx/x86_64   doggo-darwin-x86_64.tar.gz
--   macosx/aarch64  doggo-darwin-aarch64.tar.gz
--   windows/x86_64  doggo-windows-x86_64.zip    (PE32+ console, imports kernel32.dll only)
--
-- Upstream also publishes windows-i386, BSD, and 32-bit ARM builds, which are
-- outside `archs`, and publishes no Windows ARM64 archive.
-- Every upstream archive is flat at root (`doggo` / `doggo.exe`, `LICENSE`, `README.md`).

package = {
    spec = "2",

    name = "doggo",
    description = "Command-line DNS client for humans",
    homepage = "https://doggo.mrkaran.dev/",
    authors = {"Karan Sharma"},
    maintainers = {"mr-karan"},
    licenses = {"GPL-3.0"},
    repo = "https://github.com/mr-karan/doggo",
    docs = "https://doggo.mrkaran.dev/docs/",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"dns", "network", "cli", "tools"},
    keywords = {"doggo", "dns", "dig", "doh", "dot", "cli", "go"},

    programs = {"doggo"},
    xvm_enable = true,
    ci = { mirror = true },

    -- Verified upstream release assets; no CN mirror has been verified.
    extensions = {
        autoupdate = {
            source = "https://github.com/mr-karan/doggo/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/mr-karan/doggo/releases/download/${tag}/doggo-linux-x86_64.tar.gz",
                            aarch64 = "https://github.com/mr-karan/doggo/releases/download/${tag}/doggo-linux-aarch64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/mr-karan/doggo/releases/download/${tag}/doggo-darwin-x86_64.tar.gz",
                            aarch64 = "https://github.com/mr-karan/doggo/releases/download/${tag}/doggo-darwin-aarch64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/mr-karan/doggo/releases/download/${tag}/doggo-windows-x86_64.zip",
                        },
                    },
                },
            },
        },
    },

    -- Upstream builds static Go binaries; Linux ELFs have no dynamic section and
    -- Windows PE imports only kernel32.dll, so no runtime deps are needed.
    xpm = {
        linux = {
            source = "https://github.com/mr-karan/doggo/releases/download/v${version}/doggo-linux-${arch}.tar.gz",
            ["latest"] = { ref = "1.4.2" },
            ["1.4.2"] = {
                sha256 = {
                    x86_64 = "634d88c92e1e98a8e5f6bc9758ca39a797f4237e4c542156e48c441be702742c",
                    aarch64 = "87f876e7c7f78282b4ceb5cfef119a82f9bfa54ef7e6ab916e5a6edb5f1cb878",
                },
            },
        },
        macosx = {
            source = "https://github.com/mr-karan/doggo/releases/download/v${version}/doggo-darwin-${arch}.tar.gz",
            ["latest"] = { ref = "1.4.2" },
            ["1.4.2"] = {
                sha256 = {
                    x86_64 = "0e83bfb39d1a8ace355b6f2e49544d19bfd17f738be5f0fe929889df3604ecec",
                    aarch64 = "31c1c765a61fad93f8b616bcafca69f4a9c701ad7911850865760c82bffa6532",
                },
            },
        },
        windows = {
            source = "https://github.com/mr-karan/doggo/releases/download/v${version}/doggo-windows-${arch}.zip",
            ["latest"] = { ref = "1.4.2" },
            ["1.4.2"] = {
                sha256 = {
                    x86_64 = "d3dcf3e3ff233acca443027f4cf072be6b331f0301f0ac3674d4de8802438791",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

local function move_preextracted(parent, dir, exe)
    for _, f in ipairs({ exe, "LICENSE", "README.md" }) do
        if os.isfile(parent .. "/" .. f) then
            os.mv(parent .. "/" .. f, dir .. "/" .. f)
        end
    end
end

function installed()
    return payload.present({ "doggo", "LICENSE" })
        or payload.present({ "doggo.exe", "LICENSE" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("doggo: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("%.zip$") ~= nil
    local exe = is_win and "doggo.exe" or "doggo"

    os.tryrm(dir)
    fs.mkdir_p(dir)

    -- Upstream archives are flat (no top-level wrapper directory). Extract
    -- directly from the archive into install_dir so files from unrelated flat
    -- packages in the shared download directory cannot leak into this payload.
    if is_win then
        if os.isfile(archive) then
            payload.unpack{}
        elseif os.isfile(parent .. "/" .. exe) then
            move_preextracted(parent, dir, exe)
        else
            error("doggo: neither archive (" .. archive .. ") nor extracted binary exists")
        end
    else
        if os.isfile(archive) then
            system.exec(string.format([[tar -xzf "%s" -C "%s"]], normalized, dir))
        elseif os.isfile(parent .. "/" .. exe) then
            move_preextracted(parent, dir, exe)
        else
            error("doggo: neither archive (" .. archive .. ") nor extracted binary exists")
        end
        if os.isfile(dir .. "/" .. exe) then
            system.exec(string.format([[chmod +x "%s"]], dir .. "/" .. exe))
        end
    end

    payload.require({ exe, "LICENSE" })
    return true
end

function config()
    xvm.add("doggo", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("doggo")
    return true
end
