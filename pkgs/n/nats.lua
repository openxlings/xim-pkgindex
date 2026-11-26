-- NATS CLI - Command-line interface for NATS.io and JetStream.
--
-- Verified 2026-11-26 against upstream GitHub release v0.5.2 (nats-io/natscli):
-- every SHA256 below was verified against both upstream `SHA256SUMS` and the
-- downloaded archives. All six archives pack a single top-level directory
-- matching the archive stem (`nats-0.5.2-<os>-<arch>/`) containing
-- `nats` (or `nats.exe`), `LICENSE`, and `README.md`.
--
-- Linux ELF inspection (v0.5.2, readelf -d / ldd):
--   x86_64:  statically linked Go ELF64 executable, no .dynamic section
--   aarch64: statically linked Go ELF64 executable, no .dynamic section
-- Windows PE inspection (v0.5.2, PE32+ import table):
--   x86_64 (0x8664) & aarch64 (0xaa64): imports only `kernel32.dll`
--   (no VCRUNTIME140.dll / MSVCP140.dll, so no `xim:vcruntime` dep).
package = {
    spec = "2",

    name = "nats",
    description = "The NATS Command Line Interface",
    homepage = "https://nats.io",
    authors = {"The NATS Authors"},
    maintainers = {"https://github.com/nats-io/natscli/graphs/contributors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/nats-io/natscli",
    docs = "https://docs.nats.io/using-nats/nats-tools/nats_cli",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"messaging", "cli", "network", "tools"},
    keywords = {"nats", "natscli", "messaging", "pubsub", "jetstream", "cli"},

    programs = {"nats"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/nats-io/natscli/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/nats-io/natscli/releases/download/${tag}/nats-${version}-linux-amd64.zip",
                            aarch64 = "https://github.com/nats-io/natscli/releases/download/${tag}/nats-${version}-linux-arm64.zip",
                        },
                        macosx = {
                            x86_64 = "https://github.com/nats-io/natscli/releases/download/${tag}/nats-${version}-darwin-amd64.zip",
                            aarch64 = "https://github.com/nats-io/natscli/releases/download/${tag}/nats-${version}-darwin-arm64.zip",
                        },
                        windows = {
                            x86_64 = "https://github.com/nats-io/natscli/releases/download/${tag}/nats-${version}-windows-amd64.zip",
                            aarch64 = "https://github.com/nats-io/natscli/releases/download/${tag}/nats-${version}-windows-arm64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/nats-io/natscli/releases/download/v${version}/nats-${version}-linux-${arch_alias}.zip",
            ["latest"] = { ref = "0.5.2" },
            ["0.5.2"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "9dddf92072bba154c11a08165718fb6ee42af1f25ce4f1bb284d2fc141abcff2",
                    aarch64 = "7ecb342d66e67eb236d634cd8e9741ab69c53063dc0020e7e4cde05669533404",
                },
            },
        },
        macosx = {
            source = "https://github.com/nats-io/natscli/releases/download/v${version}/nats-${version}-darwin-${arch_alias}.zip",
            ["latest"] = { ref = "0.5.2" },
            ["0.5.2"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "a42870bd0a6cf6519b7fc62fbb48f158672131698218fdd6ab90bd7ac9dc9154",
                    aarch64 = "90a38da1afe0927635c0dd3b61be915dd85cf1b31cf6ff4ea27281b2a60e0435",
                },
            },
        },
        windows = {
            source = "https://github.com/nats-io/natscli/releases/download/v${version}/nats-${version}-windows-${arch_alias}.zip",
            ["latest"] = { ref = "0.5.2" },
            ["0.5.2"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "ac16f6e4ce9a2c48c0a8a18d0053c4e4acf5cfafc1dd35ed41587f20a07e92e4",
                    aarch64 = "db3490f046f58c4b9ff8f1064f38ccc70ef97b9b4e840f3c78b670e46a385457",
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

function installed()
    return payload.present({ "nats", "LICENSE" })
        or payload.present({ "nats.exe", "LICENSE" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("nats: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local filename = normalized:match("([^/]+)$") or ""
    local stem = filename:gsub("%.zip$", "")
    -- All platforms ship `.zip` archives; detect Windows by path, never by `.zip`.
    local is_win = normalized:match("windows") ~= nil
        or os.getenv("OS") == "Windows_NT"
        or tostring(dir):match("^[A-Za-z]:") ~= nil
    local exe = is_win and "nats.exe" or "nats"

    if is_win or os.isdir(parent .. "/" .. stem) then
        payload.unpack{ extracted = stem, strip = 1 }
    elseif os.isfile(archive) then
        local stage = dir .. ".unpack"
        os.tryrm(stage)
        os.tryrm(dir)
        fs.mkdir_p(stage)
        local ok = pcall(system.exec, string.format('unzip -q -o "%s" -d "%s"', archive, stage))
        local extracted = stage .. "/" .. stem
        if ok and os.isdir(extracted) then
            local dst_parent = dir:match("^(.*)/[^/]+$")
            if dst_parent then fs.mkdir_p(dst_parent) end
            os.mv(extracted, dir)
            os.tryrm(stage)
        else
            os.tryrm(stage)
            fs.mkdir_p(dir)
            system.exec(string.format('tar -xf "%s" --strip-components=1 -C "%s"', archive, dir))
        end
    else
        error("nats: archive or extracted directory (" .. stem .. ") not found in " .. parent)
    end

    if not is_win and os.isfile(dir .. "/nats") then
        system.exec(string.format('chmod +x "%s"', dir .. "/nats"))
    end

    payload.require({ exe, "LICENSE" })
    return true
end

function config()
    xvm.add("nats", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("nats")
    return true
end
