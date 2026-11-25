package = {
    spec = "2",

    name = "hex",
    description = "Hex — local voice dictation for mac, windows and linux: hold a key, speak, and it pastes the text at your cursor",

    homepage = "https://anoma.ly/hex",
    authors = {"anomalyco"},
    licenses = {"MIT"},
    repo = "https://github.com/anomalyco/hex",
    docs = "https://github.com/anomalyco/hex/blob/main/docs/README.md",

    -- xim pkg info
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"tools", "voice", "dictation"},
    keywords = {"hex", "dictation", "voice", "speech", "asr", "transcription"},

    programs = {"hex"},
    xvm_enable = true,

    -- Upstream ships one asset per platform/arch on GitHub Releases and the
    -- tag carries a `v` prefix while asset names do not. Measured matrix of
    -- v3.4.0: linux x86_64+aarch64 (raw ELF), windows x86_64+aarch64 (raw
    -- GUI-subsystem exe), macos aarch64 only (Hex.app zip; upstream
    -- publishes no x86_64 macOS build). Each asset also exists as a .deb/
    -- .rpm/setup-exe/dmg; this recipe takes the raw forms.
    --
    -- The release also carries a small `hex-<version>-windows-<arch>.com`
    -- console stub beside the exe; it is an interactive-terminal nicety
    -- upstream uses so `hex` can wait on the GUI binary. xvm's shim always
    -- captures output, and the GUI exe prints `hex --version` fine through a
    -- pipe (upstream's own installer probes it that way), so the stub is not
    -- packaged.
    extensions = {
        autoupdate = {
            source = "https://github.com/anomalyco/hex/releases",
            resources = {
                GLOBAL = { url = {
                    linux = {
                        aarch64 = "https://github.com/anomalyco/hex/releases/download/v${version}/hex-${version}-linux-arm64",
                        x86_64 = "https://github.com/anomalyco/hex/releases/download/v${version}/hex-${version}-linux-x64",
                    },
                    macosx = {
                        aarch64 = "https://github.com/anomalyco/hex/releases/download/v${version}/hex-${version}-macos-arm64.zip",
                    },
                    windows = {
                        aarch64 = "https://github.com/anomalyco/hex/releases/download/v${version}/hex-${version}-windows-arm64.exe",
                        x86_64 = "https://github.com/anomalyco/hex/releases/download/v${version}/hex-${version}-windows-x64.exe",
                    },
                } },
            },
        },
    },

    -- sha256 measured from the release assets themselves (upstream publishes
    -- no checksums file; hashes are pinned per arch, fail-closed).
    xpm = {
        linux = {
            ["latest"] = { ref = "3.4.0" },
            ["3.4.0"] = {
                aarch64 = {
                    url = "https://github.com/anomalyco/hex/releases/download/v3.4.0/hex-3.4.0-linux-arm64",
                    sha256 = "bd549e896874c417b841cd8e1e724bbaca59046978e0ad2b7e72921de4101e0c",
                },
                x86_64 = {
                    url = "https://github.com/anomalyco/hex/releases/download/v3.4.0/hex-3.4.0-linux-x64",
                    sha256 = "7f8132a2202338c1b52c36113d23d7403cf91f220bcdbd9eec82bc726f5f8029",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "3.4.0" },
            ["3.4.0"] = {
                aarch64 = {
                    url = "https://github.com/anomalyco/hex/releases/download/v3.4.0/hex-3.4.0-macos-arm64.zip",
                    sha256 = "1ab0242dc3bb011c88568903cbf1e9d30310867a46f5168309853d6f8b4ca650",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "3.4.0" },
            ["3.4.0"] = {
                aarch64 = {
                    url = "https://github.com/anomalyco/hex/releases/download/v3.4.0/hex-3.4.0-windows-arm64.exe",
                    sha256 = "9f31a38ced09e23d87d5a2e4977db3024de988275593f750f26ba6d8882b7a24",
                },
                x86_64 = {
                    url = "https://github.com/anomalyco/hex/releases/download/v3.4.0/hex-3.4.0-windows-x64.exe",
                    sha256 = "90bf9543dee8c3c799de95cbb4ccd1c05bcb29863c7212c1bd641979e287af9e",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

-- The single file only this payload provides; `installed()` means "usable",
-- so it checks the executable itself, not the install directory.
function payload_file()
    local dir = pkginfo.install_dir()
    if os.host() == "macosx" then
        return path.join(dir, "Hex.app/Contents/MacOS/hex")
    elseif os.host() == "windows" then
        return path.join(dir, "hex.exe")
    end
    return path.join(dir, "hex")
end

function installed()
    return os.isfile(payload_file())
end

function install()
    local install_dir = pkginfo.install_dir()
    os.tryrm(install_dir)
    fs.mkdir_p(install_dir)

    if os.host() == "macosx" then
        -- The zip's only top-level entry is Hex.app; xlings has already
        -- extracted it next to the download, so move the whole bundle in.
        -- The zip stores the Unix exec bits and `unzip` restores them
        -- (measured on v3.4.0: hex and scrawl-helper are 755).
        os.mv("Hex.app", install_dir)
    else
        -- Raw standalone executable (no archive wrapper); move it into our
        -- install dir under the canonical name.
        local bin_name = "hex"
        if os.host() == "windows" then
            bin_name = "hex.exe"
        end
        os.mv(pkginfo.install_file(), path.join(install_dir, bin_name))
        if os.host() ~= "windows" then
            os.exec("chmod +x \"" .. path.join(install_dir, bin_name) .. "\"")
        end
    end
    return os.isfile(payload_file())
end

function config()
    local bindir = pkginfo.install_dir()
    if os.host() == "macosx" then
        -- Upstream's documented CLI entry is inside the app bundle.
        bindir = path.join(bindir, "Hex.app/Contents/MacOS")
    end
    xvm.add("hex", { bindir = bindir })
    return true
end

function uninstall()
    xvm.remove("hex")
    return true
end
