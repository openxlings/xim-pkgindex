-- llama.cpp - LLM inference in C/C++.
--
-- Platforms and upstream release assets (ggml-org/llama.cpp, CPU builds):
--   linux    x86_64, aarch64   llama-<ver>-bin-ubuntu-{x64,arm64}.tar.gz
--                              + xim:glibc@>=2.39, xim:gcc-runtime, xim:openssl@3.1.5
--   macosx   x86_64, aarch64   llama-<ver>-bin-macos-{x64,arm64}.tar.gz
--   windows  x86_64            llama-<ver>-bin-win-cpu-x64.zip + app-local xim:vcruntime DLLs
--
-- Linux prebuilt binaries and bundled shared libraries (`libllama*.so*`,
-- `libggml*.so*`, `libmtmd.so*`) use `RUNPATH=$ORIGIN` and dynamically link
-- glibc (`libc.so.6`, `libm.so.6`, `ld-linux-*.so.*`), GCC runtime
-- (`libstdc++.so.6`, `libgcc_s.so.1`, `libgomp.so.1`), and OpenSSL 3
-- (`libssl.so.3`, `libcrypto.so.3`).
-- Windows ARM64 waits for `xim:vcruntime` ARM64 runtime DLL support.
package = {
    spec = "2",

    name = "llama.cpp",
    description = "LLM inference in C/C++",
    homepage = "https://github.com/ggml-org/llama.cpp",
    authors = {"Georgi Gerganov", "llama.cpp contributors"},
    maintainers = {"https://github.com/ggml-org/llama.cpp"},
    licenses = {"MIT"},
    repo = "https://github.com/ggml-org/llama.cpp",
    docs = "https://github.com/ggml-org/llama.cpp/blob/master/README.md",
    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"ai", "llm", "inference", "cli", "tools"},
    keywords = {"llama", "llama.cpp", "llm", "ggml", "gguf", "inference", "ai"},

    programs = {"llama-cli", "llama-server"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/ggml-org/llama.cpp/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/ggml-org/llama.cpp/releases/download/${tag}/llama-${version}-bin-ubuntu-x64.tar.gz",
                            aarch64 = "https://github.com/ggml-org/llama.cpp/releases/download/${tag}/llama-${version}-bin-ubuntu-arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/ggml-org/llama.cpp/releases/download/${tag}/llama-${version}-bin-macos-x64.tar.gz",
                            aarch64 = "https://github.com/ggml-org/llama.cpp/releases/download/${tag}/llama-${version}-bin-macos-arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/ggml-org/llama.cpp/releases/download/${tag}/llama-${version}-bin-win-cpu-x64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            deps = {
                runtime = { "xim:glibc@>=2.39", "xim:gcc-runtime", "xim:openssl@3.1.5" },
                build = { "xim:patchelf@0.18.0" },
            },
            source = "https://github.com/ggml-org/llama.cpp/releases/download/${version}/llama-${version}-bin-ubuntu-${arch_alias}.tar.gz",
            ["latest"] = { ref = "b12720" },
            ["b12720"] = {
                arch_alias = { x86_64 = "x64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "ad1c046176f8ba6f8996b3b679f8ccb64ee0f79ef8eaa096715f9404f141ad02",
                    aarch64 = "1fa4a650044c0b306a8b2b2ae76ba9a75eccab2326628f29019606d85aee5b57",
                },
            },
        },
        macosx = {
            source = "https://github.com/ggml-org/llama.cpp/releases/download/${version}/llama-${version}-bin-macos-${arch_alias}.tar.gz",
            ["latest"] = { ref = "b12720" },
            ["b12720"] = {
                arch_alias = { x86_64 = "x64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "80048a5f133f80b514098920750d90e66bfd965b529dce197a91fd745557384a",
                    aarch64 = "42d569fea95f7944c1138cb57a9aa76497cb32ae527107069da220f8668ca3a3",
                },
            },
        },
        windows = {
            deps = {
                runtime = { "xim:vcruntime" },
            },
            source = "https://github.com/ggml-org/llama.cpp/releases/download/${version}/llama-${version}-bin-win-cpu-${arch_alias}.zip",
            ["latest"] = { ref = "b12720" },
            ["b12720"] = {
                arch_alias = { x86_64 = "x64" },
                sha256 = {
                    x86_64 = "27ac9fdbb5602ab671c4ab901f80521a9fabbcd0b0341ad497a3102633b45c46",
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

local function is_windows_target()
    local archive = tostring(pkginfo.install_file() or ""):gsub("\\", "/")
    return archive:match("%.zip$") ~= nil or archive:match("win%-") ~= nil
end

function installed()
    return payload.present({ "llama-cli.exe", "llama-server.exe" })
        or payload.present({ "llama-cli", "llama-server" })
end

function install()
    local dir = pkginfo.install_dir()
    local is_win = is_windows_target()

    if is_win then
        -- Windows zip is flat (no top-level wrapper directory): extract
        -- directly into install_dir so bundled DLLs stay beside the exes
        -- without mixing into the shared runtime extraction directory.
        payload.unpack({ extracted = nil })
        if pkginfo.dep_install_dir then
            local crt = assert(pkginfo.dep_install_dir("xim:vcruntime"),
                               "llama.cpp: xim:vcruntime payload directory is missing")
            for _, dll in ipairs(fs.files(crt .. "/bin") or {}) do
                os.cp(dll, dir)
            end
        end
        payload.require({ "llama-cli.exe", "llama-server.exe" })
        return true
    end

    -- Linux / macOS tarballs enclose all binaries and bundled .so/.dylib files
    -- inside `llama-<version>/`. Preserve the entire directory contents so
    -- `$ORIGIN` / `@rpath` lookups against bundled libraries remain intact.
    payload.unpack({ extracted = "llama-" .. pkginfo.version() })
    for _, prog in ipairs({ "llama-cli", "llama-server" }) do
        system.exec(string.format('chmod +x "%s"', dir .. "/" .. prog))
    end
    payload.require({ "llama-cli", "llama-server" })
    return true
end

-- Preserve `$ORIGIN` alongside xlings' post-install elfpatch closure RPATH.
-- xlings stamps `<abi_dir>:<openssl/lib64>` on Linux binaries and bundled `.so`
-- files, overwriting upstream's `$ORIGIN`; restoring `$ORIGIN` first keeps
-- bundled `libllama*.so*`, `libggml*.so*` (including dlopen'd CPU backends),
-- and `libmtmd.so*` resolvable behind our loader with zero host fallback.
local function _preserve_origin_rpath(dir)
    if not os.isfile(dir .. "/libllama.so.1.0.0") then
        return
    end
    local pe = "patchelf"
    if type(pkginfo.build_dep) == "function" then
        local ok, bd = pcall(pkginfo.build_dep, "xim:patchelf")
        if not (ok and bd and bd.bin) then
            ok, bd = pcall(pkginfo.build_dep, "patchelf")
        end
        if ok and bd and bd.bin and os.isfile(bd.bin .. "/patchelf") then
            pe = bd.bin .. "/patchelf"
        end
    end
    if pe == "patchelf" and type(pkginfo.tool_payload_dir) == "function" then
        local ok, tdir = pcall(pkginfo.tool_payload_dir, "patchelf")
        if ok and tdir and tdir ~= "" and os.isfile(tdir .. "/bin/patchelf") then
            pe = tdir .. "/bin/patchelf"
        end
    end
    system.exec(string.format(
        [[sh -c 'set -e; pe="$1"; dir="$2"; command -v "$pe" >/dev/null 2>&1 || exit 0; orig=$(printf "\044ORIGIN"); for f in "$dir"/*; do [ -f "$f" ] && [ ! -L "$f" ] || continue; case "$f" in *.so|*.so.*|*/llama*|*/ggml*) ;; *) continue ;; esac; r=$("$pe" --print-rpath "$f" 2>/dev/null) || continue; [ -n "$r" ] || continue; case ":$r:" in *":$orig:"*) continue ;; esac; tmp="$f.rpatch.$$"; "$pe" --output "$tmp" --force-rpath --set-rpath "$orig:$r" "$f" && mv -f "$tmp" "$f"; done' _ "%s" "%s"]],
        pe, dir
    ))
end

function config()
    local dir = pkginfo.install_dir()
    _preserve_origin_rpath(dir)
    xvm.add("llama-cli", { bindir = dir })
    xvm.add("llama-server", { bindir = dir })
    xvm.add(package.name, { type = "group" })
    return true
end

function uninstall()
    xvm.remove("llama-cli")
    xvm.remove("llama-server")
    xvm.remove(package.name)
    return true
end
