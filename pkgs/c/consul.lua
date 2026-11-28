-- HashiCorp Consul - Service networking solution for service discovery, service mesh, and distributed KV configuration.
--
-- Verified 2026-11-26 against upstream HashiCorp release 2.1.0: every SHA256
-- below was verified against `consul_2.1.0_SHA256SUMS` and downloaded archives.
-- All five archives are flat (no enclosing directory) and pack `consul[.exe]`
-- and `LICENSE.txt`.
-- The Linux binaries (amd64 and arm64) are statically linked Go executables
-- (`readelf -d`: no dynamic section, `ldd`: not a dynamic executable).
package = {
    spec = "2",

    name = "consul",
    description = "Service networking solution to automate network configurations, discover services, and enable secure connectivity across any cloud or runtime",
    homepage = "https://www.consul.io",
    authors = {"HashiCorp"},
    maintainers = {"https://github.com/hashicorp/consul/graphs/contributors"},
    licenses = {"BSL-1.1"},
    repo = "https://github.com/hashicorp/consul",
    docs = "https://developer.hashicorp.com/consul/docs",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"networking", "service-mesh", "devops", "cloud", "cli", "tools"},
    keywords = {"consul", "hashicorp", "service-discovery", "service-mesh", "kv", "devops", "cli"},

    programs = {"consul"},
    xvm_enable = true,

    xpm = {
        linux = {
            source = "https://releases.hashicorp.com/consul/${version}/consul_${version}_linux_${arch_alias}.zip",
            ["latest"] = { ref = "2.1.0" },
            ["2.1.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "a9c9cdf1ed93bd29a9671b02e5433131f3f777bab16c076fcef712a2820bfe33",
                    aarch64 = "eb34b81592e25eadb3fbc553afb2036004dcd316d99a1a8e40a177fde4e0e537",
                },
            },
        },
        macosx = {
            source = "https://releases.hashicorp.com/consul/${version}/consul_${version}_darwin_${arch_alias}.zip",
            ["latest"] = { ref = "2.1.0" },
            ["2.1.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "40e614b6bf47e85387c7a9f65b97e4f0a6f21057c4e50e1b05cbc4691b338d99",
                    aarch64 = "236d6a579c5fcfb065f416bd3a296ad199a1116c2667481bffdfdc60a5e61468",
                },
            },
        },
        windows = {
            source = "https://releases.hashicorp.com/consul/${version}/consul_${version}_windows_${arch_alias}.zip",
            ["latest"] = { ref = "2.1.0" },
            ["2.1.0"] = {
                arch_alias = { x86_64 = "amd64" },
                sha256 = {
                    x86_64 = "10d28650868eff28502e541a1df5dc388e6da79f611bd6b6177871c9d02576db",
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
    return payload.present({ "consul", "LICENSE.txt" })
        or payload.present({ "consul.exe", "LICENSE.txt" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("consul: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("windows") ~= nil
    local exe = is_win and "consul.exe" or "consul"

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
        error("consul: archive not found at " .. archive .. " and no extracted " .. exe .. " in " .. parent)
    end

    if not is_win and os.isfile(dir .. "/" .. exe) then
        system.exec(string.format('chmod +x "%s"', dir .. "/" .. exe))
    end

    payload.require({ exe, "LICENSE.txt" })
    return true
end

function config()
    xvm.add("consul", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("consul")
    return true
end
