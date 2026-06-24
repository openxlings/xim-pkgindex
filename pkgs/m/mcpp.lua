package = {
    spec = "1",

    name = "mcpp",
    description = "A modern C++ build tool with module support, dependency/toolchain management, package indexing, and packaging",

    authors = {"sunrisepeak"},
    maintainers = {"https://github.com/mcpp-community/mcpp/graphs/contributors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/mcpp-community/mcpp",
    homepage = "https://github.com/mcpp-community/mcpp",
    docs = "https://github.com/mcpp-community/mcpp#readme",

    -- xim pkg info
    type = "package",
    archs = {"x86_64", "arm64", "aarch64"},
    status = "dev", -- 0.0.x: upstream is pre-1.0, expect breaking changes
    categories = {"build-tool", "cpp"},
    keywords = {"cpp", "c++", "build", "module", "package-manager"},

    programs = { "mcpp" },

    xvm_enable = true,

    -- Mirrored at xlings-res/mcpp (byte-identical to upstream
    -- mcpp-community/mcpp release artifacts, renamed to
    -- xlings-res convention `mcpp-<ver>-<platform>-<arch>.<ext>`).
    --
    -- XLINGS_RES sentinel resolves to:
    --   GLOBAL → github.com/xlings-res/mcpp/releases/download/<ver>/...
    --   CN     → gitcode.com/xlings-res/mcpp/releases/download/<ver>/...
    --
    -- Each tarball ships under `mcpp-<ver>-<platform>-<arch>/` and contains:
    --   bin/mcpp        — statically linked binary
    --   mcpp            — shell launcher → exec bin/mcpp
    --   LICENSE, README.md
    -- xvm registers `bindir = <install>/bin` so the binary is invoked
    -- directly; the shell launcher is only useful from the bundle root.
    xpm = {
        linux = {
            url_template = "https://github.com/mcpp-community/mcpp/releases/download/v{version}/mcpp-{version}-linux-x86_64.tar.gz",
            ["latest"] = { ref = "0.0.62" },
            ["0.0.62"] = "XLINGS_RES",
            ["0.0.61"] = "XLINGS_RES",
            ["0.0.60"] = "XLINGS_RES",
            ["0.0.59"] = "XLINGS_RES",
            ["0.0.58"] = "XLINGS_RES",
            ["0.0.57"] = "XLINGS_RES",
            ["0.0.56"] = "XLINGS_RES",
            ["0.0.55"] = "XLINGS_RES",
            ["0.0.54"] = "XLINGS_RES",
            ["0.0.53"] = "XLINGS_RES",
            ["0.0.52"] = "XLINGS_RES",
            ["0.0.51"] = "XLINGS_RES",
            ["0.0.50"] = "XLINGS_RES",
            ["0.0.49"] = "XLINGS_RES",
            ["0.0.48"] = "XLINGS_RES",
            ["0.0.46"] = "XLINGS_RES",
            ["0.0.45"] = "XLINGS_RES",
            ["0.0.44"] = "XLINGS_RES",
            ["0.0.43"] = "XLINGS_RES",
            ["0.0.42"] = "XLINGS_RES",
            ["0.0.41"] = "XLINGS_RES",
            ["0.0.38"] = "XLINGS_RES",
            ["0.0.37"] = "XLINGS_RES",
            ["0.0.36"] = "XLINGS_RES",
            ["0.0.35"] = "XLINGS_RES",
            ["0.0.34"] = "XLINGS_RES",
            ["0.0.33"] = "XLINGS_RES",
            ["0.0.31"] = "XLINGS_RES",
            ["0.0.30"] = "XLINGS_RES",
            ["0.0.29"] = "XLINGS_RES",
            ["0.0.28"] = "XLINGS_RES",
            ["0.0.27"] = "XLINGS_RES",
            ["0.0.26"] = "XLINGS_RES",
            ["0.0.25"] = "XLINGS_RES",
            ["0.0.24"] = "XLINGS_RES",
            ["0.0.22"] = "XLINGS_RES",
            ["0.0.21"] = "XLINGS_RES",
            ["0.0.20"] = "XLINGS_RES",
            ["0.0.19"] = "XLINGS_RES",
            ["0.0.17"] = "XLINGS_RES",
            ["0.0.16"] = "XLINGS_RES",
            ["0.0.15"] = "XLINGS_RES",
            ["0.0.14"] = "XLINGS_RES",
            ["0.0.13"] = "XLINGS_RES",
            ["0.0.11"] = "XLINGS_RES",
            ["0.0.10"] = "XLINGS_RES",
            ["0.0.9"] = "XLINGS_RES",
            ["0.0.8"] = "XLINGS_RES",
            ["0.0.7"] = "XLINGS_RES",
            ["0.0.6"] = "XLINGS_RES",
            ["0.0.5"] = "XLINGS_RES",
            ["0.0.4"] = "XLINGS_RES",
            ["0.0.3"] = "XLINGS_RES",
            ["0.0.2"] = "XLINGS_RES",
            ["0.0.1"] = "XLINGS_RES",
        },
        macosx = {
            ["latest"] = { ref = "0.0.62" },
            ["0.0.62"] = "XLINGS_RES",
            ["0.0.61"] = "XLINGS_RES",
            ["0.0.60"] = "XLINGS_RES",
            ["0.0.59"] = "XLINGS_RES",
            ["0.0.58"] = "XLINGS_RES",
            ["0.0.57"] = "XLINGS_RES",
            ["0.0.56"] = "XLINGS_RES",
            ["0.0.55"] = "XLINGS_RES",
            ["0.0.54"] = "XLINGS_RES",
            ["0.0.53"] = "XLINGS_RES",
            ["0.0.52"] = "XLINGS_RES",
            ["0.0.51"] = "XLINGS_RES",
            ["0.0.50"] = "XLINGS_RES",
            ["0.0.49"] = "XLINGS_RES",
            ["0.0.48"] = "XLINGS_RES",
            ["0.0.46"] = "XLINGS_RES",
            ["0.0.45"] = "XLINGS_RES",
            ["0.0.44"] = "XLINGS_RES",
            ["0.0.43"] = "XLINGS_RES",
            ["0.0.42"] = "XLINGS_RES",
            ["0.0.41"] = "XLINGS_RES",
            ["0.0.38"] = "XLINGS_RES",
            ["0.0.37"] = "XLINGS_RES",
            ["0.0.36"] = "XLINGS_RES",
            ["0.0.35"] = "XLINGS_RES",
            ["0.0.34"] = "XLINGS_RES",
            ["0.0.33"] = "XLINGS_RES",
            ["0.0.31"] = "XLINGS_RES",
            ["0.0.30"] = "XLINGS_RES",
            ["0.0.29"] = "XLINGS_RES",
            ["0.0.28"] = "XLINGS_RES",
            ["0.0.27"] = "XLINGS_RES",
            ["0.0.26"] = "XLINGS_RES",
            ["0.0.25"] = "XLINGS_RES",
            ["0.0.24"] = "XLINGS_RES",
            ["0.0.22"] = "XLINGS_RES",
            ["0.0.21"] = "XLINGS_RES",
            ["0.0.20"] = "XLINGS_RES",
            ["0.0.19"] = "XLINGS_RES",
            ["0.0.17"] = "XLINGS_RES",
            ["0.0.16"] = "XLINGS_RES",
        },
        windows = {
            ["latest"] = { ref = "0.0.62" },
            ["0.0.62"] = "XLINGS_RES",
            ["0.0.61"] = "XLINGS_RES",
            ["0.0.60"] = "XLINGS_RES",
            ["0.0.59"] = "XLINGS_RES",
            ["0.0.58"] = "XLINGS_RES",
            ["0.0.57"] = "XLINGS_RES",
            ["0.0.56"] = "XLINGS_RES",
            ["0.0.55"] = "XLINGS_RES",
            ["0.0.54"] = "XLINGS_RES",
            ["0.0.53"] = "XLINGS_RES",
            ["0.0.52"] = "XLINGS_RES",
            ["0.0.51"] = "XLINGS_RES",
            ["0.0.50"] = "XLINGS_RES",
            ["0.0.49"] = "XLINGS_RES",
            ["0.0.48"] = "XLINGS_RES",
            ["0.0.46"] = "XLINGS_RES",
            ["0.0.45"] = "XLINGS_RES",
            ["0.0.44"] = "XLINGS_RES",
            ["0.0.43"] = "XLINGS_RES",
            ["0.0.42"] = "XLINGS_RES",
            ["0.0.41"] = "XLINGS_RES",
            ["0.0.38"] = "XLINGS_RES",
            ["0.0.37"] = "XLINGS_RES",
            ["0.0.36"] = "XLINGS_RES",
            ["0.0.35"] = "XLINGS_RES",
            ["0.0.34"] = "XLINGS_RES",
            ["0.0.33"] = "XLINGS_RES",
            ["0.0.31"] = "XLINGS_RES",
            ["0.0.30"] = "XLINGS_RES",
            ["0.0.29"] = "XLINGS_RES",
            ["0.0.28"] = "XLINGS_RES",
            ["0.0.27"] = "XLINGS_RES",
            ["0.0.26"] = "XLINGS_RES",
            ["0.0.25"] = "XLINGS_RES",
            ["0.0.24"] = "XLINGS_RES",
            ["0.0.22"] = "XLINGS_RES",
            ["0.0.21"] = "XLINGS_RES",
            ["0.0.20"] = "XLINGS_RES",
            ["0.0.19"] = "XLINGS_RES",
            ["0.0.17"] = "XLINGS_RES",
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

local function mcpp_bin()
    local exe = "mcpp"
    if os.host() == "windows" then
        exe = "mcpp.exe"
    end
    return path.join(pkginfo.install_dir(), "bin", exe)
end

local function ensure_runtime_dir()
    if os.isfile(mcpp_bin()) then
        return true
    end

    local archive = pkginfo.install_file()
    local mcpp_dir = archive
        :replace(".tar.gz", "")
        :replace(".zip", "")
    local runtime_dir = path.join(path.directory(archive), path.filename(mcpp_dir))
    if os.isdir(runtime_dir) then
        mcpp_dir = runtime_dir
    end
    os.tryrm(pkginfo.install_dir())
    os.mv(mcpp_dir, pkginfo.install_dir())
    return os.isfile(mcpp_bin())
end

function install()
    return ensure_runtime_dir()
end

function config()
    ensure_runtime_dir()
    xvm.add("mcpp", { bindir = path.join(pkginfo.install_dir(), "bin") })
    return true
end

function uninstall()
    xvm.remove("mcpp")
    return true
end
