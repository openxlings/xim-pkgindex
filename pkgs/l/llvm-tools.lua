package = {
    spec = "1",
    homepage = "https://clang.llvm.org/extra/",

    name = "llvm-tools",
    description = "LLVM development tools (clang-format, clang-tidy, clangd)",
    maintainers = {"LLVM Project"},
    licenses = {"Apache-2.0 WITH LLVM-exception"},
    repo = "https://github.com/llvm/llvm-project",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"toolchain", "llvm", "formatter", "linter"},
    keywords = {"clang-format", "clang-tidy", "clangd", "llvm", "lsp"},

    xvm_enable = true,

    xpm = {
        linux = {
            ["latest"] = { ref = "20.1.7" },
            ["20.1.7"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/llvm/releases/download/20.1.7/llvm-tools-20.1.7-linux-x86_64.tar.gz",
                    CN = "https://gitcode.com/xlings-res/llvm/releases/download/20.1.7/llvm-tools-20.1.7-linux-x86_64.tar.gz",
                },
                sha256 = nil,
            },
        },
        windows = {
            ["latest"] = { ref = "20.1.7" },
            ["20.1.7"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/llvm/releases/download/20.1.7/llvm-tools-20.1.7-windows-x86_64.zip",
                    CN = "https://gitcode.com/xlings-res/llvm/releases/download/20.1.7/llvm-tools-20.1.7-windows-x86_64.zip",
                },
                sha256 = nil,
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

local tools = { "clang-format", "clang-tidy", "clangd" }

function install()
    local srcdir = pkginfo.install_file()
        :replace(".tar.xz", "")
        :replace(".tar.gz", "")
        :replace(".zip", "")
    os.tryrm(pkginfo.install_dir())
    os.mv(srcdir, pkginfo.install_dir())
    return true
end

function config()
    local bindir = path.join(pkginfo.install_dir(), "bin")
    local binding = package.name .. "@" .. pkginfo.version()

    xvm.add(package.name)

    for _, tool in ipairs(tools) do
        local filename = tool
        if os.host() == "windows" then
            filename = tool .. ".exe"
        end
        if os.isfile(path.join(bindir, filename)) then
            xvm.add(tool, {
                bindir = bindir,
                binding = binding,
            })
        end
    end

    return true
end

function uninstall()
    xvm.remove(package.name)

    for _, tool in ipairs(tools) do
        xvm.remove(tool)
    end

    return true
end
