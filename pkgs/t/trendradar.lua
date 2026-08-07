package = {
    spec = "1",

    name = "trendradar",
    description = "AI-driven public opinion and trend monitor with multi-platform aggregation, RSS, and smart alerts",
    homepage = "https://sansan0.github.io/TrendRadar/",
    maintainers = {"sansan0"},
    licenses = {"GPL-3.0"},
    repo = "https://github.com/sansan0/TrendRadar",
    docs = "https://github.com/sansan0/TrendRadar#readme",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"ai", "rss", "news", "monitoring"},
    keywords = {"trendradar", "trend", "hot-news", "rss", "mcp", "ai", "alerts"},

    programs = {"trendradar", "trendradar-mcp"},
    xvm_enable = true,

    xpm = {
        linux = {
            deps = {"xim:python"},
            ["latest"] = { ref = "6.6.1" },
            ["6.6.1"] = {
                url = "https://github.com/sansan0/TrendRadar/archive/refs/tags/v6.6.1.tar.gz",
                sha256 = "1e7ffcfdb6fca901a0de61fb20e2d27375cb00511ffb5cb88a07206a9141b8f5",
            },
        },
        macosx = {
            ["latest"] = { ref = "6.6.1" },
            ["6.6.1"] = {
                url = "https://github.com/sansan0/TrendRadar/archive/refs/tags/v6.6.1.tar.gz",
                sha256 = "1e7ffcfdb6fca901a0de61fb20e2d27375cb00511ffb5cb88a07206a9141b8f5",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

function __source_dir()
    return path.join(pkginfo.install_dir(), "source")
end

function __venv_dir()
    return path.join(pkginfo.install_dir(), "venv")
end

function __venv_bindir()
    return path.join(__venv_dir(), "bin")
end

function __archive_source_dir()
    local archive = pkginfo.install_file()
    return path.join(path.directory(archive), "TrendRadar-" .. pkginfo.version())
end

function __subos_bindir()
    local xlings_home = os.getenv("XLINGS_HOME") or path.join(os.getenv("HOME"), ".xlings")
    return path.join(xlings_home, "subos", "default", "bin")
end

function __write_wrapper(name)
    local wrapper = path.join(pkginfo.install_dir(), "bin", name)
    local target = path.join(__venv_bindir(), name)
    local script = string.format([[#!/usr/bin/env bash
cd "%s" || exit $?
exec "%s" "$@"
]], __source_dir(), target)
    io.writefile(wrapper, script)
    system.exec(string.format([[chmod +x "%s"]], wrapper))
end

function __write_subos_shim(name)
    local shim = path.join(__subos_bindir(), name)
    local target = path.join(pkginfo.install_dir(), "bin", name)
    os.mkdir(__subos_bindir())
    os.tryrm(shim)
    system.exec(string.format([[ln -s "%s" "%s"]], target, shim))
end

function __remove_subos_shim(name)
    os.tryrm(path.join(__subos_bindir(), name))
end

function __xvm_add()
    local bindir = path.join(pkginfo.install_dir(), "bin")
    xvm.add("trendradar", {
        bindir = bindir,
        alias = "trendradar",
    })
    xvm.add("trendradar-mcp", {
        bindir = bindir,
        alias = "trendradar-mcp",
        binding = "trendradar@" .. pkginfo.version(),
    })
end

function install()
    os.tryrm(pkginfo.install_dir())
    os.mkdir(pkginfo.install_dir())

    os.cp(__archive_source_dir(), __source_dir(), {
        symlink = true,
        verbose = true,
    })

    system.exec(string.format([[python3 -m venv "%s"]], __venv_dir()))
    local venv_pip = path.join(__venv_bindir(), "pip")
    system.exec(string.format([["%s" install --upgrade pip]], venv_pip))
    system.exec(string.format([["%s" install "%s"]], venv_pip, __source_dir()))

    os.mkdir(path.join(pkginfo.install_dir(), "bin"))
    __write_wrapper("trendradar")
    __write_wrapper("trendradar-mcp")

    -- Registration lives in config(), which xlings runs right after this, and
    -- calling __xvm_add() here too registered the same name and version twice:
    --
    --   [error] duplicate exact registration node
    --           at: trendradar@6.6.1   field: /nodes/2
    --
    -- Pre-existing since the package was added (#81) and platform-independent
    -- -- reproduced on Linux as well as macOS. It stayed invisible because this
    -- recipe had never been in a PR's changed set, so the install test had
    -- never run it.
    __write_subos_shim("trendradar")
    __write_subos_shim("trendradar-mcp")
    return true
end

function config()
    __xvm_add()
    return true
end

function uninstall()
    xvm.remove("trendradar")
    xvm.remove("trendradar-mcp")
    __remove_subos_shim("trendradar")
    __remove_subos_shim("trendradar-mcp")
    return true
end
