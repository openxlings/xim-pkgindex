package = {
    spec = "1",

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

    xpm = {
        linux = {
            -- node/npm are needed at install time only (the install
            -- hook calls `npm install bun@<ver>`); after install the
            -- bun native binary is self-contained. glibc is the actual
            -- runtime dep — bun's prebuilt is dynamically linked
            -- (NEEDED libc.so.6 / libdl.so.2 / libm.so.6 /
            -- libpthread.so.0; no libgcc_s/libstdc++).
            deps = {
                runtime = { "xim:glibc@>=2.39" },
                build   = { "xim:node", "xim:npm" },
            },
            ["latest"] = { ref = "1.3.11" },
            ["1.3.11"] = { ref = "1.3.11" },
        },
        macosx = {
            deps = {
                build = { "xim:node", "xim:npm" },
            },
            ["latest"] = { ref = "1.3.11" },
            ["1.3.11"] = { ref = "1.3.11" },
        },
        windows = {
            deps = {
                build = { "xim:node", "xim:npm" },
            },
            ["latest"] = { ref = "1.3.11" },
            ["1.3.11"] = { ref = "1.3.11" },
        },
    }
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    os.tryrm(pkginfo.install_dir())
    os.mkdir(pkginfo.install_dir())

    local npm_install = string.format(
        [[npm install --prefix "%s" --no-fund --no-audit "bun@%s"]],
        pkginfo.install_dir(),
        pkginfo.version()
    )
    os.exec(npm_install)

    return true
end

function config()
    local bindir = path.join(pkginfo.install_dir(), "node_modules", ".bin")
    local alias = "bun"

    if is_host("windows") then
        alias = "bun.cmd"
    end

    xvm.add("bun", { bindir = bindir, alias = alias })
    return true
end

function uninstall()
    xvm.remove("bun")
    return true
end
