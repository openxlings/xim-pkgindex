package = {
    spec = "1",

    name = "cc-switch",
    description = "Cross-platform desktop tool for switching providers across Claude Code / Codex / OpenCode / Gemini CLI / openclaw",
    homepage = "https://github.com/farion1231/cc-switch",
    maintainers = {"farion1231"},
    licenses = {"MIT"},
    repo = "https://github.com/farion1231/cc-switch",
    docs = "https://github.com/farion1231/cc-switch#readme",

    type = "app",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"app", "ai-agent", "tools"},
    keywords = {"claude-code", "codex", "gemini-cli", "tauri", "provider-switcher"},

    programs = {"cc-switch"},
    xvm_enable = true,

    xpm = {
        linux = {
            url_template = "https://github.com/farion1231/cc-switch/releases/download/v{version}/CC-Switch-v{version}-Linux-x86_64.AppImage",
            ["latest"] = { ref = "3.15.0" },
            ["3.15.0"] = {
                url = "https://github.com/farion1231/cc-switch/releases/download/v3.15.0/CC-Switch-v3.15.0-Linux-x86_64.AppImage",
                sha256 = "f6c70d88c5b446109f5ae8c3f8b3ad5ad9a1613226b353d9108e2467d7180809",
            },
            ["3.14.1"] = {
                url = "https://github.com/farion1231/cc-switch/releases/download/v3.14.1/CC-Switch-v3.14.1-Linux-x86_64.AppImage",
                sha256 = "a2e5c4183156437c96a1fe72df2a7b4b87ff6c857cdf0912e7057c34efcd5309",
            },
        },
        macosx = {
            url_template = "https://github.com/farion1231/cc-switch/releases/download/v{version}/CC-Switch-v{version}-macOS.zip",
            ["latest"] = { ref = "3.15.0" },
            ["3.15.0"] = {
                url = "https://github.com/farion1231/cc-switch/releases/download/v3.15.0/CC-Switch-v3.15.0-macOS.zip",
                sha256 = "095f6f9176e472788e38dd5f0950299d5300976477d8d4482337e09446d7eff2",
            },
            ["3.14.1"] = {
                url = "https://github.com/farion1231/cc-switch/releases/download/v3.14.1/CC-Switch-v3.14.1-macOS.zip",
                sha256 = "595cdbb510405b12578ccc6250dd096cc8c85dc3def2af0e0ac8c5d3e28b3807",
            },
        },
        windows = {
            url_template = "https://github.com/farion1231/cc-switch/releases/download/v{version}/CC-Switch-v{version}-Windows-Portable.zip",
            ["latest"] = { ref = "3.15.0" },
            ["3.15.0"] = {
                url = "https://github.com/farion1231/cc-switch/releases/download/v3.15.0/CC-Switch-v3.15.0-Windows-Portable.zip",
                sha256 = "0aeb1cab0f5f62416327ef351c48a41e084d2e8c36a67a5b964667fa75893385",
            },
            ["3.14.1"] = {
                url = "https://github.com/farion1231/cc-switch/releases/download/v3.14.1/CC-Switch-v3.14.1-Windows-Portable.zip",
                sha256 = "3747d1218e1fc7f3671b61d1ebf059f5a5aff556dd096b439484681b254eb866",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

-- Layout per platform:
--   Linux: download is the AppImage itself (a single self-contained ELF).
--          Rename to `cc-switch`, chmod +x, and that becomes the binary.
--   macOS: zip extracts a `CC Switch.app/` bundle containing the real
--          binary at `Contents/MacOS/cc-switch`. We move the whole .app
--          into install_dir and expose the inner binary via a symlink so
--          xvm's bindir model still works.
--   Windows: zip drops `cc-switch.exe` + `portable.ini` at the top level
--            of the extraction dir; we just lift `cc-switch.exe` out.
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
        -- Symlink so xvm's bindir model keeps working with the bundle.
        -- xmake's sandbox exposes symlink creation through os.cp's
        -- `symlink = true` flag, not via a separate os.ln.
        os.cp(path.join(app_dst, "Contents", "MacOS", "cc-switch"),
              path.join(pkginfo.install_dir(), "cc-switch"),
              { force = true, symlink = true })
    else
        os.mv(pkginfo.install_file(),
              path.join(pkginfo.install_dir(), "cc-switch"))
        os.exec("chmod +x " .. path.join(pkginfo.install_dir(), "cc-switch"))
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
