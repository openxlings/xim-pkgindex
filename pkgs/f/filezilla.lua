-- FileZilla Client is a fast and reliable FTP, FTPS, and SFTP client.
--
-- Platform and architecture:
--   windows  x86_64   FileZilla 3.72.1 (64-bit) extracted from Chocolatey .nupkg
--
-- Upstream's official CDN (filezilla-project.org) serves time-limited HMAC
-- download links (https://trac.filezilla-project.org/ticket/13186) that
-- cannot be pinned as static URLs. As in Scoop's manifest, this recipe fetches
-- Chocolatey's pinned package (`filezilla.3.72.1.nupkg`), which embeds the
-- unmodified official `FileZilla_3.72.1_win64-setup.exe` (SHA-512 verified
-- against filezilla-project.org's checksum:
-- 9af587dff5e09b80f10495b0c68b7a8bc8fb9748f1c9bd4b657e90622ec7fc49baa9590034ff290a0f027721553f8db7e0e16953adaf066f8966d1aeb0b59ccb).
--
-- Linux and macOS are not declared: upstream's binary CDN URLs expire and
-- distro/MacPorts builds link against unbundled host/prefix shared libraries
-- (libfilezilla, wxwidgets, gnutls, fzssh) not provided by this index.
-- Upstream publishes no Windows ARM64 build.
--
-- `programs` is omitted deliberately: filezilla.exe is a Windows GUI
-- executable whose wxCmdLineParser sets SwitchChars to `-` only, so
-- Windows CI's `/?` probe is parsed as a site URL and opens the GUI window
-- instead of exiting. `config()` still registers `filezilla` in xvm so the
-- shim is created on PATH and uninstalled cleanly.
--
-- MANUAL MAINTENANCE — there is deliberately no extensions.autoupdate.
-- Upstream provides neither GitHub Releases/Tags nor a Sparkle RSS appcast
-- with stable asset URLs. Bump manually by checking filezilla-project.org
-- and Chocolatey (`filezilla.<version>.nupkg`), verifying both the .nupkg
-- SHA-256 and the embedded setup executable's SHA-512.
package = {
    spec = "2",

    name = "filezilla",
    description = "FileZilla Client - fast and reliable FTP, FTPS and SFTP client",
    homepage = "https://filezilla-project.org",
    authors = {"Tim Kosse"},
    maintainers = {"Tim Kosse"},
    licenses = {"GPL-2.0-or-later"},
    docs = "https://wiki.filezilla-project.org/Documentation",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"network", "ftp", "sftp", "tools", "windows"},
    keywords = {"filezilla", "ftp", "ftps", "sftp", "client", "file-transfer"},

    xvm_enable = true,

    xpm = {
        windows = {
            deps = { build = { "xim:7zip" } },
            ["latest"] = { ref = "3.72.1" },
            ["3.72.1"] = {
                x86_64 = {
                    url = "https://packages.chocolatey.org/filezilla.3.72.1.nupkg",
                    sha256 = "b2f058831a72a522b1230c5e2230ff4dc5cc107bd1d00bf89babf55e00a840e5",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

local function winpath(p)
    return (p:gsub("/", "\\"))
end

local function ps_quote(s)
    return (s:gsub("'", "''"))
end

local function required_files()
    local dir = pkginfo.install_dir()
    return {
        dir .. "/filezilla.exe",
        dir .. "/libfilezilla-61.dll",
        dir .. "/libgnutls-30.dll",
        dir .. "/wxmsw32u_core_gcc_custom.dll",
        dir .. "/resources/defaultfilters.xml",
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
    local nupkg = pkginfo.install_file()
    local ver = pkginfo.version()
    local staging = dir .. ".staging"
    local build_dep = assert(pkginfo.build_dep("7zip"), "xim:7zip build dependency is missing")
    local seven_zip = winpath(build_dep.path) .. "\\7z.exe"

    os.tryrm(dir)
    os.tryrm(staging)
    fs.mkdir_p(dir)
    fs.mkdir_p(staging)

    local ok, err = pcall(function()
        -- 1. Extract the Chocolatey .nupkg to obtain the official win64 NSIS installer.
        -- exec-quoting-ok: every interpolated path is enclosed in PowerShell single quotes.
        system.exec(string.format(
            [[powershell -NoProfile -ExecutionPolicy Bypass -Command "$q = [char]34; $p = Start-Process -FilePath '%s' -ArgumentList ('x ' + $q + '%s' + $q + ' -o' + $q + '%s' + $q + ' -y') -Wait -NoNewWindow -PassThru; if ($p.ExitCode -ne 0) { exit $p.ExitCode }"]],
            ps_quote(seven_zip),
            ps_quote(winpath(nupkg)),
            ps_quote(winpath(staging))
        ))

        local setup_exe = staging .. "/tools/FileZilla_" .. ver .. "_win64-setup.exe"
        if not os.isfile(setup_exe) then
            error("filezilla installer not found in nupkg: " .. setup_exe)
        end

        -- 2. Extract the NSIS payload into a portable tree, excluding NSIS plugin/uninstaller stubs.
        -- exec-quoting-ok: every interpolated path is enclosed in PowerShell single quotes.
        system.exec(string.format(
            [[powershell -NoProfile -ExecutionPolicy Bypass -Command "$q = [char]34; $p = Start-Process -FilePath '%s' -ArgumentList ('x ' + $q + '%s' + $q + ' -o' + $q + '%s' + $q + ' ' + $q + '-xr!' + [char]36 + '*' + $q + ' -xr!uninstall.exe -y') -Wait -NoNewWindow -PassThru; if ($p.ExitCode -ne 0) { exit $p.ExitCode }"]],
            ps_quote(seven_zip),
            ps_quote(winpath(setup_exe)),
            ps_quote(winpath(dir))
        ))
    end)

    os.tryrm(staging)
    os.tryrm(dir .. "/uninstall.exe.nsis")
    if not ok then error(err) end

    local missing = {}
    for _, file in ipairs(required_files()) do
        if not os.isfile(file) then table.insert(missing, file) end
    end
    if #missing > 0 then
        error("filezilla is missing after install:\n    " .. table.concat(missing, "\n    "))
    end
    return true
end

function config()
    xvm.add("filezilla", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("filezilla")
    return true
end
