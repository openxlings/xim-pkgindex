-- maven: the Apache Maven build tool, from Apache's official distribution.
--
-- WHAT THIS PACKAGE IS FOR. Apache Maven is the standard build and dependency
-- management tool across the Java / JVM ecosystem. `xim:jdk-temurin` provides
-- the JDK runtime; this gives the pinned `mvn` build tool named by package and
-- version rather than whatever `mvn` a machine happens to carry.
--
-- ONE ARCHIVE FOR EVERY HOST. `apache-maven-<version>-bin.zip` is JVM bytecode
-- plus launcher scripts for POSIX shells (`bin/mvn`) and for cmd.exe
-- (`bin/mvn.cmd`). It carries no native code, so the same archive, checked
-- against the sha256 derived from Apache's official `.sha512` release digest,
-- serves linux, macosx and windows on x86_64 and aarch64 alike -- the shape
-- `gradle.lua` uses.
--
-- MIRRORS. `GLOBAL` points to `archive.apache.org/dist/maven/maven-3/...`,
-- which retains released versions permanently (unlike `dlcdn.apache.org`, which
-- drops older 3.9.x releases when a newer patch ships). `CN` points to
-- Tencent's Apache mirror (`mirrors.cloud.tencent.com/apache/maven/maven-3/...`),
-- so the package declares no `ci.mirror`: a well-known CN mirror and the xlings-res
-- copy are mutually exclusive.
-- Verified 2026-11-24: `archive.apache.org`, `dlcdn.apache.org`,
-- `mirrors.cloud.tencent.com`, `mirrors.tuna.tsinghua.edu.cn`, and
-- `mirrors.ustc.edu.cn` serve byte-identical `apache-maven-3.9.16-bin.zip`
-- archives (9,395,475 bytes) matching Apache's `.sha512` sidecar and sha256
-- `5af3b743dd8b876b5c45da33b676251e5f1687712644abb4ee519ca56e1d89ce`.
--
-- THE JDK IS A DEPENDENCY, AND THE LAUNCHER CARRIES IT. `mvn` runs on a JVM
-- and finds it through `JAVA_HOME`, then `PATH`. `install()` writes `bin/mvn`
-- (POSIX) and `bin/mvn.bat` (Windows) wrappers that set `JAVA_HOME` to the
-- `xim:jdk-temurin` payload resolved at install time (with store/`JAVA_HOME`
-- fallback if the pinned JDK directory moved) and invoke upstream's `bin/mvn`
-- or `bin/mvn.cmd` unchanged.
--
-- LAYOUT (install_dir()):
--   maven/                    upstream's archive, unmodified
--   maven/bin/mvn             upstream's POSIX script
--   maven/bin/mvn.cmd         upstream's Windows cmd script
--   bin/mvn                   launcher (POSIX)
--   bin/mvn.bat               launcher (Windows)

package = {
    spec = "2",
    homepage = "https://maven.apache.org",

    name = "maven",
    description = "Apache Maven build tool and project management system, the official distribution",

    authors = {"The Apache Software Foundation"},
    maintainers = {"The Apache Software Foundation"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/apache/maven",
    docs = "https://maven.apache.org/guides/",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"build-tool", "jvm"},
    keywords = {"maven", "mvn", "build", "jvm", "java"},

    programs = {"mvn"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/apache/maven/tags",
            tag = "maven-${version}",
            resources = {
                GLOBAL = {
                    url = "https://archive.apache.org/dist/maven/maven-3/${version}/binaries/apache-maven-${version}-bin.zip",
                    required = true,
                },
                CN = {
                    url = "https://mirrors.cloud.tencent.com/apache/maven/maven-3/${version}/binaries/apache-maven-${version}-bin.zip",
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            deps = { runtime = { "xim:jdk-temurin@25.0.4+7" } },
            ["latest"] = { ref = "3.9.16" },
            ["3.9.16"] = {
                url = {
                    GLOBAL = "https://archive.apache.org/dist/maven/maven-3/3.9.16/binaries/apache-maven-3.9.16-bin.zip",
                    CN = "https://mirrors.cloud.tencent.com/apache/maven/maven-3/3.9.16/binaries/apache-maven-3.9.16-bin.zip",
                },
                sha256 = "5af3b743dd8b876b5c45da33b676251e5f1687712644abb4ee519ca56e1d89ce",
            },
        },
        macosx = {
            deps = { runtime = { "xim:jdk-temurin@25.0.4+7" } },
            ["latest"] = { ref = "3.9.16" },
            ["3.9.16"] = {
                url = {
                    GLOBAL = "https://archive.apache.org/dist/maven/maven-3/3.9.16/binaries/apache-maven-3.9.16-bin.zip",
                    CN = "https://mirrors.cloud.tencent.com/apache/maven/maven-3/3.9.16/binaries/apache-maven-3.9.16-bin.zip",
                },
                sha256 = "5af3b743dd8b876b5c45da33b676251e5f1687712644abb4ee519ca56e1d89ce",
            },
        },
        windows = {
            deps = { runtime = { "xim:jdk-temurin@25.0.4+7" } },
            ["latest"] = { ref = "3.9.16" },
            ["3.9.16"] = {
                url = {
                    GLOBAL = "https://archive.apache.org/dist/maven/maven-3/3.9.16/binaries/apache-maven-3.9.16-bin.zip",
                    CN = "https://mirrors.cloud.tencent.com/apache/maven/maven-3/3.9.16/binaries/apache-maven-3.9.16-bin.zip",
                },
                sha256 = "5af3b743dd8b876b5c45da33b676251e5f1687712644abb4ee519ca56e1d89ce",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

-- `%s` placeholders: the JDK home resolved at install time, then the upstream
-- script to run. A JDK that moved is replaced by the newest `xim:jdk-*` in
-- the store before the launcher refuses.
local POSIX_LAUNCHER = [==[
#!/usr/bin/env bash
# xim:maven launcher. Runs Maven's own script with the JDK this package
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
        echo "maven: xim:jdk-temurin's java was not found at $JAVA_HOME/bin/java," >&2
        echo "maven: and no $__store_root/xim-x-jdk-*/*/bin/java exists either." >&2
        echo "maven: Declare xim:jdk-temurin as a dependency, or install it." >&2
        exit 2
    fi
fi

export JAVA_HOME
exec "%s" "$@"
]==]

-- `%s` placeholders: the JDK home, the upstream `.cmd` to call, and the JDK home
-- again for the refusal. Labels rather than parenthesised blocks, so a path
-- containing parentheses cannot prematurely close a block.
local WINDOWS_LAUNCHER = [==[
@echo off
rem xim:maven launcher.
setlocal
set "MAVEN_JDK=%s"
if exist "%%MAVEN_JDK%%\bin\java.exe" goto run
if not defined JAVA_HOME goto nojava
if not exist "%%JAVA_HOME%%\bin\java.exe" goto nojava
set "MAVEN_JDK=%%JAVA_HOME%%"
:run
set "JAVA_HOME=%%MAVEN_JDK%%"
call "%s" %%*
exit /b %%ERRORLEVEL%%
:nojava
echo maven: java.exe was found neither at "%s\bin\java.exe" nor under JAVA_HOME. Declare xim:jdk-temurin as a dependency, or install it. 1>&2
exit /b 2
]==]

local function winpath(p)
    return (p:gsub("/", "\\"))
end

-- A complete upstream tree: the launcher script, config, and maven-core jar.
local function complete(root)
    return os.isfile(path.join(root, "bin", "mvn"))
       and os.isfile(path.join(root, "bin", "mvn.cmd"))
       and os.isfile(path.join(root, "bin", "m2.conf"))
       and os.isfile(path.join(root, "lib", "maven-core-" .. pkginfo.version() .. ".jar"))
end

-- The archive's top directory carries the version (`apache-maven-3.9.16/`), so
-- it is named from the version being installed rather than globbed:
-- `os.dirs("apache-maven-*")` does not resolve against the hook's working
-- directory, and a glob could pick a leftover tree from a different version.
local function find_tree(where)
    local root = "apache-maven-" .. pkginfo.version()
    local named = where and path.join(where, root) or root
    if complete(named) then return named end
    for _, candidate in ipairs(os.dirs(where and path.join(where, "apache-maven-*") or "apache-maven-*") or {}) do
        if complete(candidate) then return candidate end
    end
    return nil
end

local function required_files()
    local dir = pkginfo.install_dir()
    local tree = path.join(dir, "maven")
    local files = {
        path.join(tree, "bin", "m2.conf"),
        path.join(tree, "lib", "maven-core-" .. pkginfo.version() .. ".jar"),
    }
    if is_host("windows") then
        table.insert(files, path.join(tree, "bin", "mvn.cmd"))
        table.insert(files, path.join(dir, "bin", "mvn.bat"))
    else
        table.insert(files, path.join(tree, "bin", "mvn"))
        table.insert(files, path.join(dir, "bin", "mvn"))
    end
    return files
end

function installed()
    for _, f in ipairs(required_files()) do
        if not os.isfile(f) then return false end
    end
    return true
end

function install()
    local dir = pkginfo.install_dir()
    local tree = path.join(dir, "maven")

    if not complete(tree) then
        local staged = find_tree(nil) or find_tree(dir)
        if staged then
            os.tryrm(tree)
            os.mkdir(dir)
            os.mv(staged, tree)
        elseif complete(dir) then
            local tmp = dir .. ".maven"
            os.tryrm(tmp)
            os.mv(dir, tmp)
            os.mkdir(dir)
            os.mv(tmp, tree)
        else
            error("maven: the archive's apache-maven-<version>/ tree (bin/mvn, bin/mvn.cmd, lib/) was not found")
        end
    end
    if not complete(tree) then
        error("maven: " .. tree .. " is incomplete after staging")
    end

    local jdk_home = pkginfo.dep_install_dir("xim:jdk-temurin")
    if not jdk_home then
        error("maven: xim:jdk-temurin payload not found (this package's deps declare it); "
              .. "refusing to write a launcher that cannot find java")
    end

    local bindir = path.join(dir, "bin")
    os.mkdir(bindir)
    if is_host("windows") then
        local launcher = path.join(bindir, "mvn.bat")
        local f = io.open(launcher, "w")
        if not f then error("maven: cannot write " .. launcher) end
        f:write((string.format(WINDOWS_LAUNCHER, winpath(jdk_home),
                               winpath(path.join(tree, "bin", "mvn.cmd")),
                               winpath(jdk_home)):gsub("\n", "\r\n")))
        f:close()
        if not os.isfile(launcher) then error("maven: " .. launcher .. " was not written") end
    else
        local upstream = path.join(tree, "bin", "mvn")
        os.iorun('chmod +x "' .. upstream .. '"')
        local launcher = path.join(bindir, "mvn")
        local f = io.open(launcher, "w")
        if not f then error("maven: cannot write " .. launcher) end
        f:write(string.format(POSIX_LAUNCHER, jdk_home, upstream))
        f:close()
        os.iorun('chmod +x "' .. launcher .. '"')
        local ok = pcall(os.iorun, 'bash -n "' .. launcher .. '"')
        if not ok then error("maven: " .. launcher .. " is not valid shell") end
    end

    local missing = {}
    for _, f in ipairs(required_files()) do
        if not os.isfile(f) then table.insert(missing, f) end
    end
    if #missing > 0 then
        error("maven: expected payload files missing after install:\n    " .. table.concat(missing, "\n    "))
    end

    log.debug("maven: staged %s with a launcher in %s", tree, bindir)
    return true
end

function config()
    local bindir = path.join(pkginfo.install_dir(), "bin")
    if is_host("windows") then
        xvm.add("mvn", { bindir = bindir, filename = "mvn.bat" })
    else
        xvm.add("mvn", { bindir = bindir })
    end
    xvm.add("maven", { type = "group" })
    return true
end

function uninstall()
    xvm.remove("mvn")
    xvm.remove("maven")
    return true
end
