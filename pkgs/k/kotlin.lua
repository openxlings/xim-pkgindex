-- kotlin: the Kotlin compiler (`kotlinc`) and runner (`kotlin`), JetBrains'
-- own release archive.
--
-- WHAT THIS PACKAGE IS FOR. A build tool that compiles an Android application's
-- Kotlin sources -- mcpp:plugins' `dist-apk` does, beside `javac` and `d8` --
-- needs a compiler it can name by package and pin by version, rather than
-- whatever `kotlinc` a machine happens to carry. The standard library the
-- compiled classes link against ships in the same archive
-- (`kotlinc/lib/kotlin-stdlib.jar`), so one payload answers both questions a
-- consumer asks: where the compiler is, and which stdlib matches it.
--
-- ONE ARCHIVE FOR EVERY HOST. `kotlin-compiler-<version>.zip` is the JVM
-- compiler: jars plus `bin/` launchers for POSIX shells and for cmd.exe. It
-- carries no native code, so the same file, checked against the same
-- sha256 JetBrains publishes beside it (`<archive>.zip.sha256`), serves
-- linux, macosx and windows on x86_64 and aarch64 alike -- the shape
-- `bundletool.lua` uses for its jar.
--
-- THE CN MIRROR IS THE SAME FILE. `gitcode.com/xlings-res/kotlin` carries the
-- upstream archive byte for byte (published with `gtc release publish`), so one
-- sha256 checks both URLs.
--
-- THE JDK IS A DEPENDENCY, AND THE LAUNCHER CARRIES IT. `kotlinc` runs on a
-- JVM and finds it through `JAVA_HOME`, then `PATH`. A payload that relied on
-- either would compile with whatever JDK the machine offers, so `install()`
-- writes `bin/kotlinc` and `bin/kotlin` launchers that set `JAVA_HOME` to the
-- `xim:jdk-temurin` payload resolved at install time and then run upstream's
-- own scripts unchanged. The pin is the exact store key `bundletool.lua` and
-- mcpp:plugins' `dist-apk` declare (`25.0.4+7`), so a consumer that already
-- has that JDK installs no second one.
--
-- LAYOUT (install_dir()):
--   kotlinc/                  upstream's archive, unmodified
--   kotlinc/lib/kotlin-stdlib.jar
--   bin/kotlinc, bin/kotlin   launchers (POSIX)
--   bin/kotlinc.bat, bin/kotlin.bat   launchers (Windows)

package = {
    spec = "2",
    homepage = "https://kotlinlang.org",

    name = "kotlin",
    description = "Kotlin compiler (kotlinc) and runner, with the matching kotlin-stdlib, JetBrains' release archive",

    maintainers = {"JetBrains"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/JetBrains/kotlin",
    docs = "https://kotlinlang.org/docs/command-line.html",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"compiler", "language", "jvm", "android"},
    keywords = {"kotlin", "kotlinc", "jvm", "android", "compiler"},

    programs = {"kotlinc", "kotlin"},
    xvm_enable = true,



    extensions = {
        autoupdate = {
            source = "https://github.com/JetBrains/kotlin/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = "https://github.com/JetBrains/kotlin/releases/download/v${version}/kotlin-compiler-${version}.zip",
                        macosx = "https://github.com/JetBrains/kotlin/releases/download/v${version}/kotlin-compiler-${version}.zip",
                        windows = "https://github.com/JetBrains/kotlin/releases/download/v${version}/kotlin-compiler-${version}.zip",
                    },
                    required = true,
                },
                CN = {
                    url = {
                        linux = "https://gitcode.com/xlings-res/kotlin/releases/download/${version}/kotlin-compiler-${version}.zip",
                        macosx = "https://gitcode.com/xlings-res/kotlin/releases/download/${version}/kotlin-compiler-${version}.zip",
                        windows = "https://gitcode.com/xlings-res/kotlin/releases/download/${version}/kotlin-compiler-${version}.zip",
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            deps = { runtime = { "xim:jdk-temurin@25.0.4+7" } },
            ["latest"] = { ref = "2.4.20" },
            ["2.4.20"] = {
                url = {
                    GLOBAL = "https://github.com/JetBrains/kotlin/releases/download/v2.4.20/kotlin-compiler-2.4.20.zip",
                    CN = "https://gitcode.com/xlings-res/kotlin/releases/download/2.4.20/kotlin-compiler-2.4.20.zip",
                },
                sha256 = "59e9ca74c7904ef2c122b12114937673ccce68de820a663f0ed66ccf8799e0b7",
            },
        },
        macosx = {
            deps = { runtime = { "xim:jdk-temurin@25.0.4+7" } },
            ["latest"] = { ref = "2.4.20" },
            ["2.4.20"] = {
                url = {
                    GLOBAL = "https://github.com/JetBrains/kotlin/releases/download/v2.4.20/kotlin-compiler-2.4.20.zip",
                    CN = "https://gitcode.com/xlings-res/kotlin/releases/download/2.4.20/kotlin-compiler-2.4.20.zip",
                },
                sha256 = "59e9ca74c7904ef2c122b12114937673ccce68de820a663f0ed66ccf8799e0b7",
            },
        },
        windows = {
            deps = { runtime = { "xim:jdk-temurin@25.0.4+7" } },
            ["latest"] = { ref = "2.4.20" },
            ["2.4.20"] = {
                url = {
                    GLOBAL = "https://github.com/JetBrains/kotlin/releases/download/v2.4.20/kotlin-compiler-2.4.20.zip",
                    CN = "https://gitcode.com/xlings-res/kotlin/releases/download/2.4.20/kotlin-compiler-2.4.20.zip",
                },
                sha256 = "59e9ca74c7904ef2c122b12114937673ccce68de820a663f0ed66ccf8799e0b7",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

local LAUNCHED = {"kotlinc", "kotlin"}

-- `%s` placeholders: the JDK home resolved at install time, then the upstream
-- script to run. The same fallback as `bundletool.lua`: a JDK that moved is
-- replaced by the newest `xim:jdk-*` in the store before the launcher refuses.
local POSIX_LAUNCHER = [==[
#!/usr/bin/env bash
# xim:kotlin launcher. Runs JetBrains' own script with the JDK this package
# declares.
set -uo pipefail

JAVA_HOME="%s"

if [ ! -x "$JAVA_HOME/bin/java" ]; then
    __bindir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    __store_root="$(dirname "$(dirname "$(dirname "$__bindir")")")"
    __fallback_java="$(ls -d "$__store_root"/xim-x-jdk-*/*/bin/java 2>/dev/null | sort -V | tail -1)"
    if [ -n "$__fallback_java" ] && [ -x "$__fallback_java" ]; then
        JAVA_HOME="$(dirname "$(dirname "$__fallback_java")")"
    else
        echo "kotlin: xim:jdk-temurin's java was not found at $JAVA_HOME/bin/java," >&2
        echo "kotlin: and no $__store_root/xim-x-jdk-*/*/bin/java exists either." >&2
        echo "kotlin: Declare xim:jdk-temurin as a dependency, or install it." >&2
        exit 2
    fi
fi

export JAVA_HOME
exec "%s" "$@"
]==]

-- `%s` placeholders: the JDK home, the upstream `.bat` to call, and the JDK
-- home again for the refusal. Labels rather than parenthesised blocks, for
-- the reason `bundletool.lua` gives: a path with parentheses ends a block.
local WINDOWS_LAUNCHER = [==[
@echo off
rem xim:kotlin launcher.
setlocal
set "KOTLIN_JDK=%s"
if exist "%%KOTLIN_JDK%%\bin\java.exe" goto run
if not defined JAVA_HOME goto nojava
if not exist "%%JAVA_HOME%%\bin\java.exe" goto nojava
set "KOTLIN_JDK=%%JAVA_HOME%%"
:run
set "JAVA_HOME=%%KOTLIN_JDK%%"
call "%s" %%*
exit /b %%ERRORLEVEL%%
:nojava
echo kotlin: java.exe was found neither at "%s\bin\java.exe" nor under JAVA_HOME. Declare xim:jdk-temurin as a dependency, or install it. 1>&2
exit /b 2
]==]

local function winpath(p)
    return (p:gsub("/", "\\"))
end

-- A complete upstream tree: the compiler script and the stdlib it links.
local function complete(root)
    return os.isfile(path.join(root, "bin", "kotlinc"))
       and os.isfile(path.join(root, "lib", "kotlin-stdlib.jar"))
end

function install()
    local dir = pkginfo.install_dir()
    local tree = path.join(dir, "kotlinc")

    -- xim engines differ in whether the archive is extracted into the hook's
    -- working directory or staged into install_dir() first (see
    -- `jdk-temurin.lua`'s install hook), so both are looked at, and nothing is
    -- removed until a complete tree has been found. Compared by location
    -- rather than with `path.absolute`, which the xpkg sandbox does not bind
    -- (`windows-sdk.lua`).
    if not complete(tree) then
        if complete("kotlinc") then
            os.tryrm(dir)
            os.mkdir(dir)
            os.mv("kotlinc", tree)
        elseif complete(dir) then
            -- Staged flat: move it one level down, so the launchers under
            -- bin/ do not collide with upstream's own scripts.
            local tmp = dir .. ".kotlinc"
            os.tryrm(tmp)
            os.mv(dir, tmp)
            os.mkdir(dir)
            os.mv(tmp, tree)
        else
            raise("kotlin: the archive's kotlinc/ tree (bin/kotlinc and lib/kotlin-stdlib.jar) was not found")
        end
    end
    if not complete(tree) then
        raise("kotlin: " .. tree .. " is incomplete after staging")
    end

    local jdk_home = pkginfo.dep_install_dir("xim:jdk-temurin")
    if not jdk_home then
        raise("kotlin: xim:jdk-temurin payload not found (this package's deps declare it); "
              .. "refusing to write a launcher that cannot find java")
    end

    local bindir = path.join(dir, "bin")
    os.mkdir(bindir)
    for _, name in ipairs(LAUNCHED) do
        if is_host("windows") then
            local launcher = path.join(bindir, name .. ".bat")
            local f = io.open(launcher, "w")
            if not f then raise("kotlin: cannot write " .. launcher) end
            f:write((string.format(WINDOWS_LAUNCHER, winpath(jdk_home),
                                   winpath(path.join(tree, "bin", name .. ".bat")),
                                   winpath(jdk_home)):gsub("\n", "\r\n")))
            f:close()
            if not os.isfile(launcher) then raise("kotlin: " .. launcher .. " was not written") end
        else
            local upstream = path.join(tree, "bin", name)
            os.iorun('chmod +x "' .. upstream .. '"')
            local launcher = path.join(bindir, name)
            local f = io.open(launcher, "w")
            if not f then raise("kotlin: cannot write " .. launcher) end
            f:write(string.format(POSIX_LAUNCHER, jdk_home, upstream))
            f:close()
            os.iorun('chmod +x "' .. launcher .. '"')
            local ok = try { function() return os.iorun('bash -n "' .. launcher .. '"') end }
            if ok == nil then raise("kotlin: " .. launcher .. " is not valid shell") end
        end
    end

    log.debug("kotlin: staged %s with launchers in %s", tree, bindir)
    return true
end

function config()
    local bindir = path.join(pkginfo.install_dir(), "bin")
    for _, name in ipairs(LAUNCHED) do
        if is_host("windows") then
            xvm.add(name, { bindir = bindir, filename = name .. ".bat" })
        else
            xvm.add(name, { bindir = bindir })
        end
    end
    return true
end

function uninstall()
    for _, name in ipairs(LAUNCHED) do
        xvm.remove(name)
    end
    return true
end
