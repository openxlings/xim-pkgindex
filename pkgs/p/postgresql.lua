-- postgresql - The World's Most Advanced Open Source Relational Database.
--
-- Platforms and sources (theseus-rs/postgresql-binaries, official Postgres source builds
-- with published SHA-256 sidecars, provenance, and SPDX SBOMs):
--   linux    x86_64, aarch64   *-unknown-linux-gnu tarballs + xim:glibc (elfpatch-relocated)
--   macosx   x86_64, aarch64   *-apple-darwin tarballs (self-contained @loader_path dylibs)
--   windows  x86_64            *-pc-windows-msvc archive + app-local xim:vcruntime DLLs
--
-- Windows ARM64 waits for `xim:vcruntime` ARM64 runtime DLL support.
package = {
    spec = "2",

    name = "postgresql",
    description = "PostgreSQL - object-relational database server and CLI toolkit (psql, postgres, initdb, pg_ctl, pg_dump)",
    homepage = "https://www.postgresql.org",
    authors = {"The PostgreSQL Global Development Group"},
    maintainers = {"https://github.com/theseus-rs/postgresql-binaries"},
    licenses = {"PostgreSQL"},
    repo = "https://github.com/postgres/postgres",
    docs = "https://www.postgresql.org/docs/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"database", "sql", "server", "tools"},
    keywords = {"postgresql", "postgres", "psql", "database", "sql", "rdbms"},

    programs = {
        "psql",
        "postgres",
        "initdb",
        "pg_ctl",
        "pg_dump",
        "pg_dumpall",
        "pg_restore",
        "pg_isready",
        "createdb",
        "dropdb",
        "createuser",
        "dropuser",
        "clusterdb",
        "reindexdb",
        "vacuumdb",
        "pg_basebackup",
        "pg_upgrade",
        "pg_rewind",
        "pg_verifybackup",
        "pg_combinebackup",
        "pg_checksums",
        "pg_controldata",
        "pgbench",
        "pg_config",
    },
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/theseus-rs/postgresql-binaries/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/theseus-rs/postgresql-binaries/releases/download/${version}/postgresql-${version}-x86_64-unknown-linux-gnu.tar.gz",
                            aarch64 = "https://github.com/theseus-rs/postgresql-binaries/releases/download/${version}/postgresql-${version}-aarch64-unknown-linux-gnu.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/theseus-rs/postgresql-binaries/releases/download/${version}/postgresql-${version}-x86_64-apple-darwin.tar.gz",
                            aarch64 = "https://github.com/theseus-rs/postgresql-binaries/releases/download/${version}/postgresql-${version}-aarch64-apple-darwin.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/theseus-rs/postgresql-binaries/releases/download/${version}/postgresql-${version}-x86_64-pc-windows-msvc.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            deps = { "xim:glibc" },
            ["latest"] = { ref = "19.0.0" },
            ["19"] = { ref = "19.0.0" },
            ["18"] = { ref = "18.7.0" },
            ["17"] = { ref = "17.12.0" },
            ["19.0.0"] = {
                x86_64 = {
                    url = "https://github.com/theseus-rs/postgresql-binaries/releases/download/19.0.0/postgresql-19.0.0-x86_64-unknown-linux-gnu.tar.gz",
                    sha256 = "ec7044fb9e2f1126383a869e463c8028d403d161c6a4a88501f43ca64112b623",
                },
                aarch64 = {
                    url = "https://github.com/theseus-rs/postgresql-binaries/releases/download/19.0.0/postgresql-19.0.0-aarch64-unknown-linux-gnu.tar.gz",
                    sha256 = "256ae47d0e9e0e6e22586643e10ed554b54d5679b6f401ef63d09a0fbc3368d2",
                },
            },
            ["18.7.0"] = {
                x86_64 = {
                    url = "https://github.com/theseus-rs/postgresql-binaries/releases/download/18.7.0/postgresql-18.7.0-x86_64-unknown-linux-gnu.tar.gz",
                    sha256 = "53ca01952cb581145e4fb16b6b3b675da345a82879f350707b9f65863a0642f4",
                },
                aarch64 = {
                    url = "https://github.com/theseus-rs/postgresql-binaries/releases/download/18.7.0/postgresql-18.7.0-aarch64-unknown-linux-gnu.tar.gz",
                    sha256 = "6fcf45163aa044fe58597885b0e27c4b1614c53ad088d4d0ebbbfdf5df510eaf",
                },
            },
            ["17.12.0"] = {
                x86_64 = {
                    url = "https://github.com/theseus-rs/postgresql-binaries/releases/download/17.12.0/postgresql-17.12.0-x86_64-unknown-linux-gnu.tar.gz",
                    sha256 = "af316b6e42266ec0a153bdc9194e0b1b5f12c9ce4f0b13d9a96dfca77d9aaecc",
                },
                aarch64 = {
                    url = "https://github.com/theseus-rs/postgresql-binaries/releases/download/17.12.0/postgresql-17.12.0-aarch64-unknown-linux-gnu.tar.gz",
                    sha256 = "9b3ca376cbdecb297711f9b09bfe834ae0f7c231042de58b7cb4bb2c0a526301",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "19.0.0" },
            ["19"] = { ref = "19.0.0" },
            ["18"] = { ref = "18.7.0" },
            ["17"] = { ref = "17.12.0" },
            ["19.0.0"] = {
                x86_64 = {
                    url = "https://github.com/theseus-rs/postgresql-binaries/releases/download/19.0.0/postgresql-19.0.0-x86_64-apple-darwin.tar.gz",
                    sha256 = "f255a9c1a3489b4125794c7d2221ff6d82466d5da24876a3a9655c5a596e2efd",
                },
                aarch64 = {
                    url = "https://github.com/theseus-rs/postgresql-binaries/releases/download/19.0.0/postgresql-19.0.0-aarch64-apple-darwin.tar.gz",
                    sha256 = "3165a453906bb345f54e189f65db828a76d60e7696191afd26fca6dc73ba51a4",
                },
            },
            ["18.7.0"] = {
                x86_64 = {
                    url = "https://github.com/theseus-rs/postgresql-binaries/releases/download/18.7.0/postgresql-18.7.0-x86_64-apple-darwin.tar.gz",
                    sha256 = "9cd649259d6bf4af60a235e772c83853df215b63f4c1967c2eed7f9376aefb89",
                },
                aarch64 = {
                    url = "https://github.com/theseus-rs/postgresql-binaries/releases/download/18.7.0/postgresql-18.7.0-aarch64-apple-darwin.tar.gz",
                    sha256 = "86456c0ed99d2466524eaa074db6580cf7d748b91042e252c83eaca9a9d216e7",
                },
            },
            ["17.12.0"] = {
                x86_64 = {
                    url = "https://github.com/theseus-rs/postgresql-binaries/releases/download/17.12.0/postgresql-17.12.0-x86_64-apple-darwin.tar.gz",
                    sha256 = "34ba0eca0f15776b4ab9a07b2decc6fb0b1910a57870ad7d7dacb7399b43c9bd",
                },
                aarch64 = {
                    url = "https://github.com/theseus-rs/postgresql-binaries/releases/download/17.12.0/postgresql-17.12.0-aarch64-apple-darwin.tar.gz",
                    sha256 = "2f752033b208f9a6a12ef64a9ee23bf19149cff160841980db1e221bf7d24809",
                },
            },
        },
        windows = {
            deps = { runtime = { "xim:vcruntime" } },
            ["latest"] = { ref = "19.0.0" },
            ["19"] = { ref = "19.0.0" },
            ["18"] = { ref = "18.7.0" },
            ["17"] = { ref = "17.12.0" },
            ["19.0.0"] = {
                x86_64 = {
                    url = "https://github.com/theseus-rs/postgresql-binaries/releases/download/19.0.0/postgresql-19.0.0-x86_64-pc-windows-msvc.zip",
                    sha256 = "5b0ceae52de3dbb356a2003fd95c5a323e220bab1e1b6e3ba3bb0da61f8b9ef9",
                },
            },
            ["18.7.0"] = {
                x86_64 = {
                    url = "https://github.com/theseus-rs/postgresql-binaries/releases/download/18.7.0/postgresql-18.7.0-x86_64-pc-windows-msvc.zip",
                    sha256 = "64948bd862b2f9c253067d3476e971b8b31291376fb004c5c7d5d016509401f7",
                },
            },
            ["17.12.0"] = {
                x86_64 = {
                    url = "https://github.com/theseus-rs/postgresql-binaries/releases/download/17.12.0/postgresql-17.12.0-x86_64-pc-windows-msvc.zip",
                    sha256 = "e45909100dd4d7309981054d5625e70612150999d106741d1c01a5443be918bf",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

local PROGRAMS = {
    "psql",
    "postgres",
    "initdb",
    "pg_ctl",
    "pg_dump",
    "pg_dumpall",
    "pg_restore",
    "pg_isready",
    "createdb",
    "dropdb",
    "createuser",
    "dropuser",
    "clusterdb",
    "reindexdb",
    "vacuumdb",
    "pg_basebackup",
    "pg_upgrade",
    "pg_rewind",
    "pg_verifybackup",
    "pg_combinebackup",
    "pg_checksums",
    "pg_controldata",
    "pgbench",
    "pg_config",
}

local function expected_files(ext)
    local out = {}
    for _, prog in ipairs(PROGRAMS) do
        out[#out + 1] = "bin/" .. prog .. ext
    end
    return out
end

function installed()
    return payload.present(expected_files("")) or payload.present(expected_files(".exe"))
end

function install()
    local archive = tostring(pkginfo.install_file())
    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local stem = (normalized:match("([^/]+)$") or ""):gsub("%.tar%.gz$", ""):gsub("%.zip$", "")
    local is_win = normalized:match("%.zip$") ~= nil

    payload.unpack{ extracted = stem, strip = 1 }

    if is_win and pkginfo.dep_install_dir then
        local crt = assert(pkginfo.dep_install_dir("xim:vcruntime"),
                           "postgresql: xim:vcruntime payload directory is missing")
        for _, dll in ipairs(fs.files(crt .. "/bin") or {}) do
            os.cp(dll, dir .. "/bin")
        end
    end

    payload.require(expected_files(is_win and ".exe" or ""))
    return true
end

function config()
    local bindir = pkginfo.install_dir() .. "/bin"
    local root = "psql@" .. pkginfo.version()
    xvm.add("psql", { bindir = bindir })
    for i = 2, #PROGRAMS do
        xvm.add(PROGRAMS[i], { bindir = bindir, binding = root })
    end
    return true
end

function uninstall()
    for i = #PROGRAMS, 1, -1 do
        xvm.remove(PROGRAMS[i])
    end
    return true
end
