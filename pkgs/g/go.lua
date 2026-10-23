package = {
    spec = "1",

    name = "go",
    description = "The Go programming language",
    homepage = "https://go.dev",

    authors = {"Google"},
    contributors = "https://github.com/golang/go/graphs/contributors",
    licenses = {"BSD-3-Clause"},
    repo = "https://github.com/golang/go",
    ci = { mirror = true },
    docs = "https://go.dev/doc",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"language", "compiler", "tools"},
    keywords = {"go", "golang", "language", "compiler"},

    -- Go ships gofmt, go test, go run, etc. via the same `go` driver,
    -- but `gofmt` is also exposed as a standalone binary in bin/.
    programs = { "go", "gofmt" },

    xvm_enable = true,

    -- Why direct download from go.dev rather than a tarball mirror:
    --   * Linux x86_64 binary is `statically linked` with empty
    --     DT_NEEDED (verified locally with readelf) — runs hermetically
    --     on Alpine / distroless / any x86_64 host without a libc on
    --     disk, so no runtime deps declaration needed.
    --   * go.dev publishes per-version hashes via the dl JSON API,
    --     letting us pin sha256 deterministically.


    extensions = {
        autoupdate = {
            source = "https://github.com/golang/go/tags",
            tag = "go${version}",
            resources = {
                GLOBAL = {
                    url = {
                        linux = "https://go.dev/dl/go${version}.linux-amd64.tar.gz",
                        macosx = "https://go.dev/dl/go${version}.darwin-arm64.tar.gz",
                        windows = "https://go.dev/dl/go${version}.windows-amd64.zip",
                    },
                    required = true,
                },
                CN = {
                    url = {
                        linux = "https://mirrors.nju.edu.cn/golang/go${version}.linux-amd64.tar.gz",
                        macosx = "https://mirrors.nju.edu.cn/golang/go${version}.darwin-arm64.tar.gz",
                        windows = "https://mirrors.nju.edu.cn/golang/go${version}.windows-amd64.zip",
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {

            ["latest"] = { ref = "1.27.3" },
            ["1.27.0"] = {
                url = "https://go.dev/dl/go1.27.0.linux-amd64.tar.gz",
                sha256 = "675c26c449cbb18fc24b74650de1eabbae6e16f64326fd85a283fb3b58280685",
            },
            ["1.26.2"] = {
                url = "https://go.dev/dl/go1.26.2.linux-amd64.tar.gz",
                sha256 = "990e6b4bbba816dc3ee129eaeaf4b42f17c2800b88a2166c265ac1a200262282",
            },
            ["1.27.3"] = {
                url = {
                    GLOBAL = "https://go.dev/dl/go1.27.3.linux-amd64.tar.gz",
                    CN = "https://mirrors.nju.edu.cn/golang/go1.27.3.linux-amd64.tar.gz",
                },
                sha256 = "65efbc80fdc1fa2cd2631cad5b481777a68e8725f34e89f50fc6ac714e379b40",
            },
        },
        macosx = {

            ["latest"] = { ref = "1.27.3" },
            ["1.27.0"] = {
                url = "https://go.dev/dl/go1.27.0.darwin-arm64.tar.gz",
                sha256 = "90493b3bbd5e10f91d12153198bf1994fd756399b4fec93b49b0c6e2acdeeb3e",
            },
            ["1.26.2"] = {
                url = "https://go.dev/dl/go1.26.2.darwin-arm64.tar.gz",
                sha256 = "32af1522bf3e3ff3975864780a429cc0b41d190ec7bf90faa661d6d64566e7af",
            },
            ["1.27.3"] = {
                url = {
                    GLOBAL = "https://go.dev/dl/go1.27.3.darwin-arm64.tar.gz",
                    CN = "https://mirrors.nju.edu.cn/golang/go1.27.3.darwin-arm64.tar.gz",
                },
                sha256 = "dd3908cf20959d798c1e06ebe5b72213f0505ce01373b40ce3110975a6cd99c2",
            },
        },
        windows = {

            ["latest"] = { ref = "1.27.3" },
            ["1.27.0"] = {
                url = "https://go.dev/dl/go1.27.0.windows-amd64.zip",
                sha256 = "f0c0a0d33ba94f4d2c5dbc887334ce678b21813504ddb3aafcb06e60a5a667c4",
            },
            ["1.26.2"] = {
                url = "https://go.dev/dl/go1.26.2.windows-amd64.zip",
                sha256 = "98eb3570bade15cb826b0909338df6cc6d2cf590bc39c471142002db3832b708",
            },
            ["1.27.3"] = {
                url = {
                    GLOBAL = "https://go.dev/dl/go1.27.3.windows-amd64.zip",
                    CN = "https://mirrors.nju.edu.cn/golang/go1.27.3.windows-amd64.zip",
                },
                sha256 = "f26081f438319757f8a1b46d7d0b2c5ec7583d4038e485e0aa725cfde7885fff",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    -- Tarball / zip extracts to a `go/` directory containing bin/, src/,
    -- pkg/, lib/, etc. Move the whole tree into install_dir as-is.
    os.tryrm(pkginfo.install_dir())
    os.mv("go", pkginfo.install_dir())
    return true
end

function config()
    local bindir = path.join(pkginfo.install_dir(), "bin")
    xvm.add("go",    { bindir = bindir })
    xvm.add("gofmt", { bindir = bindir })
    return true
end

function uninstall()
    xvm.remove("go")
    xvm.remove("gofmt")
    return true
end
