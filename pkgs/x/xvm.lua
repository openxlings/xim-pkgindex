package = {
    spec = "1",
    -- base info
    name = "xvm",
    description = "a simple and generic version management tool",

    authors = {"sunrisepeak"},
    maintainers = {"d2learn"},
    contributors = "https://github.com/openxlings/xlings/graphs/contributors",
    licenses = {"Apache-2.0"},
    repo = "https://github.com/openxlings/xlings",

    -- xim pkg info
    type = "package",
    archs = {"x86_64"},
    status = "stable", -- dev, stable, deprecated
    categories = {"tools", "version-management"},
    keywords = {"rust", "cross-platform", "version-management"},

    xpm = {
        windows = {
            ["latest"] = { ref = "0.0.5" },
            ["0.0.2"] = "XLINGS_RES",
            ["0.0.3"] = "XLINGS_RES",
            ["0.0.4"] = "XLINGS_RES",
            ["0.0.5"] = "XLINGS_RES",
        },
        linux = {
            ["latest"] = { ref = "0.0.5" },
            ["0.0.2"] = {
                url = "XLINGS_RES",
                sha256 = { x86_64 = "fa66931ddab9cbaa5427f6c7e125b21daa64cae20bc8a2709c65f9617110c6b2" },
            },
            ["0.0.3"] = {
                url = "XLINGS_RES",
                sha256 = { x86_64 = "c7068ebbd5b24ab27595bc335dc99c5d6ad67aebef8f11cbc3fb882ceb58f5be" },
            },
            ["0.0.4"] = {
                url = "XLINGS_RES",
                sha256 = { x86_64 = "975c9f16b3697853c8e16561ec90fdeff245c23914c4426472e65e840600576b" },
            },
            ["0.0.5"] = {
                url = "XLINGS_RES",
                sha256 = { x86_64 = "8fc2a13933124a5baf1322bbc0d7aaf9891a690cc1262767906c7775c89cc017" },
            },
        },
        macosx = {
            ["latest"] = { ref = "0.0.5" },
            ["0.0.2"] = "XLINGS_RES",
            ["0.0.3"] = "XLINGS_RES",
            ["0.0.4"] = "XLINGS_RES",
            ["0.0.5"] = "XLINGS_RES",
        },
    },
}

import("xim.libxpkg.system")

local xvm_file = {
    windows = "xvm.exe",
    linux = "xvm",
    macosx = "xvm"
}

local xvm_shim_file = {
    windows = "xvm-shim.exe",
    linux = "xvm-shim",
    macosx = "xvm-shim"
}

function installed()
    local bindir = system.bindir()
    local xvm_bin = path.join(bindir, xvm_file[os.host()])
    if os.isfile(xvm_bin) then
        return os.iorun(xvm_bin .. " --version")
    end
    return false
end

function install()
    local bindir = system.bindir()
    os.mv(xvm_file[os.host()], bindir)
    os.mv(xvm_shim_file[os.host()], bindir)
    return true
end

function uninstall()
    local bindir = system.bindir()
    -- remove cache files
    os.tryrm(xvm_file[os.host()])
    os.tryrm(xvm_shim_file[os.host()])
    -- remove xvm and xvm-shim from bindir
    os.tryrm(path.join(bindir, xvm_file[os.host()]))
    os.tryrm(path.join(bindir, xvm_shim_file[os.host()]))
    return true
end
