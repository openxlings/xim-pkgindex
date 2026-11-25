-- Composer - dependency manager for PHP.
--
-- Platform and architecture coverage:
--   linux    x86_64, aarch64   composer.phar wrapped by bin/composer (`xim:php`)
--   macosx   x86_64, aarch64   composer.phar wrapped by bin/composer (`xim:php`)
--   windows  x86_64            composer.phar wrapped by bin/composer.bat (`xim:php`)
--
-- Upstream distributes a single platform-independent `composer.phar` per release.
-- The runtime hosts match `xim:php`, which is declared as a runtime dependency
-- and resolved at install time so the wrapper always locates a working PHP binary
-- (with store/PATH fallback if the pinned PHP version directory is later removed).

package = {
    spec = "2",

    name = "composer",
    description = "Composer - dependency manager for PHP",
    homepage = "https://getcomposer.org",
    authors = {"Nils Adermann", "Jordi Boggiano"},
    maintainers = {"Nils Adermann", "Jordi Boggiano"},
    licenses = {"MIT"},
    repo = "https://github.com/composer/composer",
    docs = "https://getcomposer.org/doc/",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"php", "package-manager", "tools"},
    keywords = {"composer", "php", "package-manager", "phar", "dependencies"},

    programs = {"composer"},
    xvm_enable = true,
    ci = { mirror = true },

    extensions = {
        autoupdate = {
            source = "https://github.com/composer/composer/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = "https://github.com/composer/composer/releases/download/${version}/composer.phar",
                        macosx = "https://github.com/composer/composer/releases/download/${version}/composer.phar",
                        windows = "https://github.com/composer/composer/releases/download/${version}/composer.phar",
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            deps = { runtime = { "xim:php@>=8.0" } },
            ["latest"] = { ref = "2.11.3" },
            ["2.11.2"] = {
                revision = 1,
                url = "https://github.com/composer/composer/releases/download/2.11.2/composer.phar",
                sha256 = "dd158c0afd41d15fac89e1b4e47b5d42911fe316c3687cd5edac98319b25d028",
            },
            ["2.11.3"] = {
                url = "https://github.com/composer/composer/releases/download/2.11.3/composer.phar",
                sha256 = "04f8b003da4e3a2459056591fbfebd02b4dc3e5adeb158616b90cf55a65113ec",
            },
        },
        macosx = {
            deps = { runtime = { "xim:php@>=8.0" } },
            ["latest"] = { ref = "2.11.3" },
            ["2.11.2"] = {
                revision = 1,
                url = "https://github.com/composer/composer/releases/download/2.11.2/composer.phar",
                sha256 = "dd158c0afd41d15fac89e1b4e47b5d42911fe316c3687cd5edac98319b25d028",
            },
            ["2.11.3"] = {
                url = "https://github.com/composer/composer/releases/download/2.11.3/composer.phar",
                sha256 = "04f8b003da4e3a2459056591fbfebd02b4dc3e5adeb158616b90cf55a65113ec",
            },
        },
        windows = {
            deps = { runtime = { "xim:php@>=8.0" } },
            ["latest"] = { ref = "2.11.3" },
            ["2.11.2"] = {
                revision = 1,
                url = "https://github.com/composer/composer/releases/download/2.11.2/composer.phar",
                sha256 = "dd158c0afd41d15fac89e1b4e47b5d42911fe316c3687cd5edac98319b25d028",
            },
            ["2.11.3"] = {
                url = "https://github.com/composer/composer/releases/download/2.11.3/composer.phar",
                sha256 = "04f8b003da4e3a2459056591fbfebd02b4dc3e5adeb158616b90cf55a65113ec",
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

local PHAR_NAME = "composer.phar"

local POSIX_LAUNCHER = [==[
#!/usr/bin/env bash
set -uo pipefail

PHP_HOME="%s"
PHP_BIN="$PHP_HOME/php"

if [ ! -x "$PHP_BIN" ]; then
    __bindir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    __store_root="$(dirname "$(dirname "$(dirname "$__bindir")")")"
    __fallback_php="$(ls -d "$__store_root"/xim-x-php/*/php 2>/dev/null | sort -V | tail -1)"
    if [ -n "$__fallback_php" ] && [ -x "$__fallback_php" ]; then
        PHP_BIN="$__fallback_php"
    elif command -v php >/dev/null 2>&1; then
        PHP_BIN="$(command -v php)"
    else
        echo "composer: xim:php was not found at $PHP_HOME/php" >&2
        exit 2
    fi
fi

exec "$PHP_BIN" "%s" "$@"
]==]

local WINDOWS_LAUNCHER = [==[
@echo off
rem composer (xim:composer launcher).
setlocal
set "COMPOSER_PHP=%s\php.exe"
if exist "%%COMPOSER_PHP%%" goto run
where php.exe >nul 2>nul
if errorlevel 1 goto nophp
set "COMPOSER_PHP=php.exe"
:run
"%%COMPOSER_PHP%%" "%s" %%*
exit /b %%ERRORLEVEL%%
:nophp
echo composer: php.exe was not found at "%s\php.exe" or on PATH. Install xim:php. 1>&2
exit /b 2
]==]

local function winpath(p)
    return (p:gsub("/", "\\"))
end

local function detect_php_home()
    if pkginfo.resolved_dep then
        local resolved = pkginfo.resolved_dep("xim:php")
        if type(resolved) == "table" then
            local candidate = resolved.install_dir or resolved.path
            if candidate and candidate ~= "" then
                return candidate
            end
        end
    end
    if pkginfo.dep_install_dir then
        return pkginfo.dep_install_dir("xim:php")
    end
    return nil
end

function installed()
    local dir = pkginfo.install_dir()
    return os.isfile(dir .. "/" .. PHAR_NAME)
        and (os.isfile(dir .. "/bin/composer") or os.isfile(dir .. "/bin/composer.bat"))
end

function install()
    local dir = pkginfo.install_dir()
    local phar_src = pkginfo.install_file()
    if not phar_src or not os.isfile(phar_src) then
        error("composer: downloaded composer.phar is missing: " .. tostring(phar_src))
    end

    local php_home = detect_php_home()
    if not php_home or php_home == "" then
        error("composer: xim:php payload directory was not resolved")
    end

    local is_win = os.isfile(php_home .. "/php.exe") or os.getenv("OS") == "Windows_NT"
    local php_bin = php_home .. (is_win and "/php.exe" or "/php")
    if not os.isfile(php_bin) then
        error("composer: php executable not found in xim:php payload: " .. php_bin)
    end

    os.tryrm(dir)
    fs.mkdir_p(dir)
    local bindir = dir .. "/bin"
    fs.mkdir_p(bindir)

    local phar_dst = dir .. "/" .. PHAR_NAME
    os.cp(phar_src, phar_dst)
    if not os.isfile(phar_dst) then
        error("composer: failed to copy composer.phar to " .. phar_dst)
    end

    if is_win then
        local launcher = bindir .. "/composer.bat"
        local f, ferr = io.open(launcher, "w")
        if not f then
            error("composer: cannot write " .. launcher .. ": " .. tostring(ferr))
        end
        f:write((string.format(WINDOWS_LAUNCHER, winpath(php_home), winpath(phar_dst), winpath(php_home)):gsub("\n", "\r\n")))
        f:close()
    else
        local launcher = bindir .. "/composer"
        local f, ferr = io.open(launcher, "w")
        if not f then
            error("composer: cannot write " .. launcher .. ": " .. tostring(ferr))
        end
        f:write(string.format(POSIX_LAUNCHER, php_home, phar_dst))
        f:close()
        system.exec(string.format([[chmod +x "%s"]], launcher))
        system.exec(string.format([[bash -n "%s"]], launcher))
    end

    if not installed() then
        error("composer: install artifacts missing in " .. dir)
    end
    return true
end

function config()
    local bindir = pkginfo.install_dir() .. "/bin"
    if os.isfile(bindir .. "/composer.bat") then
        xvm.add("composer", { bindir = bindir, filename = "composer.bat" })
    else
        xvm.add("composer", { bindir = bindir })
    end
    return true
end

function uninstall()
    xvm.remove("composer")
    return true
end
