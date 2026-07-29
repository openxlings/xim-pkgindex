package = {
    spec = "1",
    -- base info
    homepage = "https://www.rust-lang.org",

    name = "rust",
    description = "A language empowering everyone to build reliable and efficient software",

    authors = {"rust team"},
    maintainers = {"https://prev.rust-lang.org/en-US/team.html"},
    licenses = {"MIT", "Apache-2.0"},
    repo = "https://github.com/rust-lang/rust",
    docs = "https://prev.rust-lang.org/en-US/documentation.html",

    -- xim pkg info
    type = "package",
    status = "stable", -- dev, stable, deprecated
    categories = {"plang", "compiler"},
    keywords = {"Reliability", "Performance", "Productivity"},

    programs = { "rustc", "cargo", "rustup" },

    xpm = {
        windows = {
            deps = {"rustup", "rustup-mirror"},
            ["latest"] = { }
        },
        linux = {
            deps = {"rustup", "rustup-mirror"},
            ["latest"] = { }
        },
        macosx = {
            deps = {"rustup", "rustup-mirror"},
            ["latest"] = { }
        },
    },
}

import("xim.libxpkg.pkgmanager")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

function installed()
    os.exec("rustc --version")
    os.exec("cargo --version")
    os.exec("rustup --version")
    return true
end

function install()
    if os.host() == "windows" then
        local toolchain_abi = _choice_toolchain()
        os.exec(
            "rustup-init"
            .. " --default-host " .. toolchain_abi
            .. " --default-toolchain stable"
            .. " --profile default -y"
        )
    else
        os.exec("rustup-init -v -y")
    end
    return true
end

function config()
    local home = os.host() == "windows" and os.getenv("USERPROFILE") or os.getenv("HOME")
    local cargo_bin = path.join(home, ".cargo", "bin")

    xvm.add("rustc", { bindir = cargo_bin })
    xvm.add("cargo", { bindir = cargo_bin, binding = "rustc@" .. "latest" })
    xvm.add("rustup", { bindir = cargo_bin, binding = "rustc@" .. "latest" })
    xvm.add("rustfmt", { bindir = cargo_bin, binding = "rustc@" .. "latest" })
    xvm.add("clippy-driver", { bindir = cargo_bin, binding = "rustc@" .. "latest" })
    xvm.add("rust-analyzer", { bindir = cargo_bin, binding = "rustc@" .. "latest" })
    -- Group placeholder: `rust` is an umbrella package whose `programs` are
    -- rustc/cargo/rustup. Empty placeholder under the package name so
    -- install detection (`xvm info rust`) finds an entry; type
    -- distinguishes it from concrete program / lib registrations.
    xvm.add("rust", { type = "group" })

    return true
end

function uninstall()
    os.exec("rustup self uninstall")
    xvm.remove("rustc")
    xvm.remove("cargo")
    xvm.remove("rustup")
    xvm.remove("rustfmt")
    xvm.remove("clippy-driver")
    xvm.remove("rust-analyzer")
    xvm.remove("rust")
end

---------------------- private

-- host toolchain abi -- only for windows
function _choice_toolchain()
    local toolchain_abi = "x86_64-pc-windows-gnu"
    log.debug("[xlings:xim]: Select toolchain ABI:")
    log.debug([[

        1. x86_64-pc-windows-gnu (default)
        2. x86_64-pc-windows-msvc
    ]])
    cprint("${dim bright cyan}please input (1 or 2):${clear}")
    io.stdout:flush()
    local confirm = io.read()

    if confirm == "2" then
        toolchain_abi = "x86_64-pc-windows-msvc"
        -- TODO: install msvc toolchain
        pkgmanager.install("msvc@onlycompiler")
    end

    return toolchain_abi
end