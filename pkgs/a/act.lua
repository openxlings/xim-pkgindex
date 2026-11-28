-- act - Run your GitHub Actions locally.
--
-- Platform and architecture coverage (verified against nektos/act v0.2.98):
--   linux    x86_64, aarch64   static Go ELF binary (`act` at archive root)
--   macosx   x86_64, aarch64   official Mach-O binary (`act` at archive root)
--   windows  x86_64, aarch64   official PE binary (`act.exe` at archive root)
--
-- All archives are flat (`LICENSE`, `README.md`, and `act`/`act.exe` sit
-- directly at the archive root with no enclosing folder). Verified with
-- `readelf -d` / `ldd`: both Linux ELFs are statically linked Go executables
-- with no dynamic section (zero runtime deps). Verified Windows PE import
-- tables: both `x86_64` and `arm64` `act.exe` import only `kernel32.dll`
-- (no `VCRUNTIME140.dll` / `MSVCP140.dll`, so no `xim:vcruntime` dep).

package = {
    spec = "2",

    name = "act",
    description = "Run your GitHub Actions locally",
    homepage = "https://nektosact.com",
    authors = {"nektos"},
    maintainers = {"https://github.com/nektos/act/graphs/contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/nektos/act",
    docs = "https://nektosact.com",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"ci", "github", "devops", "cli", "tools"},
    keywords = {"act", "github-actions", "ci", "docker", "cli", "go"},

    programs = {"act"},
    xvm_enable = true,
    ci = { mirror = true },

    extensions = {
        autoupdate = {
            source = "https://github.com/nektos/act/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/nektos/act/releases/download/v${version}/act_Linux_x86_64.tar.gz",
                            aarch64 = "https://github.com/nektos/act/releases/download/v${version}/act_Linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/nektos/act/releases/download/v${version}/act_Darwin_x86_64.tar.gz",
                            aarch64 = "https://github.com/nektos/act/releases/download/v${version}/act_Darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/nektos/act/releases/download/v${version}/act_Windows_x86_64.zip",
                            aarch64 = "https://github.com/nektos/act/releases/download/v${version}/act_Windows_arm64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/nektos/act/releases/download/v${version}/act_Linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.2.99" },
            ["0.2.98"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "d3344bd0810c04b000d2444030b08c90ab9fbf905bbe2c3e26298be00c620d65",
                    aarch64 = "a30ba1a1582cb93810c77f743415cac33c16f60fc288116a8e0943144b6a6a4f",
                },
            },
            ["0.2.99"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "244abf6b011257ae959be907d618a8243863991020190c9107e151b545e32cdd",
                    aarch64 = "e7544abd0d74a06fd63a158a45c0f935c54a3f8759bf4c615034b1eb66d3a950",
                },
            },
        },
        macosx = {
            source = "https://github.com/nektos/act/releases/download/v${version}/act_Darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.2.99" },
            ["0.2.98"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "a0885179705d0f3f5d27201cefa0309ac78e3fccda447ecdfb96877b66b565b0",
                    aarch64 = "14477d7e076b12a885c54301beff2b524a905e4238a2b3ec9b3d1fd0efdc100f",
                },
            },
            ["0.2.99"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "67129cc527906cad2cbfe90fbae73d0fc9c077d481c8fea2da874c94e0500203",
                    aarch64 = "53e650238211e6af86458c252e896dac30497eb16fecf08dd7fef4d9ce6eec5b",
                },
            },
        },
        windows = {
            source = "https://github.com/nektos/act/releases/download/v${version}/act_Windows_${arch_alias}.zip",
            ["latest"] = { ref = "0.2.99" },
            ["0.2.98"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "d0d868ee2b33bb710f4df82d69345ce3a10d2f9fc7bbee9522bf36a15779ada0",
                    aarch64 = "c67cd28ccd1c9a9238614306a8f49c2037b7df7aa01b5d890ad671d43cbdc503",
                },
            },
            ["0.2.99"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "f65de87205f8a45bf73d8fc63819cab65f60195f1e815a4c472e944af723d6a6",
                    aarch64 = "61da54b51aa3bbb4597665d3b42b814ee3b7dce2b3c5462e261a8f62592d709c",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.winpath")

function installed()
    local dir = pkginfo.install_dir()
    return os.isfile(dir .. "/act.exe") or os.isfile(dir .. "/act")
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("act: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local download_dir = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("%.zip$") ~= nil
    local exe = is_win and "act.exe" or "act"
    local pre_extracted = download_dir .. "/" .. exe

    os.tryrm(dir)
    fs.mkdir_p(dir)

    if os.isfile(pre_extracted) then
        os.mv(pre_extracted, dir .. "/" .. exe)
        for _, doc in ipairs({ "LICENSE", "README.md" }) do
            if os.isfile(download_dir .. "/" .. doc) then
                os.mv(download_dir .. "/" .. doc, dir .. "/" .. doc)
            end
        end
    elseif os.isfile(archive) then
        if is_win then
            local sysroot = winpath.native(os.getenv("SystemRoot") or "C:\\Windows"):gsub("\\+$", "")
            local systar = sysroot .. "\\System32\\tar.exe"
            -- exec-quoting-ok: the first token is the system's tar.exe, which cmd.exe must see unquoted
            system.exec(string.format('%s -xf "%s" -C "%s"', systar, winpath.native(archive), winpath.native(dir)))
        else
            system.exec(string.format([[tar -xzf "%s" -C "%s"]], normalized, dir))
        end
    else
        error("act: neither extracted binary (" .. pre_extracted .. ") nor archive (" .. archive .. ") exists")
    end

    if not is_win and os.isfile(dir .. "/" .. exe) then
        system.exec(string.format([[chmod +x "%s"]], dir .. "/" .. exe))
    end

    if not installed() then
        error("act: " .. exe .. " is missing after install in " .. dir)
    end
    return true
end

function config()
    xvm.add("act", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("act")
    return true
end
