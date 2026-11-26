-- Meilisearch - a lightning-fast, hyper-relevant search engine API (meilisearch/meilisearch).
--
-- Verified against upstream GitHub release meilisearch/meilisearch v1.58.0:
--   Every SHA256 below was verified against the GitHub release asset digests
--   and computed locally from the downloaded raw binaries. All 5 asset
--   basenames are unique across platforms and architectures; xlings skips
--   extraction for unarchived binaries and passes the downloaded file via
--   `pkginfo.install_file()`.
--   * linux/x86_64:         meilisearch-linux-amd64
--                           dynamically linked ELF, INTERP /lib64/ld-linux-x86-64.so.2,
--                           NEEDED: libgcc_s.so.1, libm.so.6, libc.so.6, ld-linux-x86-64.so.2
--                           max symbol versions: GCC_4.2.0, GLIBC_2.39 (weak) / GLIBC_2.38
--   * linux/aarch64:        meilisearch-linux-aarch64
--                           dynamically linked ELF, INTERP /lib/ld-linux-aarch64.so.1,
--                           NEEDED: libgcc_s.so.1, libm.so.6, libc.so.6, ld-linux-aarch64.so.1
--                           max symbol versions: GCC_4.2.0, GLIBC_2.39
--                           -> declares xim:glibc@>=2.39 and xim:gcc-runtime on linux
--   * macosx/x86_64:        meilisearch-macos-amd64         (Mach-O 64-bit x86_64)
--   * macosx/aarch64:       meilisearch-macos-apple-silicon (Mach-O 64-bit arm64)
--   * windows/x86_64:       meilisearch-windows-amd64.exe
--                           PE32+ x86_64 importing VCRUNTIME140.dll and UCRT API sets,
--                           so `xim:vcruntime` DLLs are copied app-local beside meilisearch.exe.
--                           (No windows/aarch64 asset published upstream.)
--
-- Note: `meilisearch /?` exits immediately (exit 2: unexpected argument '/?')
-- without starting the HTTP server, so Windows CI's program probe completes cleanly.

package = {
    spec = "2",

    name = "meilisearch",
    description = "A lightning-fast search engine API bringing AI-powered hybrid search to your sites and applications",
    homepage = "https://www.meilisearch.com",
    authors = {"Meili SAS"},
    maintainers = {"https://github.com/meilisearch/meilisearch/graphs/contributors"},
    licenses = {"MIT", "OpenLDAP"},
    repo = "https://github.com/meilisearch/meilisearch",
    docs = "https://www.meilisearch.com/docs",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"search", "database", "api", "cli", "tools"},
    keywords = {"meilisearch", "search", "search-engine", "full-text", "vector-search", "hybrid-search", "rust"},

    programs = {"meilisearch"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/meilisearch/meilisearch/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/meilisearch/meilisearch/releases/download/${tag}/meilisearch-linux-amd64",
                            aarch64 = "https://github.com/meilisearch/meilisearch/releases/download/${tag}/meilisearch-linux-aarch64",
                        },
                        macosx = {
                            x86_64 = "https://github.com/meilisearch/meilisearch/releases/download/${tag}/meilisearch-macos-amd64",
                            aarch64 = "https://github.com/meilisearch/meilisearch/releases/download/${tag}/meilisearch-macos-apple-silicon",
                        },
                        windows = {
                            x86_64 = "https://github.com/meilisearch/meilisearch/releases/download/${tag}/meilisearch-windows-amd64.exe",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            deps = {
                runtime = { "xim:glibc@>=2.39", "xim:gcc-runtime" },
            },
            source = "https://github.com/meilisearch/meilisearch/releases/download/v${version}/meilisearch-linux-${arch_alias}",
            ["latest"] = { ref = "1.58.0" },
            ["1.58.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "aarch64" },
                sha256 = {
                    x86_64 = "5e217e1694450455dc557c3719a00472e567957e4fbc3bd82de2762ded2155b7",
                    aarch64 = "24851acfd3d97e46448eba05079c2aaefb1771e4baaae2f0281a7b38b7b6392f",
                },
            },
        },
        macosx = {
            source = "https://github.com/meilisearch/meilisearch/releases/download/v${version}/meilisearch-macos-${arch_alias}",
            ["latest"] = { ref = "1.58.0" },
            ["1.58.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "apple-silicon" },
                sha256 = {
                    x86_64 = "4e6bace7db2162a96e742bce672b26072329b7673a2f13600ec4d1e3f811d1b3",
                    aarch64 = "9b700b556f33932d8960569e867e137eb4cbc657dd6ac0e0f59578d3cdb54bf4",
                },
            },
        },
        windows = {
            deps = {
                runtime = { "xim:vcruntime" },
            },
            source = "https://github.com/meilisearch/meilisearch/releases/download/v${version}/meilisearch-windows-${arch_alias}.exe",
            ["latest"] = { ref = "1.58.0" },
            ["1.58.0"] = {
                arch_alias = { x86_64 = "amd64" },
                sha256 = {
                    x86_64 = "9199197db4a260ca079296de89364a1e2e725703dcefc44340c36f62d3bcf8fe",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

function installed()
    return payload.present({ "meilisearch" })
        or payload.present({ "meilisearch.exe" })
end

function install()
    local src = tostring(pkginfo.install_file() or "")
    if src == "" then
        error("meilisearch: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = src:gsub("\\", "/")
    local is_win = normalized:lower():match("%.exe$") ~= nil
        or normalized:match("windows") ~= nil
    local exe = is_win and "meilisearch.exe" or "meilisearch"
    local target = dir .. "/" .. exe

    os.tryrm(dir)
    fs.mkdir_p(dir)

    if not os.isfile(src) then
        error("meilisearch: downloaded binary not found at " .. src)
    end
    os.mv(src, target)

    if is_win then
        if not pkginfo.dep_install_dir then
            error("meilisearch: xim:vcruntime runtime dep lookup is unavailable")
        end
        local crt = assert(pkginfo.dep_install_dir("xim:vcruntime"),
                           "meilisearch: xim:vcruntime payload directory is missing")
        local copied = 0
        for _, dll in ipairs(fs.files(crt .. "/bin") or {}) do
            os.cp(dll, dir)
            copied = copied + 1
        end
        if copied == 0 then
            error("meilisearch: no CRT DLLs found in " .. crt .. "/bin")
        end
    else
        system.exec(string.format('chmod +x "%s"', target))
    end

    payload.require({ exe })
    return true
end

function config()
    xvm.add("meilisearch", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("meilisearch")
    return true
end
