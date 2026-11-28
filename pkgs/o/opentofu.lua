-- OpenTofu - Open-source infrastructure-as-code tool (binary: `tofu`).
--
-- Verified 2026-11-25 against the upstream GitHub release v1.13.10: every
-- SHA256 below was verified against `tofu_1.13.10_SHA256SUMS` and downloaded
-- archives. All six archives are flat (no enclosing directory) and pack
-- `tofu[.exe]`, `LICENSE`, `README.md`, and `CHANGELOG.md`.
-- The Linux binaries are statically linked Go executables (`readelf -d`: no
-- dynamic section, `ldd`: not a dynamic executable); the Windows PE32+
-- binaries import only `kernel32.dll`.
package = {
    spec = "2",

    name = "opentofu",
    description = "Open-source infrastructure-as-code tool for provisioning and managing cloud infrastructure",
    homepage = "https://opentofu.org",
    authors = {"OpenTofu Authors"},
    maintainers = {"https://github.com/opentofu/opentofu/graphs/contributors"},
    licenses = {"MPL-2.0"},
    repo = "https://github.com/opentofu/opentofu",
    docs = "https://opentofu.org/docs/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"devops", "iac", "cloud", "cli", "tools"},
    keywords = {"opentofu", "tofu", "terraform", "iac", "infrastructure", "devops"},

    programs = {"tofu"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/opentofu/opentofu/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/opentofu/opentofu/releases/download/${tag}/tofu_${version}_linux_amd64.tar.gz",
                            aarch64 = "https://github.com/opentofu/opentofu/releases/download/${tag}/tofu_${version}_linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/opentofu/opentofu/releases/download/${tag}/tofu_${version}_darwin_amd64.tar.gz",
                            aarch64 = "https://github.com/opentofu/opentofu/releases/download/${tag}/tofu_${version}_darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/opentofu/opentofu/releases/download/${tag}/tofu_${version}_windows_amd64.zip",
                            aarch64 = "https://github.com/opentofu/opentofu/releases/download/${tag}/tofu_${version}_windows_arm64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/opentofu/opentofu/releases/download/v${version}/tofu_${version}_linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.13.10" },
            ["1.13.10"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "f606b6117ee03177374806d56d580bde7b512aff69f86d2b9f3148dced4ca375",
                    aarch64 = "9dcdabf93c5209feaa35a7bb6d41f4d71b0880c4c4dfaf275d612f5b6facc28a",
                },
            },
        },
        macosx = {
            source = "https://github.com/opentofu/opentofu/releases/download/v${version}/tofu_${version}_darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.13.10" },
            ["1.13.10"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "996b3a4ea0c531e4bfc6cf7d4a819417ac119b88646dbf2a855ca8e2518b575f",
                    aarch64 = "72d39c8492f04bb0fb1642615ad29fdfe35e6a344bd2ad425c5bc8559e7e2b61",
                },
            },
        },
        windows = {
            source = "https://github.com/opentofu/opentofu/releases/download/v${version}/tofu_${version}_windows_${arch_alias}.zip",
            ["latest"] = { ref = "1.13.10" },
            ["1.13.10"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "643cbcb8d699a5aaf47da12ce8f9f715362f2fd84f10a407a32d44fbe2fe8e09",
                    aarch64 = "5c7279641fbe5099a000fc6815b295477775dd402997c5937b98d6ef4724cd1c",
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
    return payload.present({ "tofu", "LICENSE" })
        or payload.present({ "tofu.exe", "LICENSE" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("opentofu: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("%.zip$") ~= nil
    local exe = is_win and "tofu.exe" or "tofu"

    os.tryrm(dir)

    -- Archives are flat (no top-level wrapper dir): extract straight from the
    -- archive into install_dir so files from unrelated flat archives in the
    -- shared runtime download directory are never pulled in.
    if is_win then
        payload.unpack{}
    elseif os.isfile(archive) then
        fs.mkdir_p(dir)
        system.exec(string.format('tar -xzf "%s" -C "%s"', normalized, dir))
    elseif os.isfile(parent .. "/" .. exe) then
        fs.mkdir_p(dir)
        for _, f in ipairs({ exe, "LICENSE", "README.md", "CHANGELOG.md" }) do
            if os.isfile(parent .. "/" .. f) then
                os.mv(parent .. "/" .. f, dir .. "/" .. f)
            end
        end
    else
        error("opentofu: archive not found at " .. archive .. " and no extracted " .. exe .. " in " .. parent)
    end

    if not is_win and os.isfile(dir .. "/" .. exe) then
        system.exec(string.format('chmod +x "%s"', dir .. "/" .. exe))
    end

    payload.require({ exe, "LICENSE" })
    return true
end

function config()
    xvm.add("tofu", { bindir = pkginfo.install_dir() })
    -- Group placeholder: the binary is `tofu`, while the package name is
    -- `opentofu`. Registering `package.name` with `type = "group"` lets
    -- `xvm info opentofu` and `xlings remove` locate the package without
    -- creating an orphan `opentofu` shim in `bin/`.
    xvm.add(package.name, { type = "group" })
    return true
end

function uninstall()
    xvm.remove("tofu")
    xvm.remove(package.name)
    return true
end
