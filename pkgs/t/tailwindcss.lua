-- Upstream v4.3.5 assets are raw executables with the CLI, Tailwind CSS and
-- native compiler modules embedded; no Node.js/npm install is needed.
-- Select the GNU Linux builds: both need glibc (GLIBC_2.17), and embedded
-- compiler/watch modules load libgcc_s.so.1 and libstdc++.so.6. The musl
-- alternatives require a musl loader and libstdc++.so.6, so are omitted.
-- macOS assets are Mach-O x86_64/arm64; Windows x64 is PE32+ with OS DLL imports
-- only. Upstream supplies no Windows ARM64 standalone binary.
-- All seven binaries were checked against upstream sha256sums.txt and release
-- asset digests; the five selected assets below come directly from upstream.
package = {
    spec = "2",
    name = "tailwindcss",
    description = "Standalone Tailwind CSS CLI for compiling utility-first CSS without Node.js",
    homepage = "https://tailwindcss.com",
    authors = {"Tailwind Labs"},
    maintainers = {"tailwindlabs"},
    licenses = {"MIT"},
    repo = "https://github.com/tailwindlabs/tailwindcss",
    docs = "https://tailwindcss.com/docs/installation/tailwind-cli",
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"css", "web", "cli", "tools"},
    keywords = {"tailwindcss", "tailwind", "css", "standalone"},
    programs = {"tailwindcss"},
    xvm_enable = true,
    ci = { mirror = true },

    extensions = {
        autoupdate = {
            source = "https://github.com/tailwindlabs/tailwindcss/releases",
            resources = {
                -- No CN mirror has been independently verified.
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/tailwindlabs/tailwindcss/releases/download/${tag}/tailwindcss-linux-x64",
                            aarch64 = "https://github.com/tailwindlabs/tailwindcss/releases/download/${tag}/tailwindcss-linux-arm64",
                        },
                        macosx = {
                            x86_64 = "https://github.com/tailwindlabs/tailwindcss/releases/download/${tag}/tailwindcss-macos-x64",
                            aarch64 = "https://github.com/tailwindlabs/tailwindcss/releases/download/${tag}/tailwindcss-macos-arm64",
                        },
                        windows = {
                            x86_64 = "https://github.com/tailwindlabs/tailwindcss/releases/download/${tag}/tailwindcss-windows-x64.exe",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            deps = {
                runtime = { "xim:glibc@>=2.39", "xim:gcc-runtime@15.1.0" },
            },
            source = "https://github.com/tailwindlabs/tailwindcss/releases/download/v${version}/tailwindcss-${arch_alias}",
            ["latest"] = { ref = "4.3.5" },
            ["4.3.5"] = {
                arch_alias = { x86_64 = "linux-x64", aarch64 = "linux-arm64" },
                sha256 = {
                    x86_64 = "e47695cee3f0d90623a91f3939b08bdee610eb5ad99340adff9d4145b284d6cc",
                    aarch64 = "ffcd0d21dbd7c605dc12743ff0c0b47debc963c86b399674084c1c8f2c96ecad",
                },
            },
        },
        macosx = {
            source = "https://github.com/tailwindlabs/tailwindcss/releases/download/v${version}/tailwindcss-${arch_alias}",
            ["latest"] = { ref = "4.3.5" },
            ["4.3.5"] = {
                arch_alias = { x86_64 = "macos-x64", aarch64 = "macos-arm64" },
                sha256 = {
                    x86_64 = "a63702686a3ed048b3135d84a73be49ea9d47f880c9b20e54b3ef60934ad8cdf",
                    aarch64 = "f3f4f5d1727e2b693b8f1c9a1492b5dd87008c86ea286bee1589cb458e6235fc",
                },
            },
        },
        windows = {
            source = "https://github.com/tailwindlabs/tailwindcss/releases/download/v${version}/tailwindcss-${arch_alias}",
            ["latest"] = { ref = "4.3.5" },
            ["4.3.5"] = {
                arch_alias = { x86_64 = "windows-x64.exe" },
                sha256 = {
                    x86_64 = "2803583268c53f4713e89943e211081fddb186c0a4a7d07b5c342c6ae853ec95",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

function installed()
    local dir = pkginfo.install_dir()
    return os.isfile(dir .. "/tailwindcss") or os.isfile(dir .. "/tailwindcss.exe")
end

function install()
    local source = tostring(pkginfo.install_file() or "")
    if source == "" or not os.isfile(source) then
        error("tailwindcss: downloaded standalone executable is missing: " .. source)
    end
    local dir = pkginfo.install_dir()
    local windows = source:lower():match("%.exe$") ~= nil
    local target = dir .. (windows and "/tailwindcss.exe" or "/tailwindcss")
    fs.mkdir_p(dir)
    -- Copy the raw file without unpacking or consuming the verified cache.
    os.cp(source, target)
    if not windows then
        system.exec(string.format([[chmod +x "%s"]], target))
    end
    if not os.isfile(target) then
        error("tailwindcss: executable missing after install: " .. target)
    end
    return true
end

function config()
    xvm.add("tailwindcss", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("tailwindcss")
    return true
end
