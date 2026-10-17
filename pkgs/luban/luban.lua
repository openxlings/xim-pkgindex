package = {
    spec = "1",

    name = "luban",
    description = "luban: the Luban OS command -- environments, machines and images of this home",

    homepage = "https://github.com/openxlings/xlings",
    repo = "https://github.com/openxlings/xlings",
    licenses = {"Apache-2.0"},

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"tools", "luban", "subos"},
    keywords = {"luban", "luban-os", "subos", "environment", "machine", "image"},

    -- The luban command (openxlings/xlings, apps/luban), released with xlings
    -- at the same date version as its own payload: bin/luban of that xlings
    -- archive (tools/luban_release.sh; mirrored to xlings-res/luban). Static,
    -- like xlings. It drives the xlings of the home it runs in (the one beside
    -- it, else $XLINGS_HOME/bin/xlings). An xlings home also carries a luban in
    -- <home>/bin; this package puts luban in the routing table, so it is on the
    -- PATH every shell of the home has -- cmd, Git Bash, a PowerShell that runs
    -- no profile -- and is managed like every other program.
    programs = {"luban"},
    xvm_enable = true,

    xpm = {
        linux = {
            ["latest"] = { ref = "2026.10.17.1" },
            ["2026.10.17.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "29e19651971ea43d7cb7c26a144e20773c2597b83794ca08b3f776806b815541",
                    x86_64 = "dc4131fcf651c3c669376b100671f1aaf0e611afd49703bf7af6f5c399cf3e6e",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "2026.10.17.1" },
            ["2026.10.17.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "06edd18c3646192199691b2ebb19d69d712b481e3c22830463e646fc5467dc45",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "2026.10.17.1" },
            ["2026.10.17.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "867cc559549b06daa1a5fd0b360d1fbedfefde62db0b39d6d07576c3a501639c",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

-- bin/luban (bin/luban.exe on Windows): the payload extracts into
-- luban-<version>-<os>-<arch>/, a .tar.gz on Linux and macOS, a .zip on Windows.
local function exe()
    return is_host("windows") and "luban.exe" or "luban"
end

function install()
    local dir = pkginfo.install_dir()
    local payload = pkginfo.install_file():replace(".tar.gz", ""):replace(".zip", "")
    if os.isdir(payload) then
        os.tryrm(dir)
        os.mv(payload, dir)
    end
    return os.isfile(path.join(dir, "bin", exe()))
end

function config()
    xvm.add("luban", { bindir = path.join(pkginfo.install_dir(), "bin") })
    return true
end

function uninstall()
    xvm.remove("luban")
    return true
end
