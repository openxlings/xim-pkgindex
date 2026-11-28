-- Official tdewolff/minify v2.25.0 CLI archives, verified 2026-11-27.
-- All five downloaded archives match checksums.txt and GitHub asset digests.
-- Linux amd64/arm64 are static Go ELF binaries (no interpreter/dynamic section).
-- Darwin provides x86_64/arm64 Mach-O; Windows provides x86_64 PE32+ only
-- (kernel32.dll import). There is no upstream Windows ARM64 CLI archive.
-- Archives are flat: minify[.exe], LICENSE, README.md, plus bash_completion
-- on POSIX. Completion files are payload only; no shell configuration changes.
package = {
    spec = "2",
    name = "minify",
    description = "Fast command-line minifier for web formats including HTML, CSS, JavaScript, JSON, SVG and XML",
    homepage = "https://github.com/tdewolff/minify",
    repo = "https://github.com/tdewolff/minify",
    docs = "https://github.com/tdewolff/minify/tree/master/cmd/minify",
    authors = {"Taco de Wolff"},
    maintainers = {"tdewolff"},
    licenses = {"MIT"},
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"tools", "web"},
    keywords = {"minify", "minification", "html", "css", "javascript", "json"},
    programs = {"minify"},
    xvm_enable = true,
    extensions = {
        autoupdate = {
            source = "https://github.com/tdewolff/minify/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/tdewolff/minify/releases/download/${tag}/minify_linux_amd64.tar.gz",
                            aarch64 = "https://github.com/tdewolff/minify/releases/download/${tag}/minify_linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/tdewolff/minify/releases/download/${tag}/minify_darwin_amd64.tar.gz",
                            aarch64 = "https://github.com/tdewolff/minify/releases/download/${tag}/minify_darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/tdewolff/minify/releases/download/${tag}/minify_windows_amd64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },
    xpm = {
        linux = {
            source = "https://github.com/tdewolff/minify/releases/download/v${version}/minify_linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "2.25.0" },
            ["2.25.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "bf5908d0266e6bca31e2d89d7ee9ab537f7a4770578382b5120cbf23dc17b2cf",
                    aarch64 = "7c7353a11e275186b2c870459ee6bb8170cf56ee7ab1c9715733ac873f914a74",
                },
            },
        },
        macosx = {
            source = "https://github.com/tdewolff/minify/releases/download/v${version}/minify_darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "2.25.0" },
            ["2.25.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "4b28a107fb44ea6ef7c7f348bdc622e3fa07869f33bd70a66c5996d02e810bc1",
                    aarch64 = "1bc11f15d947596e3a7cc775c11a536acb7edbc54c621d3f673fe8575da16e78",
                },
            },
        },
        windows = {
            source = "https://github.com/tdewolff/minify/releases/download/v${version}/minify_windows_${arch_alias}.zip",
            ["latest"] = { ref = "2.25.0" },
            ["2.25.0"] = {
                arch_alias = { x86_64 = "amd64" },
                sha256 = {
                    x86_64 = "d3b396dbe32c9bd26c55c396c20c3bb49f5e070408f7a679c9309151d342a22d",
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

local function required_files(exe)
    return { exe, "LICENSE" }
end

function installed()
    return payload.present(required_files("minify"))
        or payload.present(required_files("minify.exe"))
end

function install()
    local archive = tostring(pkginfo.install_file() or ""):gsub("\\", "/")
    local parent = archive:match("^(.*)/[^/]+$") or "."
    local windows = archive:match("%.zip$") ~= nil
    local exe = windows and "minify.exe" or "minify"
    local dir = pkginfo.install_dir()

    -- Flat archives must not move the shared cache directory into this package.
    if windows and os.isfile(archive) then
        payload.unpack{}
    else
        os.tryrm(dir)
        fs.mkdir_p(dir)
        if os.isfile(archive) then
            system.exec(string.format('tar -xzf "%s" -C "%s"', archive, dir))
        else
            for _, name in ipairs({ exe, "LICENSE", "README.md", "bash_completion" }) do
                if os.isfile(parent .. "/" .. name) then
                    os.mv(parent .. "/" .. name, dir .. "/" .. name)
                end
            end
        end
    end
    payload.require(required_files(exe))
    if not windows then
        system.exec(string.format('chmod +x "%s"', dir .. "/" .. exe))
    end
    return true
end

function config()
    xvm.add("minify", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("minify")
    return true
end
