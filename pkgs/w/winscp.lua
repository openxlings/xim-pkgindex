-- WinSCP is a Windows SFTP, FTP, WebDAV, S3 and SCP client.
--
-- Platform and architecture:
--   windows  x86_64   WinSCP-6.7.1-Portable.zip (32-bit production build)
--
-- Upstream marks the 64-bit portable archive as experimental ("The 64-bit
-- version of WinSCP is EXPERIMENTAL... For production use the 32-bit build"
-- in readme.txt and WinSCP-6.7.1-ReadMe.txt), so this recipe packages the
-- recommended 32-bit portable distribution, which runs on x86_64 Windows
-- via WOW64. Upstream publishes no Windows ARM64, Linux, or macOS builds.
--
-- Checksum verified against https://winscp.net/download/WinSCP-6.7.1-ReadMe.txt
-- and by downloading WinSCP-6.7.1-Portable.zip directly.
--
-- Entrypoints:
--   winscp      -> WinSCP.exe (GUI client; also accepts scripting flags)
--   winscp-cli  -> WinSCP.com (console wrapper; non-interactive CLI/scripting)
--
-- `programs` lists `winscp-cli` rather than `winscp`: WinSCP.exe /? enters
-- TOwnConsole::WaitBeforeExit() waiting for a keypress and WinSCP.exe
-- --version opens the login dialog, whereas WinSCP.com /? writes usage and
-- version text to stdout and exits immediately.
package = {
    spec = "2",

    name = "winscp",
    description = "WinSCP - SFTP, FTP, WebDAV, S3 and SCP client for Windows",
    homepage = "https://winscp.net",
    authors = {"Martin Prikryl"},
    maintainers = {"https://github.com/winscp/winscp/graphs/contributors"},
    licenses = {"GPL-3.0-or-later"},
    repo = "https://github.com/winscp/winscp",
    docs = "https://winscp.net/eng/docs/start",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"network", "ftp", "sftp", "tools", "windows"},
    keywords = {"winscp", "sftp", "ftp", "ftps", "scp", "webdav", "s3", "file-transfer"},

    programs = {"winscp-cli"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/winscp/winscp/tags",
            tag = "${version}",
            resources = {
                GLOBAL = {
                    url = {
                        windows = {
                            x86_64 = "https://downloads.sourceforge.net/project/winscp/WinSCP/${version}/WinSCP-${version}-Portable.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        windows = {
            deps = { build = { "xim:7zip" } },
            ["latest"] = { ref = "6.7.1" },
            ["6.7.1"] = {
                revision = 1,
                x86_64 = {
                    url = "https://downloads.sourceforge.net/project/winscp/WinSCP/6.7.1/WinSCP-6.7.1-Portable.zip",
                    sha256 = "e6d2f8e1249e41f3bf8638319bb9bd15a541a64720df0805cb0bebdedb5eda83",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.shortcut")
import("xim.pkgindex.winpath")

local function ps_quote(s)
    return (s:gsub("'", "''"))
end

local function required_files()
    local dir = pkginfo.install_dir()
    return {
        dir .. "/WinSCP.exe",
        dir .. "/WinSCP.com",
    }
end

function installed()
    for _, file in ipairs(required_files()) do
        if not os.isfile(file) then return false end
    end
    return true
end

function install()
    local dir = pkginfo.install_dir()
    local archive = pkginfo.install_file()
    local build_dep = assert(pkginfo.build_dep("7zip"), "xim:7zip build dependency is missing")
    local seven_zip = winpath.native(build_dep.path) .. "\\7z.exe"

    os.tryrm(dir)
    fs.mkdir_p(dir)

    -- exec-quoting-ok: every interpolated path is enclosed in PowerShell single quotes.
    system.exec(string.format(
        [[powershell -NoProfile -ExecutionPolicy Bypass -Command "$q = [char]34; $p = Start-Process -FilePath '%s' -ArgumentList ('x ' + $q + '%s' + $q + ' -o' + $q + '%s' + $q + ' -y') -Wait -NoNewWindow -PassThru; if ($p.ExitCode -ne 0) { exit $p.ExitCode }"]],
        ps_quote(seven_zip),
        ps_quote(winpath.native(archive)),
        ps_quote(winpath.native(dir))
    ))

    local missing = {}
    for _, file in ipairs(required_files()) do
        if not os.isfile(file) then table.insert(missing, file) end
    end
    if #missing > 0 then
        error("winscp is missing after install:\n    " .. table.concat(missing, "\n    "))
    end
    return true
end

function config()
    local dir = pkginfo.install_dir()
    xvm.add("winscp", { bindir = dir, alias = "WinSCP.exe" })
    xvm.add("winscp-cli", { bindir = dir, alias = "WinSCP.com", binding = "winscp@" .. pkginfo.version() })
    -- Best-effort by contract: shortcut.create never raises and writes its
    -- own warning (with this package's name) when the entry cannot be written.
    shortcut.create{
        name = "WinSCP",
        target = dir .. "/WinSCP.exe",
        description = "WinSCP SFTP, FTP, WebDAV, S3 and SCP client",
    }
    return true
end

function uninstall()
    shortcut.remove{ name = "WinSCP" }
    xvm.remove("winscp-cli")
    xvm.remove("winscp")
    return true
end
