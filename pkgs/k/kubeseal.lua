-- kubeseal — Client-side CLI tool for Bitnami Sealed Secrets (bitnami/sealed-secrets,
-- formerly bitnami-labs/sealed-secrets).
--
-- Verified 2026-11-26 against upstream GitHub release v0.41.2 and
-- `sealed-secrets_0.41.2_checksums.txt`: every SHA256 below matched both the
-- upstream checksums file and the downloaded release archive bytes:
--   linux/x86_64    kubeseal-0.41.2-linux-amd64.tar.gz    (static Go ELF, no .dynamic section)
--   linux/aarch64   kubeseal-0.41.2-linux-arm64.tar.gz    (static Go ELF, no .dynamic section)
--   macosx/x86_64   kubeseal-0.41.2-darwin-amd64.tar.gz   (Mach-O 64-bit x86_64)
--   macosx/aarch64  kubeseal-0.41.2-darwin-arm64.tar.gz   (Mach-O 64-bit arm64)
--   windows/x86_64  kubeseal-0.41.2-windows-amd64.tar.gz  (PE32+ console x86-64, imports kernel32.dll only; no windows-arm64 asset upstream)
--
-- Every archive (including Windows) is a flat `.tar.gz` at root containing
-- `LICENSE`, `README.md`, and `kubeseal` (or `kubeseal.exe` on Windows) with no
-- top-level wrapper directory. `install()` extracts directly into
-- `pkginfo.install_dir()` so shared download directories cannot leak unrelated
-- flat files into this payload.

package = {
    spec = "2",

    name = "kubeseal",
    description = "Kubernetes controller and CLI tool for one-way encrypted SealedSecrets",
    homepage = "https://github.com/bitnami/sealed-secrets",
    authors = {"Bitnami"},
    maintainers = {"https://github.com/bitnami/sealed-secrets/graphs/contributors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/bitnami/sealed-secrets",
    docs = "https://github.com/bitnami/sealed-secrets#readme",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"kubernetes", "k8s", "security", "cli", "tools"},
    keywords = {"kubeseal", "sealed-secrets", "kubernetes", "k8s", "encryption", "secrets", "cli"},

    programs = {"kubeseal"},
    xvm_enable = true,

    -- Verified upstream release assets; no CN mirror has been verified.
    extensions = {
        autoupdate = {
            source = "https://github.com/bitnami/sealed-secrets/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/bitnami/sealed-secrets/releases/download/${tag}/kubeseal-${version}-linux-amd64.tar.gz",
                            aarch64 = "https://github.com/bitnami/sealed-secrets/releases/download/${tag}/kubeseal-${version}-linux-arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/bitnami/sealed-secrets/releases/download/${tag}/kubeseal-${version}-darwin-amd64.tar.gz",
                            aarch64 = "https://github.com/bitnami/sealed-secrets/releases/download/${tag}/kubeseal-${version}-darwin-arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/bitnami/sealed-secrets/releases/download/${tag}/kubeseal-${version}-windows-amd64.tar.gz",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/bitnami/sealed-secrets/releases/download/v${version}/kubeseal-${version}-linux-${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.41.2" },
            ["0.41.2"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "666b5db6788ad1dedb56e2d97064e1cc3779aa77bbd6f4b56b62beeb1941ed79",
                    aarch64 = "8a73c0b252f6c0e8752a7a749da51f55a6e99dc5603e3bd29ed3c00ff9e82db2",
                },
            },
        },
        macosx = {
            source = "https://github.com/bitnami/sealed-secrets/releases/download/v${version}/kubeseal-${version}-darwin-${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.41.2" },
            ["0.41.2"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "e0f74cde61699a33c6c3e35ffa0733e7aa6bbcfcd81dab7dbffaa3c98f6764eb",
                    aarch64 = "4f9ce57bb69c419f1a94e88e0d2d5755b395f7926e34d99bf91bc8e084e27ae4",
                },
            },
        },
        windows = {
            -- Upstream publishes only kubeseal-<version>-windows-amd64.tar.gz (no windows-arm64 asset).
            source = "https://github.com/bitnami/sealed-secrets/releases/download/v${version}/kubeseal-${version}-windows-${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.41.2" },
            ["0.41.2"] = {
                arch_alias = { x86_64 = "amd64" },
                sha256 = {
                    x86_64 = "024375f645364b45fd543468885ed2b589fd3d04c721026e136605cebce58a3c",
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
import("xim.pkgindex.winpath")

function installed()
    return payload.present({ "kubeseal" })
        or payload.present({ "kubeseal.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("kubeseal: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("%-windows%-") ~= nil
        or normalized:match("windows") ~= nil
        or normalized:match("^[A-Za-z]:/") ~= nil
        or os.getenv("OS") == "Windows_NT"
    local exe = is_win and "kubeseal.exe" or "kubeseal"

    os.tryrm(dir)
    fs.mkdir_p(dir)

    if os.isfile(archive) then
        if is_win then
            local sysroot = winpath.native(os.getenv("SystemRoot") or "C:\\Windows"):gsub("\\+$", "")
            local systar = sysroot .. "\\System32\\tar.exe"
            -- exec-quoting-ok: the first token is the system's tar.exe, which cmd.exe must see unquoted
            system.exec(string.format('%s -xf "%s" -C "%s"',
                                      systar, winpath.native(archive), winpath.native(dir)))
        else
            -- Extract flat .tar.gz directly into install_dir so files never mix
            -- with other flat archives in the shared download directory.
            system.exec(string.format('tar -xzf "%s" -C "%s"', normalized, dir))
            system.exec(string.format('chmod +x "%s"', dir .. "/kubeseal"))
        end
    elseif os.isfile(parent .. "/" .. exe) then
        os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
        if not is_win then
            system.exec(string.format('chmod +x "%s"', dir .. "/kubeseal"))
        end
    else
        error("kubeseal: neither archive (" .. archive .. ") nor extracted binary exists")
    end

    payload.require({ exe })
    return true
end

function config()
    xvm.add("kubeseal", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("kubeseal")
    return true
end
