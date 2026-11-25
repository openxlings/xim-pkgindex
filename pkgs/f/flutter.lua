-- Flutter SDK - Google's cross-platform UI toolkit and bundled Dart SDK.
--
-- Platforms and sources (official Flutter stable channel releases):
--   linux    x86_64            flutter_linux_3.50.1-stable.tar.xz (deps: xim:git; resolves host glibc/GTK3 for libflutter_linux_gtk.so)
--   macosx   x86_64, aarch64   flutter_macos[_arm64]_3.50.1-stable.zip
--   windows  x86_64            flutter_windows_3.50.1-stable.zip (deps: xim:git)
--
-- Digests verified against Google's official release manifests:
--   https://storage.googleapis.com/flutter_infra_release/releases/releases_{linux,macos,windows}.json
package = {
    spec = "2",

    name = "flutter",
    description = "Flutter SDK - Google UI toolkit for building natively compiled apps (includes Dart SDK)",
    homepage = "https://flutter.dev",
    authors = {"The Flutter Authors"},
    maintainers = {"https://github.com/flutter/flutter"},
    licenses = {"BSD-3-Clause"},
    repo = "https://github.com/flutter/flutter",
    docs = "https://docs.flutter.dev",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"sdk", "mobile", "web", "desktop", "language", "tools"},
    keywords = {"flutter", "dart", "sdk", "ui", "mobile", "cross-platform"},

    programs = {"flutter", "dart"},
    xvm_enable = true,

    xpm = {
        linux = {
            deps = { "xim:git" },
            ["latest"] = { ref = "3.50.1" },
            ["3.50.1"] = {
                x86_64 = {
                    url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.50.1-stable.tar.xz",
                    sha256 = "4ad17fc8462fbcef2ba19ff4a78c0a16b7147fde1add8578e267ea62cdb92678",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "3.50.1" },
            ["3.50.1"] = {
                x86_64 = {
                    url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_3.50.1-stable.zip",
                    sha256 = "5c3d3bbabc8edd58eb98605047c59c31a82895cfe7d119318d0f62cdbd5d47ed",
                },
                aarch64 = {
                    url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_arm64_3.50.1-stable.zip",
                    sha256 = "872883d49965e0cc1d8e477d2d87f2f45930d13f94b34889e53783586f04c715",
                },
            },
        },
        windows = {
            deps = { "xim:git" },
            ["latest"] = { ref = "3.50.1" },
            ["3.50.1"] = {
                x86_64 = {
                    url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.50.1-stable.zip",
                    sha256 = "33c1e3d4dd08f1136ddb9c7976cfd2b0ab20296f1565b78ba176a4cbb4e140eb",
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

function installed()
    local dir = pkginfo.install_dir()
    return (os.isfile(dir .. "/bin/flutter") and os.isfile(dir .. "/bin/dart"))
        or (os.isfile(dir .. "/bin/flutter.bat") and os.isfile(dir .. "/bin/dart.bat"))
end

function install()
    local archive = pkginfo.install_file()
    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local extracted = parent .. "/flutter"
    local is_win = normalized:match("flutter_windows_") ~= nil

    os.tryrm(dir)

    if os.isdir(extracted) then
        local dst_parent = dir:match("^(.*)/[^/]+$")
        if dst_parent then fs.mkdir_p(dst_parent) end
        os.mv(extracted, dir)
    elseif is_win then
        fs.mkdir_p(dir)
        local sysroot = winpath(os.getenv("SystemRoot") or "C:\\Windows"):gsub("\\+$", "")
        local systar = sysroot .. "\\System32\\tar.exe"
        -- exec-quoting-ok: the first token is the system's tar.exe, which cmd.exe must see unquoted
        system.exec(string.format('%s -xf "%s" --strip-components=1 -C "%s"', systar, winpath(archive), winpath(dir)))
    else
        error("flutter extracted directory not found: " .. extracted)
    end

    if not is_win and os.isfile(dir .. "/bin/flutter") then
        system.exec(string.format([[chmod +x "%s" "%s"]], dir .. "/bin/flutter", dir .. "/bin/dart"))
        if os.isfile(dir .. "/bin/cache/dart-sdk/bin/dart") then
            system.exec(string.format([[chmod +x "%s"]], dir .. "/bin/cache/dart-sdk/bin/dart"))
        end
    end

    if not installed() then
        error("flutter SDK binaries are missing after install in " .. dir)
    end
    return true
end

function config()
    local bindir = pkginfo.install_dir() .. "/bin"
    local root = "flutter@" .. pkginfo.version()
    if os.isfile(bindir .. "/flutter.bat") then
        xvm.add("flutter", { bindir = bindir, filename = "flutter.bat" })
        xvm.add("dart", { bindir = bindir, filename = "dart.bat", binding = root })
    else
        xvm.add("flutter", { bindir = bindir })
        xvm.add("dart", { bindir = bindir, binding = root })
    end
    return true
end

function uninstall()
    xvm.remove("dart")
    xvm.remove("flutter")
    return true
end
