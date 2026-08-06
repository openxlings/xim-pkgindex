-- cc-switch — provider switcher for Claude Code / Codex / OpenCode /
-- Gemini CLI / openclaw. Upstream ships one self-contained artifact per
-- platform: a Linux AppImage (a single executable ELF), a Windows
-- portable zip holding just `cc-switch.exe`, and a macOS zip holding the
-- signed `CC Switch.app` bundle. No installer, no runtime to bring
-- along.
--
-- Why this is `spec = "2"` now: the recipe used to carry ONE url per
-- platform while declaring `archs = {"x86_64", "aarch64"}`, so an ARM
-- host was served `...-Linux-x86_64.AppImage` and got a binary it could
-- not run. That is exactly the V1 hole V2 exists to close. Upstream has
-- published `...-Linux-arm64.AppImage` since at least 3.14.1 and added
-- `...-Windows-arm64-Portable.zip` in the 3.19 line, so every declared
-- arch now resolves to a matching asset.
--
-- macOS is the exception: `CC-Switch-v<ver>-macOS.zip` is a universal
-- (x86_64 + arm64) bundle, so both arch keys intentionally point at the
-- same asset and the same sha256.
--
-- GLOBAL = the authoritative upstream GitHub release.
-- CN     = gitcode.com/xlings-res/cc-switch, a byte-identical copy of
--          those same assets under the same filenames, published so
--          mainland-China installs don't go through github.com. Only the
--          version `latest` points at is mirrored.
--
-- No `package.ci`: the auto-updater resolves one url per platform from a
-- `url_template`, which cannot express the per-arch assets above — a
-- bump it generated would silently reintroduce the wrong-arch bug. (It
-- is also why #375 downgraded this package out of auto-mirroring.) Bumps
-- are done by hand, together with the CN mirror push.

local _CCS_GH = "https://github.com/farion1231/cc-switch/releases/download"
local _CCS_CN = "https://gitcode.com/xlings-res/cc-switch/releases/download"

-- Upstream tags are `v<ver>`; the CN mirror tags are plain `<ver>`.
-- Asset filenames are identical on both sides.
local function _res(ver, asset, sha256, mirrored)
    local global = string.format("%s/v%s/%s", _CCS_GH, ver, asset)
    if not mirrored then
        return { url = global, sha256 = sha256 }
    end
    return {
        url = {
            GLOBAL = global,
            CN = string.format("%s/%s/%s", _CCS_CN, ver, asset),
        },
        sha256 = sha256,
    }
end

local function _linux(ver, sha_x86_64, sha_aarch64, mirrored)
    return {
        x86_64 = _res(ver, string.format("CC-Switch-v%s-Linux-x86_64.AppImage", ver),
                      sha_x86_64, mirrored),
        aarch64 = _res(ver, string.format("CC-Switch-v%s-Linux-arm64.AppImage", ver),
                       sha_aarch64, mirrored),
    }
end

local function _windows(ver, sha_x86_64, sha_aarch64, mirrored)
    return {
        x86_64 = _res(ver, string.format("CC-Switch-v%s-Windows-Portable.zip", ver),
                      sha_x86_64, mirrored),
        aarch64 = _res(ver, string.format("CC-Switch-v%s-Windows-arm64-Portable.zip", ver),
                       sha_aarch64, mirrored),
    }
end

-- Both arch keys resolve to one asset. That is the macOS universal
-- bundle, and also the pre-3.19 Windows builds, which shipped no arm64
-- zip at all.
local function _universal(ver, asset, sha, mirrored)
    return {
        x86_64 = _res(ver, asset, sha, mirrored),
        aarch64 = _res(ver, asset, sha, mirrored),
    }
end

local function _macosx(ver, sha, mirrored)
    return _universal(ver, string.format("CC-Switch-v%s-macOS.zip", ver), sha, mirrored)
end

package = {
    spec = "2",

    name = "cc-switch",
    description = "Cross-platform desktop tool for switching providers across Claude Code / Codex / OpenCode / Gemini CLI / openclaw",
    homepage = "https://github.com/farion1231/cc-switch",
    maintainers = {"farion1231"},
    licenses = {"MIT"},
    repo = "https://github.com/farion1231/cc-switch",
    docs = "https://github.com/farion1231/cc-switch#readme",

    -- Was the out-of-spec value "app" until now — the spec allows only
    -- package / script / template / config, cc-switch was the one recipe
    -- in the index using anything else, and having no test file is why
    -- nobody noticed.
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"app", "ai-agent", "tools"},
    keywords = {"claude-code", "codex", "gemini-cli", "tauri", "provider-switcher"},

    programs = {"cc-switch"},
    xvm_enable = true,

    xpm = {
        linux = {
            ["latest"] = { ref = "3.19.1" },
            ["3.19.1"] = _linux("3.19.1",
                "199dbdf11c3f84fcb1219118728e7c22178d426108e9bd4697924b8d7d11849f",
                "2791b86db0e381a7c8bb45b25b4c2db01f5f969ee547ab15cf58fedaaa6c9d53", true),
            ["3.14.1"] = _linux("3.14.1",
                "a2e5c4183156437c96a1fe72df2a7b4b87ff6c857cdf0912e7057c34efcd5309",
                "b9188866dca0ec8c7a369c40d324fcc8ba72abab10a464201e23f29ff3fdd706"),
        },
        macosx = {
            ["latest"] = { ref = "3.19.1" },
            ["3.19.1"] = _macosx("3.19.1",
                "4479f7774ee0be8ac358beff03e92dfdee8f1a6e3fd54f2c81235e6cebb09960", true),
            ["3.14.1"] = _macosx("3.14.1",
                "595cdbb510405b12578ccc6250dd096cc8c85dc3def2af0e0ac8c5d3e28b3807"),
        },
        windows = {
            ["latest"] = { ref = "3.19.1" },
            ["3.19.1"] = _windows("3.19.1",
                "aaefbadc03e6a9d4797d22ef22214a050bce1d8a0d73583bb407ac001ab92f5e",
                "492e03ccf529aa517555e2f6db479d96068cef5e9d17638c6f8255defaec841e", true),
            -- 3.14.1 predates the Windows arm64 portable zip, so ARM
            -- Windows takes the x64 build under emulation rather than
            -- resolving to an asset that was never published.
            ["3.14.1"] = _universal("3.14.1", "CC-Switch-v3.14.1-Windows-Portable.zip",
                "3747d1218e1fc7f3671b61d1ebf059f5a5aff556dd096b439484681b254eb866"),
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.system")

-- Layout per platform:
--   Linux: the download is the AppImage itself (a single self-contained
--          ELF). Rename to `cc-switch`, chmod +x, done.
--   macOS: the zip extracts a `CC Switch.app/` bundle whose real binary
--          sits at `Contents/MacOS/cc-switch`. Move the whole .app into
--          install_dir (Contents/Resources and the code signature have
--          to stay intact) and expose the inner binary via a symlink so
--          xvm's bindir model still finds a lowercase `cc-switch`.
--   Windows: the zip drops `cc-switch.exe` + `portable.ini` at the top
--          level of the extraction dir; lift `cc-switch.exe` out.
function install()
    os.tryrm(pkginfo.install_dir())
    os.mkdir(pkginfo.install_dir())

    local download_dir = path.directory(pkginfo.install_file())

    if is_host("windows") then
        os.mv(path.join(download_dir, "cc-switch.exe"),
              path.join(pkginfo.install_dir(), "cc-switch.exe"))
    elseif is_host("macosx") then
        local app_src = path.join(download_dir, "CC Switch.app")
        local app_dst = path.join(pkginfo.install_dir(), "CC Switch.app")
        os.mv(app_src, app_dst)
        -- xmake's sandbox exposes symlink creation through os.cp's
        -- `symlink = true` flag, not via a separate os.ln.
        os.cp(path.join(app_dst, "Contents", "MacOS", "cc-switch"),
              path.join(pkginfo.install_dir(), "cc-switch"),
              { force = true, symlink = true })
    else
        os.mv(pkginfo.install_file(),
              path.join(pkginfo.install_dir(), "cc-switch"))
        system.exec("chmod +x " .. path.join(pkginfo.install_dir(), "cc-switch"))
    end

    return true
end

function config()
    xvm.add("cc-switch", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("cc-switch")
    return true
end
