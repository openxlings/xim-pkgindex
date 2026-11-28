-- HashiCorp Vault - Tool for secrets management, encryption as a service, and privileged access management.
--
-- Verified 2026-11-26 against upstream HashiCorp release 2.2.2: every SHA256
-- below was verified against `vault_2.2.2_SHA256SUMS` and downloaded archives.
-- All five archives are flat (no enclosing directory) and pack `vault[.exe]`
-- and `LICENSE.txt`.
-- The Linux binaries (amd64 and arm64) are statically linked Go executables
-- (`readelf -d`: no dynamic section, `ldd`: not a dynamic executable).
package = {
    spec = "2",

    name = "vault",
    description = "A tool for secrets management, encryption as a service, and privileged access management",
    homepage = "https://www.vaultproject.io",
    authors = {"HashiCorp"},
    maintainers = {"https://github.com/hashicorp/vault/graphs/contributors"},
    licenses = {"BSL-1.1"},
    repo = "https://github.com/hashicorp/vault",
    docs = "https://developer.hashicorp.com/vault/docs",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"security", "secrets", "devops", "cli", "tools"},
    keywords = {"vault", "hashicorp", "secrets", "encryption", "kms", "pki", "cli"},

    programs = {"vault"},
    xvm_enable = true,

    xpm = {
        linux = {
            source = "https://releases.hashicorp.com/vault/${version}/vault_${version}_linux_${arch_alias}.zip",
            ["latest"] = { ref = "2.2.2" },
            ["2.2.2"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "5700edf139113609962fe371af7d2a53de8ecb720d545dc39b43de204515d3c4",
                    aarch64 = "78634c8672601ad1ca9b27f24e76c54224d12521c59ece957ab8d23976ddca12",
                },
            },
        },
        macosx = {
            source = "https://releases.hashicorp.com/vault/${version}/vault_${version}_darwin_${arch_alias}.zip",
            ["latest"] = { ref = "2.2.2" },
            ["2.2.2"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "57ce53e10b266d2c1c2c3646813e434777e9bddb4e5377e7e1250e85ca98a2f9",
                    aarch64 = "75843ff0559dfa4d69bfde073f98caaa22674c27fd80446d092ad2069d7f25f8",
                },
            },
        },
        windows = {
            source = "https://releases.hashicorp.com/vault/${version}/vault_${version}_windows_${arch_alias}.zip",
            ["latest"] = { ref = "2.2.2" },
            ["2.2.2"] = {
                arch_alias = { x86_64 = "amd64" },
                sha256 = {
                    x86_64 = "23dc7f8928d755c5b885a82bcc69323616bb856a28973c0dad7aaa24ce0a7d6d",
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
    return payload.present({ "vault", "LICENSE.txt" })
        or payload.present({ "vault.exe", "LICENSE.txt" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("vault: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("windows") ~= nil
    local exe = is_win and "vault.exe" or "vault"

    os.tryrm(dir)
    if is_win then
        payload.unpack{}
    elseif os.isfile(archive) then
        fs.mkdir_p(dir)
        system.exec(string.format('unzip -q -o "%s" -d "%s"', normalized, dir))
    elseif os.isfile(parent .. "/" .. exe) then
        fs.mkdir_p(dir)
        for _, f in ipairs({ exe, "LICENSE.txt" }) do
            if os.isfile(parent .. "/" .. f) then
                os.mv(parent .. "/" .. f, dir .. "/" .. f)
            end
        end
    else
        error("vault: archive not found at " .. archive .. " and no extracted " .. exe .. " in " .. parent)
    end

    if not is_win and os.isfile(dir .. "/" .. exe) then
        system.exec(string.format('chmod +x "%s"', dir .. "/" .. exe))
    end

    payload.require({ exe, "LICENSE.txt" })
    return true
end

function config()
    xvm.add("vault", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("vault")
    return true
end
