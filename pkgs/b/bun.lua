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
            -- Keep Node for the immutable 1.3.11 npm-backed package. Newer
            -- releases install directly from the native upstream archive.
            deps = {
                runtime = {"xim:glibc@>=2.39"},
                build = {"xim:node"},
            },
            ["latest"] = {ref = "1.4.5"},
            ["1.4.5"] = {
                x86_64 = {
                    url = "https://github.com/oven-sh/bun/releases/download/bun-v1.4.5/bun-linux-x64-baseline.zip",
                    sha256 = "dcb23a18a1c2fff12d57bcef696dbbb42eb67fde29f43816ecb595459a24c463",
                },
                aarch64 = {
                    url = "https://github.com/oven-sh/bun/releases/download/bun-v1.4.5/bun-linux-aarch64.zip",
                    sha256 = "18656a3bf0ea5641f5796ae4213b75255579a70a0fded2f337933785568cdf84",
                },
            },
            ["1.3.11"] = { ref = "1.3.11" },
        },
        macosx = {
            deps = {build = {"xim:node"}},
            ["latest"] = {ref = "1.4.5"},
            ["1.4.5"] = {
                x86_64 = {
                    url = "https://github.com/oven-sh/bun/releases/download/bun-v1.4.5/bun-darwin-x64-baseline.zip",
                    sha256 = "fb0121739a7e80e7511b6bfe4d2116422b48ba18a013acadef0c425348e95891",
                },
                aarch64 = {
                    url = "https://github.com/oven-sh/bun/releases/download/bun-v1.4.5/bun-darwin-aarch64.zip",
                    sha256 = "b5d6bc2e13caf14e57c89661e89efd073ff16165b41bfe43882616410609cd10",
                },
            },
            ["1.3.11"] = { ref = "1.3.11" },
        },
        windows = {
            deps = {build = {"xim:node"}},
            ["latest"] = {ref = "1.4.5"},
            ["1.4.5"] = {
                x86_64 = {
                    url = "https://github.com/oven-sh/bun/releases/download/bun-v1.4.5/bun-windows-x64-baseline.zip",
                    sha256 = "3c081c73865e7a3453a9d514cc2ba3d699880621bcf67bb17241ff5194cb1d4b",
                },
                aarch64 = {
                    url = "https://github.com/oven-sh/bun/releases/download/bun-v1.4.5/bun-windows-aarch64.zip",
                    sha256 = "41f57d49c3c6811888d9633c569e40b4eb1f7e92b5e5336e3abd3af03187d77a",
                },
            },
            ["1.3.11"] = { ref = "1.3.11" },
        },
    }
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

-- Each upstream zip contains bun under its target-specific top-level folder.
function install()
    local version = pkginfo.version()
    local install_dir = pkginfo.install_dir()

    -- Preserve the npm-backed layout for the immutable published 1.3.11 entry.
    if version == "1.3.11" then
        os.tryrm(install_dir)
        os.mkdir(install_dir)

        local npm_install = string.format(
            [[npm install --prefix "%s" --no-fund --no-audit "bun@%s"]],
            install_dir,
            version
        )
        os.exec(npm_install)

        local selected = path.join(install_dir, "node_modules", "bun", "bin", "bun.exe")
        if not os.isfile(selected) then
            return false
        end
        os.tryrm(path.join(install_dir, "node_modules", "@oven"))
        return true
    end

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
    if pkginfo.version() == "1.3.11" then
        local bindir = path.join(pkginfo.install_dir(), "node_modules", ".bin")
        local alias = is_host("windows") and "bun.cmd" or "bun"
        xvm.add("bun", {bindir = bindir, alias = alias})
        return true
    end

    xvm.add("bun", {bindir = pkginfo.install_dir()})
    return true
end

function uninstall()
    xvm.remove("bun")
    return true
end
