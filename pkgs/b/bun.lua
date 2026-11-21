package = {
    spec = "2",

    name = "bun",
    description = "Bun is an all-in-one toolkit for JavaScript and TypeScript apps",
    homepage = "https://bun.sh",
    licenses = {"MIT"},
    repo = "https://github.com/oven-sh/bun",
    docs = "https://bun.sh/docs",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"javascript", "runtime", "tools"},
    keywords = {"bun", "javascript", "runtime", "package-manager"},

    programs = {"bun"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/oven-sh/bun/releases",
            tag = "bun-v${version}",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/oven-sh/bun/releases/download/${tag}/bun-linux-x64-baseline.zip",
                            aarch64 = "https://github.com/oven-sh/bun/releases/download/${tag}/bun-linux-aarch64.zip",
                        },
                        macosx = {
                            x86_64 = "https://github.com/oven-sh/bun/releases/download/${tag}/bun-darwin-x64-baseline.zip",
                            aarch64 = "https://github.com/oven-sh/bun/releases/download/${tag}/bun-darwin-aarch64.zip",
                        },
                        windows = {
                            x86_64 = "https://github.com/oven-sh/bun/releases/download/${tag}/bun-windows-x64-baseline.zip",
                            aarch64 = "https://github.com/oven-sh/bun/releases/download/${tag}/bun-windows-aarch64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            -- The upstream Linux binary dynamically links glibc. Node is not
            -- needed: install the native Bun executable from its release zip.
            deps = {runtime = {"xim:glibc@>=2.39"}},
            source = "https://github.com/oven-sh/bun/releases/download/bun-v${version}/bun-linux-${arch_alias}.zip",
            ["latest"] = {ref = "1.4.5"},
            ["1.4.5"] = {
                -- Use baseline x64 builds so x86_64 does not imply AVX2.
                arch_alias = {x86_64 = "x64-baseline", aarch64 = "aarch64"},
                sha256 = {
                    x86_64 = "dcb23a18a1c2fff12d57bcef696dbbb42eb67fde29f43816ecb595459a24c463",
                    aarch64 = "18656a3bf0ea5641f5796ae4213b75255579a70a0fded2f337933785568cdf84",
                },
            },
            ["1.3.11"] = {
                -- Use baseline x64 builds so x86_64 does not imply AVX2.
                arch_alias = {x86_64 = "x64-baseline", aarch64 = "aarch64"},
                sha256 = {
                    x86_64 = "abe346f63414547cdf6b35b7a649a490c728b93d006226156923918a84c0e59b",
                    aarch64 = "d13944da12a53ecc74bf6a720bd1d04c4555c038dfe422365356a7be47691fdf",
                },
            },
        },
        macosx = {
            source = "https://github.com/oven-sh/bun/releases/download/bun-v${version}/bun-darwin-${arch_alias}.zip",
            ["latest"] = {ref = "1.4.5"},
            ["1.4.5"] = {
                arch_alias = {x86_64 = "x64-baseline", aarch64 = "aarch64"},
                sha256 = {
                    x86_64 = "fb0121739a7e80e7511b6bfe4d2116422b48ba18a013acadef0c425348e95891",
                    aarch64 = "b5d6bc2e13caf14e57c89661e89efd073ff16165b41bfe43882616410609cd10",
                },
            },
            ["1.3.11"] = {
                arch_alias = {x86_64 = "x64-baseline", aarch64 = "aarch64"},
                sha256 = {
                    x86_64 = "fb6739b08bf54550edaa7c824cd5b2dca45b6a06afef408443087a63105f6f8d",
                    aarch64 = "6f5a3467ed9caec4795bf78cd476507d9f870c7d57b86c945fcb338126772ffc",
                },
            },
        },
        windows = {
            source = "https://github.com/oven-sh/bun/releases/download/bun-v${version}/bun-windows-${arch_alias}.zip",
            ["latest"] = {ref = "1.4.5"},
            ["1.4.5"] = {
                arch_alias = {x86_64 = "x64-baseline", aarch64 = "aarch64"},
                sha256 = {
                    x86_64 = "3c081c73865e7a3453a9d514cc2ba3d699880621bcf67bb17241ff5194cb1d4b",
                    aarch64 = "41f57d49c3c6811888d9633c569e40b4eb1f7e92b5e5336e3abd3af03187d77a",
                },
            },
            ["1.3.11"] = {
                arch_alias = {x86_64 = "x64-baseline", aarch64 = "aarch64"},
                sha256 = {
                    x86_64 = "9d0e0f923e9626f3bc6044fc32e0d3ab29039aea753f5678ef8801cf26f75288",
                    aarch64 = "c7f661d7529ec3f2fdfc1eac39a760c65f526955bce06b74859c532cb4bf00d7",
                },
            },
        },
    }
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

-- Each upstream zip contains bun under its target-specific top-level folder.
function install()
    local extracted = pkginfo.install_file():replace(".zip", "")
    local executable = is_host("windows") and "bun.exe" or "bun"
    local source = path.join(extracted, executable)
    if not os.isfile(source) then
        return false
    end

    os.tryrm(pkginfo.install_dir())
    os.mkdir(pkginfo.install_dir())
    local target = path.join(pkginfo.install_dir(), executable)
    os.mv(source, target)
    os.tryrm(extracted)
    return os.isfile(target)
end

function config()
    xvm.add("bun", {bindir = pkginfo.install_dir()})
    return true
end

function uninstall()
    xvm.remove("bun")
    return true
end
