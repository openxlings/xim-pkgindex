package = {
    spec = "1",

    name = "ollama",
    description = "Get up and running with large language models locally",
    homepage = "https://ollama.com",
    maintainers = {"Ollama"},
    licenses = {"MIT"},
    repo = "https://github.com/ollama/ollama",
    docs = "https://github.com/ollama/ollama/blob/main/docs/README.md",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"ai", "llm", "tools"},
    keywords = {"ollama", "llama", "llm", "ai", "inference", "gguf"},

    programs = {"ollama"},
    xvm_enable = true,

    -- TODO(zstd): pin to v0.13.x because it is the last release that
    --   ships .tgz / .zip on Linux & Windows. Releases v0.14.0+ switched
    --   to .tar.zst on Linux/Windows, which xlings's is_compressed()
    --   does not auto-extract today (see xlings core/xim/base/utils.lua).
    --   Once xlings learns about .tar.zst (and zstd is wired in) we can
    --   bump this package to track the latest upstream release.
    xpm = {
        linux = {
            -- Runtime deps:
            --   * xim:glibc / xim:gcc-runtime — ollama prebuilt is
            --     dynamically linked: NEEDED libc.so.6 / libm.so.6 /
            --     libdl.so.2 / libpthread.so.0 / librt.so.1 /
            --     libresolv.so.2 (glibc) plus libstdc++.so.6 /
            --     libgcc_s.so.1 (xim:gcc-runtime). ollama uses C++
            --     heavily (llama.cpp inference path), so libstdc++
            --     is mandatory.
            --   * xim:libcuda-host-link — sentinel package that
            --     provides a stable symlink to the host's libcuda.so.1
            --     (NVIDIA driver userspace lib, NOT redistributable).
            --     Without this, ollama's bundled CUDA backends in
            --     lib/ollama/cuda_v*/ silently fail to dlopen
            --     libcuda.so.1 and ollama runs at 100% CPU even on
            --     GPU hosts. install() projects the sentinel link
            --     into each cuda_v* dir below.
            deps = {
                runtime = {
                    "xim:glibc@>=2.39",
                    "xim:gcc-runtime@15.1.0",
                    "xim:libcuda-host-link@0.0.1",
                },
            },
            ["latest"] = { ref = "0.13.3" },
            ["0.13.3"] = {
                url = "https://github.com/ollama/ollama/releases/download/v0.13.3/ollama-linux-amd64.tgz",
                sha256 = "70a3d0f4cccd003641c5531d564a3494ed9a422e397c437d40f802ec1003c6eb",
            },
            ["0.13.0"] = {
                url = "https://github.com/ollama/ollama/releases/download/v0.13.0/ollama-linux-amd64.tgz",
                sha256 = "c5e5b4840008d9c9bf955ec32c32b03afc57c986ac1c382d44c89c9f7dd2cc30",
            },
        },
        macosx = {
            ["latest"] = { ref = "0.13.3" },
            ["0.13.3"] = {
                url = "https://github.com/ollama/ollama/releases/download/v0.13.3/ollama-darwin.tgz",
                sha256 = "f2fd093b044b4951b5a0ec339f9059ba3de95abcf74df2a934c60330b6afc801",
            },
            ["0.13.0"] = {
                url = "https://github.com/ollama/ollama/releases/download/v0.13.0/ollama-darwin.tgz",
                sha256 = "fa4ca04c48453c5ff81447d0630e996ee3e6b6af76a9eba52c69c0732f748161",
            },
        },
        windows = {
            ["latest"] = { ref = "0.13.3" },
            ["0.13.3"] = {
                url = "https://github.com/ollama/ollama/releases/download/v0.13.3/ollama-windows-amd64.zip",
                sha256 = "4a81a0f130bad31962246b31fb053f27e9d2fc8314c0a68c43fd95cf787f17c2",
            },
            ["0.13.0"] = {
                url = "https://github.com/ollama/ollama/releases/download/v0.13.0/ollama-windows-amd64.zip",
                sha256 = "0fc913fc3763b8d2a490f2be90a51d474491ee22ea5a43ff31f1c58301a89656",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.system")
import("xim.libxpkg.log")

-- Archive layouts (per-platform, top-level entries):
--   linux .tgz   → bin/ollama          + lib/ollama/...
--   macOS .tgz   → ollama (flat)       + lib*.so / *.dylib at root
--   windows .zip → ollama.exe (flat)   + ollama_runners/... at root
--
-- We extract the archive directly into install_dir rather than relying
-- on xlings's auto-extract-into-runtime-dir, so the install_dir layout
-- is self-contained and not entangled with other packages' extracted
-- artifacts in the shared download dir.
function install()
    os.tryrm(pkginfo.install_dir())
    os.mkdir(pkginfo.install_dir())

    local archive = pkginfo.install_file()

    if is_host("windows") then
        system.exec(string.format(
            [[powershell -NoProfile -ExecutionPolicy Bypass -Command ]] ..
            [["Expand-Archive -Path '%s' -DestinationPath '%s' -Force"]],
            archive, pkginfo.install_dir()
        ))
    else
        system.exec(string.format(
            [[tar -xzf "%s" -C "%s"]],
            archive, pkginfo.install_dir()
        ))
        __link_cuda_backends()
        __install_systemd_user_service()
    end

    return true
end

function config()
    -- Linux puts the binary at install_dir/bin/ollama; macOS and Windows
    -- archives are flat with the binary at install_dir/ollama(.exe).
    local bindir = pkginfo.install_dir()
    if is_host("linux") then
        bindir = path.join(pkginfo.install_dir(), "bin")
    end
    xvm.add("ollama", { bindir = bindir })
    return true
end

function uninstall()
    if is_host("linux") then
        __remove_systemd_user_service()
    end
    xvm.remove("ollama")
    return true
end

-- Project the libcuda-host-link sentinel symlink into each of ollama's
-- bundled CUDA backend directories. Glob `cuda_v*` is forward-compat
-- with future ollama upstream layouts (cuda_v14, cuda_v15, ...) and
-- intentionally excludes ROCm (`rocm_v*`) which uses libamdhip64, not
-- libcuda. If the user has no NVIDIA driver, the sentinel link is
-- itself dangling — projecting it here is still correct: ln itself
-- doesn't resolve the target, and the dlopen failure will surface at
-- ollama runtime rather than corrupting install state.
--
-- Uses a shell `ls -d <unquoted-glob>` rather than libxpkg's
-- prelude `os.dirs(...)` because the shim wraps the pattern in
-- double quotes (`ls -d "<glob>"`), defeating bash's pathname
-- expansion — the call would always return empty even when the
-- dirs are present. Separate libxpkg bug; can drop the workaround
-- once that's fixed.
function __link_cuda_backends()
    local sentinel = path.join(
        pkginfo.install_dir("xim:libcuda-host-link", "0.0.1"),
        "lib", "libcuda.so.1"
    )

    local lib_ollama = path.join(pkginfo.install_dir(), "lib", "ollama")
    local cuda_dirs = {}
    local out = try {
        function() return os.iorun(string.format(
            [[ls -d %s/cuda_v* 2>/dev/null]], lib_ollama
        )) end
    }
    if out then
        for line in out:gmatch("[^\n]+") do
            local d = line:gsub("%s+$", "")
            if d ~= "" and os.isdir(d) then
                table.insert(cuda_dirs, d)
            end
        end
    end

    if #cuda_dirs == 0 then
        log.info("ollama: no cuda_v*/ backend dirs found, GPU link skipped")
        return
    end

    for _, cuda_dir in ipairs(cuda_dirs) do
        local link = path.join(cuda_dir, "libcuda.so.1")
        system.exec(string.format([[ln -sf "%s" "%s"]], sentinel, link))
        log.info("ollama: linked %s/libcuda.so.1 → %s",
                 path.filename(cuda_dir), sentinel)
    end
end

-- Path of the systemd user unit file we manage.
function __ollama_user_unit_path()
    local home = os.getenv("HOME") or ""
    if home == "" then return nil end
    return path.join(home, ".config", "systemd", "user", "ollama.service")
end

-- Bundled service unit body. Hard-pins ExecStart at the install_dir
-- binary (rather than the xvm shim) so the unit doesn't change shape
-- on `xlings use ollama X.Y.Z` switches; uninstall removes the file
-- so a switch + reinstall regenerates it cleanly. Keeps the default
-- Environment minimal — power-user tunables like
--   OLLAMA_FLASH_ATTENTION=true / OLLAMA_KEEP_ALIVE=30m / OLLAMA_HOST=...
-- can be layered on by `systemctl --user edit ollama.service`
-- without conflicting with this base unit.
-- Marker comment used by uninstall to detect units we wrote vs ones
-- the user installed by hand (don't trample those on `xim remove`).
local OLLAMA_UNIT_OWNER_MARK = "# x-managed-by: xim:ollama"

-- Default Environment block: a conservative, conventional baseline
-- that matches ollama's own runtime defaults made explicit, so users
-- can see at-a-glance what to override.
--   OLLAMA_HOST       127.0.0.1:11434  ← localhost-only by default;
--                                        flip to 0.0.0.0:<port> for LAN
--   OLLAMA_KEEP_ALIVE 5m               ← ollama's own default; common
--                                        override is 30m or "-1" (forever)
-- Power-user tunings deliberately NOT in the default unit (vary per
-- hardware/workload — users add via `systemctl --user edit`):
--   OLLAMA_FLASH_ATTENTION=true        (perf, GPU-dependent)
--   OLLAMA_KV_CACHE_TYPE=q8_0          (memory/quality tradeoff)
--   OLLAMA_NUM_PARALLEL=4              (concurrent request handling)
--   OLLAMA_MAX_LOADED_MODELS=2         (multi-model deploys)
--   OLLAMA_MODELS=/path/to/cache       (custom storage location)
local OLLAMA_USER_UNIT = [[
]] .. OLLAMA_UNIT_OWNER_MARK .. [[

[Unit]
Description=Ollama Service (managed by xim)
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=%s serve
Restart=on-failure
RestartSec=3
Environment="OLLAMA_HOST=127.0.0.1:11434"
Environment="OLLAMA_KEEP_ALIVE=5m"

[Install]
WantedBy=default.target
]]

-- Install a systemd user service so `xlings install ollama` results
-- in a running daemon, fixing the "I installed ollama but `ollama
-- list` says connection refused" UX gap.
--
-- User service (no sudo) chosen over system service intentionally:
--   * xim's install hooks run as the user, not root
--   * power users running ollama as a system daemon will likely
--     have their own service file already and benefit nothing from
--     us competing with it
--
-- Best-effort install: if systemctl is missing (containers without
-- systemd), or there's no user session bus available (SSH login
-- without lingering enabled), `daemon-reload` and `enable --now`
-- silently fall through. The unit file still gets dropped so the
-- next graphical/SSH session will pick it up.
function __install_systemd_user_service()
    local unit_path = __ollama_user_unit_path()
    if not unit_path then
        log.info("ollama: HOME unset, skip systemd user service install")
        return
    end

    -- Don't trample a pre-existing user-customized unit.
    if os.isfile(unit_path) then
        log.info("ollama: %s exists, skip overwrite", unit_path)
        return
    end

    -- Skip silently on hosts without systemd at all.
    local systemctl_ok = (try {
        function() return os.iorun("which systemctl 2>/dev/null") end
    } or ""):gsub("%s+", "")
    if systemctl_ok == "" then
        log.info("ollama: systemctl not found, skip service install")
        return
    end

    local exec_start = path.join(pkginfo.install_dir(), "bin", "ollama")
    os.mkdir(path.directory(unit_path))
    io.writefile(unit_path, string.format(OLLAMA_USER_UNIT, exec_start))
    log.info("ollama: wrote systemd user unit at %s", unit_path)

    -- Try to start the service. Failures here (no DBUS_SESSION_BUS_ADDRESS,
    -- container without systemd-as-PID-1, etc.) are non-fatal — the unit
    -- file is in place, will be honored at next user session.
    try {
        function()
            os.iorun("systemctl --user daemon-reload 2>&1")
            os.iorun("systemctl --user enable --now ollama.service 2>&1")
            log.info("ollama: systemd user service enabled and started")
        end,
        catch = function(err)
            log.warn("ollama: could not auto-start service (no user bus?)")
            log.warn("ollama: run manually after login: ")
            log.warn("        systemctl --user enable --now ollama.service")
        end
    }
end

function __remove_systemd_user_service()
    local unit_path = __ollama_user_unit_path()
    if not unit_path or not os.isfile(unit_path) then return end

    -- Only remove the unit if we own it (ownership marker present).
    -- A user who hand-rolled their own ollama.service should not have
    -- it deleted by `xim remove ollama`; their custom file lives on,
    -- and the still-installed binary path the service references is
    -- gone — they'll see a clear systemctl failure pointing at the
    -- missing binary, which is preferable to silently destroying
    -- their config.
    local content = io.readfile(unit_path) or ""
    if not content:find(OLLAMA_UNIT_OWNER_MARK, 1, true) then
        log.info("ollama: %s lacks xim ownership marker, skip removal",
                 unit_path)
        return
    end

    -- Stop + disable, swallowing failures (service may already be down,
    -- or no user bus). We don't care — the goal is removing the file.
    try {
        function() os.iorun("systemctl --user disable --now ollama.service 2>&1") end
    }
    os.tryrm(unit_path)
    try {
        function() os.iorun("systemctl --user daemon-reload 2>&1") end
    }
    log.info("ollama: removed systemd user service at %s", unit_path)
end
