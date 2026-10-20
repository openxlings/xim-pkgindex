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
            ["latest"] = { ref = "2026.10.20.3" },
            ["2026.10.20.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "b05ff07e7d28cfdf8ddc275e192da999e486220fdad80ca41e6fe5f72443548e",
                    x86_64 = "77861cd009c4dca8de16db74913d1b943e2b973c3970ab593181d00f69233c33",
                },
            },
            ["2026.10.20.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "0fb36262cf887041453a76b09b550aa5c8d929bd5fc11bd268dac0d0e9d4b2a6",
                    x86_64 = "dc866e09ef8e18ec0fab524571e2ec192fca2f8dd00909265c058a5075775b26",
                },
            },
            ["2026.10.20.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "6628e5056293ec3855e2492f07f21183e50c641dac4e93b9400010e993427486",
                    x86_64 = "f111d3b88a3b1f0d262c1bd2cbf2833ecbca6c78f616be02ec507a9a297a506c",
                },
            },
            ["2026.10.19.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "f672331ac2c6b3a500c78b0b1aab486737d8b1709714c766ac328184b2c3b482",
                    x86_64 = "a7c15784678113ccfade135b768e4b728f2eb8d0d0fe2878fdacc2932de797d1",
                },
            },
            ["2026.10.19.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "137ef2643afa17392a31a5695037fa876591fb9d2cace00af296c2fad3c9f972",
                    x86_64 = "ec21c97dea76c9413436a4646f494159e1ac3dc4326706e22aec5db1d1530631",
                },
            },
            ["2026.10.18.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "b245390e53a62b2065942c9dce5b9e321c622b29b5219b07fe6f897d703bc44d",
                    x86_64 = "a1f37741d526fc4495af1b6cbd65839480a7e3bfb9c18beb50ba215c17f86f33",
                },
            },
            ["2026.10.17.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "29e19651971ea43d7cb7c26a144e20773c2597b83794ca08b3f776806b815541",
                    x86_64 = "dc4131fcf651c3c669376b100671f1aaf0e611afd49703bf7af6f5c399cf3e6e",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "2026.10.20.3" },
            ["2026.10.20.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "65ddac3a705b1fe639f65df57a54208f5d114b71a17831834df4fb2e6d04c7f2",
                },
            },
            ["2026.10.20.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "275fb98984be58d50d6db7489dc17688fba7c09815f90764e442769c4f83c529",
                },
            },
            ["2026.10.20.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "32ba024b8eca903fb4d9b7565d55c4c29645308e04b996f44bb8a9a8eee089f3",
                },
            },
            ["2026.10.19.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "56a84c4ffb9b2aec0ef4ece8fd23bfda9b464472c0df2256fd13a12e76235408",
                },
            },
            ["2026.10.19.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "59ba1ef830abc1ad9536746264f5ca42aba1034a4de2748b3cb79c9957a91094",
                },
            },
            ["2026.10.18.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "36d85b92a649ff9886113204a7fb6c57e77803372269593f31ffe43a3c87af44",
                },
            },
            ["2026.10.17.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "06edd18c3646192199691b2ebb19d69d712b481e3c22830463e646fc5467dc45",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "2026.10.20.3" },
            ["2026.10.20.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "04a97b88eb9d8cc3faee1b819744c47089430364b9fcc785031b0b1489349e72",
                },
            },
            ["2026.10.20.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "0d426406f2f6f63a403ea638e4d0c9278a5463ccb04a943803bfe1b2078e6deb",
                },
            },
            ["2026.10.20.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "8179f840e1403c6faed36de64c3d0db7b0a43eb5793bcfe8af5232ac65c7ab74",
                },
            },
            ["2026.10.19.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "2d8ef923d1b576d6dafd3c5126a9a128cf02219183e992f4346254b9d246c9a6",
                },
            },
            ["2026.10.19.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "af1784366a7b7e38a35c7b6e835cf04186a5cbdd2da8171cfa1e70045b818d51",
                },
            },
            ["2026.10.18.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "e8f2c60ac46bbd732c313649bfd1a66ced415d77bbacc49dac2fe6125db29d76",
                },
            },
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
