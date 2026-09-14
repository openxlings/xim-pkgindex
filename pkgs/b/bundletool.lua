-- bundletool -- Google's tool for Android App Bundles: it builds an `.aab`
-- from a module archive, and APK sets from an `.aab`.
--
-- WHY THIS PACKAGE EXISTS. mcpp's official plugins turn an `app` target on
-- `*-linux-android` into an APK (`mcpp:plugins`' `dist-apk` member). The Play
-- Store takes an Android App Bundle instead, and the step that produces one
-- is `bundletool build-bundle` over a module archive that `aapt2 link
-- --proto-format` writes (mcpp#634; design record mcpp .agents/docs/
-- 2026-09-14-634-cmake-parity-items-by-home.md, section 6.5). `aapt2` is in
-- `xim:android-build-tools`; bundletool was in no package of this index.
--
-- ═══════════════════════════════════════════════════════════════════════
-- WHAT IS PACKAGED, AND WHAT WAS MEASURED (2026-09-14)
-- ═══════════════════════════════════════════════════════════════════════
--
-- Upstream publishes one file per release, `bundletool-all-<version>.jar`, on
-- its GitHub releases (https://github.com/google/bundletool/releases). 1.18.3
-- is the current release (published 2025-12-15). The jar was fetched with
-- curl, its size is 32520401 bytes, and the sha256 below was computed from
-- that download. Its manifest names `Main-Class:
-- com.android.tools.build.bundletool.BundleToolMain`; `BundleToolMain.class`
-- carries class file major version 52 (Java 8), and `java -jar
-- bundletool-all-1.18.3.jar version` under `xim:jdk-temurin` 25.0.4+7 prints
-- `1.18.3` and exits 0.
--
-- The jar is one download for every host: the same url and sha256 appear in
-- each platform section. The hosts are the JDK's: `xim:jdk-temurin` publishes
-- x86_64 and aarch64 for Linux and macOS and x86_64 for Windows.
--
-- LICENCE: Apache-2.0 (the repository's licence; the jar carries its own
-- NOTICE). No CN entry is written: a GitCode release of this jar has not been
-- published, and an address that was not published is not written.
--
-- ═══════════════════════════════════════════════════════════════════════
-- JAVA
-- ═══════════════════════════════════════════════════════════════════════
--
-- The JDK is a declared runtime dependency, pinned to the exact store key
-- `25.0.4+7`, for the reason `pkgs/a/android-build-tools.lua` records: a range
-- that matches `jdk-temurin`'s alias key `25.0.4` resolves
-- `pkginfo.dep_install_dir` to a directory that does not exist. The JDK home
-- is resolved at install time and written into the launcher, so the program
-- does not depend on the consumer's active `java`.
--
--   POSIX     `bin/bundletool`, a bash launcher that runs the baked JDK's
--             `java -jar` on the jar; if that JDK has moved, it takes the
--             newest `xim-x-jdk-*/*/bin/java` in the payload store, as the
--             android-build-tools wrappers do, and otherwise refuses naming
--             the dependency.
--   windows   `bin/bundletool.bat`, which runs the baked JDK's `java.exe`,
--             and only when that file is absent the one under `JAVA_HOME`.
--             The launcher reads no environment to find its own JDK, and the
--             xvm registration passes none: measured on windows-2022, an xvm
--             `envs = { JAVA_HOME = <jdk> }` joined the runner's own
--             `JAVA_HOME` to the value with `;`, and a launcher that trusted
--             the variable found no `java.exe` under the joined string.
--
-- ═══════════════════════════════════════════════════════════════════════
-- INSTALLED LAYOUT
-- ═══════════════════════════════════════════════════════════════════════
--
--   <install_dir>/bundletool-all.jar      upstream's jar, unmodified
--   <install_dir>/bin/bundletool          the launcher (linux, macosx)
--   <install_dir>/bin/bundletool.bat      the launcher (windows)
package = {
    spec = "2",
    homepage = "https://developer.android.com/tools/bundletool",

    name = "bundletool",
    description = "bundletool: build Android App Bundles and the APK sets they produce, Google's own tool",

    maintainers = {"Google"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/google/bundletool",
    docs = "https://developer.android.com/tools/bundletool",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"tool", "android", "build-tools"},
    keywords = {"android", "bundletool", "aab", "app-bundle", "apk"},

    programs = {"bundletool"},
    xvm_enable = true,

    xpm = {
        linux = {
            deps = { runtime = { "xim:jdk-temurin@25.0.4+7" } },
            ["latest"] = { ref = "1.18.3" },
            ["1.18.3"] = {
                url = {
                    GLOBAL = "https://github.com/google/bundletool/releases/download/1.18.3/bundletool-all-1.18.3.jar",
                },
                sha256 = "a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29",
            },
        },
        macosx = {
            deps = { runtime = { "xim:jdk-temurin@25.0.4+7" } },
            ["latest"] = { ref = "1.18.3" },
            ["1.18.3"] = {
                url = {
                    GLOBAL = "https://github.com/google/bundletool/releases/download/1.18.3/bundletool-all-1.18.3.jar",
                },
                sha256 = "a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29",
            },
        },
        windows = {
            deps = { runtime = { "xim:jdk-temurin@25.0.4+7" } },
            ["latest"] = { ref = "1.18.3" },
            ["1.18.3"] = {
                url = {
                    GLOBAL = "https://github.com/google/bundletool/releases/download/1.18.3/bundletool-all-1.18.3.jar",
                },
                sha256 = "a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

local JAR = "bundletool-all.jar"

-- `%s` placeholders: the JDK home resolved at install time, then the jar's
-- absolute path.
local POSIX_LAUNCHER = [==[
#!/usr/bin/env bash
# bundletool (xim:bundletool launcher).
#
# Runs the jar with the JDK this package declares. No `-e`: the fallback
# probe below assigns a command substitution that may legitimately find
# nothing, and the `if` after it handles that case.
set -uo pipefail

JAVA_HOME="%s"

if [ ! -x "$JAVA_HOME/bin/java" ]; then
    # The JDK resolved at install time is not there. Take the newest
    # xim:jdk-* payload in the store before refusing, as the
    # xim:android-build-tools wrappers do.
    __bindir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    __store_root="$(dirname "$(dirname "$(dirname "$__bindir")")")"
    __fallback_java="$(ls -d "$__store_root"/xim-x-jdk-*/*/bin/java 2>/dev/null | sort -V | tail -1)"
    if [ -n "$__fallback_java" ] && [ -x "$__fallback_java" ]; then
        JAVA_HOME="$(dirname "$(dirname "$__fallback_java")")"
    else
        echo "bundletool: xim:jdk-temurin's java was not found at" >&2
        echo "bundletool: $JAVA_HOME/bin/java, and no" >&2
        echo "bundletool: $__store_root/xim-x-jdk-*/*/bin/java exists either." >&2
        echo "bundletool: Declare xim:jdk-temurin as a dependency, or install it." >&2
        exit 2
    fi
fi

export JAVA_HOME
exec "$JAVA_HOME/bin/java" -jar "%s" "$@"
]==]

-- `%s` placeholders: the JDK home resolved at install time, the jar's
-- absolute path, and the JDK home again for the refusal. The baked JDK comes
-- first; `JAVA_HOME` is consulted only when that JDK is absent, and only as a
-- directory holding `bin\java.exe`. Labels rather than parenthesised blocks:
-- a path with parentheses, expanded inside a block, ends the block.
local WINDOWS_LAUNCHER = [==[
@echo off
rem bundletool (xim:bundletool launcher).
setlocal
set "BUNDLETOOL_JAVA=%s\bin\java.exe"
if exist "%%BUNDLETOOL_JAVA%%" goto run
if not defined JAVA_HOME goto nojava
if not exist "%%JAVA_HOME%%\bin\java.exe" goto nojava
set "BUNDLETOOL_JAVA=%%JAVA_HOME%%\bin\java.exe"
:run
"%%BUNDLETOOL_JAVA%%" -jar "%s" %%*
exit /b %%ERRORLEVEL%%
:nojava
echo bundletool: java.exe was found neither at "%s\bin\java.exe" nor under JAVA_HOME. Declare xim:jdk-temurin as a dependency, or install it. 1>&2
exit /b 2
]==]

local function winpath(p)
    return (p:gsub("/", "\\"))
end

function install()
    local dir = pkginfo.install_dir()
    local jarfile = pkginfo.install_file()
    if not jarfile or not os.isfile(jarfile) then
        raise("bundletool: the downloaded jar is missing (install_file = "
              .. tostring(jarfile) .. ")")
    end

    os.tryrm(dir)
    os.mkdir(dir)
    local jar = path.join(dir, JAR)
    os.cp(jarfile, jar)
    if not os.isfile(jar) then
        raise("bundletool: " .. jar .. " was not written")
    end

    local jdk_home = pkginfo.dep_install_dir("xim:jdk-temurin")
    if not jdk_home then
        raise("bundletool: xim:jdk-temurin payload not found (this package's "
              .. "deps declare xim:jdk-temurin); refusing to write a launcher "
              .. "that cannot find java")
    end

    local bindir = path.join(dir, "bin")
    os.mkdir(bindir)

    if is_host("windows") then
        local launcher = path.join(bindir, "bundletool.bat")
        local f = io.open(launcher, "w")
        if not f then
            raise("bundletool: cannot write " .. launcher)
        end
        f:write((string.format(WINDOWS_LAUNCHER, winpath(jdk_home), winpath(jar),
                               winpath(jdk_home))
                 :gsub("\n", "\r\n")))
        f:close()
        if not os.isfile(launcher) then
            raise("bundletool: " .. launcher .. " was not written")
        end
    else
        local launcher = path.join(bindir, "bundletool")
        local f = io.open(launcher, "w")
        if not f then
            raise("bundletool: cannot write " .. launcher)
        end
        f:write(string.format(POSIX_LAUNCHER, jdk_home, jar))
        f:close()
        os.iorun('chmod +x "' .. launcher .. '"')
        if not os.isfile(launcher) then
            raise("bundletool: " .. launcher .. " was not written")
        end
        local ok = try { function() return os.iorun('bash -n "' .. launcher .. '"') end }
        if ok == nil then
            raise("bundletool: " .. launcher .. " is not valid shell")
        end
    end

    return true
end

function config()
    local bindir = path.join(pkginfo.install_dir(), "bin")
    if is_host("windows") then
        -- No `envs`: the launcher carries its JDK (see JAVA in the header).
        xvm.add(package.name, { bindir = bindir, filename = "bundletool.bat" })
    else
        xvm.add(package.name, { bindir = bindir })
    end
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
