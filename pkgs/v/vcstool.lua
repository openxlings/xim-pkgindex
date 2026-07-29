package = {
    spec = "1",

    name = "vcstool",
    description = "Version control system tool for multiple repos (ROS vcstool)",
    homepage = "https://github.com/dirk-thomas/vcstool",
    maintainers = {"Dirk Thomas"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/dirk-thomas/vcstool",
    docs = "https://github.com/dirk-thomas/vcstool/blob/master/README.rst",

    type = "package",
    archs = {"x86_64", "arm64"},
    status = "stable",
    categories = {"ros", "vcs", "robotics"},
    keywords = {"ros", "vcstool", "vcs", "git", "robotics", "ros2"},

    programs = {"vcs"},
    xvm_enable = true,

    xpm = {
        linux = {
            deps = {"python"},
            ["latest"] = { ref = "0.3.0" },
            ["0.3.0"] = {
                url = "https://files.pythonhosted.org/packages/6c/d5/4aca2c05481a0fb74bd2660b14b0dd0ea975e4f38bc150511a64c55af986/vcstool-0.3.0-py3-none-any.whl",
                sha256 = "ad73309e83b67344efb1f6cf9f556b2d75e297b4b137f643378ba75f930a6ecb",
            },
        },
        macosx = {
            deps = {"python"},
            ["latest"] = { ref = "0.3.0" },
            ["0.3.0"] = {
                url = "https://files.pythonhosted.org/packages/6c/d5/4aca2c05481a0fb74bd2660b14b0dd0ea975e4f38bc150511a64c55af986/vcstool-0.3.0-py3-none-any.whl",
                sha256 = "ad73309e83b67344efb1f6cf9f556b2d75e297b4b137f643378ba75f930a6ecb",
            },
        },
        windows = {
            deps = {"python"},
            ["latest"] = { ref = "0.3.0" },
            ["0.3.0"] = {
                url = "https://files.pythonhosted.org/packages/6c/d5/4aca2c05481a0fb74bd2660b14b0dd0ea975e4f38bc150511a64c55af986/vcstool-0.3.0-py3-none-any.whl",
                sha256 = "ad73309e83b67344efb1f6cf9f556b2d75e297b4b137f643378ba75f930a6ecb",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.system")

-- Python venv lays out its entry-point scripts under "bin/" on POSIX and
-- "Scripts/" on Windows; select the right subdir instead of hardcoding.
local function __venv_bindir()
    local sub = is_host("windows") and "Scripts" or "bin"
    return path.join(pkginfo.install_dir(), sub)
end

function install()
    os.tryrm(pkginfo.install_dir())

    -- create venv and install vcstool into it (standard pip/pipx approach)
    system.exec(string.format([[python3 -m venv "%s"]], pkginfo.install_dir()))

    if is_host("windows") then
        -- Windows: xlings' Lua runtime does not expose os.execv, so the
        -- only way to run pip from the venv is to build a command string
        -- that xmake hands to a Windows shell. Several things bite when
        -- we do that through os.exec directly:
        --   * path.join returns mixed-separator strings that cmd.exe
        --     mis-parses as switches
        --   * CreateProcess won't auto-append .exe for an absolute path
        --   * cmd.exe interprets `<` in a quoted arg as stdin redirect
        -- Driving the install through PowerShell with single-quoted
        -- arguments sidesteps all three. Any `'` in a spec would need
        -- `''` escaping, but our specs are plain package names.
        local venv = (pkginfo.install_dir():gsub("/", "\\"))
        local wheel = (pkginfo.install_file():gsub("/", "\\"))
        local py = venv .. "\\Scripts\\python.exe"
        system.exec(string.format(
            [[powershell -NoProfile -ExecutionPolicy Bypass -Command ]] ..
            [["& '%s' -m pip install 'setuptools<71'; ]] ..
            [[if ($LASTEXITCODE) { exit $LASTEXITCODE }; ]] ..
            [[& '%s' -m pip install '%s'"]],
            py, py, wheel))
    else
        local venv_pip = path.join(__venv_bindir(), "pip")
        -- vcstool uses pkg_resources which was removed in setuptools >= 71
        system.exec(string.format([["%s" install "setuptools<71"]], venv_pip))
        system.exec(string.format([["%s" install "%s"]], venv_pip, pkginfo.install_file()))
    end

    return true
end

function config()
    xvm.add("vcs", { bindir = __venv_bindir() })
    -- Group placeholder: the binary is `vcs` (upstream's CLI command) but the
    -- package name is `vcstool`. Empty placeholder so install
    -- detection (`xvm info vcstool`) finds an entry.
    xvm.add("vcstool", { type = "group" })
    return true
end

function uninstall()
    xvm.remove("vcs")
    xvm.remove("vcstool")
    return true
end
