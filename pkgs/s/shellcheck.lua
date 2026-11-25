-- ShellCheck - a static analysis tool for shell scripts.
--
-- Official prebuilt binaries verified against koalaman/shellcheck v0.11.0:
--   * linux/x86_64: statically linked ELF64 executable (no dynamic section)
--   * linux/aarch64: statically linked ELF64 executable (no dynamic section)
--   * macosx/x86_64 & macosx/aarch64: Mach-O executables linking only system
--     dylibs (libiconv.2, libSystem.B, Security.framework, libcharset.1)
--   * windows/x86_64: PE32+ executable importing only Windows OS / UCRT DLLs
--     (no VCRUNTIME140.dll or MSVCP140.dll; no windows/aarch64 release asset)
--
-- Linux and macOS `.tar.xz` archives unpack into `shellcheck-v<ver>/` with
-- `shellcheck`, `LICENSE.txt`, and `README.txt`. Windows `.zip` is flat at root.

package = {
    spec = "2",

    name = "shellcheck",
    description = "A static analysis tool for shell scripts",
    homepage = "https://www.shellcheck.net/",
    authors = {"Vidar Holen"},
    maintainers = {"koalaman"},
    licenses = {"GPL-3.0"},
    repo = "https://github.com/koalaman/shellcheck",
    docs = "https://www.shellcheck.net/wiki/",
    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "linter", "shell", "tools"},
    keywords = {"shellcheck", "shell", "bash", "sh", "linter", "static-analysis"},

    programs = {"shellcheck"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/koalaman/shellcheck/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/koalaman/shellcheck/releases/download/${tag}/shellcheck-${tag}.linux.x86_64.tar.xz",
                            aarch64 = "https://github.com/koalaman/shellcheck/releases/download/${tag}/shellcheck-${tag}.linux.aarch64.tar.xz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/koalaman/shellcheck/releases/download/${tag}/shellcheck-${tag}.darwin.x86_64.tar.xz",
                            aarch64 = "https://github.com/koalaman/shellcheck/releases/download/${tag}/shellcheck-${tag}.darwin.aarch64.tar.xz",
                        },
                        windows = {
                            x86_64 = "https://github.com/koalaman/shellcheck/releases/download/${tag}/shellcheck-${tag}.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/koalaman/shellcheck/releases/download/v${version}/shellcheck-v${version}.linux.${arch}.tar.xz",
            ["latest"] = { ref = "0.11.0" },
            ["0.11.0"] = {
                sha256 = {
                    x86_64 = "8c3be12b05d5c177a04c29e3c78ce89ac86f1595681cab149b65b97c4e227198",
                    aarch64 = "12b331c1d2db6b9eb13cfca64306b1b157a86eb69db83023e261eaa7e7c14588",
                },
            },
        },
        macosx = {
            source = "https://github.com/koalaman/shellcheck/releases/download/v${version}/shellcheck-v${version}.darwin.${arch}.tar.xz",
            ["latest"] = { ref = "0.11.0" },
            ["0.11.0"] = {
                sha256 = {
                    x86_64 = "3c89db4edcab7cf1c27bff178882e0f6f27f7afdf54e859fa041fca10febe4c6",
                    aarch64 = "56affdd8de5527894dca6dc3d7e0a99a873b0f004d7aabc30ae407d3f48b0a79",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "0.11.0" },
            ["0.11.0"] = {
                x86_64 = {
                    url = "https://github.com/koalaman/shellcheck/releases/download/v0.11.0/shellcheck-v0.11.0.zip",
                    sha256 = "8a4e35ab0b331c85d73567b12f2a444df187f483e5079ceffa6bda1faa2e740e",
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
    return payload.present({ "shellcheck" }) or payload.present({ "shellcheck.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file())
    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("%.zip$") ~= nil
    local exe = is_win and "shellcheck.exe" or "shellcheck"
    local top_dir = "shellcheck-v" .. pkginfo.version()

    if is_win then
        if os.isdir(parent .. "/" .. top_dir) then
            payload.unpack{ extracted = top_dir }
        elseif os.isfile(parent .. "/shellcheck.exe") then
            os.tryrm(dir)
            fs.mkdir_p(dir)
            for _, f in ipairs({ "shellcheck.exe", "LICENSE.txt", "README.txt" }) do
                if os.isfile(parent .. "/" .. f) then
                    os.mv(parent .. "/" .. f, dir .. "/" .. f)
                end
            end
        else
            payload.unpack{}
        end
    else
        payload.unpack{ extracted = top_dir }
        system.exec(string.format('chmod +x "%s"', dir .. "/shellcheck"))
    end

    payload.require({ exe })
    return true
end

function config()
    xvm.add("shellcheck", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("shellcheck")
    return true
end
