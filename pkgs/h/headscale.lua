-- Upstream raw binaries: Linux is static; macOS 13+ uses system dylibs only.
-- Deliberately avoid the .deb's service, accounts, /etc config and /var state.
-- No Windows binary is published; FreeBSD is outside this index's platform matrix.
package = {
    spec = "2",
    name = "headscale",
    description = "Self-hosted, open-source Tailscale control server",
    homepage = "https://headscale.net",
    repo = "https://github.com/juanfont/headscale",
    docs = "https://headscale.net/stable/",
    maintainers = {"juanfont"},
    licenses = {"BSD-3-Clause"},
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"network", "tools"},
    keywords = {"headscale", "tailscale", "vpn", "wireguard"},
    programs = {"headscale"},
    xvm_enable = true,

    -- Direct official assets only; no CN mirror has been independently verified.
    extensions = {
        autoupdate = {
            source = "https://github.com/juanfont/headscale/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/juanfont/headscale/releases/download/${tag}/headscale_${version}_linux_amd64",
                            aarch64 = "https://github.com/juanfont/headscale/releases/download/${tag}/headscale_${version}_linux_arm64",
                        },
                        macosx = {
                            x86_64 = "https://github.com/juanfont/headscale/releases/download/${tag}/headscale_${version}_darwin_amd64",
                            aarch64 = "https://github.com/juanfont/headscale/releases/download/${tag}/headscale_${version}_darwin_arm64",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/juanfont/headscale/releases/download/v${version}/headscale_${version}_linux_${arch_alias}",
            ["latest"] = { ref = "0.29.8" },
            ["0.29.8"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "4f55dc066924bdc234a4b300c7330df4fbd89d42ba180176b6335d4a3c19759b",
                    aarch64 = "0b02e6f23e0fc3cbe679f9fd3abf9933f6c579e1cb7fca94e2d921d15948b755",
                },
            },
        },
        macosx = {
            source = "https://github.com/juanfont/headscale/releases/download/v${version}/headscale_${version}_darwin_${arch_alias}",
            ["latest"] = { ref = "0.29.8" },
            ["0.29.8"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "0f169588fa533d5780d0bc13aca3b47c2a949c260e489db899679217bf793a47",
                    aarch64 = "7348ad39eabc943dad14b78d268bd43c2189aae34756ee60e5f09ce36b54c4d3",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

function installed()
    return os.isfile(pkginfo.install_dir() .. "/headscale")
end

function install()
    local dir = pkginfo.install_dir()
    local target = dir .. "/headscale"
    os.tryrm(dir)
    fs.mkdir_p(dir)
    os.mv(pkginfo.install_file(), target)
    system.exec(string.format([[chmod +x "%s"]], target))
    if not os.isfile(target) then
        error("headscale: executable missing after install at " .. target)
    end
    return true
end

function config()
    xvm.add("headscale", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("headscale")
    return true
end
