-- kustomize — customization of Kubernetes YAML configurations (kubernetes-sigs/kustomize).
--
-- Distribution: upstream publishes flat release archives under monorepo release
-- tags `kustomize/v<version>`. Each archive contains a single executable at root
-- (`kustomize` / `kustomize.exe`) with no top-level wrapper directory.
--
-- Platform and architecture coverage (verified against kustomize/v5.8.3):
--   linux    x86_64, aarch64   kustomize_v<ver>_linux_<arch>.tar.gz    (static Go ELF, no .dynamic section)
--   macosx   x86_64, aarch64   kustomize_v<ver>_darwin_<arch>.tar.gz   (Mach-O 64-bit executable)
--   windows  x86_64, aarch64   kustomize_v<ver>_windows_<arch>.zip     (PE32+ console executable, imports kernel32.dll only)
--
-- All 6 SHA256 digests below were verified against both upstream `checksums.txt`
-- and the downloaded release archives.

package = {
    spec = "2",

    name = "kustomize",
    description = "Customization of Kubernetes YAML configurations",
    homepage = "https://kustomize.io",
    maintainers = {"Kubernetes SIGs"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/kubernetes-sigs/kustomize",
    docs = "https://kubectl.docs.kubernetes.io/references/kustomize/",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"kubernetes", "k8s", "cli", "yaml", "tools"},
    keywords = {"kustomize", "kubernetes", "k8s", "yaml", "manifests", "cli"},

    programs = {"kustomize"},
    xvm_enable = true,
    ci = { mirror = true },

    extensions = {
        autoupdate = {
            source = "https://github.com/kubernetes-sigs/kustomize/releases",
            tag = "kustomize/v${version}",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/kubernetes-sigs/kustomize/releases/download/${tag}/kustomize_v${version}_linux_amd64.tar.gz",
                            aarch64 = "https://github.com/kubernetes-sigs/kustomize/releases/download/${tag}/kustomize_v${version}_linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/kubernetes-sigs/kustomize/releases/download/${tag}/kustomize_v${version}_darwin_amd64.tar.gz",
                            aarch64 = "https://github.com/kubernetes-sigs/kustomize/releases/download/${tag}/kustomize_v${version}_darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/kubernetes-sigs/kustomize/releases/download/${tag}/kustomize_v${version}_windows_amd64.zip",
                            aarch64 = "https://github.com/kubernetes-sigs/kustomize/releases/download/${tag}/kustomize_v${version}_windows_arm64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/v${version}/kustomize_v${version}_linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "5.8.3" },
            ["5.8.3"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "cb9e31198d3f63b44848bd0afc4c8efc56e6cfef9c93a4a39a211940e6decd61",
                    aarch64 = "9867b76482cfc6d25b546abc1d2b5a32bd137505aba640649b4b378f64f6d68f",
                },
            },
        },
        macosx = {
            source = "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/v${version}/kustomize_v${version}_darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "5.8.3" },
            ["5.8.3"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "d08fb85846c3d977f0e2a66e7ff45f1b5264c294685e5e726e1a8bdfe0da8dee",
                    aarch64 = "4cbb08e209d8fff47cd60bfb6407daaf5ee699f9b9295849a1065024fac2d1ef",
                },
            },
        },
        windows = {
            source = "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/v${version}/kustomize_v${version}_windows_${arch_alias}.zip",
            ["latest"] = { ref = "5.8.3" },
            ["5.8.3"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "763c4040ff01435bfce39661072452ebdf1cf2808bb91f5708ab4420834fbd42",
                    aarch64 = "b86236917e649e2f9531899c519f333e554cd1fc0c87132b86b885bf315735dc",
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
    return payload.present({ "kustomize" }) or payload.present({ "kustomize.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("kustomize: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("%.zip$") ~= nil
    local exe = is_win and "kustomize.exe" or "kustomize"

    os.tryrm(dir)
    fs.mkdir_p(dir)

    -- Upstream archives are flat (no top-level wrapper directory). Extract
    -- directly from the archive into install_dir so files from unrelated flat
    -- packages in the shared download directory cannot leak into this payload.
    if is_win then
        if os.isfile(archive) then
            payload.unpack{}
        elseif os.isfile(parent .. "/" .. exe) then
            os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
        else
            error("kustomize: neither archive (" .. archive .. ") nor extracted binary exists")
        end
    else
        if os.isfile(archive) then
            system.exec(string.format([[tar -xzf "%s" -C "%s"]], normalized, dir))
        elseif os.isfile(parent .. "/" .. exe) then
            os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
        else
            error("kustomize: neither archive (" .. archive .. ") nor extracted binary exists")
        end
        if os.isfile(dir .. "/" .. exe) then
            system.exec(string.format([[chmod +x "%s"]], dir .. "/" .. exe))
        end
    end

    payload.require({ exe })
    return true
end

function config()
    xvm.add("kustomize", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("kustomize")
    return true
end
