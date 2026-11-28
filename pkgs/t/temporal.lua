-- Temporal CLI - Command-line interface for running Temporal Server and
-- interacting with Workflows, Activities, Namespaces, and Schedules.
--
-- Verified 2026-11-26 against upstream GitHub release v1.10.1 (temporalio/cli):
--   linux    x86_64, aarch64   temporal_cli_<ver>_linux_{amd64,arm64}.tar.gz
--   macosx   x86_64, aarch64   temporal_cli_<ver>_darwin_{amd64,arm64}.tar.gz
--   windows  x86_64, aarch64   temporal_cli_<ver>_windows_{amd64,arm64}.zip
--
-- Every archive is flat at root containing `LICENSE` and a single executable
-- (`temporal` on POSIX, `temporal.exe` on Windows). All six SHA-256 digests
-- match upstream `checksums.txt` and locally downloaded archives.
--
-- Both Linux ELF binaries are statically linked Go executables (`readelf -d`:
-- no dynamic section; `ldd`: not a dynamic executable), so no runtime library
-- deps are required. Both Windows PE32+ executables (`0x8664`, `0xaa64`) import
-- only `kernel32.dll` (no VCRUNTIME DLL dependency). Offline
-- `temporal --version` exits 0 (`temporal version 1.10.1 ...`), `temporal --help`
-- exits 0, `temporal completion bash` exits 0, and `temporal /?` exits 1
-- (`Error: unknown command`) immediately without blocking.

package = {
    spec = "2",

    name = "temporal",
    description = "Command-line interface for running Temporal Server and interacting with Workflows",
    homepage = "https://temporal.io",
    authors = {"Temporal Technologies Inc."},
    maintainers = {"https://github.com/temporalio/cli/graphs/contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/temporalio/cli",
    docs = "https://docs.temporal.io/cli",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"workflow", "cli", "devtools", "tools"},
    keywords = {"temporal", "workflow", "durable-execution", "cli", "microservices"},

    programs = {"temporal"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/temporalio/cli/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/temporalio/cli/releases/download/${tag}/temporal_cli_${version}_linux_amd64.tar.gz",
                            aarch64 = "https://github.com/temporalio/cli/releases/download/${tag}/temporal_cli_${version}_linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/temporalio/cli/releases/download/${tag}/temporal_cli_${version}_darwin_amd64.tar.gz",
                            aarch64 = "https://github.com/temporalio/cli/releases/download/${tag}/temporal_cli_${version}_darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/temporalio/cli/releases/download/${tag}/temporal_cli_${version}_windows_amd64.zip",
                            aarch64 = "https://github.com/temporalio/cli/releases/download/${tag}/temporal_cli_${version}_windows_arm64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/temporalio/cli/releases/download/v${version}/temporal_cli_${version}_linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.10.1" },
            ["1.10.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "4c1500e2ce2d4de136e5fe8852d9b7f82eb62f19b6b383b3e0c040519a9d20b1",
                    aarch64 = "2f748e9411b37c9cabb57f1f08e37765388c12b5534432c7aea28b593df9145d",
                },
            },
        },
        macosx = {
            source = "https://github.com/temporalio/cli/releases/download/v${version}/temporal_cli_${version}_darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.10.1" },
            ["1.10.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "8ec6c513ad2177de4eb15d2cb17a4fe5070e6078afd7f80bdfcc37fae459d3c4",
                    aarch64 = "94f7f982b26438e8abbde6000ba471b694be6a2413b31f6162f87a9f9c48c738",
                },
            },
        },
        windows = {
            source = "https://github.com/temporalio/cli/releases/download/v${version}/temporal_cli_${version}_windows_${arch_alias}.zip",
            ["latest"] = { ref = "1.10.1" },
            ["1.10.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "5069cdb76569914305ed7c90e1c8406cd27bcb6c2a822fce201a488c34ab074f",
                    aarch64 = "dcd1964a5544bbd2e3c8036abc273100d4171cf192a55347a87ab525872aea08",
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
    return payload.present({ "temporal" })
        or payload.present({ "temporal.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("temporal: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("%.zip$") ~= nil
        or normalized:match("_windows_") ~= nil
        or os.getenv("OS") == "Windows_NT"
        or tostring(dir):match("^[A-Za-z]:") ~= nil
    local exe = is_win and "temporal.exe" or "temporal"

    os.tryrm(dir)

    -- Upstream archives are flat (no top-level wrapper directory). Extract
    -- directly into install_dir so unrelated files in the shared download
    -- directory cannot leak into this payload.
    if is_win then
        if os.isfile(archive) then
            payload.unpack{}
        elseif os.isfile(parent .. "/" .. exe) then
            fs.mkdir_p(dir)
            os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
        else
            error("temporal: neither archive (" .. archive .. ") nor extracted binary exists")
        end
    else
        fs.mkdir_p(dir)
        if os.isfile(archive) then
            system.exec(string.format('tar -xzf "%s" -C "%s"', normalized, dir))
        elseif os.isfile(parent .. "/" .. exe) then
            os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
        else
            error("temporal: neither archive (" .. archive .. ") nor extracted binary exists")
        end
        if os.isfile(dir .. "/" .. exe) then
            system.exec(string.format('chmod +x "%s"', dir .. "/" .. exe))
        end
    end

    payload.require({ exe })
    return true
end

function config()
    xvm.add("temporal", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("temporal")
    return true
end
