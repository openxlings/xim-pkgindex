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

    -- PHP 7.4.33 is published as an official windows.php.net VC15 archive only;
    -- StaticPHP distributes 8.0+ across Linux, macOS, and Windows.
    platform_versions_diverge = true,

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
            ["8.5"] = { ref = "8.5.12" },
            ["8.4"] = { ref = "8.4.27" },
            ["8.3"] = { ref = "8.3.36" },
            ["8.2"] = { ref = "8.2.35" },
            ["8.1"] = { ref = "8.1.34" },
            ["8.0"] = { ref = "8.0.30" },
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
            ["8.4.27"] = {
                x86_64 = {
                    url = "https://dl.static-php.dev/v3/php-bin/common/php-8.4.27-1-cli-linux-x86_64.tar.gz",
                    sha256 = "befd80e3259079ea77bc7f54f26c51b0f5874ece3247ce983ddf2cad99b5281d",
                },
                aarch64 = {
                    url = "https://dl.static-php.dev/v3/php-bin/common/php-8.4.27-1-cli-linux-aarch64.tar.gz",
                    sha256 = "9a8db373e800506fbcbb6986ea15273ab76b28e1473d498e1fe5ad2a5c3d3990",
                },
            },
            ["8.3.36"] = {
                x86_64 = {
                    url = "https://dl.static-php.dev/v3/php-bin/common/php-8.3.36-1-cli-linux-x86_64.tar.gz",
                    sha256 = "843fa3c037db2f10ecc12d463e1f4b223314e407bb70f62fd3ae89ee63265634",
                },
                aarch64 = {
                    url = "https://dl.static-php.dev/v3/php-bin/common/php-8.3.36-1-cli-linux-aarch64.tar.gz",
                    sha256 = "93f65d6a932761e321a3c1a6d6ec528ccda2a42d467b8136687f36b816fc2fc3",
                },
            },
            ["8.2.35"] = {
                x86_64 = {
                    url = "https://dl.static-php.dev/v3/php-bin/common/php-8.2.35-1-cli-linux-x86_64.tar.gz",
                    sha256 = "2ea9f7eb5837a38c1844bd398bfda62fa82fdba839fbc31a36fadfeb3a2c874f",
                },
                aarch64 = {
                    url = "https://dl.static-php.dev/v3/php-bin/common/php-8.2.35-1-cli-linux-aarch64.tar.gz",
                    sha256 = "415d028c548cb12f8d4e27b0f42d036d57e3dac1b6219aa0d645cc95b53407c5",
                },
            },
            ["8.1.34"] = {
                x86_64 = {
                    url = "https://dl.static-php.dev/static-php-cli/common/php-8.1.34-cli-linux-x86_64.tar.gz",
                    sha256 = "4caa8b82b574212b2f7af83cc800b23e0529b3dec85b8b2887547f909e717143",
                },
                aarch64 = {
                    url = "https://dl.static-php.dev/static-php-cli/common/php-8.1.34-cli-linux-aarch64.tar.gz",
                    sha256 = "134a0244b399c73792db3e91337fa3c18f0d773fd78ecfc26b14560fec7bcd6d",
                },
            },
            ["8.0.30"] = {
                x86_64 = {
                    url = "https://dl.static-php.dev/static-php-cli/common/php-8.0.30-cli-linux-x86_64.tar.gz",
                    sha256 = "1a5b1d5e60bca9e0c06557640f878e88bd52ac4eb28e8a118103867b084e8ff8",
                },
                aarch64 = {
                    url = "https://dl.static-php.dev/static-php-cli/common/php-8.0.30-cli-linux-aarch64.tar.gz",
                    sha256 = "7515adedd9553d5c07f5fcead401a97e37b23e3cc0f156285b00a9232b2cdeff",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "8.5.12" },
            ["8.5"] = { ref = "8.5.12" },
            ["8.4"] = { ref = "8.4.27" },
            ["8.3"] = { ref = "8.3.36" },
            ["8.2"] = { ref = "8.2.35" },
            ["8.1"] = { ref = "8.1.34" },
            ["8.0"] = { ref = "8.0.30" },
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
            ["8.4.27"] = {
                x86_64 = {
                    url = "https://dl.static-php.dev/v3/php-bin/common/php-8.4.27-1-cli-macos-x86_64.tar.gz",
                    sha256 = "657424a75b9d147919a8d5fbcdd230d7cd8361da0cc3794e3bde3cd8d36abaaa",
                },
                aarch64 = {
                    url = "https://dl.static-php.dev/v3/php-bin/common/php-8.4.27-1-cli-macos-aarch64.tar.gz",
                    sha256 = "963d42519d204b08ce57666a9aa5303200b51087a9bf0ff42754ca69aea9deff",
                },
            },
            ["8.3.36"] = {
                x86_64 = {
                    url = "https://dl.static-php.dev/v3/php-bin/common/php-8.3.36-1-cli-macos-x86_64.tar.gz",
                    sha256 = "2f295f5024d76afc4544487e3a1126591e33dfdbf946222a3d76ab894e624340",
                },
                aarch64 = {
                    url = "https://dl.static-php.dev/v3/php-bin/common/php-8.3.36-1-cli-macos-aarch64.tar.gz",
                    sha256 = "b52accd6c5adcb99c3b753f7c0d4780b04d6752bd70206b74ca5016522965507",
                },
            },
            ["8.2.35"] = {
                x86_64 = {
                    url = "https://dl.static-php.dev/v3/php-bin/common/php-8.2.35-1-cli-macos-x86_64.tar.gz",
                    sha256 = "a70ad20991893323f8aeb7847143cfce3fc676a56a251c3ce5c758e7e1199be3",
                },
                aarch64 = {
                    url = "https://dl.static-php.dev/v3/php-bin/common/php-8.2.35-1-cli-macos-aarch64.tar.gz",
                    sha256 = "b3b7bd5818682e4805c2eac03c29e374c27df33b685615eb61e45ddee25a90bc",
                },
            },
            ["8.1.34"] = {
                x86_64 = {
                    url = "https://dl.static-php.dev/static-php-cli/common/php-8.1.34-cli-macos-x86_64.tar.gz",
                    sha256 = "91dddd79c1a8296eec6baa79e890d174a7ddcac40e0565390ae97eea09055e25",
                },
                aarch64 = {
                    url = "https://dl.static-php.dev/static-php-cli/common/php-8.1.34-cli-macos-aarch64.tar.gz",
                    sha256 = "4feae4b89a6a2b1d0f1c9cc6bbb37e7a7f299a392a6f8f207946fc60c6ed631a",
                },
            },
            ["8.0.30"] = {
                x86_64 = {
                    url = "https://dl.static-php.dev/static-php-cli/common/php-8.0.30-cli-macos-x86_64.tar.gz",
                    sha256 = "8851a859b67e2abb6b15ec87eea547a47ec2380d7abc8297f26a9fb927eac46f",
                },
                aarch64 = {
                    url = "https://dl.static-php.dev/static-php-cli/common/php-8.0.30-cli-macos-aarch64.tar.gz",
                    sha256 = "af2e06f1c0e872712177dda3478434890ed9bfc278f5435ed7d82f989b28a080",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "8.5.12" },
            ["8.5"] = { ref = "8.5.12" },
            ["8.4"] = { ref = "8.4.27" },
            ["8.3"] = { ref = "8.3.36" },
            ["8.2"] = { ref = "8.2.35" },
            ["8.1"] = { ref = "8.1.34" },
            ["8.0"] = { ref = "8.0.30" },
            ["7.4"] = { ref = "7.4.33" },
            ["8.5.12"] = {
                x86_64 = {
                    url = "https://dl.static-php.dev/v3/php-bin/spc-max/php-8.5.12-cli-win.zip",
                    sha256 = "422faff4d46af80622785f7a576c4e7fb68a7a255990aa634aa0d0f5b3881bb9",
                },
            },
            ["8.4.27"] = {
                x86_64 = {
                    url = "https://dl.static-php.dev/v3/php-bin/spc-max/php-8.4.27-1-cli-win.zip",
                    sha256 = "a8bb7bccc7ab2e7e70e00bd927dfce1d75a6aa8e13956387d63d2e955cd91e76",
                },
            },
            ["8.3.36"] = {
                x86_64 = {
                    url = "https://dl.static-php.dev/v3/php-bin/spc-max/php-8.3.36-1-cli-win.zip",
                    sha256 = "d6f38951b6ecbb05cea4e4a65480d079e34062d896a9186df7e20fa9e6f2c516",
                },
            },
            ["8.2.35"] = {
                x86_64 = {
                    url = "https://dl.static-php.dev/v3/php-bin/spc-max/php-8.2.35-1-cli-win.zip",
                    sha256 = "35cb73a3ada022faff8e33a56ec211739ba027dff5d3150950fcb317c03688e1",
                },
            },
            ["8.1.34"] = {
                x86_64 = {
                    url = "https://dl.static-php.dev/static-php-cli/windows/spc-max/php-8.1.34-cli-win.zip",
                    sha256 = "112f3a411280a91eb5a32716484b52124e874678edb8f1a0ffbe0db767afc5ff",
                },
            },
            ["8.0.30"] = {
                x86_64 = {
                    url = "https://dl.static-php.dev/static-php-cli/windows/spc-max/php-8.0.30-cli-win.zip",
                    sha256 = "67c98a95790d2dd9f79b051c2b6cab0cf9bb4d4cc0b4c5401c991bc99c99ac82",
                },
            },
            ["7.4.33"] = {
                x86_64 = {
                    url = "https://windows.php.net/downloads/releases/archives/php-7.4.33-nts-Win32-vc15-x64.zip",
                    sha256 = "14ae3250d4447c8ccfc4c45a70d90adfbcd61e728d85f0be56a7ddf8f9c8aace",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

local function is_win_vc15_bundle()
    return pkginfo.version and pkginfo.version() == "7.4.33"
end

function installed()
    local dir = pkginfo.install_dir()
    if is_win_vc15_bundle() then
        return os.isfile(dir .. "/php.exe") and os.isfile(dir .. "/php7.dll")
    end
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

    if is_win and (is_win_vc15_bundle() or normalized:find("Win32%-vc15") ~= nil) then
        local sysroot = (os.getenv("SystemRoot") or "C:\\Windows"):gsub("/", "\\"):gsub("\\+$", "")
        local systar = sysroot .. "\\System32\\tar.exe"
        -- exec-quoting-ok: the first token is the system's tar.exe, which cmd.exe must see unquoted
        system.exec(string.format('%s -xf "%s" -C "%s"', systar, archive:gsub("/", "\\"), dir:gsub("/", "\\")))
    else
        os.mv(parent .. "/" .. bin, dir .. "/" .. bin)
        if not is_win then
            system.exec(string.format([[chmod +x "%s"]], dir .. "/php"))
        end
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
