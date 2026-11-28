-- cue - Validate and define text-based and dynamic configuration (cue-lang/cue).
--
-- Platform and architecture coverage (verified against cue-lang/cue v0.18.0):
--   linux    x86_64, aarch64   cue_v<ver>_linux_<arch>.tar.gz   (static Go ELF, CGO_ENABLED=0, no .dynamic section)
--   macosx   x86_64, aarch64   cue_v<ver>_darwin_<arch>.tar.gz  (official Mach-O binary)
--   windows  x86_64, aarch64   cue_v<ver>_windows_<arch>.zip    (official PE32+ binary, imports kernel32.dll only)
--
-- All upstream archives are flat at root (`cue` / `cue.exe`, `LICENSE`,
-- `README.md`, `doc/...`) with no top-level wrapper directory. Every SHA256
-- below was verified against the GitHub release asset digests of v0.18.0
-- and locally downloaded archives.

package = {
    spec = "2",

    name = "cue",
    description = "Validate and define text-based and dynamic configuration with the CUE language",
    homepage = "https://cuelang.org",
    authors = {"The CUE Authors"},
    maintainers = {"cue-lang/cue"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/cue-lang/cue",
    docs = "https://cuelang.org/docs/",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"config", "validation", "schema", "cli", "tools"},
    keywords = {"cue", "cuelang", "config", "schema", "validation", "json", "yaml", "go"},

    programs = {"cue"},
    xvm_enable = true,
    ci = { mirror = true },

    extensions = {
        autoupdate = {
            source = "https://github.com/cue-lang/cue/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/cue-lang/cue/releases/download/${tag}/cue_${tag}_linux_amd64.tar.gz",
                            aarch64 = "https://github.com/cue-lang/cue/releases/download/${tag}/cue_${tag}_linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/cue-lang/cue/releases/download/${tag}/cue_${tag}_darwin_amd64.tar.gz",
                            aarch64 = "https://github.com/cue-lang/cue/releases/download/${tag}/cue_${tag}_darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/cue-lang/cue/releases/download/${tag}/cue_${tag}_windows_amd64.zip",
                            aarch64 = "https://github.com/cue-lang/cue/releases/download/${tag}/cue_${tag}_windows_arm64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/cue-lang/cue/releases/download/v${version}/cue_v${version}_linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.18.0" },
            ["0.18.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "6f763cc20c42174344fbead70737714d63a50c3fa7ec71179e67974c4f9c5f81",
                    aarch64 = "20b99a70821f358413318d80c956d36214aa98f61307af19130d31c3490b8451",
                },
            },
        },
        macosx = {
            source = "https://github.com/cue-lang/cue/releases/download/v${version}/cue_v${version}_darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.18.0" },
            ["0.18.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "d122cb6717bc6b80240882a3a85ae5d364e5483e57829c185d58214bd93206e9",
                    aarch64 = "9f8959a8a8bee82db08facd890b138f285c0b850b8b18125086761c0fded58a5",
                },
            },
        },
        windows = {
            source = "https://github.com/cue-lang/cue/releases/download/v${version}/cue_v${version}_windows_${arch_alias}.zip",
            ["latest"] = { ref = "0.18.0" },
            ["0.18.0"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "c2b17fc673b1395704cf4db657327c5f9da831edab5164531ec315ba05bb95b4",
                    aarch64 = "77e3ec0cb46bfbbf76967bd1bbdb94769084ddf489d77504f0c6a26e51d5ac82",
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
    return payload.present({ "cue" }) or payload.present({ "cue.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("cue: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("%.zip$") ~= nil
    local exe = is_win and "cue.exe" or "cue"

    os.tryrm(dir)
    fs.mkdir_p(dir)

    -- Upstream archives are flat (no top-level wrapper directory). Extract
    -- directly from the archive into install_dir so files from unrelated flat
    -- packages in the shared download directory cannot leak into this payload.
    if is_win then
        if os.isfile(archive) then
            payload.unpack{}
        elseif os.isfile(parent .. "/" .. exe) then
            os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
        else
            error("cue: neither archive (" .. archive .. ") nor extracted binary exists")
        end
    else
        if os.isfile(archive) then
            system.exec(string.format([[tar -xzf "%s" -C "%s"]], normalized, dir))
        elseif os.isfile(parent .. "/" .. exe) then
            os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
        else
            error("cue: neither archive (" .. archive .. ") nor extracted binary exists")
        end
        if os.isfile(dir .. "/" .. exe) then
            system.exec(string.format([[chmod +x "%s"]], dir .. "/" .. exe))
        end
    end

    payload.require({ exe })
    return true
end

function config()
    xvm.add("cue", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("cue")
    return true
end
