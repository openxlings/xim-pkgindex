package = {
    spec = "2",
    homepage = "https://developer.android.com/studio/run/emulator",

    name = "android-runner",
    description = "android-run: an mcpp `runner` session over the Android emulator -- boots the named AVD headless, waits for boot, hands the artifact to adb-run, tears the emulator down",

    maintainers = {"https://github.com/xlings-res/android-runner"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/xlings-res/android-runner",
    docs = "https://github.com/mcpp-community/mcpp/blob/main/docs/04-mcpp-toml.md",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"runner", "android"},
    keywords = {"android", "emulator", "runner", "mcpp"},

    xvm_enable = true,

    -- adb-run (xim:android-platform-tools) already runs ONE artifact on
    -- whatever device adb reaches; what it deliberately does not do is own a
    -- device. This package's program owns one for the length of one run: it
    -- boots the AVD ANDROID_RUN_AVD names, waits for sys.boot_completed=1,
    -- execs adb-run with every argument unchanged, and stops the emulator it
    -- started. A device adb already reaches is used as found -- no second
    -- emulator, nothing killed this program did not start.
    --
    -- MEASURED END TO END (2026-11-11, x86_64 Linux, /dev/kvm, android-24
    -- default x86_64 AVD, image of xim:android-system-image): boot to
    -- sys.boot_completed=1 in seconds; a dynamic x86_64-linux-android
    -- artifact pushed to /data/local/tmp prints its output on stdout and its
    -- exit code (42 in the measurement) is returned, the emulator stopped
    -- behind it.
    --
    -- The AVD is the caller's. Writing an AVD's two files by hand (an .ini
    -- pointer and a <name>.avd/ directory; the emulator package's own header
    -- documents the form -- no avdmanager, no JDK) is the declared way to
    -- make one. The system image directory is ANDROID_RUN_SYSDIR when set;
    -- install() below bakes the installed xim:android-system-image payload
    -- as the default through the shim it writes beside the payload's own
    -- program, the same baking the emulator package's wrapper does for its
    -- sdk root. The emulator package's sdk-root is read-only and carries no
    -- system-images/ sibling (measured), which is exactly why -sysdir, not a
    -- symlink, is the mechanism here.

    xpm = {
        deps = {
            -- adb-run entered platform-tools at 37.0.1-3; the emulator and
            -- one system image are the session's other halves. A version
            -- pin below the adb-run-bearing revision would resolve a program
            -- this package execs into a file that is not there (measured on
            -- a machine carrying both 37.0.1 and 37.0.1-2: the older
            -- registration shadows, and android-run names it).
            "xim:android-platform-tools@>=37.0.1-3",
            "xim:android-emulator",
            "xim:android-system-image",
        },
        source = {
            GLOBAL = "https://github.com/xlings-res/android-runner/releases/download/${version}/android-runner-${version}.tar.xz",
            CN = "https://gitcode.com/xlings-res/android-runner/releases/download/${version}/android-runner-${version}.tar.xz",
        },
        linux = {
            ["latest"] = { ref = "0.1.0" },
            ["0.1.0"] = { sha256 = "891268878e4138a3e5e5b0931eeefa1c813a185fc01d7d7b6eb945937a7c744b" },
        },
        macosx = {
            ["latest"] = { ref = "0.1.0" },
            ["0.1.0"] = { sha256 = "891268878e4138a3e5e5b0931eeefa1c813a185fc01d7d7b6eb945937a7c744b" },
        },
        -- The program is a POSIX shell script; on Windows it runs only under
        -- an environment that provides one, the same coverage boundary
        -- adb-run's own header states.
        windows = {
            ["latest"] = { ref = "0.1.0" },
            ["0.1.0"] = { sha256 = "891268878e4138a3e5e5b0931eeefa1c813a185fc01d7d7b6eb945937a7c744b" },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    -- Bake the installed system image as the default -sysdir: the payload's
    -- program moves to bin/android-run.real and bin/android-run becomes a
    -- shim that sets ANDROID_RUN_SYSDIR only if unset (`: "${V:=d}"`), the
    -- same only-if-unset contract the emulator wrapper keeps.
    local img = pkginfo.dep_install_dir("xim:android-system-image")
    local bindir = path.join(pkginfo.install_dir(), "bin")
    local real = path.join(bindir, "android-run")
    if not img or not os.isfile(real) then
        return true
    end
    os.mv(real, path.join(bindir, "android-run.real"))
    local f = io.open(real, "w")
    if not f then
        return false, "android-runner: cannot write " .. real
    end
    f:write(string.format([==[
#!/usr/bin/env bash
: "${ANDROID_RUN_SYSDIR:=%s}"
exec "$(dirname "$0")/android-run.real" "$@"
]==], img))
    f:close()
    os.iorun('chmod +x "' .. real .. '"')
    return true
end

function config()
    local dir = pkginfo.install_dir()
    xvm.add(package.name)
    xvm.add("android-run", { bindir = path.join(dir, "bin") })
    return true
end

function uninstall()
    xvm.remove("android-run")
    xvm.remove(package.name)
    return true
end
