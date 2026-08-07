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

    -- `rustup` is deliberately NOT listed. This package does register a
    -- `rustup` shim (below, against ~/.cargo/bin), but it does not own the
    -- name: the `rustup` package registers it too. `programs` asserts
    -- exclusive ownership -- it is what the index's uninstall check uses to
    -- decide which surviving shims are a leak -- and a shim kept alive by a
    -- second, still-installed owner is not a leak.
    programs = { "rustc", "cargo" },

    xpm = {
        windows = {
            deps = {"xim:rustup", "config:rustup-mirror"},
            ["latest"] = { }
        },
        linux = {
            deps = {"xim:rustup", "config:rustup-mirror"},
            ["latest"] = { }
        },
        macosx = {
            deps = {"xim:rustup", "config:rustup-mirror"},
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
    -- `group` is the only kind that both avoids a bogus shim under the
    -- package name and lets `xlings remove` find the package; removal of a
    -- group root needs xlings >= 2026.7.x, which is why CI pins a current
    -- client (older ones refuse the remove and leak the shims).
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
--
-- The choice has to be expressible WITHOUT a prompt, because `io.read()` in an
-- install hook does not degrade -- it blocks forever. On a CI runner stdin
-- stays open and never delivers a line, so the install hangs rather than
-- failing: observed at 4 hours on a windows-test job, parked on
--
--     please input (1 or 2):
--
-- with no way to tell "slow" from "stuck" from the outside. Any unattended
-- install (a Dockerfile, a provisioning script, `xlings install rust -y`) has
-- the same shape.
--
-- It went unnoticed because this line was unreachable in CI: rust declared a
-- dep on `rustup-mirror` that resolved to nothing, so the install aborted at
-- dependency resolution before ever getting here. Fixing that namespace is
-- what let the hook run for the first time.
--
-- So: honour XLINGS_RUST_ABI when set, take the default when nobody can answer,
-- and only prompt when there is a human present.
function _choice_toolchain()
    local toolchain_abi = "x86_64-pc-windows-gnu"

    local want = os.getenv("XLINGS_RUST_ABI")
    if want == "msvc" or want == "x86_64-pc-windows-msvc" then
        log.info("XLINGS_RUST_ABI=%s -- using the msvc toolchain", want)
        pkgmanager.install("msvc@onlycompiler")
        return "x86_64-pc-windows-msvc"
    elseif want == "gnu" or want == "x86_64-pc-windows-gnu" then
        log.info("XLINGS_RUST_ABI=%s -- using the gnu toolchain", want)
        return toolchain_abi
    elseif want then
        log.warn("XLINGS_RUST_ABI='%s' is not 'gnu' or 'msvc'; ignoring it", want)
    end

    if os.getenv("XLINGS_NON_INTERACTIVE") or os.getenv("CI") then
        log.warn("no terminal to ask on; defaulting to %s. "
                 .. "Set XLINGS_RUST_ABI=msvc to choose the other one.",
                 toolchain_abi)
        return toolchain_abi
    end

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