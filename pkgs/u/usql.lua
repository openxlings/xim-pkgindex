-- usql - Universal command-line interface for SQL databases (xo/usql).
--
-- Verified 2026-11-26 against upstream GitHub release v0.21.6 (`xo/usql`).
-- Every SHA-256 digest below matches the GitHub release asset digest and the
-- locally downloaded archive bytes:
--   * linux   x86_64, aarch64   `usql_static-<ver>-linux-{amd64,arm64}.tar.bz2`
--                               (flat archive packing `usql_static` + `LICENSE`;
--                               `usql_static` is a truly static ELF executable:
--                               `readelf -d` shows no dynamic section and `ldd`
--                               reports not a dynamic executable, so zero runtime
--                               deps are required — unlike non-static `usql`,
--                               which dynamically links glibc, libm, libstdc++,
--                               and libgcc_s).
--   * macosx  x86_64, aarch64   `usql-<ver>-darwin-{amd64,arm64}.tar.bz2`
--                               (flat archive packing `usql` + `LICENSE`).
--   * windows x86_64            `usql-<ver>-windows-amd64.zip`
--                               (flat archive packing `usql.exe` + `LICENSE`;
--                               PE32+ console executable importing only
--                               `KERNEL32.dll` and Windows 10+ UCRT API sets
--                               `api-ms-win-crt-*-l1-1-0.dll`, no VCRUNTIME DLL;
--                               upstream publishes no `windows-arm64` asset).

package = {
    spec = "2",

    name = "usql",
    description = "Universal command-line interface for SQL databases",
    homepage = "https://github.com/xo/usql",
    authors = {"Kenneth Shaw"},
    maintainers = {"https://github.com/xo/usql"},
    licenses = {"MIT"},
    repo = "https://github.com/xo/usql",
    docs = "https://github.com/xo/usql#readme",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"database", "sql", "cli", "tools"},
    keywords = {"usql", "sql", "database", "cli", "sqlite", "postgres", "mysql"},

    programs = {"usql"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/xo/usql/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/xo/usql/releases/download/${tag}/usql_static-${version}-linux-amd64.tar.bz2",
                            aarch64 = "https://github.com/xo/usql/releases/download/${tag}/usql_static-${version}-linux-arm64.tar.bz2",
                        },
                        macosx = {
                            x86_64 = "https://github.com/xo/usql/releases/download/${tag}/usql-${version}-darwin-amd64.tar.bz2",
                            aarch64 = "https://github.com/xo/usql/releases/download/${tag}/usql-${version}-darwin-arm64.tar.bz2",
                        },
                        windows = {
                            x86_64 = "https://github.com/xo/usql/releases/download/${tag}/usql-${version}-windows-amd64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/xo/usql/releases/download/v${version}/usql_static-${version}-linux-${arch_alias}.tar.bz2",
            ["latest"] = { ref = "0.21.6" },
            ["0.21.6"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "046b25a4ce8d16b200d38a47e85c45c5eb694eb5ae071a21436d39fe08a897bc",
                    aarch64 = "19415f69089431e31e96a9f17e38c7611375c8552efb9f095aaf733860172116",
                },
            },
        },
        macosx = {
            source = "https://github.com/xo/usql/releases/download/v${version}/usql-${version}-darwin-${arch_alias}.tar.bz2",
            ["latest"] = { ref = "0.21.6" },
            ["0.21.6"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "ece7442e062d25e54fa8f32b9de959a5444830b4d613ced89ac08fb2b17d79c8",
                    aarch64 = "869b969d58b3ffd33ad97de46e3b29130dc337a5ad8027297ce63d5fe535f4b5",
                },
            },
        },
        windows = {
            source = "https://github.com/xo/usql/releases/download/v${version}/usql-${version}-windows-${arch_alias}.zip",
            ["latest"] = { ref = "0.21.6" },
            ["0.21.6"] = {
                arch_alias = { x86_64 = "amd64" },
                sha256 = {
                    x86_64 = "9b5dd191fc13d2619e7cefd9f619093bf151381bc7eb4f01dce88d03bea02a99",
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
    return payload.present({ "usql", "LICENSE" })
        or payload.present({ "usql.exe", "LICENSE" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("usql: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:lower():match("%.zip$") ~= nil
        or normalized:match("%-windows%-") ~= nil

    os.tryrm(dir)

    if is_win then
        payload.unpack{}
    elseif os.isfile(archive) then
        -- Archives are flat at root (`usql_static` or `usql`, plus `LICENSE`).
        -- Extract straight into install_dir so files from other flat archives
        -- in the shared runtime download directory cannot mix in.
        fs.mkdir_p(dir)
        system.exec(string.format([[tar -xjf "%s" -C "%s"]], normalized, dir))
    elseif os.isfile(parent .. "/usql_static") or os.isfile(parent .. "/usql") then
        fs.mkdir_p(dir)
        if os.isfile(parent .. "/usql_static") then
            os.mv(parent .. "/usql_static", dir .. "/usql")
        else
            os.mv(parent .. "/usql", dir .. "/usql")
        end
        if os.isfile(parent .. "/LICENSE") then
            os.mv(parent .. "/LICENSE", dir .. "/LICENSE")
        end
    else
        error("usql: archive not found at " .. archive)
    end

    if not is_win then
        if os.isfile(dir .. "/usql_static") and not os.isfile(dir .. "/usql") then
            os.mv(dir .. "/usql_static", dir .. "/usql")
        end
        if os.isfile(dir .. "/usql") then
            system.exec(string.format([[chmod +x "%s"]], dir .. "/usql"))
        end
    end

    payload.require({ is_win and "usql.exe" or "usql", "LICENSE" })
    return true
end

function config()
    xvm.add("usql", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("usql")
    return true
end
