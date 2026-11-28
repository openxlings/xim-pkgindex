-- q - Tiny command-line DNS client with support for UDP, TCP, DoT, DoH, DoQ and ODoH.
--
-- Verified against natesales/q release v0.19.12 (SHA-256 verified against
-- upstream `q_0.19.12_checksums.txt`):
--   linux/x86_64     q_0.19.12_linux_amd64.tar.gz    (static Go ELF, no .dynamic section)
--   linux/aarch64    q_0.19.12_linux_arm64.tar.gz    (static Go ELF, no .dynamic section)
--   macosx/x86_64    q_0.19.12_darwin_amd64.tar.gz
--   macosx/aarch64   q_0.19.12_darwin_arm64.tar.gz
--   windows/x86_64   q_0.19.12_windows_amd64.zip     (PE32+ console, imports kernel32.dll only)
--   windows/aarch64  q_0.19.12_windows_arm64.zip     (PE32+ console ARM64)
--
-- Upstream also publishes FreeBSD, .deb, and .rpm artifacts, which are outside
-- xlings' supported platform/archive matrix.
-- Every upstream archive is flat at root (`q` / `q.exe`, `LICENSE`, `README.md`).

package = {
    spec = "2",

    name = "q",
    description = "Tiny command-line DNS client with support for UDP, TCP, DoT, DoH, DoQ and ODoH",
    homepage = "https://github.com/natesales/q",
    authors = {"Nate Sales"},
    maintainers = {"natesales"},
    licenses = {"GPL-3.0"},
    repo = "https://github.com/natesales/q",
    docs = "https://github.com/natesales/q#readme",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"dns", "network", "cli", "tools"},
    keywords = {"q", "dns", "dig", "doh", "dot", "doq", "odoh", "cli", "go"},

    programs = {"q"},
    xvm_enable = true,
    ci = { mirror = true },

    -- Verified upstream release assets; no CN mirror has been verified.
    extensions = {
        autoupdate = {
            source = "https://github.com/natesales/q/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/natesales/q/releases/download/${tag}/q_${version}_linux_amd64.tar.gz",
                            aarch64 = "https://github.com/natesales/q/releases/download/${tag}/q_${version}_linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/natesales/q/releases/download/${tag}/q_${version}_darwin_amd64.tar.gz",
                            aarch64 = "https://github.com/natesales/q/releases/download/${tag}/q_${version}_darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/natesales/q/releases/download/${tag}/q_${version}_windows_amd64.zip",
                            aarch64 = "https://github.com/natesales/q/releases/download/${tag}/q_${version}_windows_arm64.zip",
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
            source = "https://github.com/natesales/q/releases/download/v${version}/q_${version}_linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.19.12" },
            ["0.19.12"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "4adfaa55594a68d8aec60348aaa6345d5232701a1c05ac144ad3fd12dc291f7a",
                    aarch64 = "ac7de2a6aef215789eb077d55c3ada001e2a0c4f858fc8492e95820d8f499ef5",
                },
            },
        },
        macosx = {
            source = "https://github.com/natesales/q/releases/download/v${version}/q_${version}_darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.19.12" },
            ["0.19.12"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "ddab1798213840510556558d5f7e66fe66dd2b239bc7cd4c3d5fc5b916b6ec15",
                    aarch64 = "4ac106c317d96199c9b684b1093d7ed0e5bc4e008081cd86d3f017826b437faa",
                },
            },
        },
        windows = {
            source = "https://github.com/natesales/q/releases/download/v${version}/q_${version}_windows_${arch_alias}.zip",
            ["latest"] = { ref = "0.19.12" },
            ["0.19.12"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "35238a11b4b2623064dbb7e61207a53e1b55619f3249f2e9b3acd26f8de18d14",
                    aarch64 = "25479b18dbcb3897551d712d5a993707be982d6cb14932ca4e2abf801548f19e",
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
    return payload.present({ "q", "LICENSE" })
        or payload.present({ "q.exe", "LICENSE" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("q: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("%.zip$") ~= nil
    local exe = is_win and "q.exe" or "q"

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
            error("q: neither archive (" .. archive .. ") nor extracted binary exists")
        end
    else
        if os.isfile(archive) then
            system.exec(string.format([[tar -xzf "%s" -C "%s"]], normalized, dir))
        elseif os.isfile(parent .. "/" .. exe) then
            move_preextracted(parent, dir, exe)
        else
            error("q: neither archive (" .. archive .. ") nor extracted binary exists")
        end
        if os.isfile(dir .. "/" .. exe) then
            system.exec(string.format([[chmod +x "%s"]], dir .. "/" .. exe))
        end
    end

    payload.require({ exe, "LICENSE" })
    return true
end

function config()
    xvm.add("q", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("q")
    return true
end
