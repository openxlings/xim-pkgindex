-- Miller - like awk, sed, cut, join, and sort for name-indexed data (binary: `mlr`).
--
-- Verified 2026-11-26 against the upstream GitHub release v6.23.0: every
-- SHA256 below was verified against `miller-6.23.0-checksums.txt` and downloaded
-- archives. All six archives pack a single top-level directory
-- `miller-6.23.0-<os>-<arch>/` containing `mlr[.exe]`, `LICENSE.txt`, and
-- `README.md`.
-- The Linux binaries are statically linked Go executables (`readelf -d`: no
-- dynamic section, `ldd`: not a dynamic executable); the Windows PE32+
-- binaries (`x86_64` and `aarch64`) import only `kernel32.dll`.
package = {
    spec = "2",

    name = "miller",
    description = "Like awk, sed, cut, join, and sort for name-indexed data such as CSV, TSV, and tabular JSON",
    homepage = "https://miller.readthedocs.io",
    authors = {"John Kerl"},
    maintainers = {"https://github.com/johnkerl/miller/graphs/contributors"},
    licenses = {"BSD-2-Clause"},
    repo = "https://github.com/johnkerl/miller",
    docs = "https://miller.readthedocs.io",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "data", "csv", "json", "tools"},
    keywords = {"miller", "mlr", "csv", "tsv", "json", "awk", "sed", "data", "cli"},

    programs = {"mlr"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/johnkerl/miller/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/johnkerl/miller/releases/download/${tag}/miller-${version}-linux-amd64.tar.gz",
                            aarch64 = "https://github.com/johnkerl/miller/releases/download/${tag}/miller-${version}-linux-arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/johnkerl/miller/releases/download/${tag}/miller-${version}-darwin-amd64.tar.gz",
                            aarch64 = "https://github.com/johnkerl/miller/releases/download/${tag}/miller-${version}-darwin-arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/johnkerl/miller/releases/download/${tag}/miller-${version}-windows-amd64.zip",
                            aarch64 = "https://github.com/johnkerl/miller/releases/download/${tag}/miller-${version}-windows-arm64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/johnkerl/miller/releases/download/v${version}/miller-${version}-linux-${arch_alias}.tar.gz",
            ["latest"] = { ref = "6.23.0" },
            ["6.23.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "3d9b22ee1269b46c864ffc64e5696abe3352a7f91530bb01be51967a4ceeeac3",
                    aarch64 = "2d5e66474c5c5143f40e671a429a18ef05b91b06dbde8ec253978e5a35d20c7d",
                },
            },
        },
        macosx = {
            source = "https://github.com/johnkerl/miller/releases/download/v${version}/miller-${version}-darwin-${arch_alias}.tar.gz",
            ["latest"] = { ref = "6.23.0" },
            ["6.23.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "c75ac2aab422e96cb59a642e39659e2664ceb80639ff8a0c5387fc56d2e9ebc7",
                    aarch64 = "b91a8daafface9c1c4f93f82c3daa32c5db44001cce83c9aa4ea0ed56e46041d",
                },
            },
        },
        windows = {
            source = "https://github.com/johnkerl/miller/releases/download/v${version}/miller-${version}-windows-${arch_alias}.zip",
            ["latest"] = { ref = "6.23.0" },
            ["6.23.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "8192fbc5e959637f4112b34dcfdc518c1b59701bc34777ca528dc749ece15a1a",
                    aarch64 = "86a14238d63d441e10a1d979a882afc444eedc291f5c98d8650a8f9b40162cbc",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

function installed()
    return payload.present({ "mlr", "LICENSE.txt" })
        or payload.present({ "mlr.exe", "LICENSE.txt" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("miller: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local stem = (normalized:match("([^/]+)$") or ""):gsub("%.tar%.gz$", ""):gsub("%.zip$", "")
    local is_win = normalized:match("%.zip$") ~= nil
    local exe = is_win and "mlr.exe" or "mlr"

    payload.unpack{ extracted = stem, strip = 1 }

    if not is_win and os.isfile(dir .. "/" .. exe) then
        system.exec(string.format('chmod +x "%s"', dir .. "/" .. exe))
    end

    payload.require({ exe, "LICENSE.txt" })
    return true
end

function config()
    -- Group placeholder: the binary is `mlr`, while the package name is
    -- `miller`. Registering `package.name` with `type = "group"` lets
    -- `xvm info miller` and `xlings remove` locate the package without
    -- creating an orphan `miller` shim in `bin/`.
    xvm.add(package.name, { type = "group" })
    xvm.add("mlr", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("mlr")
    xvm.remove(package.name)
    return true
end
