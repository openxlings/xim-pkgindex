-- Task - a task runner / simpler Make alternative written in Go (go-task/task).
--
-- Platform and architecture coverage (verified 2026-11-25 against v3.54.0):
--   linux    x86_64, aarch64   task_linux_<arch>.tar.gz  (static Go ELF, no .dynamic section)
--   macosx   x86_64, aarch64   task_darwin_<arch>.tar.gz
--   windows  x86_64, aarch64   task_windows_<arch>.zip   (PE32+ importing kernel32.dll only)
--
-- Every upstream archive is flat at root (`task` / `task.exe`, `LICENSE`, `README.md`,
-- `completion/...`), verified against upstream `task_checksums.txt` and hashed locally.

package = {
    spec = "2",

    name = "task",
    description = "A task runner / simpler Make alternative written in Go",
    homepage = "https://taskfile.dev",
    authors = {"Andrey Nering"},
    maintainers = {"go-task"},
    licenses = {"MIT"},
    repo = "https://github.com/go-task/task",
    docs = "https://taskfile.dev/docs/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"build", "automation", "cli", "tools"},
    keywords = {"task", "taskfile", "make", "build", "automation", "go"},

    programs = {"task"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/go-task/task/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/go-task/task/releases/download/${tag}/task_linux_amd64.tar.gz",
                            aarch64 = "https://github.com/go-task/task/releases/download/${tag}/task_linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/go-task/task/releases/download/${tag}/task_darwin_amd64.tar.gz",
                            aarch64 = "https://github.com/go-task/task/releases/download/${tag}/task_darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/go-task/task/releases/download/${tag}/task_windows_amd64.zip",
                            aarch64 = "https://github.com/go-task/task/releases/download/${tag}/task_windows_arm64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    -- Upstream builds with CGO_ENABLED=0; Linux binaries are statically linked Go ELFs
    -- with no dynamic section or external libc/runtime dependencies.
    xpm = {
        linux = {
            source = "https://github.com/go-task/task/releases/download/v${version}/task_linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "3.54.0" },
            ["3.54.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "680859dbb4d881a9c72d4d9a8f510825450849af8567deacd7302c01124416fb",
                    aarch64 = "d7189d439d4a6058e39e1b2acd7c8b27acd4856691b408f23b242e4294e1df5b",
                },
            },
        },
        macosx = {
            source = "https://github.com/go-task/task/releases/download/v${version}/task_darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "3.54.0" },
            ["3.54.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "0543b0844a725814c0412d3f4bed12873ce9ed0da207b15775f63a97d734aac0",
                    aarch64 = "12a69fcf37bb8d5bc9150c44f9a936775b73e59ff044c2c245232f198c135637",
                },
            },
        },
        windows = {
            source = "https://github.com/go-task/task/releases/download/v${version}/task_windows_${arch_alias}.zip",
            ["latest"] = { ref = "3.54.0" },
            ["3.54.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "837f42f71899ea41d07a47acc81d4d6ea80cb41c68292345f915c656473efcb7",
                    aarch64 = "4618ea027582738a056af9a5b78086c402e93c82c1c67df0eab2d20c649608e2",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.winpath")

function installed()
    local dir = pkginfo.install_dir()
    return os.isfile(dir .. "/task") or os.isfile(dir .. "/task.exe")
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("task: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local download_dir = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("%.zip$") ~= nil
    local exe = is_win and "task.exe" or "task"

    os.tryrm(dir)
    fs.mkdir_p(dir)

    if os.isfile(archive) then
        -- All upstream archives are flat; extract directly from the archive into
        -- install_dir so files never mingle with unrelated payloads in runtimedir.
        if is_win then
            local sysroot = winpath.native(os.getenv("SystemRoot") or "C:\\Windows"):gsub("\\+$", "")
            local systar = sysroot .. "\\System32\\tar.exe"
            -- exec-quoting-ok: the first token is the system's tar.exe, which cmd.exe must see unquoted
            system.exec(string.format('%s -xf "%s" -C "%s"', systar, winpath.native(archive), winpath.native(dir)))
        else
            system.exec(string.format([[tar -xzf "%s" -C "%s"]], normalized, dir))
        end
    elseif os.isfile(download_dir .. "/" .. exe) then
        os.mv(download_dir .. "/" .. exe, dir .. "/" .. exe)
        for _, extra in ipairs({ "LICENSE", "README.md" }) do
            if os.isfile(download_dir .. "/" .. extra) then
                os.mv(download_dir .. "/" .. extra, dir .. "/" .. extra)
            end
        end
    else
        error("task: neither archive (" .. archive .. ") nor extracted binary (" .. download_dir .. "/" .. exe .. ") exists")
    end

    if not is_win and os.isfile(dir .. "/" .. exe) then
        system.exec(string.format([[chmod +x "%s"]], dir .. "/" .. exe))
    end

    if not installed() then
        error("task: " .. exe .. " is missing after install in " .. dir)
    end
    return true
end

function config()
    xvm.add("task", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("task")
    return true
end
