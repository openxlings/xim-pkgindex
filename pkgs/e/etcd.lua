-- etcd - Distributed reliable key-value store for the most critical data of a distributed system.
--
-- Verified 2026-11-25 against upstream GitHub release v3.7.4
-- (`etcd-io/etcd`). Every SHA256 below matches both upstream `SHA256SUMS` and
-- locally downloaded archives:
--   * linux   x86_64, aarch64   `.tar.gz` (`etcd-v<ver>-linux-<arch>/`); all
--                               three binaries (`etcd`, `etcdctl`, `etcdutl`)
--                               are statically linked Go ELFs with no dynamic
--                               section or external libc dependency (`readelf -d`,
--                               `ldd`).
--   * macosx  x86_64, aarch64   `.zip` (`etcd-v<ver>-darwin-<arch>/`).
--   * windows x86_64            `.zip` (`etcd-v<ver>-windows-amd64/`); all
--                               three PE32+ executables (`etcd.exe`,
--                               `etcdctl.exe`, `etcdutl.exe`) import only
--                               `kernel32.dll` (no VCRUNTIME DLL dependency).
--                               Upstream publishes no Windows ARM64 asset.

package = {
    spec = "2",

    name = "etcd",
    description = "Distributed reliable key-value store for the most critical data of a distributed system",
    homepage = "https://etcd.io",
    authors = {"etcd Authors"},
    maintainers = {"etcd-io"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/etcd-io/etcd",
    docs = "https://etcd.io/docs/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"database", "distributed", "kv", "server", "cli"},
    keywords = {"etcd", "etcdctl", "etcdutl", "kv", "raft", "distributed", "kubernetes"},

    programs = {"etcd", "etcdctl", "etcdutl"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/etcd-io/etcd/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/etcd-io/etcd/releases/download/${tag}/etcd-v${version}-linux-amd64.tar.gz",
                            aarch64 = "https://github.com/etcd-io/etcd/releases/download/${tag}/etcd-v${version}-linux-arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/etcd-io/etcd/releases/download/${tag}/etcd-v${version}-darwin-amd64.zip",
                            aarch64 = "https://github.com/etcd-io/etcd/releases/download/${tag}/etcd-v${version}-darwin-arm64.zip",
                        },
                        windows = {
                            x86_64 = "https://github.com/etcd-io/etcd/releases/download/${tag}/etcd-v${version}-windows-amd64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/etcd-io/etcd/releases/download/v${version}/etcd-v${version}-linux-${arch_alias}.tar.gz",
            ["latest"] = { ref = "3.7.4" },
            ["3.7.4"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "a0d47d07d081c12611fe69dc81a16ae8dd758401c0fe3a83d508823a1dac558e",
                    aarch64 = "3f5d12a3b4119141bd5bc80a0a895100d049d6c85a2c76b1bb767204a899024a",
                },
            },
        },
        macosx = {
            source = "https://github.com/etcd-io/etcd/releases/download/v${version}/etcd-v${version}-darwin-${arch_alias}.zip",
            ["latest"] = { ref = "3.7.4" },
            ["3.7.4"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "2477b78926372784f32d6c6174aca98525fd1339dec3de0e667c9ae38f8ee431",
                    aarch64 = "8288e23b0c531af38b4daa72d4c3a83886ff773b0950d9b38e1174b0370cb36a",
                },
            },
        },
        windows = {
            source = "https://github.com/etcd-io/etcd/releases/download/v${version}/etcd-v${version}-windows-${arch_alias}.zip",
            ["latest"] = { ref = "3.7.4" },
            ["3.7.4"] = {
                arch_alias = { x86_64 = "amd64" },
                sha256 = {
                    x86_64 = "25cc2d77af4fbb49a9cf0960e8c182783595172cc2da815b1aca19df127e969d",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

local function top_dirs()
    local v = "etcd-v" .. pkginfo.version() .. "-"
    return {
        v .. "linux-amd64",
        v .. "linux-arm64",
        v .. "darwin-amd64",
        v .. "darwin-arm64",
        v .. "windows-amd64",
    }
end

function installed()
    return payload.present({ "etcd", "etcdctl", "etcdutl" })
        or payload.present({ "etcd.exe", "etcdctl.exe", "etcdutl.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file())
    local normalized = archive:gsub("\\", "/")
    local filename = normalized:match("([^/]+)$") or ""
    local stem = filename:gsub("%.tar%.gz$", ""):gsub("%.zip$", "")
    local is_win = normalized:match("%-windows%-") ~= nil or os.getenv("OS") == "Windows_NT"

    local candidates = top_dirs()
    if stem ~= "" then
        table.insert(candidates, 1, stem)
    end

    payload.unpack{
        extracted = candidates,
        strip = 1,
    }

    local ext = is_win and ".exe" or ""
    payload.require({ "etcd" .. ext, "etcdctl" .. ext, "etcdutl" .. ext })
    return true
end

function config()
    local bindir = pkginfo.install_dir()
    local binding = "etcd@" .. pkginfo.version()
    xvm.add("etcd", { bindir = bindir })
    xvm.add("etcdctl", { bindir = bindir, binding = binding })
    xvm.add("etcdutl", { bindir = bindir, binding = binding })
    return true
end

function uninstall()
    xvm.remove("etcdutl")
    xvm.remove("etcdctl")
    xvm.remove("etcd")
    return true
end
