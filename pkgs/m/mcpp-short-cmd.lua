package = {
    spec = "2",

    name = "mcpp-short-cmd",
    description = "Short command aliases for mcpp (mp/mbuild/mrun/mtest/...)",

    homepage = "https://github.com/mcpp-community/mcpp",
    maintainers = {"xim team"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/mcpp-community/mcpp",
    docs = "https://github.com/mcpp-community/mcpp#readme",

    -- xim pkg info
    type = "package",
    status = "dev", -- follows mcpp's own CLI surface, which is pre-1.0
    categories = {"cpp", "build-tool", "shortcut"},
    keywords = {"mcpp", "alias", "shortcut", "cli", "cpp"},

    programs = {
        "mp",
        "mnew", "mbuild", "mrun", "mtest", "mclean",
        "madd", "mremove", "mupdate", "msearch", "mpublish", "mpack",
        "mexpkg", "mxparse",
        "mtinstall", "mtlist", "mtdefault",
        "mcdir", "mclist", "mcinfo", "mcgc",
        "milist", "miadd", "miremove", "miupdate",
        "msdoctor", "msenv", "msconfig", "msversion", "msexplain",
    },

    xvm_enable = true,

    -- Payload-free package: there is nothing to download. The whole package is
    -- the set of xvm shims registered in config(), each one an alias onto the
    -- `mcpp` shim (not a hardcoded binary path), so `xlings use mcpp <ver>`
    -- keeps switching the version the short commands drive.
    xpm = {
        linux = {
            deps = { "xim:mcpp" },
            ["latest"] = { ref = "0.0.1" },
            ["0.0.1"] = {},
        },
        macosx = {
            deps = { "xim:mcpp" },
            ["latest"] = { ref = "0.0.1" },
            ["0.0.1"] = {},
        },
        windows = {
            deps = { "xim:mcpp" },
            ["latest"] = { ref = "0.0.1" },
            ["0.0.1"] = {},
        },
    },
}

import("xim.libxpkg.log")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

-- Naming rule: keep one letter for every word but the last, and the last word
-- in full — `mcpp self doctor` -> m + s + doctor -> `msdoctor`. `mp` is the
-- bare `mcpp` entry point (the one name the rule cannot derive).
local SHORT_CMDS = {
    { "mp",        "" },              -- mcpp

    -- project lifecycle
    { "mnew",      "new" },
    { "mbuild",    "build" },
    { "mrun",      "run" },
    { "mtest",     "test" },
    { "mclean",    "clean" },

    -- dependencies / registry
    { "madd",      "add" },
    { "mremove",   "remove" },
    { "mupdate",   "update" },
    { "msearch",   "search" },
    { "mpublish",  "publish" },
    { "mpack",     "pack" },
    { "mexpkg",    "emit xpkg" },
    { "mxparse",   "xpkg parse" },

    -- resource management
    { "mtinstall", "toolchain install" },
    { "mtlist",    "toolchain list" },
    { "mtdefault", "toolchain default" },
    { "mcdir",     "cache dir" },
    { "mclist",    "cache list" },
    { "mcinfo",    "cache info" },
    { "mcgc",      "cache gc" },
    { "milist",    "index list" },
    { "miadd",     "index add" },
    { "miremove",  "index remove" },
    { "miupdate",  "index update" },

    -- mcpp itself
    { "msdoctor",  "self doctor" },
    { "msenv",     "self env" },
    { "msconfig",  "self config" },
    { "msversion", "self version" },
    { "msexplain", "self explain" },
}

function install()
    -- Nothing to unpack: the package ships no files.
    return true
end

function config()
    -- Package-name placeholder so `xvm info mcpp-short-cmd` / `xlings remove`
    -- find an entry. `group` avoids creating a bogus `mcpp-short-cmd` shim.
    xvm.add(package.name, { type = "group" })

    local binding = package.name .. "@" .. pkginfo.version()
    for _, entry in ipairs(SHORT_CMDS) do
        local short, sub = entry[1], entry[2]
        local alias = (sub == "") and "mcpp" or ("mcpp " .. sub)
        xvm.add(short, { alias = alias, binding = binding })
    end

    log.info("registered %d mcpp short commands (mp, mbuild, mrun, ...)", #SHORT_CMDS)
    return true
end

function uninstall()
    for _, entry in ipairs(SHORT_CMDS) do
        xvm.remove(entry[1])
    end
    xvm.remove(package.name)
    return true
end
