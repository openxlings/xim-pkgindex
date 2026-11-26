-- AIChat - All-in-one LLM CLI Tool (sigoden/aichat).
--
-- Platform and architecture coverage (verified 2026-11-26 against v0.30.0):
--   linux    x86_64    aichat-v<ver>-x86_64-unknown-linux-musl.tar.gz   (static-pie ELF, zero DT_NEEDED)
--   linux    aarch64   aichat-v<ver>-aarch64-unknown-linux-musl.tar.gz  (statically linked ELF, no .dynamic section)
--   macosx   x86_64    aichat-v<ver>-x86_64-apple-darwin.tar.gz         (Mach-O 64-bit x86_64)
--   macosx   aarch64   aichat-v<ver>-aarch64-apple-darwin.tar.gz        (Mach-O 64-bit arm64)
--   windows  x86_64    aichat-v<ver>-x86_64-pc-windows-msvc.zip         (PE32+ CUI; imports VCRUNTIME140.dll -> xim:vcruntime)
--   windows  aarch64   omitted: aichat-v<ver>-aarch64-pc-windows-msvc.zip also imports
--                      VCRUNTIME140.dll, while xim:vcruntime currently supports x86_64 only.
--
-- Every upstream archive is flat at root (single `aichat` or `aichat.exe` binary),
-- verified against GitHub release asset digests and locally computed SHA-256 checksums.

package = {
    spec = "2",

    name = "aichat",
    description = "All-in-one LLM CLI Tool featuring Shell Assistant, Chat-REPL, RAG, AI Tools & Agents",
    homepage = "https://github.com/sigoden/aichat",
    authors = {"sigoden"},
    maintainers = {"sigoden"},
    licenses = {"MIT", "Apache-2.0"},
    repo = "https://github.com/sigoden/aichat",
    docs = "https://github.com/sigoden/aichat#readme",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"ai", "llm", "cli", "chat", "rag", "tools"},
    keywords = {"aichat", "llm", "ai", "chatbot", "rag", "shell", "rust"},

    programs = {"aichat"},
    xvm_enable = true,
    ci = { mirror = true },

    extensions = {
        autoupdate = {
            source = "https://github.com/sigoden/aichat/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/sigoden/aichat/releases/download/${tag}/aichat-${tag}-x86_64-unknown-linux-musl.tar.gz",
                            aarch64 = "https://github.com/sigoden/aichat/releases/download/${tag}/aichat-${tag}-aarch64-unknown-linux-musl.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/sigoden/aichat/releases/download/${tag}/aichat-${tag}-x86_64-apple-darwin.tar.gz",
                            aarch64 = "https://github.com/sigoden/aichat/releases/download/${tag}/aichat-${tag}-aarch64-apple-darwin.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/sigoden/aichat/releases/download/${tag}/aichat-${tag}-x86_64-pc-windows-msvc.zip",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/sigoden/aichat/releases/download/v${version}/aichat-v${version}-${arch}-unknown-linux-musl.tar.gz",
            ["latest"] = { ref = "0.30.0" },
            ["0.30.0"] = {
                sha256 = {
                    x86_64 = "6b0cc08c5ceb551dc52bfac2221752f82215be5908c70605d655e9b91ab1557c",
                    aarch64 = "eb1cd0948569404c5d9d01c10b32b902e11f8231073315456454dec246bdf26e",
                },
            },
        },
        macosx = {
            source = "https://github.com/sigoden/aichat/releases/download/v${version}/aichat-v${version}-${arch}-apple-darwin.tar.gz",
            ["latest"] = { ref = "0.30.0" },
            ["0.30.0"] = {
                sha256 = {
                    x86_64 = "94aa09315773929e027bcb399f78661c2ddffd887b65348bae446601989d9ddd",
                    aarch64 = "680d36ed7f7ba8a2c2490a099df26c9da54495903c27956109a89c87eeb9edb3",
                },
            },
        },
        windows = {
            deps = {
                runtime = { "xim:vcruntime" },
            },
            source = "https://github.com/sigoden/aichat/releases/download/v${version}/aichat-v${version}-${arch}-pc-windows-msvc.zip",
            -- Windows ARM64 imports VCRUNTIME140.dll and awaits `xim:vcruntime` ARM64 support.
            ["latest"] = { ref = "0.30.0" },
            ["0.30.0"] = {
                sha256 = {
                    x86_64 = "89df8c4ccd6dad310ac713eb5d550494ae7fa14722cde346588fab38ff4afd8f",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")
import("xim.pkgindex.shell")

local function is_windows()
    if os.getenv("OS") == "Windows_NT" then return true end
    local dir = tostring(pkginfo.install_dir() or "")
    if dir:match("^[A-Za-z]:") or dir:find("\\", 1, true) then return true end
    local archive = tostring(pkginfo.install_file() or "")
    return archive:match("%.zip$") ~= nil
end

function installed()
    return payload.present({ "aichat" })
        or payload.present({ "aichat.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("aichat: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = is_windows()
    local exe = is_win and "aichat.exe" or "aichat"

    os.tryrm(dir)

    -- Archives are flat (no enclosing directory): extract directly from
    -- install_file into a clean install_dir so unrelated files in the shared
    -- runtime download directory cannot leak into the payload.
    if is_win then
        payload.unpack{}
        if not pkginfo.dep_install_dir then
            error("aichat: xim:vcruntime runtime dep lookup is unavailable")
        end
        local crt = assert(pkginfo.dep_install_dir("xim:vcruntime"),
                           "aichat: xim:vcruntime payload directory is missing")
        local copied = 0
        for _, dll in ipairs(fs.files(crt .. "/bin") or {}) do
            os.cp(dll, dir)
            copied = copied + 1
        end
        if copied == 0 then
            error("aichat: no CRT DLLs found in " .. crt .. "/bin")
        end
    elseif os.isfile(archive) then
        fs.mkdir_p(dir)
        shell.exec({ "tar", "-xzf", archive, "-C", dir })
        shell.exec({ "chmod", "+x", dir .. "/" .. exe })
    elseif os.isfile(parent .. "/" .. exe) then
        fs.mkdir_p(dir)
        os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
        shell.exec({ "chmod", "+x", dir .. "/" .. exe })
    else
        error("aichat: archive not found at " .. archive .. " and no extracted " .. exe .. " in " .. parent)
    end

    payload.require({ exe })
    return true
end

function config()
    xvm.add("aichat", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("aichat")
    return true
end
