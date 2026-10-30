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
            -- node is needed at install time only (it also provides npm);
            -- after install the selected bun native binary is self-contained.
            -- glibc is the actual runtime dep. Bun's npm package keeps
            -- @oven/* optional platform payloads, including musl variants;
            -- install() removes them after postinstall has copied the selected
            -- binary, because CI scans every ELF in the payload.
            deps = {
                runtime = { "xim:glibc@>=2.39" },
                build   = { "xim:node" },
            },
            ["latest"] = { ref = "1.3.11" },
            ["1.3.11"] = { ref = "1.3.11" },
        },
        macosx = {
            deps = {
                build = { "xim:node" },
            },
            ["latest"] = { ref = "1.3.11" },
            ["1.3.11"] = { ref = "1.3.11" },
        },
        windows = {
            deps = {
                build = { "xim:node" },
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

    local selected = path.join(pkginfo.install_dir(), "node_modules", "bun", "bin", "bun.exe")
    if not os.isfile(selected) then
        return false
    end
    os.tryrm(path.join(pkginfo.install_dir(), "node_modules", "@oven"))
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
