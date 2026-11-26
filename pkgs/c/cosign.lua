-- cosign - container signing, verification, and storage in an OCI registry (sigstore/cosign).
--
-- Platform and architecture coverage (verified against sigstore/cosign v3.1.6):
--   linux    x86_64, aarch64   cosign-linux-{amd64,arm64}    (static Go ELF, no .dynamic section)
--   macosx   x86_64, aarch64   cosign-darwin-{amd64,arm64}   (Mach-O 64-bit executable)
--   windows  x86_64            cosign-windows-amd64.exe      (PE32+ console executable; no windows-arm64 asset upstream)
--
-- Every asset is a standalone single-file binary with a distinct filename (no archive
-- container and no materialize basename collision), verified against upstream
-- `cosign_checksums.txt` and hashed (SHA-256).
--
-- Linking:
--   linux/x86_64, linux/aarch64: static Go ELFs (`readelf -d`: no dynamic section;
--     `ldd`: not a dynamic executable). Zero runtime library deps required.
--   windows/x86_64: PE32+ importing only KERNEL32.dll and Windows 10 Universal CRT
--     API-set DLLs (`api-ms-win-crt-*.dll`); no VCRUNTIME140.dll or MSVCP140.dll.

package = {
    spec = "2",

    name = "cosign",
    description = "Code signing and transparency for containers and binaries",
    homepage = "https://docs.sigstore.dev/cosign/system_config/installation/",
    authors = {"Sigstore Authors"},
    maintainers = {"sigstore"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/sigstore/cosign",
    docs = "https://docs.sigstore.dev/cosign/signing/overview/",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"security", "signing", "containers", "cli", "tools"},
    keywords = {"cosign", "sigstore", "signing", "oci", "sbom", "supply-chain", "security"},

    programs = {"cosign"},
    xvm_enable = true,
    ci = { mirror = true },

    extensions = {
        autoupdate = {
            source = "https://github.com/sigstore/cosign/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/sigstore/cosign/releases/download/${tag}/cosign-linux-amd64",
                            aarch64 = "https://github.com/sigstore/cosign/releases/download/${tag}/cosign-linux-arm64",
                        },
                        macosx = {
                            x86_64 = "https://github.com/sigstore/cosign/releases/download/${tag}/cosign-darwin-amd64",
                            aarch64 = "https://github.com/sigstore/cosign/releases/download/${tag}/cosign-darwin-arm64",
                        },
                        windows = {
                            x86_64 = "https://github.com/sigstore/cosign/releases/download/${tag}/cosign-windows-amd64.exe",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/sigstore/cosign/releases/download/v${version}/cosign-linux-${arch_alias}",
            ["latest"] = { ref = "3.1.6" },
            ["3.1.6"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "318a99ade4156a0c4113aa983b46c0a0830fa7896a096c63121ee47b610a94c6",
                    aarch64 = "bbb2ebc765f483cf9fac42da8763dddc2b55b350ee12ea0c44a520a6d6d52334",
                },
            },
        },
        macosx = {
            source = "https://github.com/sigstore/cosign/releases/download/v${version}/cosign-darwin-${arch_alias}",
            ["latest"] = { ref = "3.1.6" },
            ["3.1.6"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "a91eebd5824c1d40a2f3fb730a65f470ec0acf99e5c63dc7b79c322eeb9b5549",
                    aarch64 = "0ce6045c42e9f21427b3a8b70d54b130ca35cdd88a38358cc303fc6fec7366ba",
                },
            },
        },
        windows = {
            -- Upstream publishes only windows-amd64.exe (no windows-arm64 asset).
            source = "https://github.com/sigstore/cosign/releases/download/v${version}/cosign-windows-${arch_alias}.exe",
            ["latest"] = { ref = "3.1.6" },
            ["3.1.6"] = {
                arch_alias = { x86_64 = "amd64" },
                sha256 = {
                    x86_64 = "0a5abb35f16b18266d6f3991cb69f8933c4449c1eafb475ae57bde554b273ddf",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

local function _is_windows_payload(file)
    return tostring(file):lower():match("%.exe$") ~= nil
end

function installed()
    local dir = pkginfo.install_dir()
    return os.isfile(dir .. "/cosign") or os.isfile(dir .. "/cosign.exe")
end

function install()
    local src = pkginfo.install_file()
    local dir = pkginfo.install_dir()
    local is_win = _is_windows_payload(src)
    local target = dir .. (is_win and "/cosign.exe" or "/cosign")

    if not os.isfile(src) then
        error("cosign: downloaded binary not found at " .. tostring(src))
    end

    os.tryrm(dir)
    fs.mkdir_p(dir)
    os.mv(src, target)
    if not is_win then
        system.exec(string.format([[chmod +x "%s"]], target))
    end
    if not os.isfile(target) then
        error("cosign: executable missing after install at " .. target)
    end
    return true
end

function config()
    xvm.add("cosign", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("cosign")
    return true
end
