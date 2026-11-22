-- redis - in-memory data structure store (cache, database, message broker).
--
-- Platforms and sources:
--   linux    x86_64, aarch64   Statically compiled from official redis/redis 8.10.3 source (BUILD_TLS=no, pinned xim:make@4.3 + xim:musl-gcc@15.1.0)
--   macosx   x86_64, aarch64   Compiled from official redis/redis 8.10.3 source (BUILD_TLS=no, Xcode CLT make + cc)
--   windows  x86_64            Self-contained MSYS2 build from redis-windows/redis-windows (.zip, TLS enabled)
--
-- Note: Moving Linux/macOS to prebuilt musl-static / static binaries published via
-- `tools/res/build.sh` -> `xlings-res` can replace install-time compilation once
-- factory artifacts are published.
package = {
    spec = "2",

    name = "redis",
    description = "Redis - in-memory key-value data structure store, cache and message broker (POSIX built with BUILD_TLS=no)",
    homepage = "https://redis.io",
    authors = {"Salvatore Sanfilippo", "Redis Ltd."},
    maintainers = {"https://github.com/redis/redis"},
    licenses = {"RSALv2", "SSPLv1", "AGPLv3"},
    repo = "https://github.com/redis/redis",
    docs = "https://redis.io/docs/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"database", "cache", "server", "tools"},
    keywords = {"redis", "database", "cache", "nosql", "key-value", "in-memory"},

    programs = {
        "redis-server",
        "redis-cli",
        "redis-benchmark",
        "redis-check-aof",
        "redis-check-rdb",
        "redis-sentinel",
    },
    xvm_enable = true,

    xpm = {
        linux = {
            deps = {
                build = { "xim:make@4.3", "xim:musl-gcc@15.1.0" },
            },
            ["latest"] = { ref = "8.10.3" },
            ["8.10.3"] = {
                url = "https://github.com/redis/redis/archive/refs/tags/8.10.3.tar.gz",
                sha256 = "85ae62e175cc76f638015fa18cb384b549b6808a765425d9e9d47466f69532ea",
            },
        },
        macosx = {
            ["latest"] = { ref = "8.10.3" },
            ["8.10.3"] = {
                url = "https://github.com/redis/redis/archive/refs/tags/8.10.3.tar.gz",
                sha256 = "85ae62e175cc76f638015fa18cb384b549b6808a765425d9e9d47466f69532ea",
            },
        },
        windows = {
            ["latest"] = { ref = "8.10.3" },
            ["8.10.3"] = {
                x86_64 = {
                    url = "https://github.com/redis-windows/redis-windows/releases/download/8.10.3/Redis-8.10.3-Windows-x64-msys2.zip",
                    sha256 = "af16df340525b431e9ec8dabfd625d5e7a233f82805b5418819904ea909c447f",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

local PROGRAMS = {
    "redis-server",
    "redis-cli",
    "redis-benchmark",
    "redis-check-aof",
    "redis-check-rdb",
    "redis-sentinel",
}

local POSIX_REQUIRED = {
    "bin/redis-server",
    "bin/redis-cli",
    "bin/redis-benchmark",
    "bin/redis-check-aof",
    "bin/redis-check-rdb",
    "bin/redis-sentinel",
    "etc/redis.conf",
    "etc/sentinel.conf",
}

local WIN_REQUIRED = {
    "redis-server.exe",
    "redis-cli.exe",
    "redis-benchmark.exe",
    "redis-check-aof.exe",
    "redis-check-rdb.exe",
    "redis-sentinel.exe",
    "redis.conf",
    "sentinel.conf",
}

local JOBS_PRELUDE = [[jobs=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4); case "$jobs" in ""|*[!0-9]*) jobs=4 ;; esac; [ "$jobs" -lt 1 ] && jobs=1; [ "$jobs" -gt 8 ] && jobs=8; ]]

local function sh_quote(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function run_checked(step_name, script)
    local p, perr = io.popen("sh -c " .. sh_quote(script) .. " 2>&1")
    if not p then
        error(string.format("redis: failed to spawn %s: %s", step_name, tostring(perr)))
    end
    local out = p:read("*a") or ""
    local ok, _, code = p:close()
    if not ok then
        local tail = #out > 2000 and out:sub(-2000) or out
        error(string.format("redis: %s failed (exit %s):\n%s",
                            step_name, tostring(code or "?"), tail))
    end
    return out
end

function installed()
    return payload.present(POSIX_REQUIRED) or payload.present(WIN_REQUIRED)
end

function install()
    local archive = tostring(pkginfo.install_file())
    local dir = pkginfo.install_dir()
    local ver = pkginfo.version()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("%.zip$") ~= nil

    if is_win then
        payload.unpack{ extracted = "Redis-" .. ver .. "-Windows-x64-msys2", strip = 1 }
        payload.require(WIN_REQUIRED)
        return true
    end

    os.tryrm(dir)

    local srcdir = parent .. "/redis-" .. ver
    if not os.isdir(srcdir) then
        error("redis source directory not found: " .. srcdir)
    end

    local make_dep = pkginfo.build_dep and pkginfo.build_dep("make")
    local musl_dep = pkginfo.build_dep and pkginfo.build_dep("musl-gcc")

    if musl_dep and musl_dep.path then
        local make_bin = assert(
            make_dep and make_dep.path and os.isfile(make_dep.path .. "/bin/make")
                and (make_dep.path .. "/bin/make"),
            "redis: xim:make@4.3 build dependency is missing"
        )
        local triple = os.isfile(musl_dep.path .. "/bin/aarch64-linux-musl-gcc")
            and "aarch64-linux-musl"
            or "x86_64-linux-musl"
        local bindir = musl_dep.path .. "/bin"
        local cc = bindir .. "/" .. triple .. "-gcc"
        local ar = bindir .. "/" .. triple .. "-ar"
        local ranlib = bindir .. "/" .. triple .. "-ranlib"
        run_checked("make", JOBS_PRELUDE
            .. "export PATH=" .. sh_quote(bindir) .. ":\"$PATH\"; "
            .. sh_quote(make_bin) .. " -C " .. sh_quote(srcdir .. "/src")
            .. " -j\"$jobs\""
            .. " CC=" .. sh_quote(cc)
            .. " AR=" .. sh_quote(ar)
            .. " RANLIB=" .. sh_quote(ranlib)
            .. " LDFLAGS=-static MALLOC=libc BUILD_TLS=no USE_SYSTEMD=no"
            .. " redis-server redis-cli redis-benchmark")
    else
        local ok_clt, clt_err = pcall(
            run_checked,
            "xcode-clt check",
            [[test "$(uname -s)" = "Darwin" && xcode-select -p >/dev/null 2>&1 && command -v make >/dev/null 2>&1 && command -v cc >/dev/null 2>&1]]
        )
        if not ok_clt then
            error("redis: on Linux xim:musl-gcc@15.1.0 is required; on macOS Xcode Command Line Tools (`xcode-select --install`) with make and cc are required (" .. tostring(clt_err) .. ")")
        end
        run_checked("make", JOBS_PRELUDE
            .. "make -C " .. sh_quote(srcdir .. "/src")
            .. " -j\"$jobs\" MALLOC=libc BUILD_TLS=no USE_SYSTEMD=no"
            .. " redis-server redis-cli redis-benchmark")
    end

    fs.mkdir_p(dir .. "/bin")
    run_checked("stage binaries",
        "cp -f " .. sh_quote(srcdir .. "/src/redis-server")
        .. " " .. sh_quote(srcdir .. "/src/redis-cli")
        .. " " .. sh_quote(srcdir .. "/src/redis-benchmark")
        .. " " .. sh_quote(dir .. "/bin/")
        .. " && ln -sf redis-server " .. sh_quote(dir .. "/bin/redis-check-aof")
        .. " && ln -sf redis-server " .. sh_quote(dir .. "/bin/redis-check-rdb")
        .. " && ln -sf redis-server " .. sh_quote(dir .. "/bin/redis-sentinel"))

    fs.mkdir_p(dir .. "/etc")
    os.cp(srcdir .. "/redis.conf", dir .. "/etc/redis.conf")
    os.cp(srcdir .. "/sentinel.conf", dir .. "/etc/sentinel.conf")

    payload.require(POSIX_REQUIRED)
    return true
end

function config()
    local dir = pkginfo.install_dir()
    local bindir = os.isfile(dir .. "/redis-server.exe") and dir or (dir .. "/bin")
    local root = "redis-server@" .. pkginfo.version()
    xvm.add("redis-server", { bindir = bindir })
    for i = 2, #PROGRAMS do
        xvm.add(PROGRAMS[i], { bindir = bindir, binding = root })
    end
    return true
end

function uninstall()
    for i = #PROGRAMS, 1, -1 do
        xvm.remove(PROGRAMS[i])
    end
    return true
end
