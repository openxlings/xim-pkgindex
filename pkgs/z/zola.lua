-- Zola - fast static site generator in a single binary with everything built-in.
--
-- Platform and architecture coverage (verified against getzola/zola v0.23.6):
--   linux    x86_64   zola-v<ver>-x86_64-unknown-linux-musl.tar.gz   (static musl ELF, no NEEDED)
--   linux    aarch64  zola-v<ver>-aarch64-unknown-linux-gnu.tar.gz   (GLIBC_2.35, GCC_4.2.0)
--   macosx   x86_64   zola-v<ver>-x86_64-apple-darwin.tar.gz
--   macosx   aarch64  zola-v<ver>-aarch64-apple-darwin.tar.gz
--   windows  x86_64   zola-v<ver>-x86_64-pc-windows-msvc.zip         (imports VCRUNTIME140.dll)

package = {
    spec = "2",

    name = "zola",
    description = "A fast static site generator in a single binary with everything built-in",
    homepage = "https://www.getzola.org",
    authors = {"Vincent Prouillet"},
    maintainers = {"https://github.com/getzola/zola"},
    licenses = {"MIT"},
    repo = "https://github.com/getzola/zola",
    docs = "https://www.getzola.org/documentation/getting-started/overview/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"web", "ssg", "cli", "tools"},
    keywords = {"zola", "ssg", "static-site-generator", "markdown", "web", "rust"},

    programs = {"zola"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/getzola/zola/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/getzola/zola/releases/download/${tag}/zola-${tag}-x86_64-unknown-linux-musl.tar.gz",
                            aarch64 = "https://github.com/getzola/zola/releases/download/${tag}/zola-${tag}-aarch64-unknown-linux-gnu.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/getzola/zola/releases/download/${tag}/zola-${tag}-x86_64-apple-darwin.tar.gz",
                            aarch64 = "https://github.com/getzola/zola/releases/download/${tag}/zola-${tag}-aarch64-apple-darwin.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/getzola/zola/releases/download/${tag}/zola-${tag}-x86_64-pc-windows-msvc.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            deps = { runtime = { "xim:glibc", "xim:gcc-runtime" } },
            ["latest"] = { ref = "0.23.5" },
            ["0.23.5"] = {
                x86_64 = {
                    url = "https://github.com/getzola/zola/releases/download/v0.23.5/zola-v0.23.5-x86_64-unknown-linux-musl.tar.gz",
                    sha256 = "a19d966ff8fa2256801032073facc81642221e8733d44c401efc510b0f964c3a",
                },
                aarch64 = {
                    url = "https://github.com/getzola/zola/releases/download/v0.23.5/zola-v0.23.5-aarch64-unknown-linux-gnu.tar.gz",
                    sha256 = "3e61af6cf2a2072a2397f3be7121b5032b46c6ec93bf46d154c8e72abc104c49",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "0.23.5" },
            ["0.23.5"] = {
                x86_64 = {
                    url = "https://github.com/getzola/zola/releases/download/v0.23.5/zola-v0.23.5-x86_64-apple-darwin.tar.gz",
                    sha256 = "bd63b0af0dd22c246e845c520a3bad8675096a70410574cf794c556be4340c06",
                },
                aarch64 = {
                    url = "https://github.com/getzola/zola/releases/download/v0.23.5/zola-v0.23.5-aarch64-apple-darwin.tar.gz",
                    sha256 = "8c83a33271ab5e7009cf1841cc022819c8c7109d4d61f439f25d8f6508c8b09c",
                },
            },
        },
        windows = {
            deps = { runtime = { "xim:vcruntime" } },
            ["latest"] = { ref = "0.23.5" },
            ["0.23.5"] = {
                x86_64 = {
                    url = "https://github.com/getzola/zola/releases/download/v0.23.5/zola-v0.23.5-x86_64-pc-windows-msvc.zip",
                    sha256 = "878fccd4ec4f4cfe7babbff1c5bae2abac9c47181ea383ccde2322dcdf445be2",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

function installed()
    return payload.present({ "zola" }) or payload.present({ "zola.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("zola: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("%.zip$") ~= nil
    local exe = is_win and "zola.exe" or "zola"

    os.tryrm(dir)
    fs.mkdir_p(dir)

    if is_win then
        if os.isfile(archive) then
            payload.unpack{}
        elseif os.isfile(parent .. "/" .. exe) then
            os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
        else
            error("zola: neither archive (" .. archive .. ") nor extracted binary exists")
        end
    else
        -- Upstream tarballs are flat (no top-level wrapper directory). Extract
        -- directly into install_dir so files from unrelated flat packages in the
        -- shared download directory cannot leak into this payload.
        if os.isfile(archive) then
            system.exec(string.format([[tar -xzf "%s" -C "%s"]], normalized, dir))
        elseif os.isfile(parent .. "/zola") then
            os.mv(parent .. "/zola", dir .. "/zola")
        else
            error("zola: neither archive (" .. archive .. ") nor extracted binary exists")
        end
        if os.isfile(dir .. "/zola") then
            system.exec(string.format([[chmod +x "%s"]], dir .. "/zola"))
        end
    end

    payload.require({ exe })
    return true
end

function config()
    local dir = pkginfo.install_dir()
    local cfg = { bindir = dir }
    if os.isfile(dir .. "/zola.exe") then
        cfg.alias = "zola.exe"
    end
    xvm.add("zola", cfg)
    return true
end

function uninstall()
    xvm.remove("zola")
    return true
end
