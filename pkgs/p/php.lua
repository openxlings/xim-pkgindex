-- PHP is a general-purpose scripting language suited for web development and
-- CLI scripting.
--
-- Prebuilt standalone CLI distributions from StaticPHP (dl.static-php.dev):
--   linux    x86_64, aarch64   static ELF binary (`php`), zero DT_NEEDED
--   macosx   x86_64, aarch64   standalone Mach-O binary (`php`)
--   windows  x86_64            standalone PE executable (`php.exe`), no bundled MSVC CRT
--
-- Linux binaries are statically linked (verified with `file` and `ldd`:
-- "statically linked", zero DT_NEEDED), so no `xim:glibc` runtime dependency
-- is declared — declaring one would make elfpatch rewrite a static binary.
-- Every archive unpacks a single executable (`php` or `php.exe`) at its root
-- with 52 built-in extensions (including curl, openssl, mbstring, pdo_mysql,
-- pdo_pgsql, pdo_sqlite, redis, zip, gd, opcache).
--
-- Every sha256 below matches upstream's published `.sha256` sidecar and was
-- independently verified by downloading and hashing each of the five archives.
--
-- MANUAL MAINTENANCE — there is deliberately no extensions.autoupdate.
-- dl.static-php.dev publishes JSON version manifests rather than GitHub
-- Releases/Tags or a Sparkle RSS appcast, and php/php-src tags advance ahead
-- of StaticPHP prebuilt releases. Bump manually from
-- https://dl.static-php.dev/v3/php-bin/common/ and
-- https://dl.static-php.dev/v3/php-bin/spc-max/.
package = {
    spec = "2",

    name = "php",
    description = "PHP - general-purpose scripting language and standalone CLI runtime (StaticPHP build)",
    homepage = "https://www.php.net",
    authors = {"The PHP Group"},
    maintainers = {"https://github.com/crazywhalecc/static-php-cli"},
    licenses = {"PHP-3.01"},
    repo = "https://github.com/php/php-src",
    docs = "https://www.php.net/docs.php",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"language", "runtime", "web", "tools"},
    keywords = {"php", "cli", "scripting", "web", "static-php"},

    programs = {"php"},
    xvm_enable = true,

    xpm = {
        linux = {
            ["latest"] = { ref = "8.5.12" },
            ["8.5.12"] = {
                x86_64 = {
                    url = "https://dl.static-php.dev/v3/php-bin/common/php-8.5.12-cli-linux-x86_64.tar.gz",
                    sha256 = "570891017ae3c18c52a6cf623910cc6f57050eece35348d3348ab866b4d32f0a",
                },
                aarch64 = {
                    url = "https://dl.static-php.dev/v3/php-bin/common/php-8.5.12-cli-linux-aarch64.tar.gz",
                    sha256 = "be55f711a4e89015be3f4244c0d3aca1200e5b08dd26e0a1808ca1b9229fde4d",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "8.5.12" },
            ["8.5.12"] = {
                x86_64 = {
                    url = "https://dl.static-php.dev/v3/php-bin/common/php-8.5.12-cli-macos-x86_64.tar.gz",
                    sha256 = "492cc40aadb7207433cd15fd6085525d6f8661ce50719c84c2456d0e70f39dd7",
                },
                aarch64 = {
                    url = "https://dl.static-php.dev/v3/php-bin/common/php-8.5.12-cli-macos-aarch64.tar.gz",
                    sha256 = "15b530298ac4e3560d685bbce5031dafa2db062f0b114b620db3fabfe25e326b",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "8.5.12" },
            ["8.5.12"] = {
                x86_64 = {
                    url = "https://dl.static-php.dev/v3/php-bin/spc-max/php-8.5.12-cli-win.zip",
                    sha256 = "422faff4d46af80622785f7a576c4e7fb68a7a255990aa634aa0d0f5b3881bb9",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

function installed()
    local dir = pkginfo.install_dir()
    return os.isfile(dir .. "/php") or os.isfile(dir .. "/php.exe")
end

function install()
    local archive = pkginfo.install_file()
    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("%.zip$") ~= nil
    local bin = is_win and "php.exe" or "php"

    os.tryrm(dir)
    fs.mkdir_p(dir)
    os.mv(parent .. "/" .. bin, dir .. "/" .. bin)

    if not is_win then
        system.exec(string.format([[chmod +x "%s"]], dir .. "/php"))
    end
    if not installed() then
        error("php executable is missing after install in " .. dir)
    end
    return true
end

function config()
    xvm.add("php", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("php")
    return true
end
