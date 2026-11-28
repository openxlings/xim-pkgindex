-- Official Go binaries: Linux has no dynamic section; Windows imports only
-- kernel32.dll. macOS uses system libSystem/libresolv. No extra runtime is needed.
package = {
    spec = "2",
    name = "witr",
    description = "Explain why a process is running by tracing its ancestry",
    type = "package",
    licenses = {"Apache-2.0"},
    repo = "https://github.com/pranshuparmar/witr",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    programs = {"witr"},
    xvm_enable = true,
    ci = { mirror = true },

    xpm = {
        linux = {
            source = "https://github.com/pranshuparmar/witr/releases/download/v${version}/witr-linux-${arch_alias}",
            ["latest"] = { ref = "0.3.4" },
            ["0.3.4"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "d99098c61002f9b8a5337977d527dbe8ee29453f2a62c531038ea2749ea738eb",
                    aarch64 = "ecd737fcca418026514ed45a6ad06ecc2e02997e1b75ed6e7100ac8cc69eee54",
                },
            },
        },
        macosx = {
            source = "https://github.com/pranshuparmar/witr/releases/download/v${version}/witr-darwin-${arch_alias}",
            ["latest"] = { ref = "0.3.4" },
            ["0.3.4"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "e8dae6b77e71826805fb1e27a22ca2ec90d85cb50809044dab3a3232269b5f74",
                    aarch64 = "731b7ed07b07e4c413bfcfae7e4865b5020f7f2379c7f1cdea09c235c5280515",
                },
            },
        },
        windows = {
            source = "https://github.com/pranshuparmar/witr/releases/download/v${version}/witr-windows-${arch_alias}.zip",
            ["latest"] = { ref = "0.3.4" },
            ["0.3.4"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "34ef930e6f53c026e952f5952442281640bae551e59477137a045f9a2141188f",
                    aarch64 = "c1db651220bc8a86433fba7e680c87f9db868a41c0fb144427f37750ec62a7ce",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")
import("xim.pkgindex.shell")

local function binary_name()
    return tostring(pkginfo.install_file()):match("%.zip$") and "witr.exe" or "witr"
end

function installed()
    return payload.present{binary_name()}
end

function install()
    local binary = binary_name()
    local dir = pkginfo.install_dir()
    if binary == "witr.exe" then
        -- Re-extract this flat ZIP into its own directory, never move the shared
        -- runtime directory or its pre-extracted files from other packages.
        payload.unpack()
    else
        os.tryrm(dir)
        fs.mkdir_p(dir)
        os.mv(pkginfo.install_file(), dir .. "/" .. binary)
        shell.exec({"chmod", "+x", dir .. "/" .. binary})
    end
    payload.require{binary}
    return true
end

function config()
    xvm.add("witr", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("witr")
    return true
end
