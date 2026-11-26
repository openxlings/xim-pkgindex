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
            ["latest"] = { ref = "0.23.6" },
            ["0.23.6"] = {
                x86_64 = {
                    url = "https://github.com/getzola/zola/releases/download/v0.23.6/zola-v0.23.6-x86_64-unknown-linux-musl.tar.gz",
                    sha256 = "7d77a4220a4f699cba2fc0e0c7859f780e887e269159ad4fab90e11ea16c906f",
                },
                aarch64 = {
                    url = "https://github.com/getzola/zola/releases/download/v0.23.6/zola-v0.23.6-aarch64-unknown-linux-gnu.tar.gz",
                    sha256 = "266448fffbf7c7004ca399d0e76dd699541771096d8a42aede98cebe2a029d02",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "0.23.6" },
            ["0.23.6"] = {
                x86_64 = {
                    url = "https://github.com/getzola/zola/releases/download/v0.23.6/zola-v0.23.6-x86_64-apple-darwin.tar.gz",
                    sha256 = "79a4d0ab51a4d863c068e6e594c6fce36f0aa17429a414ea63066f5910d14460",
                },
                aarch64 = {
                    url = "https://github.com/getzola/zola/releases/download/v0.23.6/zola-v0.23.6-aarch64-apple-darwin.tar.gz",
                    sha256 = "cbffbd29b3f59c3f52633507c8cb945a7a02d8b1399b43b235f5932912297aa3",
                },
            },
        },
        windows = {
            deps = { runtime = { "xim:vcruntime" } },
            ["latest"] = { ref = "0.23.6" },
            ["0.23.6"] = {
                x86_64 = {
                    url = "https://github.com/getzola/zola/releases/download/v0.23.6/zola-v0.23.6-x86_64-pc-windows-msvc.zip",
                    sha256 = "c285748dd5265d2715b952b4ae1c588c91088c24d4e0fca77b7f94d43ff8fda8",
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
