package = {
    spec = "2",

    name = "pi",
    description = "Minimal, extensible AI coding-agent CLI",
    homepage = "https://pi.dev",
    licenses = {"MIT"},
    repo = "https://github.com/earendil-works/pi",
    docs = "https://pi.dev/docs/latest",

    -- The release ELF uses the host loader/libc; do not declare xim:glibc,
    -- which would hand this Bun single-file binary to elfpatch. Pi's optional
    -- Linux clipboard addon loads only with DISPLAY and tolerates missing XCB.

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"ai", "cli", "tools"},
    keywords = {"pi", "coding-agent", "ai", "llm"},

    programs = {"pi"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/earendil-works/pi/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/earendil-works/pi/releases/download/v${version}/pi-linux-x64.tar.gz",
                            aarch64 = "https://github.com/earendil-works/pi/releases/download/v${version}/pi-linux-arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/earendil-works/pi/releases/download/v${version}/pi-darwin-x64.tar.gz",
                            aarch64 = "https://github.com/earendil-works/pi/releases/download/v${version}/pi-darwin-arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/earendil-works/pi/releases/download/v${version}/pi-windows-x64.zip",
                            aarch64 = "https://github.com/earendil-works/pi/releases/download/v${version}/pi-windows-arm64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/earendil-works/pi/releases/download/v${version}/pi-linux-${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.0.0" },
            ["1.0.0"] = {
                arch_alias = { x86_64 = "x64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "8fd5543a52a889d60ad57ccbf6c969e73c75c5240aae18ac40b506947a63dc38",
                    aarch64 = "b60b3fda830a43c1dc3f5edb5fc7b681f22a0a930b48cdac13b97570c6045819",
                },
            },
        },
        macosx = {
            source = "https://github.com/earendil-works/pi/releases/download/v${version}/pi-darwin-${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.0.0" },
            ["1.0.0"] = {
                arch_alias = { x86_64 = "x64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "62fb78fcdbc7c0dbd21044dd44bfb3af20df447285bb55e9debf86ff4838776d",
                    aarch64 = "97291e7d2eb2d7d95ab1f67d26de7902302201bc8786c132bbbc9e53fa8526cc",
                },
            },
        },
        windows = {
            deps = { build = { "xim:7zip" } },
            source = "https://github.com/earendil-works/pi/releases/download/v${version}/pi-windows-${arch_alias}.zip",
            ["latest"] = { ref = "1.0.0" },
            ["1.0.0"] = {
                arch_alias = { x86_64 = "x64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "f7dbd39814bf6763f01e7f688ad089615de1d0eb55fc8915a49acdc2088f4404",
                    aarch64 = "122d3a1825eac4aa17081c769188c1d058febf579a9407091ae829626997ea96",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.system")

function install()
    local dir = pkginfo.install_dir()
    local archive = pkginfo.install_file()
    local staging = dir .. ".staging"
    os.tryrm(dir)
    os.tryrm(staging)
    os.mkdir(staging)

    if is_host("windows") then
        local build_dep = assert(pkginfo.build_dep("7zip"), "xim:7zip build dependency is missing")
        local seven_zip = path.join(build_dep.path, "7z.exe")
        local function powershell_escape(value)
            return (value:gsub("'", "''"))
        end
        -- Start-Process joins arguments into a command line; retain quotes for
        -- archive/output paths without nesting double quotes through cmd.exe.
        system.exec(string.format([[
powershell -NoProfile -ExecutionPolicy Bypass -Command "$quote = [char]34; $process = Start-Process -FilePath '%s' -ArgumentList ('x ' + $quote + '%s' + $quote + ' -o' + $quote + '%s' + $quote + ' -y') -Wait -NoNewWindow -PassThru; exit $process.ExitCode"
]], powershell_escape(seven_zip), powershell_escape(archive), powershell_escape(staging)))
    else
        system.exec(string.format([[tar -xzf "%s" -C "%s"]], archive, staging))
    end

    -- Unix assets wrap the payload in pi/; Windows assets contain pi.exe at
    -- the ZIP root. Normalize both layouts to xlings' install directory.
    local payload = is_host("windows") and staging or path.join(staging, "pi")
    if not os.isfile(path.join(payload, is_host("windows") and "pi.exe" or "pi")) then
        raise("pi: release executable is missing from extracted archive")
    end
    if not os.isfile(path.join(payload, "package.json")) then
        raise("pi: package.json is missing from extracted archive")
    end

    local dest = is_host("windows") and dir or path.join(dir, "pi")
    if not is_host("windows") then
        os.mkdir(dir)
    end
    os.mv(payload, dest)

    local executable = path.join(dest, is_host("windows") and "pi.exe" or "pi")
    if not is_host("windows") then
        system.exec(string.format([[chmod +x "%s"]], executable))
    end
    os.tryrm(staging)

    -- The standalone release is a Bun binary. Pi intentionally refuses to
    -- self-update Bun-binary installs; xvm remains the version owner.
    return os.isfile(executable) and os.isfile(path.join(dest, "package.json"))
end

function config()
    local bindir = is_host("windows") and pkginfo.install_dir() or path.join(pkginfo.install_dir(), "pi")
    local alias = is_host("windows") and "pi.exe" or "pi"
    xvm.add(package.name, { bindir = bindir, alias = alias })
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
