-- nfpm writes deb, rpm, apk, Arch Linux, and IPK packages from one YAML
-- description of the files to install. It is one static Go program with no
-- dependency on dpkg-deb, rpmbuild, or any other host packaging tool, so a
-- build plugin can produce Linux packages from any host it runs on, which is
-- what the mcpp-plugins deb and rpm members invoke it for.
--
-- Verified 2026-11-18 against the GitHub Releases API: v2.49.0 is the latest
-- release (published 2026-11-12), every hash below is the one upstream's
-- checksums.txt lists for the asset, and the Linux x86_64 asset was downloaded
-- and checked against it. The archives hold `nfpm` at their root beside
-- LICENSE.md, README.md, completions/ and manpages/, so the install directory
-- is the archive's entries and needs no install() hook.
--
-- Measured on Linux x86_64: with SOURCE_DATE_EPOCH fixed, two runs over the
-- same staged tree produce byte-identical deb and rpm files, and `dpkg-deb
-- --contents` and `rpm -qlp` list the same paths.
package = {
    spec = "3",

    homepage = "https://nfpm.goreleaser.com",
    name = "nfpm",
    description = "Simple deb, rpm, apk, Arch Linux, and IPK packager written in Go",

    maintainers = {"https://github.com/goreleaser/nfpm/graphs/contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/goreleaser/nfpm",
    docs = "https://nfpm.goreleaser.com/docs/",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"packaging", "tools"},
    keywords = {"deb", "rpm", "apk", "packaging", "linux", "goreleaser"},

    programs = {"nfpm"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/goreleaser/nfpm/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/goreleaser/nfpm/releases/download/v${version}/nfpm_${version}_Linux_x86_64.tar.gz",
                            aarch64 = "https://github.com/goreleaser/nfpm/releases/download/v${version}/nfpm_${version}_Linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/goreleaser/nfpm/releases/download/v${version}/nfpm_${version}_Darwin_x86_64.tar.gz",
                            aarch64 = "https://github.com/goreleaser/nfpm/releases/download/v${version}/nfpm_${version}_Darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/goreleaser/nfpm/releases/download/v${version}/nfpm_${version}_Windows_x86_64.zip",
                            aarch64 = "https://github.com/goreleaser/nfpm/releases/download/v${version}/nfpm_${version}_Windows_arm64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        -- Upstream spells the operating system and the aarch64 architecture its
        -- own way (Linux, Darwin, Windows; arm64), and the Windows asset is a zip,
        -- so each architecture names its asset.
        linux = {
            ["latest"] = { ref = "2.49.0" },
            ["2.49.0"] = {
                x86_64 = {
                    url = "https://github.com/goreleaser/nfpm/releases/download/v2.49.0/nfpm_2.49.0_Linux_x86_64.tar.gz",
                    sha256 = "2afaa5ffb5e3493402e31e7c67a5a1fb42133e3f66fc315ca0051934125561c7",
                },
                aarch64 = {
                    url = "https://github.com/goreleaser/nfpm/releases/download/v2.49.0/nfpm_2.49.0_Linux_arm64.tar.gz",
                    sha256 = "d4eee71839e92c68cbd3b101640bad32d2856fc551acae0635be9118e48c9d9c",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "2.49.0" },
            ["2.49.0"] = {
                x86_64 = {
                    url = "https://github.com/goreleaser/nfpm/releases/download/v2.49.0/nfpm_2.49.0_Darwin_x86_64.tar.gz",
                    sha256 = "182ba6c5ded85c87bf276dd80c0ecfd8a2f8b25f7db6ac5fb999557c5b4258ce",
                },
                aarch64 = {
                    url = "https://github.com/goreleaser/nfpm/releases/download/v2.49.0/nfpm_2.49.0_Darwin_arm64.tar.gz",
                    sha256 = "27728af45782962ab59a8ff13ae041c7d955fe51dd94ab7883d9c5966a233f5d",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "2.49.0" },
            ["2.49.0"] = {
                x86_64 = {
                    url = "https://github.com/goreleaser/nfpm/releases/download/v2.49.0/nfpm_2.49.0_Windows_x86_64.zip",
                    sha256 = "e410472f50b580c05087acc9a8e62bbe617a9e17226aff274f207c3b1bd31c5f",
                },
                aarch64 = {
                    url = "https://github.com/goreleaser/nfpm/releases/download/v2.49.0/nfpm_2.49.0_Windows_arm64.zip",
                    sha256 = "f4966da7364ed5ca4c0e5ba445e80c0443e1e2d3cfd787ecc77ef8adca13a78e",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function config()
    xvm.add("nfpm", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("nfpm")
    return true
end
