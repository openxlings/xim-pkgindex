-- coursier: the Maven / Ivy dependency resolver and fetcher (`cs`), the
-- self-contained JVM launcher coursier releases.
--
-- WHAT THIS PACKAGE IS FOR. A build tool that consumes Maven artifacts --
-- mcpp:plugins' `dist-apk` resolves an Android application's AndroidX and
-- other AAR/JAR dependencies -- needs a resolver that reads POMs, mediates
-- versions across a transitive graph, verifies repository checksums and
-- keeps a cache, and it needs that resolver pinned. coursier does all of it
-- behind one command (`cs fetch ... --json-output-file`), including the
-- `aar` packaging Google's Maven repository publishes Android libraries in
-- (`-A aar,jar`).
--
-- THE JAR, NOT THE NATIVE LAUNCHERS, AND THE REASON IS COVERAGE. The v2.1.24
-- release publishes native `cs` images for linux x86_64, macOS x86_64 and
-- aarch64 and windows x86_64, and none for linux aarch64 or windows aarch64.
-- `coursier.jar` is the same CLI (`Main-Class: coursier.cli.Coursier`) and
-- runs on every host this index names, so one file with one sha256 serves
-- all of them -- the shape `bundletool.lua` uses. The jar carries a short
-- shell preamble before the archive (unzip reports 544 extra bytes);
-- `java -jar` reads the archive from its central directory and runs it
-- unchanged, measured with JDK 21 resolving an AndroidX AAR graph.
--
-- THE CN MIRROR IS THE SAME FILE. `gitcode.com/xlings-res/coursier` carries the
-- upstream jar byte for byte (published with `gtc release publish`), so one
-- sha256 checks both URLs.
--
-- THE JDK IS A DEPENDENCY, AND THE LAUNCHER CARRIES IT, exactly as in
-- `bundletool.lua` and `kotlin.lua`, pinned to the same store key.
--
-- LAYOUT (install_dir()):
--   coursier.jar
--   bin/cs, bin/coursier            launchers (POSIX)
--   bin/cs.bat, bin/coursier.bat    launchers (Windows)

package = {
    spec = "2",
    homepage = "https://get-coursier.io",

    name = "coursier",
    description = "coursier (cs): Maven/Ivy dependency resolver and artifact fetcher, the self-contained JVM launcher",

    maintainers = {"The coursier authors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/coursier/coursier",
    docs = "https://get-coursier.io/docs/cli-fetch",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"tool", "jvm", "build-tools", "android"},
    keywords = {"coursier", "cs", "maven", "ivy", "dependency", "resolver", "aar", "android"},

    programs = {"cs", "coursier"},
    xvm_enable = true,



    extensions = {
        autoupdate = {
            source = "https://github.com/coursier/coursier/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = "https://github.com/coursier/coursier/releases/download/v${version}/coursier.jar",
                        macosx = "https://github.com/coursier/coursier/releases/download/v${version}/coursier.jar",
                        windows = "https://github.com/coursier/coursier/releases/download/v${version}/coursier.jar",
                    },
                    required = true,
                },
                CN = {
                    url = {
                        linux = "https://gitcode.com/xlings-res/coursier/releases/download/${version}/coursier.jar",
                        macosx = "https://gitcode.com/xlings-res/coursier/releases/download/${version}/coursier.jar",
                        windows = "https://gitcode.com/xlings-res/coursier/releases/download/${version}/coursier.jar",
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            deps = { runtime = { "xim:jdk-temurin@25.0.4+7" } },
            ["latest"] = { ref = "2.1.24" },
            ["2.1.24"] = {
                url = {
                    GLOBAL = "https://github.com/coursier/coursier/releases/download/v2.1.24/coursier.jar",
                    CN = "https://gitcode.com/xlings-res/coursier/releases/download/2.1.24/coursier.jar",
                },
                sha256 = "8c724dc204534353ea8263ba0af624979658f7ab62395f35b04f03ce5714f330",
            },
        },
        macosx = {
            deps = { runtime = { "xim:jdk-temurin@25.0.4+7" } },
            ["latest"] = { ref = "2.1.24" },
            ["2.1.24"] = {
                url = {
                    GLOBAL = "https://github.com/coursier/coursier/releases/download/v2.1.24/coursier.jar",
                    CN = "https://gitcode.com/xlings-res/coursier/releases/download/2.1.24/coursier.jar",
                },
                sha256 = "8c724dc204534353ea8263ba0af624979658f7ab62395f35b04f03ce5714f330",
            },
        },
        windows = {
            deps = { runtime = { "xim:jdk-temurin@25.0.4+7" } },
            ["latest"] = { ref = "2.1.24" },
            ["2.1.24"] = {
                url = {
                    GLOBAL = "https://github.com/coursier/coursier/releases/download/v2.1.24/coursier.jar",
                    CN = "https://gitcode.com/xlings-res/coursier/releases/download/2.1.24/coursier.jar",
                },
                sha256 = "8c724dc204534353ea8263ba0af624979658f7ab62395f35b04f03ce5714f330",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

local JAR = "coursier.jar"
local LAUNCHED = {"cs", "coursier"}

-- `%s` placeholders: the JDK home resolved at install time, then the jar's
-- absolute path. The fallback is `bundletool.lua`'s.
local POSIX_LAUNCHER = [==[
#!/usr/bin/env bash
# xim:coursier launcher. Runs coursier.jar with the JDK this package declares.
set -uo pipefail

JAVA_HOME="%s"

if [ ! -x "$JAVA_HOME/bin/java" ]; then
    __bindir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    __store_root="$(dirname "$(dirname "$(dirname "$__bindir")")")"
    __fallback_java="$(ls -d "$__store_root"/xim-x-jdk-*/*/bin/java 2>/dev/null | sort -V | tail -1)"
    if [ -n "$__fallback_java" ] && [ -x "$__fallback_java" ]; then
        JAVA_HOME="$(dirname "$(dirname "$__fallback_java")")"
    else
        echo "coursier: xim:jdk-temurin's java was not found at $JAVA_HOME/bin/java," >&2
        echo "coursier: and no $__store_root/xim-x-jdk-*/*/bin/java exists either." >&2
        echo "coursier: Declare xim:jdk-temurin as a dependency, or install it." >&2
        exit 2
    fi
fi

export JAVA_HOME
exec "$JAVA_HOME/bin/java" -jar "%s" "$@"
]==]

-- `%s` placeholders: the JDK home, the jar, and the JDK home again for the
-- refusal.
local WINDOWS_LAUNCHER = [==[
@echo off
rem xim:coursier launcher.
setlocal
set "COURSIER_JAVA=%s\bin\java.exe"
rem The declared JDK is 25, which prints four warnings on stderr each time
rem coursier loads its Windows JNI helper unless native access is enabled.
rem Only that JDK is given the flag: a JDK older than 22 refuses it.
set "COURSIER_JAVA_OPTS=--enable-native-access=ALL-UNNAMED"
if exist "%%COURSIER_JAVA%%" goto run
if not defined JAVA_HOME goto nojava
if not exist "%%JAVA_HOME%%\bin\java.exe" goto nojava
set "COURSIER_JAVA=%%JAVA_HOME%%\bin\java.exe"
set "COURSIER_JAVA_OPTS="
:run
"%%COURSIER_JAVA%%" %%COURSIER_JAVA_OPTS%% -jar "%s" %%*
exit /b %%ERRORLEVEL%%
:nojava
echo coursier: java.exe was found neither at "%s\bin\java.exe" nor under JAVA_HOME. Declare xim:jdk-temurin as a dependency, or install it. 1>&2
exit /b 2
]==]

local function winpath(p)
    return (p:gsub("/", "\\"))
end

function install()
    local dir = pkginfo.install_dir()
    local jarfile = pkginfo.install_file()
    if not jarfile or not os.isfile(jarfile) then
        raise("coursier: the downloaded jar is missing (install_file = " .. tostring(jarfile) .. ")")
    end

    os.tryrm(dir)
    os.mkdir(dir)
    local jar = path.join(dir, JAR)
    os.cp(jarfile, jar)
    if not os.isfile(jar) then
        raise("coursier: " .. jar .. " was not written")
    end

    local jdk_home = pkginfo.dep_install_dir("xim:jdk-temurin")
    if not jdk_home then
        raise("coursier: xim:jdk-temurin payload not found (this package's deps declare it); "
              .. "refusing to write a launcher that cannot find java")
    end

    local bindir = path.join(dir, "bin")
    os.mkdir(bindir)
    for _, name in ipairs(LAUNCHED) do
        if is_host("windows") then
            local launcher = path.join(bindir, name .. ".bat")
            local f = io.open(launcher, "w")
            if not f then raise("coursier: cannot write " .. launcher) end
            f:write((string.format(WINDOWS_LAUNCHER, winpath(jdk_home), winpath(jar),
                                   winpath(jdk_home)):gsub("\n", "\r\n")))
            f:close()
            if not os.isfile(launcher) then raise("coursier: " .. launcher .. " was not written") end
        else
            local launcher = path.join(bindir, name)
            local f = io.open(launcher, "w")
            if not f then raise("coursier: cannot write " .. launcher) end
            f:write(string.format(POSIX_LAUNCHER, jdk_home, jar))
            f:close()
            os.iorun('chmod +x "' .. launcher .. '"')
            local ok = try { function() return os.iorun('bash -n "' .. launcher .. '"') end }
            if ok == nil then raise("coursier: " .. launcher .. " is not valid shell") end
        end
    end

    log.debug("coursier: staged %s with launchers in %s", jar, bindir)
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
