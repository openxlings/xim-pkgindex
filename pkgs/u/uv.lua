package = {
    spec = "1",

    name = "uv",
    description = "An extremely fast Python package and project manager (Astral)",
    homepage = "https://docs.astral.sh/uv",
    maintainers = {"Astral"},
    licenses = {"MIT", "Apache-2.0"},
    repo = "https://github.com/astral-sh/uv",
    ci = { update = true },
    docs = "https://docs.astral.sh/uv",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"python", "package-manager", "tools"},
    keywords = {"python", "uv", "pip", "venv", "poetry", "astral"},

    programs = {"uv", "uvx"},
    xvm_enable = true,

    xpm = {
        linux = {
            -- No runtime deps. Astral publishes both
            -- `-linux-gnu.tar.gz` and `-linux-musl.tar.gz`; we use
            -- the musl variant which is `static-pie linked` with
            -- empty DT_NEEDED and no `.interp` section (verified
            -- locally via readelf). Rust musl builds bundle the
            -- whole runtime into the binary, so neither glibc nor
            -- libgcc_s is needed.
            -- Earlier (PR #121) declared deps on xim:glibc + xim:gcc-runtime
            -- against the gnu artifact; switching the source eliminates
            -- both deps.
            -- url_template: opt-in marker for the in-repo version checker
            -- (.github/scripts/version-check.py). The placeholder
            -- {version} is substituted with the upstream GitHub release
            -- version when proposing a bump. xlings install does not read
            -- this field; it stays on the explicit per-version `url`.
            -- See docs/spec/url-template.md.
            url_template = "https://github.com/astral-sh/uv/releases/download/{version}/uv-x86_64-unknown-linux-musl.tar.gz",
            ["latest"] = { ref = "0.11.8" },
            ["0.11.8"] = {
                url = "https://github.com/astral-sh/uv/releases/download/0.11.8/uv-x86_64-unknown-linux-musl.tar.gz",
                sha256 = "de82507d12e31cfc86c1c776238f7c248e48e40d996dedc812d64fdd31c6ed12",
            },
            ["0.11.7"] = {
                url = "https://github.com/astral-sh/uv/releases/download/0.11.7/uv-x86_64-unknown-linux-musl.tar.gz",
                sha256 = "64ddb5f1087649e3f75aa50d139aa4f36ddde728a5295a141e0fa9697bfb7b0f",
            },
        },
        -- macosx: the upstream ships separate x86_64 and aarch64 builds.
        -- Modern Macs (and the GitHub macos-latest runner) are aarch64,
        -- which is what we ship. Intel-Mac users would need a separate
        -- per-arch dispatch (xpm doesn't natively branch on arch yet).
        macosx = {
            url_template = "https://github.com/astral-sh/uv/releases/download/{version}/uv-aarch64-apple-darwin.tar.gz",
            ["latest"] = { ref = "0.11.8" },
            ["0.11.8"] = {
                url = "https://github.com/astral-sh/uv/releases/download/0.11.8/uv-aarch64-apple-darwin.tar.gz",
                sha256 = "c729adb365114e844dd7f9316313a7ed6443b89bb5681d409eebac78b0bd06c8",
            },
            ["0.11.7"] = {
                url = "https://github.com/astral-sh/uv/releases/download/0.11.7/uv-aarch64-apple-darwin.tar.gz",
                sha256 = "66e37d91f839e12481d7b932a1eccbfe732560f42c1cfb89faddfa2454534ba8",
            },
        },
        windows = {
            url_template = "https://github.com/astral-sh/uv/releases/download/{version}/uv-x86_64-pc-windows-msvc.zip",
            ["latest"] = { ref = "0.11.8" },
            ["0.11.8"] = {
                url = "https://github.com/astral-sh/uv/releases/download/0.11.8/uv-x86_64-pc-windows-msvc.zip",
                sha256 = "c84629a56e0706b69a47ea35862208af827cb6fbfa1d0ca763c52c67594637e8",
            },
            ["0.11.7"] = {
                url = "https://github.com/astral-sh/uv/releases/download/0.11.7/uv-x86_64-pc-windows-msvc.zip",
                sha256 = "fe0c7815acf4fc45f8a5eff58ed3cf7ae2e15c3cf1dceadbd10c816ec1690cc1",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

-- Archive layouts:
--   Linux/macOS .tar.gz extracts into a single dir named after the
--     archive (e.g. `uv-x86_64-unknown-linux-gnu/`) containing `uv`
--     and `uvx` at its top level.
--   Windows .zip drops `uv.exe`, `uvx.exe`, `uvw.exe` directly into
--     the extraction directory (no enclosing folder).
--
-- The download dir is the directory containing pkginfo.install_file(),
-- and the extracted folder is named the same as the tarball without
-- its compression suffix. Deriving paths from install_file() avoids
-- assuming xlings's cwd matches the extraction location, which has
-- proven flaky across hosts.
function install()
    os.tryrm(pkginfo.install_dir())
    os.mkdir(pkginfo.install_dir())

    local download_dir = path.directory(pkginfo.install_file())

    if is_host("windows") then
        for _, exe in ipairs({"uv.exe", "uvx.exe"}) do
            os.mv(path.join(download_dir, exe), path.join(pkginfo.install_dir(), exe))
        end
    else
        local extracted = pkginfo.install_file():replace(".tar.gz", "")
        for _, exe in ipairs({"uv", "uvx"}) do
            os.mv(path.join(extracted, exe), path.join(pkginfo.install_dir(), exe))
        end
        os.tryrm(extracted)
    end

    return true
end

function config()
    local bindir = pkginfo.install_dir()
    xvm.add("uv", { bindir = bindir })
    xvm.add("uvx", { bindir = bindir, binding = "uv@" .. pkginfo.version() })
    return true
end

function uninstall()
    xvm.remove("uv")
    xvm.remove("uvx")
    return true
end
