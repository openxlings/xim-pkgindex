package = {
    spec = "1",

    name = "go",
    description = "The Go programming language",
    homepage = "https://go.dev",

    authors = {"Google"},
    contributors = "https://github.com/golang/go/graphs/contributors",
    licenses = {"BSD-3-Clause"},
    repo = "https://github.com/golang/go",
    ci = { mirror = true, update = true },
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
    xpm = {
        linux = {
            url_template = "https://go.dev/dl/go{version}.linux-amd64.tar.gz",
            ["latest"] = { ref = "1.26.2" },
            ["1.26.2"] = {
                url = "https://go.dev/dl/go1.26.2.linux-amd64.tar.gz",
                sha256 = "990e6b4bbba816dc3ee129eaeaf4b42f17c2800b88a2166c265ac1a200262282",
            },
        },
        macosx = {
            url_template = "https://go.dev/dl/go{version}.darwin-arm64.tar.gz",
            ["latest"] = { ref = "1.26.2" },
            ["1.26.2"] = {
                url = "https://go.dev/dl/go1.26.2.darwin-arm64.tar.gz",
                sha256 = "32af1522bf3e3ff3975864780a429cc0b41d190ec7bf90faa661d6d64566e7af",
            },
        },
        windows = {
            url_template = "https://go.dev/dl/go{version}.windows-amd64.zip",
            ["latest"] = { ref = "1.26.2" },
            ["1.26.2"] = {
                url = "https://go.dev/dl/go1.26.2.windows-amd64.zip",
                sha256 = "98eb3570bade15cb826b0909338df6cc6d2cf590bc39c471142002db3832b708",
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
