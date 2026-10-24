package = {
    -- Platform version sets differ ON PURPOSE: macOS and Windows builds of the
    -- window start at 2026.10.15.1; Linux carries the releases before it.
    platform_versions_diverge = true,
    spec = "1",

    name = "luban-os",
    description = "Luban OS: the systems of this home in a window -- a list, then a system's console or desktop, and a management panel",

    homepage = "https://github.com/openxlings/xlings",
    repo = "https://github.com/openxlings/xlings",
    licenses = {"Apache-2.0"},

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"desktop", "luban", "gui"},
    keywords = {"luban", "luban-os", "desktop", "window", "machine", "subos"},

    -- The Luban OS window (xlings: Luban OS architecture design §14), released
    -- with xlings at the same date version (openxlings/xlings,
    -- tools/luban_os_release.sh; mirrored to xlings-res/luban-os). It opens a
    -- window, so unlike xlings and luban it is not static: it links glibc and
    -- X11 (through SDL), which these dependencies are, and an install patches
    -- it onto them. It drives the xlings and luban of the home it is installed
    -- in. config() adds its desktop entry (~/.local/share/applications). Its
    -- fonts are luban-fonts' (share/fonts/luban), on every system.
    --
    -- It draws on the GPU through the graphics stack, as every package that
    -- opens a window on Linux does: SDL dlopens libEGL/libGL, and on the
    -- loader of this home it finds neither the host's nor any other. Without
    -- the stack SDL falls back to its software renderer without a word -- a
    -- desktop view took 47% of a core for a moving pointer (RTX 4080; 2% on
    -- the stack). Three things together, any one missing is that fallback
    -- again: the stack's libraries on the RPATH (the deps below), the stack's
    -- discovery variables on the shim (graphics.consumer_envs()), and the
    -- desktop entry starting the shim, not the payload.
    programs = {"luban-os"},
    xvm_enable = true,

    -- How it is checked (xlings design 2026-10-21 §6.1): luban status --check runs
    -- `run` and `launcher`; a desktop session (luban-os-ci L3) the rest.
    extensions = { luban = { checks = {
        { id = "luban-os-runs", what = "the Luban OS app starts", run = "luban-os --version", timeout = 20 },
    } } },

    xpm = {
        linux = {
            deps = {
                "xim:glibc@>=2.44",
                "xim:gcc-runtime",
                "xim:libX11@>=1.8",
                "xim:libxcb@>=1.17",
                "xim:libXcursor",
                "xim:libXext@>=1.3",
                "xim:libXfixes",
                "xim:libXi",
                "xim:libXrandr",
                "xim:luban-fonts",
                -- The stack, and what it declares for its consumers. Lower
                -- bounds: the stack moves on its own.
                "xim:graphics@>=0.1",
                -- What the program loads itself, declared here because elfpatch
                -- puts a package's OWN dependencies' libraries on its RPATH,
                -- not theirs: SDL dlopens libGL/libEGL (glvnd's dispatch), and
                -- the vendor libraries glvnd then opens -- the host's NVIDIA
                -- ones through the bridge, D3D12 on WSL -- find their own
                -- dependencies on this program's RPATH. mesa is also asked for
                -- by config() (godot.lua says why).
                "xim:mesa@>=25",
                "xim:libglvnd@>=1.7.0.1",
                "xim:nvidia-gl-host-link@>=0.1.2",
                "xim:wsl-gl-host-link@>=0.1",
                -- The pointer a desktop names, drawn by the window from the
                -- Luban theme (xlings design 2026-10-19 §15.2; read from
                -- 2026.10.19.2, before which nothing uses it).
                "luban:cursors",
            },
            ["latest"] = { ref = "2026.10.24.2" },
            ["2026.10.24.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "e0f1ac73a2b745a01cb8303d968027f966e597ceffb50e429d74e78084d4669b",
                },
            },
            ["2026.10.24.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "81f25647f3ea28ec75a29a0b60ef096f3c7adc29f07c6b7ecc66f5e22073f7ce",
                },
            },
            ["2026.10.23.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "50636999ee8dcfffa5403505b10fe64e9df3b1d4a157acae4118d018ec731932",
                },
            },
            ["2026.10.23.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "7a99ef30384b8e58dd8f2f6be626abaa13a349b08bdf6d173c7ca0b9b7ece0ff",
                },
            },
            ["2026.10.22.4"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "3c0800fd89471793bbd01cb9cfbc17db1de0c5ea6ef686024fe3f217f559f462",
                },
            },
            ["2026.10.22.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "a7f24356c8f6604eea9cbf5ebe0dd64eef0cbe5b03ce6e5dfbfd47b5101c8c10",
                },
            },
            ["2026.10.22.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "bd84f76d050a1af94eae9365f35beacc76e445fa97f52de6388137d6a199c738",
                },
            },
            ["2026.10.22.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "8b6235452218ceb629a755728ee16512189706e3fc21189778c47e7d06027200",
                },
            },
            ["2026.10.21.4"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "a08a2994343e496b99d31b068aa50e1777380a411ae0d9b5f36b9a7131de3836",
                },
            },
            ["2026.10.21.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "73019a11b67382a7f3542b44d2759780520b3e6a8269954193d0a9817aa3768a",
                },
            },
            ["2026.10.21.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "7ffe029634685c8d487c45f3ec8331cc067464d660133b7807676efc260b251e",
                },
            },
            ["2026.10.21.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "4b46164cba854659637a2f6b905355dc5223eb9b6f3f9a78965725123e35240b",
                },
            },
            ["2026.10.20.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "477f96701d19a115e12444f3a79108696199a7e53fb557308f5198464ec43c7f",
                },
            },
            ["2026.10.20.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "c791c222f62a6692f462721ca3e75d508b7cece42cd1a597a5cc418d00d00860",
                },
            },
            ["2026.10.20.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "d0bcd0dcfbe88139d041f489c6181ffd32a79c083bd1fa9ff16992a973f062b2",
                },
            },
            ["2026.10.19.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "e38128cf95da94b4dce71d258c77c76d0869e876f88c4e64f851385a8eb643e2",
                },
            },
            ["2026.10.19.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "bfce62ec656df55f3fa0d004b4e12c802fee59ba469b87c95595a81e9d96d1bf",
                },
            },
            ["2026.10.18.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "ce613194b79fe5b4eb19bb0af2d2ea38081badd79e09c708bd1054b81868fb73",
                },
            },
            -- Revision 1: the graphics stack (deps above, config()). xlings
            -- replaces a payload of revision 0 on its next install.
            ["2026.10.17.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "ff0cfefd91f8bcdfebf9f4b30ec364f5323a2d7e7a783a005f911128205e755c",
                },
                revision = 1,
            },
            ["2026.10.16.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "b8226b4686683fa308bbdf1f5f2b92fe5dc0e66c7424626c60a3489e3a3712fb",
                },
            },
            ["2026.10.16.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "4e40066176c879c8db819d6014918e18073612f56b4b8f603db190c15ec76ec2",
                },
            },
            ["2026.10.15.4"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "440f04b0d0fec2e3ccdd5ecd570b1e6a2acd7c123584c64ca998f06389260206",
                },
            },
            ["2026.10.15.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "0736faecbab6f0629ac506478c88039bea2df1654876d139e311149e835dce60",
                },
            },
            ["2026.10.15.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "fb4aacac1c1bcdab2ed35cfa299fd162e2b58178e355660f4a5658f7564e2712",
                },
            },
            ["2026.10.15.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "67040e3a2d0b8417c17856d682b55448319a7cec4f91df34f6eb0153980ff761",
                },
            },
            ["2026.10.13.4"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "3894e9abf4893256b2ec69485d46f46333a199ab9ced3dc1245dbaa8a0ea0148",
                },
            },
            ["2026.10.13.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "fd3b3c5e562ab65dd53b963b22c1e71d85d037adecb7edeed528e5c9b3594f2e",
                },
            },
            ["2026.10.13.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "009fc85fcdf352692fa5eccbb4c8c514f52caf439622d5ee1cb41a7672da2aa2",
                },
            },
            ["2026.10.13.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "1d493a67f52c09fb14eca43b37185b10a89e9f1ed0acd8ad7ef9224a88e07d2a",
                },
            },
        },
        macosx = {
            deps = { "xim:luban-fonts", "luban:cursors" },
            ["latest"] = { ref = "2026.10.24.2" },
            ["2026.10.24.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "34d398dc27be07613c49ee39e7171289daf469ca46272987b2bfc6064ee6d232",
                },
            },
            ["2026.10.24.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "2eb8baf094debaf05d17d7d5803473569a1a7801d32169d595882892767a648f",
                },
            },
            ["2026.10.23.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "df4ee185418e6b058feb1661d3f8b838b59b8a18ddd37f8a6e645858d3631cbb",
                },
            },
            ["2026.10.23.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "417a3f76fb3740fafa6f6a0a15420c58625b94ac6f515c27cb8a77cdd9323f5a",
                },
            },
            ["2026.10.22.4"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "ceb0115ec0675811bbccc2faf8160a1459e62ddcaeefca0e4e5e5ca4ec05eff2",
                },
            },
            ["2026.10.22.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "4fc225db5ec7eb10c9233a0a6fc12ba9aa174a4559a0a734ba8f43a07042c666",
                },
            },
            ["2026.10.22.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "bea264664061452f36d00eb94b4c61e569d8c92846ef649a42f2f41cbea67bce",
                },
            },
            ["2026.10.22.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "ad190fa8fcf1d476e3fcb2db118fa979d8d6a6948984209f7028ebcd1bbe7d5e",
                },
            },
            ["2026.10.21.4"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "4a2b27fbea0c4656d8af9af4b7c56a8cec95c8b92dfe67f03d96fa830a5edbf7",
                },
            },
            ["2026.10.21.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "5179975e7776e0d29c23c2a3441d631e8ad74535d95e93a589b0d595667274d8",
                },
            },
            ["2026.10.21.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "2f592f0718ede9c5e48524c93da94ca14d09d452f8da5220fc2702dd38249934",
                },
            },
            ["2026.10.21.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "e04226ce9b242f631d38fc3471db4d8c1ab9f7d06bdec5eda244782784c004f1",
                },
            },
            ["2026.10.20.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "e320478ed24b1c887aae01ada43180ffa8737b80490d167c46028563c7c63bc8",
                },
            },
            ["2026.10.20.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "a19f97aafa37eedb5a376ecf7fc1f3c5ba550f748165242a7d3a1ee35b756226",
                },
            },
            ["2026.10.20.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "e416ad2a2ecd0886c5e7371733cf8b08940522a99900574c45345e5eb4d5c5b1",
                },
            },
            ["2026.10.19.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "5d39824b7dadd1a5005197ebceec30ae92f3af02e397469f2b28d5dfb2ca032f",
                },
            },
            ["2026.10.19.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "da5f39e345530de088901f2bdfecebc2c4dd5d7fa69f54d598bfde07c967b974",
                },
            },
            ["2026.10.18.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "a72b6a2e5c1f70d1475631a996f5da9bee06f98e555597c7f752ff9fcbd5654b",
                },
            },
            ["2026.10.17.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "12c6a11726e2026ee177ee7b06c7c6f7dcad1bda273f524a940db93a509a56ff",
                },
            },
            ["2026.10.16.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "99582cada89d6cf9c3f67821ace299e4147ab6bec82719b2d1b531d4ed496cbf",
                },
            },
            ["2026.10.16.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "05aeab5f02b2c91783cd2dc065245b81d7039266d0d3f90db0eb87414e42a4ec",
                },
            },
            ["2026.10.15.4"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "151a31993f6b65a63deb10665c4a4559ea386bbf74c203085d8064d05586aa01",
                },
            },
            ["2026.10.15.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "02bcc5f9beab53abeecdaf8fed47c5c4176b924d248182628c700d7478f68801",
                },
            },
            ["2026.10.15.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "9be453ef4279f00b9799e329ed0376edb81788f13587da5c99997fd371a95a0a",
                },
            },
            ["2026.10.15.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "31dd65de8156e09eb1a388a99c9abc2d410b72c4c227f984bcd628ef487b8fad",
                },
            },
        },
        windows = {
            deps = { "xim:luban-fonts", "luban:cursors" },
            ["latest"] = { ref = "2026.10.24.2" },
            ["2026.10.24.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "c0781876ca539617ecc0c63002537d6d39408ee0a59e38be39588f29387c7f75",
                },
            },
            ["2026.10.24.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "2eaacacf3f5f4ce2057d543078550ab8922e57918c83a8c4c27df6047cee028f",
                },
            },
            ["2026.10.23.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "97853d82efe053ef4377850d2189d575aac2ce8b588d65a6e0408c17d1483dab",
                },
            },
            ["2026.10.23.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "e86a0813f9e5a14353c5a2af6fbd67daa4debd1964bf792b2f57d7210dcfee5c",
                },
            },
            ["2026.10.22.4"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "a2f07ece8538c807695ad71e69b9f4f35e4a83d56995ef6f3798d917606b3548",
                },
            },
            ["2026.10.22.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "e974b891ff72426e91ccb0c9968eb13a76c5d6dbb25891fc75624dff634bfa9b",
                },
            },
            ["2026.10.22.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "0958884337bb99de84203a65a7e8b0cc975bff5545c757df73458fd6c8ba39a9",
                },
            },
            ["2026.10.22.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "479f07261e0e7b60816edf6db35566852b8e4f87bc8773a6da57dbb304911330",
                },
            },
            ["2026.10.21.4"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "c9a4fae56171529a84d0c9aa72f10201cc2400367269774e60d17f916037c096",
                },
            },
            ["2026.10.21.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "b40771296bfb266159a0bf48e46571ad54da8dee3bfa2bedc7ba73447befe0e8",
                },
            },
            ["2026.10.21.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "3c45c5ec121a9669e2c467e2177be7aee0aa651fefe9b6f1f0da261c52424ae5",
                },
            },
            ["2026.10.21.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "f90dc1ed30d8a3c39f6e9e100bf96b510311939a380da2664254ee9b8601570d",
                },
            },
            ["2026.10.20.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "4838fb838c2e973d5d9d81a065d9fa7df6c889d7b76aa640ef886bc75e0f9970",
                },
            },
            ["2026.10.20.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "e06b1bc4ca3119a8a0576f1a64b7f2cb487358a1f41f8a27d0a1950abff4cd92",
                },
            },
            ["2026.10.20.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "cc2daab3c23ec7d461a1326fd3d1f2acd5c553594263a3ad1f2d5903d39f17a9",
                },
            },
            ["2026.10.19.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "eac94892d422881d141ff38f43ed822df19c4436b8c80561b186e55aabf939c6",
                },
            },
            ["2026.10.19.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "220786743d7cf3fbc276e464b626244624d8ddb251c654aa4715fe3d7fc96492",
                },
            },
            ["2026.10.18.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "42ea88619f4580efee67086726a4d7c8f4213f5700d7a53157fdbee198df85da",
                },
            },
            ["2026.10.17.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "71aa2ac6d1450587c0d7e66873768abda92f927c9bc5dafc69e1b8cb34b3b27f",
                },
            },
            ["2026.10.16.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "5356a037cd2c026f4a5d6f12c2570d40d04e4aa554183d44ab58feaccdb6dab7",
                },
            },
            ["2026.10.16.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "bce9b7e10735e44270e39bc1792b51308f493f4714a7506dc9612099eca4fb47",
                },
            },
            ["2026.10.15.4"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "54a041d886db6b7ccd9dc4ad59af36262c18d296d525cbb856a26d40a1335247",
                },
            },
            ["2026.10.15.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "9c9165dd72aa7bf60f141423ca25c3a1d8762513d89dc3677ac8138643e56a27",
                },
            },
            ["2026.10.15.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "15011fa3b54f500dcc09ddd1ceccf1678b3f501c99fb378c0291b689d202e642",
                },
            },
            ["2026.10.15.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "7534dca161db18f4589998ac1f3ab57d87096feae177705c289d3955aa5aeee6",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")
import("xim.libxpkg.system")
import("xim.pkgindex.graphics")

-- bin/luban-os (bin/luban-os.exe on Windows): the payload extracts into
-- luban-os-<version>-<os>-<arch>/, a .tar.gz on Linux and macOS, a .zip on Windows.
local function exe()
    return is_host("windows") and "luban-os.exe" or "luban-os"
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

local function entry_file()
    return path.join(os.getenv("HOME") or "", ".local/share/applications", "luban-os.xvm.desktop")
end

-- The stack is in this home when mesa's payload is: then its discovery
-- variables name directories something fills. Pointed at an empty subos
-- directory, mesa would fall back to software without a word.
local function have_stack()
    local mesa = pkginfo.dep_install_dir and pkginfo.dep_install_dir("xim:mesa") or nil
    return mesa and mesa ~= "" and os.isdir(path.join(mesa, "lib"))
end

function config()
    local dir = pkginfo.install_dir()
    local node = { bindir = path.join(dir, "bin") }
    if is_host("linux") and have_stack() then
        node.envs = graphics.consumer_envs()
    end
    xvm.add("luban-os", node)
    -- The host's application menu (a freedesktop one: Linux): the window of this home.
    if is_host("linux") and os.getenv("HOME") then
        local home = os.getenv("XLINGS_HOME") or path.join(os.getenv("HOME"), ".xlings")
        -- The shim, which carries the stack's variables; the payload where
        -- this client does not say where the shims are.
        local shim = system.bindir() and path.join(system.bindir(), "luban-os")
        local exec = shim or path.join(dir, "bin", "luban-os")
        local entry = string.format([[
[Desktop Entry]
Type=Application
Name=Luban OS
Comment=Your Luban OS systems: start one, or manage them
Exec=env XLINGS_HOME=%s %s
Icon=%s
Terminal=false
Categories=System;Emulator;
StartupWMClass=luban-os
]], home, exec, path.join(dir, "share/icons/hicolor/scalable/apps/luban-os.svg"))
        os.mkdir(path.join(os.getenv("HOME"), ".local/share/applications"))
        io.writefile(entry_file(), entry)
        log.debug("desktop entry %s", entry_file())
    end
    return true
end

function uninstall()
    os.tryrm(entry_file())
    xvm.remove("luban-os")
    return true
end
