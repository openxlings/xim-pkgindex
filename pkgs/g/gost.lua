package = {
    spec = "2",
    name = "gost",
    description = "GO Simple Tunnel: a network proxy and tunnel tool",
    homepage = "https://gost.run",
    repo = "https://github.com/go-gost/gost",
    docs = "https://gost.run/en/",
    licenses = {"MIT"},
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"network", "tools"},
    keywords = {"gost", "proxy", "tunnel", "socks", "http"},
    programs = {"gost"},
    xvm_enable = true,

    -- Portable amd64 builds, not the optional amd64v3 CPU-feature variant.
    -- Limit this initial package to the x86_64/aarch64 targets admitted
    -- by the index's existing automatic-update validation policy.
    -- Verified upstream release assets; no CN mirror has been verified.
    extensions = {
        autoupdate = {
            source = "https://github.com/go-gost/gost/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/go-gost/gost/releases/download/v${version}/gost_${version}_linux_amd64.tar.gz",
                            aarch64 = "https://github.com/go-gost/gost/releases/download/v${version}/gost_${version}_linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/go-gost/gost/releases/download/v${version}/gost_${version}_darwin_amd64.tar.gz",
                            aarch64 = "https://github.com/go-gost/gost/releases/download/v${version}/gost_${version}_darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/go-gost/gost/releases/download/v${version}/gost_${version}_windows_amd64.zip",
                            aarch64 = "https://github.com/go-gost/gost/releases/download/v${version}/gost_${version}_windows_arm64.zip",
                        },
                    },
                },
            },
        },
    },
    -- Upstream uses CGO_ENABLED=0. Linux executables are static ELF files,
    -- so no glibc, compiler runtime or loader dependency is required.
    xpm = {
        linux = {
            source = "https://github.com/go-gost/gost/releases/download/v${version}/gost_${version}_linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "3.3.3" },
            ["3.3.3"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "f4c1255dc892a7014c0ad6e5f1c3573108f7bea4403f04f21873406ab58aa666",
                    aarch64 = "4c704c92df6eeea8a3b08d0de4fd3c44343095a20136b3b6cf334f98d2f174ab",
                },
            },
        },
        macosx = {
            source = "https://github.com/go-gost/gost/releases/download/v${version}/gost_${version}_darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "3.3.3" },
            ["3.3.3"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "bf3b9b8ae647ea74aff928e646f3486239e79634d3a5a4ed7f742c055ac1c7bb",
                    aarch64 = "12ea2773f2cb455af0f157e6456667637014101cca0f79c38e42b3b35f8c1b6b",
                },
            },
        },
        windows = {
            source = "https://github.com/go-gost/gost/releases/download/v${version}/gost_${version}_windows_${arch_alias}.zip",
            ["latest"] = { ref = "3.3.3" },
            ["3.3.3"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "b00441624a66ebed94a2ddcc01ab2832069f053e6ca0abf19d7104b84fad1f78",
                    aarch64 = "9bdba3d429dbaa1f926b1a2e75a5e35d427129c5ae9dbebcaf1a929d8ab570d6",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

-- Archives are flat; default extraction retains the executable, license and
-- documentation. No daemon, service or user configuration is installed.
function config()
    local root = pkginfo.install_dir()
    if not os.isfile(root .. "/gost") and not os.isfile(root .. "/gost.exe") then
        error("gost executable is missing from " .. root)
    end
    xvm.add("gost", { bindir = root })
    return true
end

function uninstall()
    xvm.remove("gost")
    return true
end
