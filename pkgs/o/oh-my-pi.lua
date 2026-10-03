package = {
    spec = "2",

    name = "oh-my-pi",
    description = "Coding agent with the IDE wired in",
    homepage = "https://omp.sh",
    repo = "https://github.com/can1357/oh-my-pi",
    docs = "https://github.com/can1357/oh-my-pi#readme",
    licenses = {"MIT"},
    -- Add each new upstream stable release by reviewed PR; keep older pins.

    -- The glibc release executable uses the host loader and libc (GLIBC_2.17);
    -- it has no bundled shared libraries or xim-provided runtime closure.
    -- Do not add xim:glibc: that would make elfpatch rewrite this Bun binary.
    -- The xvm-launched OMP disables startup update checks; an explicit
    -- `omp update` is still user-controlled and is not intercepted here.

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"ai", "cli", "tools"},
    keywords = {"oh-my-pi", "omp", "coding-agent"},

    programs = {"omp"},
    xvm_enable = true,

    xpm = {
        linux = {
            source = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/omp-linux-${arch_alias}",
            ["latest"] = { ref = "18.5.0" },
            ["18.4.10"] = {
                arch_alias = { x86_64 = "x64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "e3f24c475d90b83acec05a26fd4499d2e6dffbf4ca3b0ee9e3e1bc1ab1a4e289",
                    aarch64 = "8f6b0b6547b149b7f538d44848e80502f5895663ca9cef6b14c7337be2f4f617",
                },
            },
            ["18.4.12"] = {
                arch_alias = { x86_64 = "x64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "8178466631d09c2165c19c14c92ee7f4e3e68c5f41953e8815adfb1214a64999",
                    aarch64 = "7e9c91e9f34765abfd775b8f87c00bb82d5c14025d58770fe4213791452f3182",
                },
            },
            ["18.5.0"] = {
                arch_alias = { x86_64 = "x64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "b8413e6e085a423c7a9b1d7bc025c2af794923b6b6c57330a309639b6176c8a1",
                    aarch64 = "1244860c58bb68a3a45390d4932e5c7983183ec8c12cb6848c1afd709de38a07",
                },
            },
        },
        macosx = {
            source = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/omp-darwin-${arch_alias}",
            ["latest"] = { ref = "18.5.0" },
            ["18.4.10"] = {
                arch_alias = { x86_64 = "x64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "88cb5bc7fc8a32a16276be3af3a7e9e9f195a4c994db75f15ee0bc24dd30928d",
                    aarch64 = "23d3f9ab712fe700e80a43dbd1e8159dfea8e106bf717648a49b1bba1ad3e508",
                },
            },
            ["18.4.12"] = {
                arch_alias = { x86_64 = "x64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "d3305b641d3e62c30f8cd5a44343d219cdc45c3ad9a6c13729df61749ff40ac6",
                    aarch64 = "1a81bd323ba6d67374adf5645fe52e194671416e15c69ef17ac18e32b42c55ff",
                },
            },
            ["18.5.0"] = {
                arch_alias = { x86_64 = "x64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "be01b2213d7633b716bf18250c7ef756ee29111dfd76ccabc42e7e3b35d35b4b",
                    aarch64 = "5608ba1705ae8081f4bced9b54b583752d05926ff9c63779aa866a4c13d43aad",
                },
            },
        },
        windows = {
            source = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/omp-windows-${arch_alias}.exe",
            ["latest"] = { ref = "18.5.0" },
            ["18.4.10"] = {
                arch_alias = { x86_64 = "x64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "7232c209641f0cad7e20bdb3a074cdb2fb31ae2aa73d42c491c705d28e0d3895",
                    aarch64 = "21eba9799ba0310b94cc1937c092f3ad376c6608a9f5a30340b10ec8e7ecd817",
                },
            },
            ["18.4.12"] = {
                arch_alias = { x86_64 = "x64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "41f749a49d99fbc7daa8dfd571c20b396f4cfd4b2cd16735624bc416137f67ab",
                    aarch64 = "b61df7f7849ce83c73c2a18916b8cb43ee9a236d62cddc61d884d8ee0a4659ec",
                },
            },
            ["18.5.0"] = {
                arch_alias = { x86_64 = "x64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "9a359d96277514db5e1f66bd88e4f7321d7c41fce123023629325a7bdc53b7ca",
                    aarch64 = "5fb9c866344c3446e9fc456ef2254c15f459b9dff2354506baae9e8845494f37",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.system")

function install()
    os.tryrm(pkginfo.install_dir())
    os.mkdir(pkginfo.install_dir())

    local source = pkginfo.install_file()
    local target = path.join(pkginfo.install_dir(), is_host("windows") and "omp.exe" or "omp")
    os.mv(source, target)

    local config = path.join(pkginfo.install_dir(), "xlings-config.yml")
    io.writefile(config, "startup:\n  checkUpdate: false\n")

    if not is_host("windows") then
        system.exec(string.format([[chmod +x "%s"]], target))
    end

    return os.isfile(target) and io.readfile(config) == "startup:\n  checkUpdate: false\n"
end

function config()
    local alias = is_host("windows") and "omp.exe" or "omp"
    xvm.add(package.name, { type = "group" })
    xvm.add("omp", {
        bindir = pkginfo.install_dir(), alias = alias,
        envs = { PI_CONFIG_FILES = path.join(pkginfo.install_dir(), "xlings-config.yml") },
    })
    return true
end

function uninstall()
    xvm.remove("omp")
    xvm.remove(package.name)
    return true
end
