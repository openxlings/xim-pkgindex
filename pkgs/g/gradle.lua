-- gradle: the Gradle build tool, from Gradle's own distribution service.
--
-- WHAT THIS PACKAGE IS FOR. A JVM-platform build that a consumer has to run
-- rather than read: an IntelliJ-platform plugin is a Gradle project, and so is
-- most of what Android and Kotlin ship. `xim:kotlin` already gives the compiler
-- and `xim:jdk-temurin` the runtime; this gives the build tool that drives them,
-- named by package and pinned by version rather than whatever `gradle` a machine
-- happens to carry.
--
-- ONE ARCHIVE FOR EVERY HOST. `gradle-<version>-bin.zip` is JVM bytecode plus
-- launcher scripts for POSIX shells and for cmd.exe. It carries no native code,
-- so the same file, checked against the same sha256 Gradle publishes beside it
-- (`<archive>.zip.sha256`), serves linux, macosx and windows on x86_64 and
-- aarch64 alike -- the shape `kotlin.lua` uses for its compiler.
--
-- THE CN MIRROR IS THE SAME FILE, AND IT IS NOT ONE WE PUBLISH. Tencent's
-- mirror carries `services.gradle.org/distributions` as a full copy, so CN
-- points at it directly rather than re-uploading a tree that already has a CN
-- copy -- the reason `node.lua` points at npmmirror instead of xlings-res.
-- Verified 2026-09-16: the upstream archive and the Tencent copy are
-- byte-identical, and both match the digest in Gradle's own `.sha256` sidecar
-- and its `services.gradle.org/versions/current` record. The sha256 below is
-- what proves this at install time, whichever of the two a machine reaches.
--
-- THE JDK IS A DEPENDENCY, AND THE LAUNCHER CARRIES IT. `gradle` runs on a JVM
-- and finds it through JAVA_HOME, then PATH. A payload that relied on either
-- would build with whatever JDK the machine offers, so `install()` writes a
-- `bin/gradle` launcher that sets JAVA_HOME to the `xim:jdk-temurin` payload
-- resolved at install time and then runs upstream's own script unchanged. The
-- pin is the exact store key `kotlin.lua` declares, so a consumer that already
-- has that JDK installs no second one. Verified 2026-09-16 on linux x86_64:
-- Gradle 9.7.1 runs on Temurin 25.0.4+7 (`Launcher JVM: 25.0.4`).
--
-- LAYOUT (install_dir()):
--   gradle/                   upstream's archive, unmodified
--   gradle/bin/gradle         upstream's script
--   bin/gradle                launcher (POSIX)
--   bin/gradle.bat            launcher (Windows)

package = {
    spec = "2",
    homepage = "https://gradle.org",

    name = "gradle",
    description = "Gradle build tool, the official distribution",

    maintainers = {"Gradle Inc."},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/gradle/gradle",
    docs = "https://docs.gradle.org/current/userguide/userguide.html",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"build-tool", "jvm"},
    keywords = {"gradle", "build", "jvm", "kotlin", "android", "intellij"},

    programs = {"gradle"},
    xvm_enable = true,

    xpm = {
        linux = {
            deps = { runtime = { "xim:jdk-temurin@25.0.4+7" } },
            ["latest"] = { ref = "9.7.1" },
            ["9.7.1"] = {
                url = {
                    GLOBAL = "https://services.gradle.org/distributions/gradle-9.7.1-bin.zip",
                    CN = "https://mirrors.cloud.tencent.com/gradle/gradle-9.7.1-bin.zip",
                },
                sha256 = "acd53f1edaf02f1a8ff99879f8a34b302661a057d9b063ae9e35b552f804d20a",
            },
        },
        macosx = {
            deps = { runtime = { "xim:jdk-temurin@25.0.4+7" } },
            ["latest"] = { ref = "9.7.1" },
            ["9.7.1"] = {
                url = {
                    GLOBAL = "https://services.gradle.org/distributions/gradle-9.7.1-bin.zip",
                    CN = "https://mirrors.cloud.tencent.com/gradle/gradle-9.7.1-bin.zip",
                },
                sha256 = "acd53f1edaf02f1a8ff99879f8a34b302661a057d9b063ae9e35b552f804d20a",
            },
        },
        windows = {
            deps = { runtime = { "xim:jdk-temurin@25.0.4+7" } },
            ["latest"] = { ref = "9.7.1" },
            ["9.7.1"] = {
                url = {
                    GLOBAL = "https://services.gradle.org/distributions/gradle-9.7.1-bin.zip",
                    CN = "https://mirrors.cloud.tencent.com/gradle/gradle-9.7.1-bin.zip",
                },
                sha256 = "acd53f1edaf02f1a8ff99879f8a34b302661a057d9b063ae9e35b552f804d20a",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

-- `%s` placeholders: the JDK home resolved at install time, then the upstream
-- script to run. The same fallback as `kotlin.lua`: a JDK that moved is replaced
-- by the newest `xim:jdk-*` in the store before the launcher refuses.
local POSIX_LAUNCHER = [==[
#!/usr/bin/env bash
# xim:gradle launcher. Runs Gradle's own script with the JDK this package
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
        echo "gradle: xim:jdk-temurin's java was not found at $JAVA_HOME/bin/java," >&2
        echo "gradle: and no $__store_root/xim-x-jdk-*/*/bin/java exists either." >&2
        echo "gradle: Declare xim:jdk-temurin as a dependency, or install it." >&2
        exit 2
    fi
fi

export JAVA_HOME
exec "%s" "$@"
]==]

-- `%s` placeholders: the JDK home, the upstream `.bat` to call, and the JDK home
-- again for the refusal. Labels rather than parenthesised blocks, for the reason
-- `kotlin.lua` gives: a path with parentheses ends a block.
local WINDOWS_LAUNCHER = [==[
@echo off
rem xim:gradle launcher.
setlocal
set "GRADLE_JDK=%s"
if exist "%%GRADLE_JDK%%\bin\java.exe" goto run
if not defined JAVA_HOME goto nojava
if not exist "%%JAVA_HOME%%\bin\java.exe" goto nojava
set "GRADLE_JDK=%%JAVA_HOME%%"
:run
set "JAVA_HOME=%%GRADLE_JDK%%"
call "%s" %%*
exit /b %%ERRORLEVEL%%
:nojava
echo gradle: java.exe was found neither at "%s\bin\java.exe" nor under JAVA_HOME. Declare xim:jdk-temurin as a dependency, or install it. 1>&2
exit /b 2
]==]

local function winpath(p)
    return (p:gsub("/", "\\"))
end

-- A complete upstream tree: the launcher script and the jar it starts.
local function complete(root)
    return os.isfile(path.join(root, "bin", "gradle"))
       and os.isdir(path.join(root, "lib"))
end

-- The archive's top directory carries the version (`gradle-9.7.1/`), unlike
-- kotlin's fixed `kotlinc/`, so it is named from the version being installed
-- rather than globbed: `os.dirs("gradle-*")` does not resolve against the
-- hook's working directory, and a glob would in any case be free to pick a
-- leftover tree from a different version.
local function find_tree(where)
    local root = "gradle-" .. pkginfo.version()
    local named = where and path.join(where, root) or root
    if complete(named) then return named end
    for _, candidate in ipairs(os.dirs(where and path.join(where, "gradle-*") or "gradle-*") or {}) do
        if complete(candidate) then return candidate end
    end
    return nil
end

function install()
    local dir = pkginfo.install_dir()
    local tree = path.join(dir, "gradle")

    -- xim engines differ in whether the archive is extracted into the hook's
    -- working directory or staged into install_dir() first (see
    -- `jdk-temurin.lua`), so both are looked at, and nothing is removed until a
    -- complete tree has been found. Compared by location rather than with
    -- `path.absolute`, which the xpkg sandbox does not bind (`windows-sdk.lua`).
    if not complete(tree) then
        local staged = find_tree(nil) or find_tree(dir)
        if staged then
            os.tryrm(tree)
            os.mkdir(dir)
            os.mv(staged, tree)
        elseif complete(dir) then
            -- Staged flat: move it one level down, so the launcher under bin/
            -- does not collide with upstream's own script.
            local tmp = dir .. ".gradle"
            os.tryrm(tmp)
            os.mv(dir, tmp)
            os.mkdir(dir)
            os.mv(tmp, tree)
        else
            raise("gradle: the archive's gradle-<version>/ tree (bin/gradle and lib/) was not found")
        end
    end
    if not complete(tree) then
        raise("gradle: " .. tree .. " is incomplete after staging")
    end

    local jdk_home = pkginfo.dep_install_dir("xim:jdk-temurin")
    if not jdk_home then
        raise("gradle: xim:jdk-temurin payload not found (this package's deps declare it); "
              .. "refusing to write a launcher that cannot find java")
    end

    local bindir = path.join(dir, "bin")
    os.mkdir(bindir)
    if is_host("windows") then
        local launcher = path.join(bindir, "gradle.bat")
        local f = io.open(launcher, "w")
        if not f then raise("gradle: cannot write " .. launcher) end
        f:write((string.format(WINDOWS_LAUNCHER, winpath(jdk_home),
                               winpath(path.join(tree, "bin", "gradle.bat")),
                               winpath(jdk_home)):gsub("\n", "\r\n")))
        f:close()
        if not os.isfile(launcher) then raise("gradle: " .. launcher .. " was not written") end
    else
        local upstream = path.join(tree, "bin", "gradle")
        os.iorun('chmod +x "' .. upstream .. '"')
        local launcher = path.join(bindir, "gradle")
        local f = io.open(launcher, "w")
        if not f then raise("gradle: cannot write " .. launcher) end
        f:write(string.format(POSIX_LAUNCHER, jdk_home, upstream))
        f:close()
        os.iorun('chmod +x "' .. launcher .. '"')
        local ok = try { function() return os.iorun('bash -n "' .. launcher .. '"') end }
        if ok == nil then raise("gradle: " .. launcher .. " is not valid shell") end
    end

    log.debug("gradle: staged %s with a launcher in %s", tree, bindir)
    return true
end

function config()
    local bindir = path.join(pkginfo.install_dir(), "bin")
    if is_host("windows") then
        xvm.add("gradle", { bindir = bindir, filename = "gradle.bat" })
    else
        xvm.add("gradle", { bindir = bindir })
    end
    return true
end

function uninstall()
    xvm.remove("gradle")
    return true
end
