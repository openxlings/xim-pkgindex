-- Stern - Multi pod and container log tailing for Kubernetes.
--
-- Verified 2026-11-25 against upstream GitHub release v1.35.0 (stern/stern):
--   linux    x86_64, aarch64   stern_<ver>_linux_{amd64,arm64}.tar.gz
--   macosx   x86_64, aarch64   stern_<ver>_darwin_{amd64,arm64}.tar.gz
--   windows  x86_64, aarch64   stern_<ver>_windows_{amd64,arm64}.zip
--
-- Every archive is flat at root (`stern` / `stern.exe`, `LICENSE`).
-- All six SHA-256 digests match upstream `checksums.txt` and downloaded archives.
-- Both Linux ELF binaries are statically linked Go executables (`readelf -d`:
-- no dynamic section; `ldd`: not a dynamic executable), so no runtime deps are
-- required. Both Windows PE32+ executables (`x86_64`, `aarch64`) import only
-- `kernel32.dll`.
package = {
    spec = "2",

    name = "stern",
    description = "Multi pod and container log tailing for Kubernetes",
    homepage = "https://github.com/stern/stern",
    maintainers = {"https://github.com/stern/stern/graphs/contributors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/stern/stern",
    docs = "https://github.com/stern/stern#readme",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"kubernetes", "devops", "cli", "tools"},
    keywords = {"stern", "kubernetes", "k8s", "logs", "tail", "pods"},

    programs = {"stern"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/stern/stern/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/stern/stern/releases/download/${tag}/stern_${version}_linux_amd64.tar.gz",
                            aarch64 = "https://github.com/stern/stern/releases/download/${tag}/stern_${version}_linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/stern/stern/releases/download/${tag}/stern_${version}_darwin_amd64.tar.gz",
                            aarch64 = "https://github.com/stern/stern/releases/download/${tag}/stern_${version}_darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/stern/stern/releases/download/${tag}/stern_${version}_windows_amd64.zip",
                            aarch64 = "https://github.com/stern/stern/releases/download/${tag}/stern_${version}_windows_arm64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/stern/stern/releases/download/v${version}/stern_${version}_linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.35.0" },
            ["1.35.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "03729b01a8fcfab25f6ea53389bd38bc37400ff86d90cd2dcda541f248cf843e",
                    aarch64 = "b12f5e2ee0d01f6f21e0759cced0be2d8df9cd4e93e6a3cf11393170ae0f43cf",
                },
            },
        },
        macosx = {
            source = "https://github.com/stern/stern/releases/download/v${version}/stern_${version}_darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.35.0" },
            ["1.35.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "6a0b9d99a73a70326fc30079d1b70f03c9593f1b1d441c64a93907e79baec815",
                    aarch64 = "951ba00a33ea09b9e64c8ab7b71443b9be4d65f6f6c91b184fbec6d684d9dd0a",
                },
            },
        },
        windows = {
            source = "https://github.com/stern/stern/releases/download/v${version}/stern_${version}_windows_${arch_alias}.zip",
            ["latest"] = { ref = "1.35.0" },
            ["1.35.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "eb2fba5caa9a0f8e4b58045de2ed1efa59d283770607f937aaf50d836bd285ac",
                    aarch64 = "15e3195331d22684254dd0ee5db464133cb4acfdffb048222e7621db0402b516",
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
    return payload.present({ "stern", "LICENSE" })
        or payload.present({ "stern.exe", "LICENSE" })
end

function install()
    local archive = tostring(pkginfo.install_file())
    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("%.zip$") ~= nil

    os.tryrm(dir)

    if is_win then
        payload.unpack{}
    elseif os.isfile(archive) then
        -- Extract flat .tar.gz directly into install_dir so files never mix
        -- with other flat archives in the shared runtimedir.
        fs.mkdir_p(dir)
        system.exec(string.format('tar -xf "%s" -C "%s"', archive, dir))
        system.exec(string.format('chmod +x "%s"', dir .. "/stern"))
    elseif os.isfile(parent .. "/stern") then
        fs.mkdir_p(dir)
        for _, f in ipairs({ "stern", "LICENSE" }) do
            if os.isfile(parent .. "/" .. f) then
                os.mv(parent .. "/" .. f, dir .. "/" .. f)
            end
        end
        system.exec(string.format('chmod +x "%s"', dir .. "/stern"))
    else
        error("stern: archive not found at " .. archive)
    end

    payload.require({ is_win and "stern.exe" or "stern", "LICENSE" })
    return true
end

function config()
    xvm.add("stern", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("stern")
    return true
end
