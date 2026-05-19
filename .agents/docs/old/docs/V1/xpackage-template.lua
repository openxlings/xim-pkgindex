package = {
    spec = "1",

    -- base info
    name = "package-name",
    description = "Package description",
    type = "package", -- package, script, template, config

    homepage = "https://example.com",
    authors = {"Author Name"},
    maintainers = {"Maintainer Name"},
    contributors = "https://github.com/xxx/graphs/contributors",
    licenses = {"MIT"},
    repo = "https://example.com/repo",
    docs = "https://example.com/docs",

    -- xim pkg info
    archs = {"x86_64"},
    status = "stable", -- dev, stable, deprecated
    categories = {"category1", "category2"},
    keywords = {"keyword1", "keyword2"},

    programs = {"program1"},

    -- xvm: xlings version management
    xvm_enable = true,

    xpm = {
        windows = {
            deps = {"dep1", "dep2"},
            ["latest"] = { ref = "1.0.0" },
            ["1.0.0"] = {
                url = "https://example.com/pkg-1.0.0-windows.zip",
                sha256 = nil
            },
        },
        linux = {
            ["latest"] = { ref = "1.0.0" },
            ["1.0.0"] = "XLINGS_RES",
        },
        macosx = {
            ["latest"] = { ref = "1.0.0" },
            ["1.0.0"] = "XLINGS_RES",
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function installed()
    return os.iorun("program1 --version")
end

function install()
    os.mv("program1", pkginfo.install_dir())
    return true
end

function config()
    xvm.add("package-name")
    return true
end

function uninstall()
    xvm.remove("package-name")
    return true
end
