-- podman -- daemonless container engine for developing, managing, and running
-- OCI containers and pods (https://podman.io).
--
-- Verified 2026-11-26 against version 6.2.1 (tag `v6.2.1`).
--
-- Source provenance (deliberate cross-tier selection by platform):
--   * linux/x86_64, linux/aarch64 (Tier 2: `mgoltzsche/podman-static`):
--       Official `podman-container-tools/podman` releases publish only the
--       client-only `podman-remote-static` binary on Linux and ship no
--       standalone local engine tarball. `mgoltzsche/podman-static` publishes
--       GPG-signed, fully statically linked Linux bundles matching each
--       upstream tag (`podman-linux-{amd64,arm64}.tar.gz`) containing the full
--       local engine (`podman`) and its entire helper stack (`crun`, `runc`,
--       `conmon`, `netavark`, `aardvark-dns`, `passt`/`pasta`, `catatonit`,
--       `fuse-overlayfs`, `fusermount3`, `rootlessport`, `quadlet`, and default
--       `/etc/containers` configs). Every ELF binary in the bundle is static or
--       static-pie with zero `DT_NEEDED` entries (no `xim:glibc` dependency).
--       `install()` generates a relocatable `etc/containers/xlings-containers.conf`
--       pointing at the bundled helpers and seccomp profile inside
--       `pkginfo.install_dir()`, and `config()` wires `CONTAINERS_CONF`,
--       `CONTAINERS_POLICY_JSON`, and `CONTAINERS_REGISTRIES_CONF` on the xvm
--       shim so rootless local containers work without writing to `/etc` or
--       `/usr/local`. Bundled `pasta`/`passt` remain private inside the payload
--       and are not registered in xvm so they do not collide with `xim:passt`.
--   * macosx/aarch64 (Tier 1: official `podman-container-tools/podman`):
--       `podman-remote-release-darwin_arm64.zip` (`podman-6.2.1/usr/bin/podman`
--       and `podman-mac-helper`, Mach-O 64-bit arm64). `macosx/x86_64` is
--       omitted because upstream Podman 6.x no longer publishes macOS Intel
--       archives.
--   * windows/x86_64, windows/aarch64 (Tier 1: official `podman-container-tools/podman`):
--       `podman-remote-release-windows_{amd64,arm64}.zip`
--       (`podman-6.2.1/usr/bin/podman.exe`, `gvproxy.exe`, `win-sshproxy.exe`).
--       All three PE32+ executables import only `kernel32.dll` (no
--       `VCRUNTIME140.dll`, so no `xim:vcruntime` dependency). Helper binaries
--       stay beside `podman.exe` in `usr/bin` and are omitted from `programs`
--       so Windows CI probes only the CLI `podman`.

package = {
    spec = "2",

    name = "podman",
    description = "Daemonless container engine for developing, managing, and running OCI containers and pods",
    homepage = "https://podman.io",
    authors = {"Podman Contributors"},
    maintainers = {"https://github.com/podman-container-tools/podman/graphs/contributors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/podman-container-tools/podman",
    docs = "https://docs.podman.io/",
    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"container", "devops", "cli", "tools"},
    keywords = {"podman", "container", "oci", "docker", "pod", "rootless", "cli"},

    programs = {"podman"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/podman-container-tools/podman/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/mgoltzsche/podman-static/releases/download/${tag}/podman-linux-amd64.tar.gz",
                            aarch64 = "https://github.com/mgoltzsche/podman-static/releases/download/${tag}/podman-linux-arm64.tar.gz",
                        },
                        macosx = {
                            aarch64 = "https://github.com/podman-container-tools/podman/releases/download/${tag}/podman-remote-release-darwin_arm64.zip",
                        },
                        windows = {
                            x86_64 = "https://github.com/podman-container-tools/podman/releases/download/${tag}/podman-remote-release-windows_amd64.zip",
                            aarch64 = "https://github.com/podman-container-tools/podman/releases/download/${tag}/podman-remote-release-windows_arm64.zip",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/mgoltzsche/podman-static/releases/download/v${version}/podman-linux-${arch_alias}.tar.gz",
            ["latest"] = { ref = "6.2.1" },
            ["6.2.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "e95435d3ad37be41ec00a6b10ea5063563c9f8b485da47fbb1cbc21eb102464f",
                    aarch64 = "8379c337701ec827bc86916478ba8953aca9992d0a08bc6b85a9de72e352f857",
                },
            },
        },
        macosx = {
            source = "https://github.com/podman-container-tools/podman/releases/download/v${version}/podman-remote-release-darwin_${arch_alias}.zip",
            ["latest"] = { ref = "6.2.1" },
            ["6.2.1"] = {
                arch_alias = { aarch64 = "arm64" },
                sha256 = {
                    aarch64 = "c53ea525e5e902dd02bd0382299b6742c0ebc1955f38853e64a16290da9127ba",
                },
            },
        },
        windows = {
            source = "https://github.com/podman-container-tools/podman/releases/download/v${version}/podman-remote-release-windows_${arch_alias}.zip",
            ["latest"] = { ref = "6.2.1" },
            ["6.2.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "a42468966997bade4e161b8a5aac96f757f4f88e5d5aa8a4ccaa4e3c089bd55d",
                    aarch64 = "56fc19da947fbc62deaaf55ff09acb8607c017ee068f2cee879122a5d02bd15d",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")
import("xim.pkgindex.shell")

local LINUX_FILES = {
    "usr/local/bin/podman",
    "usr/local/bin/crun",
    "usr/local/bin/runc",
    "usr/local/bin/fuse-overlayfs",
    "usr/local/bin/fusermount3",
    "usr/local/bin/passt",
    "usr/local/bin/pasta",
    "usr/local/lib/podman/conmon",
    "usr/local/lib/podman/netavark",
    "usr/local/lib/podman/aardvark-dns",
    "usr/local/lib/podman/catatonit",
    "usr/local/lib/podman/rootlessport",
    "usr/local/libexec/podman/quadlet",
    "etc/containers/xlings-containers.conf",
    "etc/containers/policy.json",
    "etc/containers/registries.conf",
    "etc/containers/seccomp.json",
}

local MACOS_FILES = {
    "usr/bin/podman",
    "usr/bin/podman-mac-helper",
}

local WINDOWS_FILES = {
    "usr/bin/podman.exe",
    "usr/bin/gvproxy.exe",
    "usr/bin/win-sshproxy.exe",
}

local function toml_quote(s)
    return '"' .. tostring(s):gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
end

local function write_linux_containers_conf(dir)
    local conf_path = dir .. "/etc/containers/xlings-containers.conf"
    local content = table.concat({
        "# Generated by xlings podman xpkg for relocatable static execution.",
        "[containers]",
        "seccomp_profile = " .. toml_quote(dir .. "/etc/containers/seccomp.json"),
        "init_path = " .. toml_quote(dir .. "/usr/local/lib/podman/catatonit"),
        "",
        "[engine]",
        'cgroup_manager = "cgroupfs"',
        'events_logger = "file"',
        'runtime = "crun"',
        "helper_binaries_dir = ["
            .. toml_quote(dir .. "/usr/local/lib/podman") .. ", "
            .. toml_quote(dir .. "/usr/local/libexec/podman") .. ", "
            .. toml_quote(dir .. "/usr/local/bin") .. "]",
        "conmon_path = [" .. toml_quote(dir .. "/usr/local/lib/podman/conmon") .. "]",
        "",
        "[engine.runtimes]",
        "crun = [" .. toml_quote(dir .. "/usr/local/bin/crun") .. "]",
        "runc = [" .. toml_quote(dir .. "/usr/local/bin/runc") .. "]",
        "",
        "[network]",
        'network_backend = "netavark"',
        'default_rootless_network_cmd = "pasta"',
        "",
    }, "\n")
    local f, err = io.open(conf_path, "wb")
    if not f then
        error("podman: failed to write " .. conf_path .. ": " .. tostring(err))
    end
    local ok, werr = f:write(content)
    f:close()
    if not ok then
        error("podman: failed to write " .. conf_path .. ": " .. tostring(werr))
    end
end

function installed()
    return payload.present(LINUX_FILES)
        or payload.present(MACOS_FILES)
        or payload.present(WINDOWS_FILES)
end

function install()
    local ver = tostring(pkginfo.version())
    local dir = pkginfo.install_dir()

    payload.unpack{
        extracted = {
            "podman-linux-amd64",
            "podman-linux-arm64",
            "podman-" .. ver,
        },
        strip = 1,
    }

    if os.isfile(dir .. "/usr/local/bin/podman") then
        write_linux_containers_conf(dir)
        payload.require(LINUX_FILES)
    elseif os.isfile(dir .. "/usr/bin/podman.exe") then
        payload.require(WINDOWS_FILES)
    elseif os.isfile(dir .. "/usr/bin/podman") then
        shell.exec({ "chmod", "+x", dir .. "/usr/bin/podman", dir .. "/usr/bin/podman-mac-helper" })
        payload.require(MACOS_FILES)
    else
        error("podman: unpacked payload in " .. dir .. " does not contain podman binary")
    end

    return true
end

function config()
    local dir = pkginfo.install_dir()
    if os.isfile(dir .. "/usr/local/bin/podman") then
        xvm.add("podman", {
            bindir = dir .. "/usr/local/bin",
            envs = {
                CONTAINERS_CONF = dir .. "/etc/containers/xlings-containers.conf",
                CONTAINERS_POLICY_JSON = dir .. "/etc/containers/policy.json",
                CONTAINERS_REGISTRIES_CONF = dir .. "/etc/containers/registries.conf",
            },
        })
    elseif os.isfile(dir .. "/usr/bin/podman.exe") or os.isfile(dir .. "/usr/bin/podman") then
        xvm.add("podman", { bindir = dir .. "/usr/bin" })
    else
        error("podman: no podman binary found in " .. dir)
    end
    return true
end

function uninstall()
    xvm.remove("podman")
    return true
end
