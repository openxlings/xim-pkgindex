package = {
    spec = "3",
    name = "helix",
    description = "A post-modern modal text editor",
    homepage = "https://helix-editor.com",
    licenses = {"MPL-2.0"},
    repo = "https://github.com/helix-editor/helix",
    docs = "https://docs.helix-editor.com",
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"editor"},
    keywords = {"helix", "hx", "editor", "terminal"},
    programs = {"hx"},
    xvm_enable = true,

    -- Verified upstream release assets; no CN mirror has been verified.
    extensions = {
        autoupdate = {
            source = "https://github.com/helix-editor/helix/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/helix-editor/helix/releases/download/${version}/helix-${version}-x86_64-linux.tar.xz",
                            aarch64 = "https://github.com/helix-editor/helix/releases/download/${version}/helix-${version}-aarch64-linux.tar.xz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/helix-editor/helix/releases/download/${version}/helix-${version}-x86_64-macos.tar.xz",
                            aarch64 = "https://github.com/helix-editor/helix/releases/download/${version}/helix-${version}-aarch64-macos.tar.xz",
                        },
                        windows = {
                            x86_64 = "https://github.com/helix-editor/helix/releases/download/${version}/helix-${version}-x86_64-windows.zip",
                        },
                    },
                },
            },
        },
    },
    xpm = {
        linux = {
            strip = 1,
            source = "https://github.com/helix-editor/helix/releases/download/${version}/helix-${version}-${arch}-linux.tar.xz",
            -- Measured ELF closure: libc, libm and libgcc_s; no bundled loader.
            deps = { runtime = { "xim:glibc@>=2.34", "xim:gcc-runtime@15.1.0" } },
            ["latest"] = { ref = "25.07.1" },
            ["25.07.1"] = {
                sha256 = {
                    x86_64 = "3f08e63ecd388fff657ad39722f88bb03dcf326f1f2da2700d99e1dc40ab2e8b",
                    aarch64 = "ce23fa8d395e633e3e54c052012f11965d91d8d5c2bfa659685f50430b4f8175",
                },
            },
        },
        macosx = {
            strip = 1,
            source = "https://github.com/helix-editor/helix/releases/download/${version}/helix-${version}-${arch}-macos.tar.xz",
            ["latest"] = { ref = "25.07.1" },
            ["25.07.1"] = {
                sha256 = {
                    x86_64 = "84dc32d617d28d32f4aa21e3aafac47bd715d1154aeb977697d4d60b887b7103",
                    aarch64 = "00b1651b4fdbbe0a2ae981c8e76b858bd26a7c33f5b3583f3b6bb9137d54f1ff",
                },
            },
        },
        windows = {
            strip = 1,
            source = "https://github.com/helix-editor/helix/releases/download/${version}/helix-${version}-${arch}-windows.zip",
            ["latest"] = { ref = "25.07.1" },
            ["25.07.1"] = {
                sha256 = {
                    x86_64 = "5c8325ced8bacd8418d62706f669e96d9c3578a9237526e34d546900cbc049b6",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.fs")

-- Preserve runtime/ beside hx: Helix discovers themes, queries and grammars
-- relative to its executable, without setting a global HELIX_RUNTIME.
function install()
    local root = pkginfo.install_dir()
    return (fs.is_file(root .. "/hx") or fs.is_file(root .. "/hx.exe"))
        and fs.is_file(root .. "/runtime/queries/rust/highlights.scm")
        and fs.is_file(root .. "/runtime/themes/base16_default_dark.toml")
end

function config()
    xvm.add("helix", { type = "group" })
    xvm.add("hx", { bindir = pkginfo.install_dir(), binding = "helix@" .. pkginfo.version() })
    return true
end

function uninstall()
    xvm.remove("hx")
    xvm.remove("helix")
    return true
end
