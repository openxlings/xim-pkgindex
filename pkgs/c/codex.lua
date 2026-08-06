-- Codex CLI — OpenAI's official prebuilt release package.
--
-- This recipe used to `npm install @openai/codex`, which meant node +
-- npm as dependencies for a program that is a Rust binary. Upstream
-- publishes the binary directly, so both deps are gone.
--
-- Upstream ships two shapes per target and they are NOT interchangeable:
--
--   codex-<target>.tar.gz          one file, the bare `codex` binary,
--                                  named after the target
--   codex-package-<target>.tar.gz  the real install layout
--
-- This uses the **package**, because codex is not just its own binary.
-- The archive expands to:
--
--   bin/codex[.exe]                the entrypoint
--   bin/codex-code-mode-host[.exe]
--   codex-path/rg[.exe]            ripgrep, prepended to codex's PATH
--   codex-resources/bwrap          sandbox helper (linux)
--   codex-resources/zsh/bin/zsh    the shell its command tool runs in
--   codex-resources/codex-command-runner.exe   (windows)
--   codex-package.json             { layoutVersion, version, target,
--                                    entrypoint, resourcesDir, pathDir }
--
-- codex-package.json is upstream *declaring* that layout, and codex
-- resolves the helpers through it at runtime. So install() moves the
-- tree across whole and never cherry-picks the entrypoint out of it:
-- lifting `bin/codex` alone would produce a codex with no ripgrep, no
-- sandbox and no shell — working enough to pass `--version` and broken
-- in use.
--
-- All six targets upstream builds are covered:
--   linux   x86_64-unknown-linux-musl / aarch64-unknown-linux-musl
--   macosx  x86_64-apple-darwin       / aarch64-apple-darwin
--   windows x86_64-pc-windows-msvc    / aarch64-pc-windows-msvc
--
-- No `deps` on any platform, and unlike claude.lua that needs no
-- argument: linux is the **musl** target and Rust links it static —
-- `file bin/codex` reports `static-pie linked`, so there is no
-- interpreter, no NEEDED entry and nothing for elfpatch to rewrite.
-- macOS and Windows binaries are self-contained the same way.
--
-- Versions: upstream tags releases `rust-v<version>`, and the
-- `codex-package-*` assets start at 0.133.0 — 0.128.0 and older only
-- ever shipped the bare `codex-<target>` binary, so the pins this recipe
-- used to carry for them cannot be served natively and are dropped
-- rather than left pointing at npm. Pre-releases (`rust-v*-alpha.*`) are
-- deliberately not tracked.
--
-- GLOBAL = the authoritative upstream GitHub release.
-- CN     = gitcode.com/xlings-res/codex, a byte-identical copy under the
--          same filenames (tag drops the `rust-v` prefix), so mainland
--          China installs don't go through github.com. Only the version
--          `latest` points at is mirrored — the six assets run
--          ~120-146 MB each.

local _CODEX_GH = "https://github.com/openai/codex/releases/download"
local _CODEX_CN = "https://gitcode.com/xlings-res/codex/releases/download"

local function _asset(target)
    return "codex-package-" .. target .. ".tar.gz"
end

-- Upstream only. Used for the historical pins, which are not mirrored.
local function _up(ver, target, sha256)
    return {
        url = string.format("%s/rust-v%s/%s", _CODEX_GH, ver, _asset(target)),
        sha256 = sha256,
    }
end

-- Upstream + the CN mirror of the same bytes.
local function _mirrored(ver, target, sha256)
    return {
        url = {
            GLOBAL = string.format("%s/rust-v%s/%s", _CODEX_GH, ver, _asset(target)),
            CN = string.format("%s/%s/%s", _CODEX_CN, ver, _asset(target)),
        },
        sha256 = sha256,
    }
end

-- One platform's per-arch resource map (Shape B). `mirrored` opts the
-- version into the CN table; without it the entry stays upstream-only.
local function _entry(x86_target, arm_target, ver, sha_x86_64, sha_aarch64, mirrored)
    local res = mirrored and _mirrored or _up
    return {
        x86_64 = res(ver, x86_target, sha_x86_64),
        aarch64 = res(ver, arm_target, sha_aarch64),
    }
end

local function _linux(ver, sha_x86_64, sha_aarch64, mirrored)
    return _entry("x86_64-unknown-linux-musl", "aarch64-unknown-linux-musl",
                  ver, sha_x86_64, sha_aarch64, mirrored)
end

local function _macosx(ver, sha_x86_64, sha_aarch64, mirrored)
    return _entry("x86_64-apple-darwin", "aarch64-apple-darwin",
                  ver, sha_x86_64, sha_aarch64, mirrored)
end

local function _windows(ver, sha_x86_64, sha_aarch64, mirrored)
    return _entry("x86_64-pc-windows-msvc", "aarch64-pc-windows-msvc",
                  ver, sha_x86_64, sha_aarch64, mirrored)
end

package = {
    spec = "2",

    name = "codex",
    description = "Codex CLI from OpenAI",
    homepage = "https://github.com/openai/codex",
    licenses = {"Apache-2.0"},
    repo = "https://github.com/openai/codex",
    docs = "https://github.com/openai/codex#readme",

    -- No `package.ci`: upstream tags are `rust-v<version>` and the
    -- release stream is dominated by `-alpha.*` pre-releases, which
    -- version-check.py's `normalize_version()` would propose as literal
    -- version keys. Bumps are done by hand together with the CN mirror
    -- push.

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"ai", "cli", "tools"},
    keywords = {"codex", "openai", "agent", "cli"},

    programs = {"codex"},
    xvm_enable = true,

    xpm = {
        linux = {
            ["latest"] = { ref = "0.146.1" },
            ["0.146.1"] = _linux("0.146.1",
                "15d9b6aaa47ee02743266581f8ab96b6049e3a2a13a82fbd7920745ba9fc34cb",
                "a72b2bd37dd69ece77f5584a418bc34ecfa4b28e769727134a1d604b4b2b8e5f", true),
            ["0.145.0"] = _linux("0.145.0",
                "71a28d362c96ac9829bf8203a2c71be451aeb726adb843167fdaf0eae8fe7dd9",
                "54f79a05aba6f9abf8ef988abcae8bf2fcefba20beb549b4ff2b3acdb2cb6f54"),
            ["0.144.1"] = _linux("0.144.1",
                "3fd50cf96809b1eea294bbfba0a5c3a576871b4876a1f0e91226e520c1923be1",
                "218ab48bdda98dde3e10df184cc0c4eb92c4372d9ca924ef1aa5fc81b4f6a38e"),
            -- Oldest release with `codex-package-*` assets.
            ["0.133.0"] = _linux("0.133.0",
                "cad5f38b92247186a532157111ea43edca77d3427eb6127e603b7887db484473",
                "7a77d416f9ce16f18e09fdc57622a15aab6ad131c34e078ab9d55a13bb3d9b05"),
        },
        macosx = {
            ["latest"] = { ref = "0.146.1" },
            ["0.146.1"] = _macosx("0.146.1",
                "5b61e447baa14747e1ea6ad10ad8fca1f8ef0d5e11f53ca88a144bf52cf12e06",
                "a0be385972f38d02e81f9b40de1f842daf8354636fc295666b8630d2f6a5aec6", true),
            ["0.145.0"] = _macosx("0.145.0",
                "9d402c9ca814655fddc07b548d7086491c0afcebe1f746cdeba1045fd6f62646",
                "ece937169d4c9e910d60826a6ea4ae7848a16c089403d122e70e7da4ac41ba34"),
            ["0.144.1"] = _macosx("0.144.1",
                "1c797880977549b281eeb4ecd9dbd145542c4ce262a2835ea2847f19922ed30c",
                "326198829dfb4b68da59723cf605478a2e9bec89ff47feb645814a4c5eaf5f6c"),
            ["0.133.0"] = _macosx("0.133.0",
                "79ce0bfee5996c8a40661d92b67a45f3cbdb3d81425d2ebb786d3955870804e0",
                "7da572ce5631deccb8b05c4cb4bbb608d65d5b3197f5e2c79fa7a156c02fc6d6"),
        },
        windows = {
            ["latest"] = { ref = "0.146.1" },
            ["0.146.1"] = _windows("0.146.1",
                "6b26524c4287564a2c6c3511e73dcd32ea3c8c0a994cc1caa731b63f7844c8b6",
                "2048300c1572b94d3809df3c852e46c391ce702d70b08212557432749b994f49", true),
            ["0.145.0"] = _windows("0.145.0",
                "8d0d281346aedf63c4cc3922997df822fbb8881f7ffb2b57416f48e8c52a734e",
                "753b97a27805e83a209492b5537c46dbf178eeffe1980f6c784924e3cc9b4184"),
            ["0.144.1"] = _windows("0.144.1",
                "ce94e1fb84693d3f7332ceeab5be73e93de38725da4b82dff863cd2c795b4730",
                "a471e55e85bdada7a9d1cb081bed896688a0e7fe0f0fdcd61027187aaa59f8a1"),
            ["0.133.0"] = _windows("0.133.0",
                "b7996b021590f3f877b1b2e9088b6c0e43ec781ff3def8a67ae8f14fa703237e",
                "a133778c79f6116e78c475ad4767397ef042c6addb748e6cf7e56551f27dcc0a"),
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.system")

-- The top level of every `codex-package-*` archive, identical across all
-- six targets. Moved across as a unit — see the header for why the
-- entrypoint must not be lifted out on its own.
local _PAYLOAD = { "bin", "codex-path", "codex-resources", "codex-package.json" }

local function _bindir()
    return path.join(pkginfo.install_dir(), "bin")
end

local function _installed_exe()
    return path.join(_bindir(), os.host() == "windows" and "codex.exe" or "codex")
end

-- A note for whoever verifies a change to this hook, because it cost a
-- day: **xlings skips install() entirely when the same name and version
-- is already installed under another namespace, and still prints
-- `✓ 1 package(s) installed`.** With `xim:codex@0.146.1` present, every
-- `local:codex@0.146.1` install was a silent no-op that left an install
-- dir holding only `.xpkg.lua` — which reads exactly like a broken
-- install hook. Clear both before testing:
--
--     rm -rf ~/.xlings/data/xpkgs/{xim,local}-x-codex/<version>
--
-- Related: a `raise()` in here does not reach the summary either, so a
-- genuinely failed install can still be reported as succeeding. A Lua
-- *runtime* error does surface. Verify by listing the install directory,
-- never by the exit code.
function install()
    -- Idempotent across xim engines: never wipe install_dir before a
    -- replacement payload is confirmed, and never report success unless
    -- the entrypoint landed — a bare `return true` gets stamped as
    -- installed and leaves a dangling shim over an empty directory.
    local exe = _installed_exe()
    if os.isfile(exe) then
        return true
    end

    -- The archive expands into the download directory with no wrapper
    -- directory of its own, so the payload entries sit beside the
    -- tarball rather than under a `codex-0.146.1/` root.
    local download_dir = path.directory(pkginfo.install_file())

    os.tryrm(pkginfo.install_dir())
    os.mkdir(pkginfo.install_dir())

    -- `os.mv`, the same as every other recipe in the index. #526 changed
    -- this to `os.cp` on the theory that moving consumed a shared cache
    -- xlings would not re-extract; that theory is wrong. Measured after
    -- the fact: delete `bin/` out of the download directory and install
    -- again and xlings puts it straight back — it re-extracts, and it
    -- re-downloads when the archive itself is gone. `os.mv` installs
    -- cleanly twice in a row. godot.lua and cc-switch.lua, suspected of
    -- the same "bug", were tested and are fine too.
    --
    -- What actually produced the empty install directories was the trap
    -- documented at the top of install(): xlings skips the install hook
    -- entirely when the same name and version is already installed under
    -- another namespace, and still reports success. Proven with an
    -- `io.writefile` probe inside the hook — the log file was never
    -- created.
    for _, entry in ipairs(_PAYLOAD) do
        local src = path.join(download_dir, entry)
        -- `os.exists` is NOT bound in the xim hook runtime — calling it
        -- fails the install with `attempt to call a nil value (field
        -- 'exists')`, and what you see is an install dir holding only
        -- `.xpkg.lua`. Ask about the two kinds separately.
        if os.isdir(src) or os.isfile(src) then
            os.mv(src, path.join(pkginfo.install_dir(), entry))
        end
    end

    if not os.isfile(exe) then
        raise("codex payload has no bin/codex after install")
    end
    -- codex-package.json is what codex reads to find codex-path and
    -- codex-resources; without it the helpers are unreachable even
    -- though they are on disk.
    if not os.isfile(path.join(pkginfo.install_dir(), "codex-package.json")) then
        raise("codex payload has no codex-package.json after install")
    end

    if os.host() ~= "windows" then
        -- tar preserves the executable bit, but restoring it explicitly
        -- keeps the recipe correct on extractors that drop unix modes —
        -- and it has to cover the helpers, not just the entrypoint.
        system.exec(string.format([[chmod -R +x "%s"]], _bindir()))
        system.exec(string.format([[chmod -R +x "%s"]],
                                  path.join(pkginfo.install_dir(), "codex-path")))
        system.exec(string.format([[chmod -R +x "%s"]],
                                  path.join(pkginfo.install_dir(), "codex-resources")))
    end

    return os.isfile(exe)
end

function config()
    -- `bindir` rather than the install root: the entrypoint lives in
    -- bin/, and codex locates codex-path/ and codex-resources/ relative
    -- to itself through codex-package.json, so the layout above it has
    -- to stay where it is. Only `codex` is registered —
    -- codex-code-mode-host is codex's own helper, not a user-facing
    -- command, and registering it would put a name in the subos that
    -- nobody types.
    xvm.add("codex", { bindir = _bindir() })
    return true
end

function uninstall()
    xvm.remove("codex")
    return true
end
