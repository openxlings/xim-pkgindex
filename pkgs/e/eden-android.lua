local apk = {
    url = "https://stable.eden-emu.dev/v0.2.1/Eden-Android-v0.2.1-standard.apk",
    sha256 = "befbf70b1a05715811fe092ef9cf71e6f1c1672008a6c5caa31d633e99615668",
}

package = {
    spec = "2",
    name = "eden-android",
    description = "Official Eden ARM64 Android APK for manual installation on a connected device",
    homepage = "https://eden-emu.dev/",
    repo = "https://git.eden-emu.dev/eden-emu/eden",
    licenses = {"GPL-3.0-or-later"},
    type = "package",
    -- Host architectures: the downloaded APK always targets Android ARM64.
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"app", "android", "emulator"},
    keywords = {"eden", "switch", "android", "apk"},
    xvm_enable = true,
    xpm = {
        linux = {
            ["latest"] = { ref = "0.2.1" },
            ["0.2.1"] = { x86_64 = apk, aarch64 = apk },
        },
        windows = {
            ["latest"] = { ref = "0.2.1" },
            ["0.2.1"] = { x86_64 = apk, aarch64 = apk },
        },
        macosx = {
            ["latest"] = { ref = "0.2.1" },
            ["0.2.1"] = { x86_64 = apk, aarch64 = apk },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function installed()
    return os.isfile(pkginfo.install_dir() .. "/eden.apk")
end

function install()
    os.mkdir(pkginfo.install_dir())
    os.cp(pkginfo.install_file(), pkginfo.install_dir() .. "/eden.apk")
    assert(installed(), "Eden Android APK is missing")
    return true
end

function config()
    xvm.add("eden-android", { type = "group" })
    return true
end

function uninstall()
    xvm.remove("eden-android")
    return true
end
