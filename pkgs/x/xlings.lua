package = {
    spec = "1",

    -- base info
    name = "xlings",
    description = [[Xlings | Highly abstract [ package manager ] - "Multi-version management + Everything can be a package"]],
    type = "package",

    authors = {"Sunrisepeak"},
    maintainers = {"d2learn"},
    contributors = "https://github.com/openxlings/xlings/graphs/contributors",
    licenses = {"Apache-2.0"},
    repo = "https://github.com/openxlings/xlings",
    ci = { update = true },

    -- xim pkg info
    archs = {"x86_64", "aarch64"},
    status = "stable", -- dev, stable, deprecated
    categories = {"tools", "package-manager", "version-manager"},
    keywords = {"xlings", "package-manager", "version-manager", "dev-tools"},

    -- Only `xlings` is registered via xvm.add in config() below.
    -- The other CLI entry points the xlings binary recognizes — `xim`,
    -- `xinstall`, `xsubos`, `xself` — are multicall aliases that
    -- `xlings self init` (xself::ensure_subos_shims) wires up on xlings's
    -- own install side, NOT here. Listing them under `programs` would
    -- make CI's declared-program audit demand a shim from this xpkg's
    -- config(), which it never produces, so they don't belong here.
    programs = { "xlings" },

    xvm_enable = true,

    -- Recent mirrored releases use XLINGS_RES so downloads can
    -- resolve through the configured multi-mirror resource service.
    -- Historical 0.4.x entries keep their direct GitHub release URLs.
    xpm = {
        linux = {
            -- res_versioned: version-bump bot tracks openxlings/xlings releases and
            -- appends new ["x.y.z"] = "XLINGS_RES" entries (see version-check.py).
            res_versioned = true,
            ["latest"] = { ref = "0.4.65" },
            ["0.4.65"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "beaf1ab5758029c37aa962883b71ed58e2d9aca638d8a067c699093dfbb17ff8",
                    x86_64 = "893b46dfa68d236079d5ec9383a12d4abdd7dc2f156197b2671f6c7eb7fde93d",
                },
            },
            ["0.4.64"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "6a360997abb924f66bf4df8615ff9322e9125c12fc61b7be3d8e27e1f757ba72",
                    x86_64 = "68d030a16b56c6356d5f1dadee49f7a930c79925de4c49143b073ee066eb2f5a",
                },
            },
            ["0.4.63"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "596a6f57577293ca533a701136227ce353e0d4e0d7a623b77f84a9e2bc95fcea",
                    x86_64 = "3a435ae7ed58bd839053d9f5c72320a0123942ae9ccf920f424ce28f520076f6",
                },
            },
            ["0.4.62"] = "XLINGS_RES",
            ["0.4.60"] = "XLINGS_RES",
            ["0.4.55"] = "XLINGS_RES",
            ["0.4.54"] = "XLINGS_RES",
            ["0.4.53"] = "XLINGS_RES",
            ["0.4.52"] = "XLINGS_RES",
            ["0.4.51"] = "XLINGS_RES",
            ["0.4.50"] = "XLINGS_RES",
            ["0.4.49"] = "XLINGS_RES",
            ["0.4.48"] = "XLINGS_RES",
            ["0.4.47"] = "XLINGS_RES",
            ["0.4.46"] = "XLINGS_RES",
            ["0.4.44"] = "XLINGS_RES",
            ["0.4.43"] = "XLINGS_RES",
            ["0.4.42"] = "XLINGS_RES",
            ["0.4.41"] = "XLINGS_RES",
            ["0.4.40"] = "XLINGS_RES",
            ["0.4.39"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.39/xlings-0.4.39-linux-x86_64.tar.gz",
                sha256 = "beac3c49dc561527e56f62564f9229510389e11379640819c352af17e3567f71",
            },
            ["0.4.38"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.38/xlings-0.4.38-linux-x86_64.tar.gz",
                sha256 = "55dfca43dcbbef31b20c1fb4aced545fb37ca8119ad816ff8bbbdc286c172129",
            },
            ["0.4.37"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.37/xlings-0.4.37-linux-x86_64.tar.gz",
                sha256 = "4b63644ce3b7d17e598b01ce45ce593bf41b0e2f12644d80e20975a6c6448137",
            },
            ["0.4.36"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.36/xlings-0.4.36-linux-x86_64.tar.gz",
                sha256 = "a818bd7493e24fa83edb8a3f142d5b96a37acf6a34949dd944d61791c0db2513",
            },
            ["0.4.35"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.35/xlings-0.4.35-linux-x86_64.tar.gz",
                sha256 = "f5278472e25282c771b0bc08d00d6355e4b51b6fa7f54e61537dd9a8829a2a38",
            },
            ["0.4.34"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.34/xlings-0.4.34-linux-x86_64.tar.gz",
                sha256 = "1ac30caada0045a6d6d2cd100d7e06fce632e8419c46131cc6d1b0bbfe83a599",
            },
            ["0.4.33"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.33/xlings-0.4.33-linux-x86_64.tar.gz",
                sha256 = "d53274818b2c0dcb5b9c5130aeec0402c7df8eb4fc332bc6e109d760db81434e",
            },
            ["0.4.32"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.32/xlings-0.4.32-linux-x86_64.tar.gz",
                sha256 = "c897c2c3e9c66e5f1cd48f8505f3211984446b2baec79d3b529c6a8490e39b30",
            },
            ["0.4.31"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.31/xlings-0.4.31-linux-x86_64.tar.gz",
                sha256 = "bec1f92e59d2732fdadad2960459d788034468c3885c588b51c3bb1e0c9aa769",
            },
            ["0.4.30"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.30/xlings-0.4.30-linux-x86_64.tar.gz",
                sha256 = "3ba999d0940e203a938efa9d122010b83584a7ce1438053fd87b175452b6ea86",
            },
            ["0.4.29"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.29/xlings-0.4.29-linux-x86_64.tar.gz",
                sha256 = "3a2b86bc2e4b94ee9e0826e8d5288f08e17e142feb57501931fb1fd725585b2e",
            },
            ["0.4.28"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.28/xlings-0.4.28-linux-x86_64.tar.gz",
                sha256 = "5b5447d33c483e586f445c56e73288d300f58074a3505be955760d3bf717a985",
            },
            ["0.4.26"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.26/xlings-0.4.26-linux-x86_64.tar.gz",
                sha256 = "3de72252154104db605577ae1a8b5c2be2beb07158379c212188105f2fafe0c4",
            },
            ["0.4.25"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.25/xlings-0.4.25-linux-x86_64.tar.gz",
                sha256 = "2471326289be9ccca5a66d80ca827f9aa1d27f108c8b94b6952c859fa3e6b366",
            },
            ["0.4.24"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.24/xlings-0.4.24-linux-x86_64.tar.gz",
                sha256 = "a68fa8b874c712b9a7f469329cea6574a0d7857f42bdac701f7dbe8fad56f669",
            },
            ["0.4.23"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.23/xlings-0.4.23-linux-x86_64.tar.gz",
                sha256 = "c123afe8d2576d14bace1400c2403f0d1c9f2d25ff5fc14a2fa98dbe7efee59b",
            },
            ["0.4.22"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.22/xlings-0.4.22-linux-x86_64.tar.gz",
                sha256 = "0f14275d57c15b042919d260a28d0c39eac66e593fd39858e8ff7450df3d1b20",
            },
            ["0.4.21"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.21/xlings-0.4.21-linux-x86_64.tar.gz",
                sha256 = "f9ddd2b60c998dacdb1ddc6f7af09aa1675854971944dd26f25e307e3853f78f",
            },
            ["0.4.20"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.20/xlings-0.4.20-linux-x86_64.tar.gz",
                sha256 = "d7b250bc61019158ff5e1303572d82c2f8e20c36da44bb628cedbc61ebc80748",
            },
            ["0.4.19"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.19/xlings-0.4.19-linux-x86_64.tar.gz",
                sha256 = "fefca02c7aee4f05c4c30b97fca4a5e22b842eab8d8beb802ae1a40d0b442de2",
            },
            ["0.4.17"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.17/xlings-0.4.17-linux-x86_64.tar.gz",
                sha256 = "e34720c0657f010812c0ff4fbb07b23f4f0df9e97078c989c9861720088a8782",
            },
            ["0.4.16"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.16/xlings-0.4.16-linux-x86_64.tar.gz",
                sha256 = "2c3f898ba12cb1311bd57c614fd001b52c6f582818723a24d7999960a09c61d9",
            },
            ["0.4.15"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.15/xlings-0.4.15-linux-x86_64.tar.gz",
                sha256 = "ee3cddb490e345f02551a9ae16adf47bf0424c13eadb9bea453d8e4dea4d4967",
            },
            ["0.4.14"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.14/xlings-0.4.14-linux-x86_64.tar.gz",
                sha256 = "4d5ba18fb5f8b32ec899c43c64719302445fe13eec952629f28cce9d8c400b71",
            },
            ["0.4.13"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.13/xlings-0.4.13-linux-x86_64.tar.gz",
                sha256 = "74be30e988c82b9f2f3c44a48df2ae736aec6ad9ee05558351c3e37ee73088ec",
            },
            ["0.4.12"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.12/xlings-0.4.12-linux-x86_64.tar.gz",
                sha256 = "efccd525bfc5259a6387c40b523a23c2803678a48ecd4285efa6badac15d6338",
            },
            ["0.4.10"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.10/xlings-0.4.10-linux-x86_64.tar.gz",
                sha256 = "7308f5d65fb71773f1e3546be86c720e77ee21509b6a66dcee86ebf0239e8faf",
            },
            ["0.4.8"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.8/xlings-0.4.8-linux-x86_64.tar.gz",
                sha256 = "983b1ce4aa5b0fc4707907a314b5c1944362f141c085e2129a0c0c54cd030451",
            },
            ["0.4.7"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.7/xlings-0.4.7-linux-x86_64.tar.gz",
                sha256 = "e56d7fb5a0a44424ebd48ac4d5cb1f13abe6b296967b910c7ad2ac6e87c79ffd",
            },
            ["0.4.6"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.6/xlings-0.4.6-linux-x86_64.tar.gz",
                sha256 = "b7a61b944f784f0865b1874085f1840432b5a5b0f2b994983ab654ddabde5f9c",
            },
            ["0.4.5"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.5/xlings-0.4.5-linux-x86_64.tar.gz",
                sha256 = "2c1e1605376f0e427adbc0b070250af8843a000e1cb575be81265a7d742d75af",
            },
            ["0.4.4"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.4/xlings-0.4.4-linux-x86_64.tar.gz",
                sha256 = "bea197fe019dacc7062b54994aaa3d77ae92376eb60220d729d2f8e1de8361a6",
            },
            ["0.3.1"] = "XLINGS_RES",
            ["0.3.0"] = "XLINGS_RES",
        },
        macosx = {
            -- res_versioned: version-bump bot tracks openxlings/xlings releases and
            -- appends new ["x.y.z"] = "XLINGS_RES" entries (see version-check.py).
            res_versioned = true,
            ["latest"] = { ref = "0.4.65" },
            ["0.4.65"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "65ad3e3287de41905593a00216af1c493ba70db56d1f92fb9edc1021242309a8",
                },
            },
            ["0.4.64"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "c1668e0d25b30c59eb5c8159f91e90a4913a312830c8d67d91d7b018d7baea9b",
                },
            },
            ["0.4.63"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "e58e585836c26861ce470c2d519f5bba6f641bbc8691c1d668070bafbeaf0602",
                },
            },
            ["0.4.62"] = "XLINGS_RES",
            ["0.4.60"] = "XLINGS_RES",
            ["0.4.55"] = "XLINGS_RES",
            ["0.4.54"] = "XLINGS_RES",
            ["0.4.53"] = "XLINGS_RES",
            ["0.4.52"] = "XLINGS_RES",
            ["0.4.51"] = "XLINGS_RES",
            ["0.4.50"] = "XLINGS_RES",
            ["0.4.49"] = "XLINGS_RES",
            ["0.4.48"] = "XLINGS_RES",
            ["0.4.47"] = "XLINGS_RES",
            ["0.4.46"] = "XLINGS_RES",
            ["0.4.44"] = "XLINGS_RES",
            ["0.4.43"] = "XLINGS_RES",
            ["0.4.42"] = "XLINGS_RES",
            ["0.4.41"] = "XLINGS_RES",
            ["0.4.40"] = "XLINGS_RES",
            ["0.4.39"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.39/xlings-0.4.39-macosx-arm64.tar.gz",
                sha256 = "cdae486f87c3b980186ed20d6ebf01fd1b4d725d2ae6984e3d6729a3b0b3cb5f",
            },
            ["0.4.38"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.38/xlings-0.4.38-macosx-arm64.tar.gz",
                sha256 = "48876b1fad4336ee00191d3e29e32e6b3689685850cc5848dba6dcf45996b628",
            },
            ["0.4.37"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.37/xlings-0.4.37-macosx-arm64.tar.gz",
                sha256 = "6764766092a7d558fbe97739ba9370cde37b8015148ac5a2fe67ffeee5c094c3",
            },
            ["0.4.36"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.36/xlings-0.4.36-macosx-arm64.tar.gz",
                sha256 = "d2db5ebfb9f7264a52269c5d825de24a5bf3ed6b6841948694538f1ecc7125be",
            },
            ["0.4.35"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.35/xlings-0.4.35-macosx-arm64.tar.gz",
                sha256 = "d6931c9d0e2872b95780d9a78776c3f669bc77ad808e4fdcf5fb691be3087b7f",
            },
            ["0.4.34"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.34/xlings-0.4.34-macosx-arm64.tar.gz",
                sha256 = "61093967c78e696e486c6db563ee27a951032cf4aa78474b9ec0bb4668a05fdb",
            },
            ["0.4.33"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.33/xlings-0.4.33-macosx-arm64.tar.gz",
                sha256 = "bebd55b99c6c5f310ecde180c55567aa91fb0a43c166d49377a501fb38221def",
            },
            ["0.4.32"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.32/xlings-0.4.32-macosx-arm64.tar.gz",
                sha256 = "0447ce52d2c4eb18da5d0501900ab65b394d8ca39a8ac0892335ae9cc890600c",
            },
            ["0.4.31"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.31/xlings-0.4.31-macosx-arm64.tar.gz",
                sha256 = "b5ba1d1f8977a4ade29906a1ae45e4c6b7628f59ce853fcb12d3f77a0b1d6eda",
            },
            ["0.4.30"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.30/xlings-0.4.30-macosx-arm64.tar.gz",
                sha256 = "c1cf411c20dcbe1fbf830230b6cc93ac787338745853b9ea6b55ffda3510626b",
            },
            ["0.4.29"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.29/xlings-0.4.29-macosx-arm64.tar.gz",
                sha256 = "75fe03a3c293e28050ca8ef0c98146c7d0f2c15aa533bdf04cbb317222cad0a7",
            },
            ["0.4.28"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.28/xlings-0.4.28-macosx-arm64.tar.gz",
                sha256 = "6938d2df1f60c778f54f269136c8fb62364bd06937ec5c09c46a2cdf0b8c0c58",
            },
            ["0.4.26"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.26/xlings-0.4.26-macosx-arm64.tar.gz",
                sha256 = "7cacbee2689c5581c24242f9b5b5e6bc75bf3e272eeb5189da5f14e815fe905f",
            },
            ["0.4.25"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.25/xlings-0.4.25-macosx-arm64.tar.gz",
                sha256 = "6040964f394a63f01a0f7a79301e85770643289c03dab334792ef2613882e24b",
            },
            ["0.4.24"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.24/xlings-0.4.24-macosx-arm64.tar.gz",
                sha256 = "07ca20caff3fe343b9f0d46785c25e9ce0f959f0ad16afe1b782cbb29dd7350b",
            },
            ["0.4.23"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.23/xlings-0.4.23-macosx-arm64.tar.gz",
                sha256 = "afd444f348806818eb75df3ae15687d8f6a221abb84a7907eadc0027c4b139b7",
            },
            ["0.4.22"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.22/xlings-0.4.22-macosx-arm64.tar.gz",
                sha256 = "e10f0c5b208104c5813956eebddc5f91e6b17a49232d85c2da914e9b9d2ef02c",
            },
            ["0.4.21"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.21/xlings-0.4.21-macosx-arm64.tar.gz",
                sha256 = "741116c67f8fc7c461a9d4b0b679218a0d0a652b7d774e29dd103c08599dac5e",
            },
            ["0.4.20"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.20/xlings-0.4.20-macosx-arm64.tar.gz",
                sha256 = "647edb71c63a116ef0df57ee4fef944c8063e7d1751272a8d5651917515c423c",
            },
            ["0.4.19"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.19/xlings-0.4.19-macosx-arm64.tar.gz",
                sha256 = "e973a897f2cd785deaab5ad76fd3d37564442483fe5128230c1ea54bbea1dd4f",
            },
            ["0.4.17"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.17/xlings-0.4.17-macosx-arm64.tar.gz",
                sha256 = "2a4237ad4d05302e4af31591a7473cfcbd746077ccc049b92edbedf2dee8317c",
            },
            ["0.4.16"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.16/xlings-0.4.16-macosx-arm64.tar.gz",
                sha256 = "4548743163b8cf7f43ff14f6f4583b516e0b4c62dc824812754799af9836d0c8",
            },
            ["0.4.15"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.15/xlings-0.4.15-macosx-arm64.tar.gz",
                sha256 = "307b5c72d035ffdc87a77efcc0bdb349f68082a7148e7f3d0fb65a7ed03dd640",
            },
            ["0.4.14"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.14/xlings-0.4.14-macosx-arm64.tar.gz",
                sha256 = "fc8747e6fbd32bacb513b467e71fcd4eb5f3457be2eb77d0c18f6b26e2c160b3",
            },
            ["0.4.13"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.13/xlings-0.4.13-macosx-arm64.tar.gz",
                sha256 = "d64625801bba3a6895b3f61b9dd3e4fecac67d2fecfac7379693bf1f2298864d",
            },
            ["0.4.12"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.12/xlings-0.4.12-macosx-arm64.tar.gz",
                sha256 = "2350db515e3c326320a3404a36bf2a7b30705d89028e89130b9456d45c6ddf79",
            },
            ["0.4.10"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.10/xlings-0.4.10-macosx-arm64.tar.gz",
                sha256 = "3b45256592eddf9e47bcaea9e4856183e5d3714fd5684016c04fa7529f889b0f",
            },
            ["0.4.8"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.8/xlings-0.4.8-macosx-arm64.tar.gz",
                sha256 = "a3159b72315bd8f71294b3554c4bde991da857fa87a9aa047ef8abf516a5a94d",
            },
            ["0.4.7"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.7/xlings-0.4.7-macosx-arm64.tar.gz",
                sha256 = "f45df49073c9aba50f211c10954b90726fc747efd383c5cd178a8727a30e5fe1",
            },
            ["0.4.6"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.6/xlings-0.4.6-macosx-arm64.tar.gz",
                sha256 = "c8e653da23a2c56f508b53c4c60066db5cc13b3e45a5897a17630e3d188f76e2",
            },
            ["0.4.5"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.5/xlings-0.4.5-macosx-arm64.tar.gz",
                sha256 = "dd4995cb951c1c45e145b05a57406676590948469a367fd15ce51f2ee7f5e574",
            },
            ["0.4.4"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.4/xlings-0.4.4-macosx-arm64.tar.gz",
                sha256 = "7051d331451e3f1ce9c9a8f35f4e4f14fd96b30912bcc944d46333ca9b6b0b7d",
            },
            ["0.3.1"] = "XLINGS_RES",
            ["0.3.0"] = "XLINGS_RES",
        },
        windows = {
            -- res_versioned: version-bump bot tracks openxlings/xlings releases and
            -- appends new ["x.y.z"] = "XLINGS_RES" entries (see version-check.py).
            res_versioned = true,
            ["latest"] = { ref = "0.4.65" },
            ["0.4.65"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "aa37912dd708f14bd3f94e6ba1b062d330938270b2ffee4f6da28ae53d5c7850",
                },
            },
            ["0.4.64"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "9b76dd6d1f3f4f4d5054c158afcfbd62136dbcd8a860e87537b26c1fcc242b44",
                },
            },
            ["0.4.63"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "0ec7845bcc346439c46332676cb8430cea8384f31ee67256df5d58f38a08fe1c",
                },
            },
            ["0.4.62"] = "XLINGS_RES",
            ["0.4.60"] = "XLINGS_RES",
            ["0.4.55"] = "XLINGS_RES",
            ["0.4.54"] = "XLINGS_RES",
            ["0.4.53"] = "XLINGS_RES",
            ["0.4.52"] = "XLINGS_RES",
            ["0.4.51"] = "XLINGS_RES",
            ["0.4.50"] = "XLINGS_RES",
            ["0.4.49"] = "XLINGS_RES",
            ["0.4.48"] = "XLINGS_RES",
            ["0.4.47"] = "XLINGS_RES",
            ["0.4.46"] = "XLINGS_RES",
            ["0.4.44"] = "XLINGS_RES",
            ["0.4.43"] = "XLINGS_RES",
            ["0.4.42"] = "XLINGS_RES",
            ["0.4.41"] = "XLINGS_RES",
            ["0.4.40"] = "XLINGS_RES",
            ["0.4.39"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.39/xlings-0.4.39-windows-x86_64.zip",
                sha256 = "b6b83a6b627682023a07e7ceca7f6b757cb3a82eaba7bc4157081d1435e9d376",
            },
            ["0.4.38"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.38/xlings-0.4.38-windows-x86_64.zip",
                sha256 = "982b13a430597556fe824142a2af53cab26f52d787f80524cbe126a61d993295",
            },
            ["0.4.37"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.37/xlings-0.4.37-windows-x86_64.zip",
                sha256 = "5f8f341a1efaa89ed5d9df5ff0e77a1a58e6ee4270e7d9e299d8119557fea45a",
            },
            ["0.4.36"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.36/xlings-0.4.36-windows-x86_64.zip",
                sha256 = "959d75e8fbcba3f671670071342d57342823b67a518a6cf99251be9d768c74ce",
            },
            ["0.4.35"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.35/xlings-0.4.35-windows-x86_64.zip",
                sha256 = "944313bc644b15fbb5be8e15e4c7bdba1616940cb8e42c70953f7cb5e8a06936",
            },
            ["0.4.34"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.34/xlings-0.4.34-windows-x86_64.zip",
                sha256 = "8d7159309dca16153bd046cc226f3ce49966a1e8cfb6f6614695203e8185a595",
            },
            ["0.4.33"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.33/xlings-0.4.33-windows-x86_64.zip",
                sha256 = "e8fac2b9d22a626115b10376ebd325f8d9d703a9f494c02e3951c922cfb8a593",
            },
            ["0.4.32"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.32/xlings-0.4.32-windows-x86_64.zip",
                sha256 = "b03c60a150946f3f27ad3fe281732d29785f9950a4824748e54fe682f8495abd",
            },
            ["0.4.31"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.31/xlings-0.4.31-windows-x86_64.zip",
                sha256 = "9aeb660dc5a643b3edb3a150d06e2f2308737356ea4b07d03dffcbdc8ec3d0b7",
            },
            ["0.4.30"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.30/xlings-0.4.30-windows-x86_64.zip",
                sha256 = "d5ab6bf2e50457467a265b6284e0f169e7b1fca13b37c6b5254b98618c1d5542",
            },
            ["0.4.29"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.29/xlings-0.4.29-windows-x86_64.zip",
                sha256 = "03e8d7bbb3bf247cbad00781dbe43ae82a42527ac9ffd5d0e278ed0b3312f10f",
            },
            ["0.4.28"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.28/xlings-0.4.28-windows-x86_64.zip",
                sha256 = "1b6f85f48e0528a3965abb12dda71efd9becd07a49ca0ee73b863857e2e46864",
            },
            ["0.4.26"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.26/xlings-0.4.26-windows-x86_64.zip",
                sha256 = "11dd26f10817e347658ef449a66e311328db2a97d214caf31f390a9a5c2d209b",
            },
            ["0.4.25"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.25/xlings-0.4.25-windows-x86_64.zip",
                sha256 = "85c21d087113cd91bc78d07f84a7b70f3e0c67038955879d809c66787cbf94d1",
            },
            ["0.4.24"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.24/xlings-0.4.24-windows-x86_64.zip",
                sha256 = "9b96bbfb122806b3cef4e1f320f26feae0719dd5463ebaa92af3254e86f96929",
            },
            ["0.4.23"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.23/xlings-0.4.23-windows-x86_64.zip",
                sha256 = "57998a651466d8730bdbe018824a24ea3cdb3bae007c92c2b31ebf10c9a29354",
            },
            ["0.4.22"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.22/xlings-0.4.22-windows-x86_64.zip",
                sha256 = "14937c221c8daa51b2f7889531874cd2df3233bef379aabfc25ec2ca7bdd7289",
            },
            ["0.4.21"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.21/xlings-0.4.21-windows-x86_64.zip",
                sha256 = "06b6c6a4126111527a422cb73b5b7995d829150fa63d8d37adcd763f093df9a8",
            },
            ["0.4.20"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.20/xlings-0.4.20-windows-x86_64.zip",
                sha256 = "409aa41fc88b831439a8495e7846921e5cc0167ef0987618bcc2dcca80d358d0",
            },
            ["0.4.19"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.19/xlings-0.4.19-windows-x86_64.zip",
                sha256 = "7b1d4be51ea67137d5094eb85661b439b72ed320b13ebc7b36ba679aeb8222d3",
            },
            ["0.4.17"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.17/xlings-0.4.17-windows-x86_64.zip",
                sha256 = "34a2001fbd4a4211e7e658fe70f7476f41b769e8d9f637a8b561c8d93881c0ed",
            },
            ["0.4.16"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.16/xlings-0.4.16-windows-x86_64.zip",
                sha256 = "c57ca9a1ed45f80013f86e4db510a1b565bc146250e02b3a34d6813a93f723b6",
            },
            ["0.4.15"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.15/xlings-0.4.15-windows-x86_64.zip",
                sha256 = "894f2f462fa1d32fb2ca6df5acce460393dfd13b3803d78260cd48886d69dd9a",
            },
            ["0.4.14"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.14/xlings-0.4.14-windows-x86_64.zip",
                sha256 = "92ee06165f7b469ec78a34f5b5b9590d4500cf212e31b24c61f35c653695724a",
            },
            ["0.4.13"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.13/xlings-0.4.13-windows-x86_64.zip",
                sha256 = "6953fc974d241e72de0625d80b15b7250cb071a906a500da5b3c6b410c9df878",
            },
            ["0.4.12"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.12/xlings-0.4.12-windows-x86_64.zip",
                sha256 = "9d600b38a8897e772d6c787df95f9e6e0a13bff3f9c3729bf91ed2f6f66f9e62",
            },
            ["0.4.10"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.10/xlings-0.4.10-windows-x86_64.zip",
                sha256 = "fec7d922d96903b29bfaa59befb241ad87adc059d3f4f3a8dd64fbb46cc532a3",
            },
            ["0.4.8"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.8/xlings-0.4.8-windows-x86_64.zip",
                sha256 = "a1f28b904f79106156de43b5790f7b0338cab1371d2e0ff3eabf7a1636159b2b",
            },
            ["0.4.7"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.7/xlings-0.4.7-windows-x86_64.zip",
                sha256 = "13ecbdac25e5370b97812860aed058e86ac0be6c4a77ebd508a581d2a51172c5",
            },
            ["0.4.6"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.6/xlings-0.4.6-windows-x86_64.zip",
                sha256 = "ed20e4bf2f0b6e4a3c981e87d1c65cec60483350b17e7c5c0f57f1e497aaa8f7",
            },
            ["0.4.5"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.5/xlings-0.4.5-windows-x86_64.zip",
                sha256 = "46a62c229a6b729663e9068782f9ac9ea3b50ad193f8cdb159d90f1c43055d78",
            },
            ["0.4.4"] = {
                url = "https://github.com/openxlings/xlings/releases/download/v0.4.4/xlings-0.4.4-windows-x86_64.zip",
                sha256 = "45a1f6271d23d3386c713340069e8638559520d5bfc5517ef8eb33e1bea2b577",
            },
            ["0.3.1"] = "XLINGS_RES",
            ["0.3.0"] = "XLINGS_RES",
        }
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

function install()
    local xlingsdir = pkginfo.install_file()
        :replace(".zip", "")
        :replace(".tar.gz", "")
    os.tryrm(pkginfo.install_dir())
    os.mv(xlingsdir, pkginfo.install_dir())
    return true
end

function config()
    xvm.add("xlings", {
        bindir = path.join(pkginfo.install_dir(), "bin"),
    })
    return true
end

function uninstall()
    xvm.remove("xlings")
    return true
end
