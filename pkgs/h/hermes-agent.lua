package = {
    spec = "1",

    name = "hermes-agent",
    description = "The self-improving AI agent from Nous Research — creates skills from experience, improves them during use, and runs anywhere",
    homepage = "https://hermes-agent.nousresearch.com",
    maintainers = {"Nous Research"},
    licenses = {"MIT"},
    repo = "https://github.com/NousResearch/hermes-agent",
    docs = "https://hermes-agent.nousresearch.com/docs",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"ai", "cli", "tools"},
    keywords = {"hermes", "nous", "agent", "cli", "self-improving"},

    programs = {"hermes", "hermes-agent", "hermes-acp"},
    xvm_enable = true,

    xpm = {
        linux = {
            deps = {"xim:python"},
            ["latest"] = { ref = "2026.4.23" },
            ["2026.4.23"] = {
                url = "https://github.com/NousResearch/hermes-agent/archive/refs/tags/v2026.4.23.tar.gz",
                sha256 = "1ee1be80a2112b7edc581770cee8858e725ba110cc423979cd7102492504bc6b",
            },
            ["2026.4.16"] = {
                url = "https://github.com/NousResearch/hermes-agent/archive/refs/tags/v2026.4.16.tar.gz",
                sha256 = "ef999b93b487532c50f8ed42c3ac0141a52d128052ba0a0d0e90c6edc02e97fe",
            },
        },
        macosx = {
            deps = {"xim:python"},
            ["latest"] = { ref = "2026.4.23" },
            ["2026.4.23"] = {
                url = "https://github.com/NousResearch/hermes-agent/archive/refs/tags/v2026.4.23.tar.gz",
                sha256 = "1ee1be80a2112b7edc581770cee8858e725ba110cc423979cd7102492504bc6b",
            },
            ["2026.4.16"] = {
                url = "https://github.com/NousResearch/hermes-agent/archive/refs/tags/v2026.4.16.tar.gz",
                sha256 = "ef999b93b487532c50f8ed42c3ac0141a52d128052ba0a0d0e90c6edc02e97fe",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.system")

-- Extracted tarball layout:
--   <download_dir>/hermes-agent-<version>/   (pyproject.toml + sources)
-- We create a venv inside install_dir and `pip install` the extracted source
-- into it. The project's [project.scripts] entries (`hermes`, `hermes-agent`,
-- `hermes-acp`) become console scripts under <install_dir>/bin.
function __source_dir()
    local archive = pkginfo.install_file()
    local dir = path.directory(archive)
    return path.join(dir, "hermes-agent-" .. pkginfo.version())
end

function install()
    os.tryrm(pkginfo.install_dir())

    system.exec(string.format([[python3 -m venv "%s"]], pkginfo.install_dir()))
    local venv_pip = path.join(pkginfo.install_dir(), "bin", "pip")

    system.exec(string.format([["%s" install --upgrade pip]], venv_pip))
    system.exec(string.format([["%s" install "%s"]], venv_pip, __source_dir()))

    return true
end

function config()
    local bindir = path.join(pkginfo.install_dir(), "bin")
    local root_binding = "hermes@" .. pkginfo.version()
    xvm.add("hermes", { bindir = bindir })
    xvm.add("hermes-agent", { bindir = bindir, binding = root_binding })
    xvm.add("hermes-acp", { bindir = bindir, binding = root_binding })
    return true
end

function uninstall()
    xvm.remove("hermes")
    xvm.remove("hermes-agent")
    xvm.remove("hermes-acp")
    return true
end
