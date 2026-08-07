package = {
    spec = "1",
    homepage = "https://www.npmjs.com",
    name = "npm",
    description = "The package manager for JavaScript",
    licenses = {"Artistic License 2.0"},
    type = "package",
    repo = "https://github.com/npm/cli",
    docs = "https://docs.npmjs.com/cli",

    -- xim pkg info
    archs = {"x86_64"},
    status = "stable", -- dev, stable, deprecated
    categories = {"package-manager", "javascript"},

    xpm = {
        -- os_common
    },
}

os_common = {
    deps = { "xim:node" },
    ["latest"] = { ref = "11.2.0" },
    ["11.2.0"] = { },
    ["11.0.0"] = { },
    ["10.9.2"] = { },
    ["9.9.4"] = { },
    ["8.19.4"] = { },
}

package.xpm.linux = os_common
package.xpm.windows = os_common
package.xpm.macosx = os_common

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

function install()
    local npm_installcmd_template = "npm install -g npm@%s --prefix %s"
    os.iorun(string.format(npm_installcmd_template, pkginfo.version(), pkginfo.install_dir()))
    return true
end

function config()
    log.debug("config xvm...")

    config = {}
    if os.host() == "windows" then
        config.alias = "npm.cmd"
        --config.bindir = pkginfo.install_dir() -- default
    else
        config.bindir = path.join(pkginfo.install_dir(), "bin")
    end

    xvm.add("npm", config)
    return true
end

function uninstall()
    xvm.remove("npm")
    return true
end