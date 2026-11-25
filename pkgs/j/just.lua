-- just -- a handy way to save and run project-specific commands (casey/just).
--
-- Verified against official upstream release `casey/just` 1.59.0
-- (published 2026-10-15); all SHA-256 digests match upstream `SHA256SUMS` and
-- locally downloaded archives.
--
-- Supported platforms & architectures (official prebuilt archives):
--   * linux/x86_64    : just-1.59.0-x86_64-unknown-linux-musl.tar.gz
--                       `static-pie linked` ELF with zero DT_NEEDED entries
--                       (`ldd` reports `statically linked`).
--   * linux/aarch64   : just-1.59.0-aarch64-unknown-linux-musl.tar.gz
--                       `statically linked` ELF with no `.dynamic` section.
--   * macosx/x86_64   : just-1.59.0-x86_64-apple-darwin.tar.gz
--   * macosx/aarch64  : just-1.59.0-aarch64-apple-darwin.tar.gz
--   * windows/x86_64  : just-1.59.0-x86_64-pc-windows-msvc.zip
--                       PE32+ imports only Windows OS DLLs (`bcryptprimitives.dll`,
--                       `kernel32.dll`, `api-ms-win-core-synch-l1-2-0.dll`,
--                       `userenv.dll`, `shell32.dll`, `combase.dll`, `ntdll.dll`);
--                       no `VCRUNTIME140.dll` import or delay-load import.
--   * windows/aarch64 : just-1.59.0-aarch64-pc-windows-msvc.zip
--                       PE32+ ARM64 imports only the same Windows OS DLLs;
--                       no `VCRUNTIME140.dll` import.
--
-- Archive layout: every upstream archive is flat at top level (`just` or
-- `just.exe`, `just.1`, `LICENSE`, `README.md`, `GRAMMAR.md`, `Cargo.toml`,
-- `Cargo.lock`, `completions/`). install() unpacks directly into `install_dir`
-- so shared `runtimedir` files from other flat archives are never mixed in.

package = {
    spec = "2",

    name = "just",
    description = "Just a command runner",
    homepage = "https://just.systems",
    authors = {"Casey Rodarmor"},
    maintainers = {"Casey Rodarmor"},
    licenses = {"CC0-1.0"},
    repo = "https://github.com/casey/just",
    docs = "https://just.systems/man/en/",
    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "build", "tools", "task-runner"},
    keywords = {"just", "justfile", "command-runner", "task-runner", "make", "rust"},

    programs = {"just"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/casey/just/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/casey/just/releases/download/${tag}/just-${version}-x86_64-unknown-linux-musl.tar.gz",
                            aarch64 = "https://github.com/casey/just/releases/download/${tag}/just-${version}-aarch64-unknown-linux-musl.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/casey/just/releases/download/${tag}/just-${version}-x86_64-apple-darwin.tar.gz",
                            aarch64 = "https://github.com/casey/just/releases/download/${tag}/just-${version}-aarch64-apple-darwin.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/casey/just/releases/download/${tag}/just-${version}-x86_64-pc-windows-msvc.zip",
                            aarch64 = "https://github.com/casey/just/releases/download/${tag}/just-${version}-aarch64-pc-windows-msvc.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            ["latest"] = { ref = "1.59.0" },
            ["1.59.0"] = {
                x86_64 = {
                    url = "https://github.com/casey/just/releases/download/1.59.0/just-1.59.0-x86_64-unknown-linux-musl.tar.gz",
                    sha256 = "409044617b6f06517c1035e55ca38c8c856ff8b650e41bc2aa1ef82d5903a23e",
                },
                aarch64 = {
                    url = "https://github.com/casey/just/releases/download/1.59.0/just-1.59.0-aarch64-unknown-linux-musl.tar.gz",
                    sha256 = "23871b1702bfd550fb5f901778fd4290ecf2ee034a45a889fbe96d89b188086d",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "1.59.0" },
            ["1.59.0"] = {
                x86_64 = {
                    url = "https://github.com/casey/just/releases/download/1.59.0/just-1.59.0-x86_64-apple-darwin.tar.gz",
                    sha256 = "036ead9df9bc31dbae9934ae3b4236ed124d0bafcffd33439460ae084d5c9cb7",
                },
                aarch64 = {
                    url = "https://github.com/casey/just/releases/download/1.59.0/just-1.59.0-aarch64-apple-darwin.tar.gz",
                    sha256 = "6574cea774ed4cae12e24b6aa11857de33e80dab4667cf628fd5840df96a2a9d",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "1.59.0" },
            ["1.59.0"] = {
                x86_64 = {
                    url = "https://github.com/casey/just/releases/download/1.59.0/just-1.59.0-x86_64-pc-windows-msvc.zip",
                    sha256 = "9c5463e2d0974e31bee71346aa5cbf19167de1585a4abc1bae7b3b04604ea9c0",
                },
                aarch64 = {
                    url = "https://github.com/casey/just/releases/download/1.59.0/just-1.59.0-aarch64-pc-windows-msvc.zip",
                    sha256 = "a72808bc8f8028c25aaae87cf26405d2bd85d2769a779380b344c69607216971",
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
    return payload.present({ "just" }) or payload.present({ "just.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    local dir = pkginfo.install_dir()
    local is_win = is_windows()
    local exe = is_win and "just.exe" or "just"

    os.tryrm(dir)

    if is_win then
        payload.unpack{}
    else
        fs.mkdir_p(dir)
        shell.exec({ "tar", "-xzf", archive, "-C", dir })
        shell.exec({ "chmod", "+x", dir .. "/" .. exe })
    end

    payload.require({ exe })
    return true
end

function config()
    xvm.add("just", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("just")
    return true
end
