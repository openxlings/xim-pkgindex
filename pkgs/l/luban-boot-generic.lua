-- luban-boot-generic: how a Luban image boots on a machine (xlings: Luban OS
-- design part 2 §2.4) -- the generic kernel (linux-kernel), limine, and a
-- console on the screen and the first serial port. The default of the Luban
-- editions; `luban export box x.iso --boot generic`. Data, written by
-- libs/luban.lua.
package = {
    spec = "2",
    name = "luban-boot-generic",
    description = "Luban boot profile for machines: the generic kernel, limine, screen and serial console",
    homepage = "https://github.com/openxlings/xlings",
    licenses = {"Apache-2.0"},
    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"system", "boot", "luban"},
    keywords = {"luban", "boot", "generic", "kernel", "iso"},
    xpm = {
        linux = {
            deps = { runtime = { "xim:linux-kernel@6.8.0-71", "xim:limine@12.9.3" } },
            ["latest"] = { ref = "2026.10.10.1" },
            ["2026.10.10.1"] = {},
        },
    },
}

import("xim.pkgindex.luban")
import("xim.libxpkg.xvm")

function install()
    return luban.boot([[
{ "profile": "generic", "release": "6.8.0-71-generic",
  "cmdline": ["console=tty0", "console=ttyS0"] }
]])
end

-- Registered as installed (`xlings list`, `remove`); nothing to run.
function config()
    xvm.add(package.name)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
