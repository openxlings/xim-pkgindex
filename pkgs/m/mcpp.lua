package = {
    spec = "1",

    name = "mcpp",
    description = "A modern C++ build tool with module support, dependency/toolchain management, package indexing, and packaging",

    authors = {"sunrisepeak"},
    maintainers = {"https://github.com/mcpp-community/mcpp/graphs/contributors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/mcpp-community/mcpp",
    ci = { update = true },
    homepage = "https://github.com/mcpp-community/mcpp",
    docs = "https://github.com/mcpp-community/mcpp#readme",

    -- xim pkg info
    type = "package",
    archs = {"x86_64", "arm64", "aarch64"},
    status = "dev", -- 0.0.x: upstream is pre-1.0, expect breaking changes
    categories = {"build-tool", "cpp"},
    keywords = {"cpp", "c++", "build", "module", "package-manager"},

    programs = { "mcpp" },

    xvm_enable = true,

    -- Mirrored at xlings-res/mcpp (byte-identical to upstream
    -- mcpp-community/mcpp release artifacts, renamed to
    -- xlings-res convention `mcpp-<ver>-<platform>-<arch>.<ext>`).
    --
    -- XLINGS_RES sentinel resolves to:
    --   GLOBAL → github.com/xlings-res/mcpp/releases/download/<ver>/...
    --   CN     → gitcode.com/xlings-res/mcpp/releases/download/<ver>/...
    --
    -- Each tarball ships under `mcpp-<ver>-<platform>-<arch>/` and contains:
    --   bin/mcpp        — statically linked binary
    --   mcpp            — shell launcher → exec bin/mcpp
    --   LICENSE, README.md
    -- xvm registers `bindir = <install>/bin` so the binary is invoked
    -- directly; the shell launcher is only useful from the bundle root.
    xpm = {
        source = "xlings-res",
        linux = {
            -- res_versioned: version-bump bot tracks mcpp-community/mcpp releases
            -- and appends checked XLINGS_RES entries (see version-check.py).
            res_versioned = true,
            ["latest"] = { ref = "0.0.99" },
            ["0.0.99"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "2feb083cfc972eb8a334a5839403a3fa54508f85f3d06ce1830ac27157dfe823",
                    x86_64 = "16646379c9160d29506aa76a8fbb2d6c204c5b4f356aa207bbabd829e82b7e14",
                },
            },
            ["0.0.98"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "7e248944b177081dff736c121208194cd307d85a9559602b16f2147fdc3e02a7",
                    x86_64 = "e3af817de9170fa573c26d77e7740620c54f912d9a5f741e2783809e751efe9c",
                },
            },
            ["0.0.97"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "e8262ea830e5e309b0d3b24e10fd83ef739bdd02f1d02d42511b6d4670543f5d",
                    x86_64 = "733649448f287990c893b9238c1aff96a9c084bcc1209c17077402ed2f9d5cf4",
                },
            },
            ["0.0.96"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "aa1bc6836ab2d33327b818b9ca725724c6ffdae273dc451b9fd64742a55f1917",
                    x86_64 = "037b439b3bb87e95d1dbbbb0278582d8ae7f5f26179f799254f6a47142f3a966",
                },
            },
            ["0.0.95"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "af09cee1a87b6119f7936536112164ad64d00dff8d14a75554e8bf4d8ec06b9b",
                    x86_64 = "1361123edd7550b904d9ef4e38d4f9c74787b96534d70a398663a67ae1cdf75b",
                },
            },
            ["0.0.94"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "c2baeb6e4a91d0d22573652133054f4ddc3bd9f7a3cfc07e194188e1773c0fc6",
                    x86_64 = "820f351bb6a4615b1ff5df826fe722b22bba22fdeb269dfc20159aaef5b264f3",
                },
            },
            ["0.0.93"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "5ce8603a4aaa846a85f0b131f5509686aa302f3f3f1c9912e4eb7725a570f186",
                    x86_64 = "f54e9b2cba792614586fcd5b8ca60fbd50376ad6871a13c6ae20d431c8abae39",
                },
            },
            ["0.0.92"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "d05f317fabdf9bc81e3d082c89968ca24b6d90868514a153c01963b5495c1447",
                    x86_64 = "ebe1751e66d6e84a1a7072c761f0c395b4d933c26efeccf99649fc6985d154a1",
                },
            },
            ["0.0.91"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "e2d8e23d8539d6db8da5ccbaaa01acd8af251bf4f08aa31fea2495d034f8264d",
                    x86_64 = "4ae6575af5759c26acc50d1823546e123e4f598539dfb2081cffc18d0d563486",
                },
            },
            ["0.0.90"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "43451fbe9e8c5400ee9904fc4fd8ed29b8b7b47dfaad6e8f3f3625b2ba67c3ea",
                    x86_64 = "79d7df3c9c1e8b15daaee15642d4a8ad87166cf292c738c7ecfc3fdb09c4e985",
                },
            },
            ["0.0.89"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "163bc8fee60737fbeecfc8d570526c1dbe4f732e00af6d5b5d96a56dee23ea8e",
                    aarch64 = "c1abf178dce5c7ce49ea9842faf6fe157f54a6ad69eff7571c6598585bdf84cf",
                },
            },
            ["0.0.88"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "10cd54c675b038f70fa2700d822fc21e33432ed49a1c7f9575e8a439e3d555b3",
                    x86_64 = "cdfc10001d0fbfd5977993df1792e0f960ee8631604ba76e6f3535a2e91a3991",
                },
            },
            ["0.0.87"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "2130c29785e427bd888963408d2dcc1825696a229c3ff642adf52d5e08d5923e",
                    aarch64 = "acc5c2af4274a6c3ca69462f271d96d161ae68c9421a0ff5048add6077479a9b",
                },
            },
            ["0.0.86"] = "XLINGS_RES",
            ["0.0.85"] = "XLINGS_RES",
            ["0.0.84"] = "XLINGS_RES",
            ["0.0.83"] = "XLINGS_RES",
            ["0.0.82"] = "XLINGS_RES",
            ["0.0.81"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "47c41529a00930ad701a76bb53e0847220c0764eb1f8e6cf6d515c45fea8cfcc",
                    aarch64 = "27894adfdafd841436fb6c7342e81c107ae7131345bbb249e31483b0452ff5cc",
                },
            },
            ["0.0.80"] = "XLINGS_RES",
            ["0.0.79"] = "XLINGS_RES",
            ["0.0.78"] = "XLINGS_RES",
            ["0.0.77"] = "XLINGS_RES",
            ["0.0.76"] = "XLINGS_RES",
            ["0.0.75"] = "XLINGS_RES",
            ["0.0.74"] = "XLINGS_RES",
            ["0.0.73"] = "XLINGS_RES",
            ["0.0.72"] = "XLINGS_RES",
            ["0.0.70"] = "XLINGS_RES",
            ["0.0.68"] = "XLINGS_RES",
            ["0.0.67"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "db7d00564ec33b7ecd22e2294f805c0245b8107b42dd256e9db4e982e838a5a9",
                    aarch64 = "4690fcefbe356ecd090948899d30c1ca1904d34efc72217268d7113db87aa63a",
                },
            },
            ["0.0.66"] = "XLINGS_RES",
            ["0.0.65"] = "XLINGS_RES",
            ["0.0.64"] = "XLINGS_RES",
            ["0.0.63"] = "XLINGS_RES",
            ["0.0.62"] = "XLINGS_RES",
            ["0.0.61"] = "XLINGS_RES",
            ["0.0.60"] = "XLINGS_RES",
            ["0.0.59"] = "XLINGS_RES",
            ["0.0.58"] = "XLINGS_RES",
            ["0.0.57"] = "XLINGS_RES",
            ["0.0.56"] = "XLINGS_RES",
            ["0.0.55"] = "XLINGS_RES",
            ["0.0.54"] = "XLINGS_RES",
            ["0.0.53"] = "XLINGS_RES",
            ["0.0.52"] = "XLINGS_RES",
            ["0.0.51"] = "XLINGS_RES",
            ["0.0.50"] = "XLINGS_RES",
            ["0.0.49"] = "XLINGS_RES",
            ["0.0.48"] = "XLINGS_RES",
            ["0.0.46"] = "XLINGS_RES",
            ["0.0.45"] = "XLINGS_RES",
            ["0.0.44"] = "XLINGS_RES",
            ["0.0.43"] = "XLINGS_RES",
            ["0.0.42"] = "XLINGS_RES",
            ["0.0.41"] = "XLINGS_RES",
            ["0.0.38"] = "XLINGS_RES",
            ["0.0.37"] = "XLINGS_RES",
            ["0.0.36"] = "XLINGS_RES",
            ["0.0.35"] = "XLINGS_RES",
            ["0.0.34"] = "XLINGS_RES",
            ["0.0.33"] = "XLINGS_RES",
            ["0.0.31"] = "XLINGS_RES",
            ["0.0.30"] = "XLINGS_RES",
            ["0.0.29"] = "XLINGS_RES",
            ["0.0.28"] = "XLINGS_RES",
            ["0.0.27"] = "XLINGS_RES",
            ["0.0.26"] = "XLINGS_RES",
            ["0.0.25"] = "XLINGS_RES",
            ["0.0.24"] = "XLINGS_RES",
            ["0.0.22"] = "XLINGS_RES",
            ["0.0.21"] = "XLINGS_RES",
            ["0.0.20"] = "XLINGS_RES",
            ["0.0.19"] = "XLINGS_RES",
            ["0.0.17"] = "XLINGS_RES",
            ["0.0.16"] = "XLINGS_RES",
            ["0.0.15"] = "XLINGS_RES",
            ["0.0.14"] = "XLINGS_RES",
            ["0.0.13"] = "XLINGS_RES",
            ["0.0.11"] = "XLINGS_RES",
            ["0.0.10"] = "XLINGS_RES",
            ["0.0.9"] = "XLINGS_RES",
            ["0.0.8"] = "XLINGS_RES",
            ["0.0.7"] = "XLINGS_RES",
            ["0.0.6"] = "XLINGS_RES",
            ["0.0.5"] = "XLINGS_RES",
            ["0.0.4"] = "XLINGS_RES",
            ["0.0.3"] = "XLINGS_RES",
            ["0.0.2"] = "XLINGS_RES",
            ["0.0.1"] = "XLINGS_RES",
        },
        macosx = {
            -- res_versioned: version-bump bot tracks mcpp-community/mcpp releases
            -- and appends checked XLINGS_RES entries (see version-check.py).
            res_versioned = true,
            ["latest"] = { ref = "0.0.99" },
            ["0.0.99"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "53174ec6092e7d542facb7c0891683b01a69a87440f90e7d9e77f2185232dfd9",
                },
            },
            ["0.0.98"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "8da0407caf8075fa8cbf4ef12ae7ba8027a203b38d95d09c1d0d659d091d0450",
                },
            },
            ["0.0.97"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "adb0f2a5f5e7377b086387264e1b6d88d84ef6cada1c9790943492c8e94d1c03",
                },
            },
            ["0.0.96"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "30251bcd5201b912099380104091327e2acfbe3fad6ab6258a59f1fa2aa517cd",
                },
            },
            ["0.0.95"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "ccf753b958d3d1bc97b1f8430d2382f0f0b8ada2fcae0c89fc43ef719263d419",
                },
            },
            ["0.0.94"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "5cee6a962e4213c8e3861e2dd4efc9d19070c00fcc98e8fad96c65ef97e21f57",
                },
            },
            ["0.0.93"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "a6d2d1ed6165574b00e5f68e1815c33aa6053e1a68b03b55e6de2f0097214a5d",
                },
            },
            ["0.0.92"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "13c50318469e87c1592c2a6167f34adbcbf64af8148dfa4ccf69d673fce9c4aa",
                },
            },
            ["0.0.91"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "d864cb4e8d025c82df0488842ffb5f25246aecf45e8ed144c23032d1610343a6",
                },
            },
            ["0.0.90"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "35e83e5212796e01223688af9704e23b0b87c42696d86cb3a44412954945f5f7",
                },
            },
            ["0.0.89"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "9299d94c93ba7ac601becae52c67c8fb60850f6993c870a79b872124e33cd4e4",
                },
            },
            ["0.0.88"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "7169166a0533cb756f7f9ec7dd63e9ce4cadbb16090d789c86298767ed5c7df1",
                },
            },
            ["0.0.87"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "4b85c5600e4ac1c26eb88feedcf50bdfd5bfbc8ce2d3993585a1cf98cb115f12",
                },
            },
            ["0.0.86"] = "XLINGS_RES",
            ["0.0.85"] = "XLINGS_RES",
            ["0.0.84"] = "XLINGS_RES",
            ["0.0.83"] = "XLINGS_RES",
            ["0.0.82"] = "XLINGS_RES",
            ["0.0.81"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "a9678b69f39e536cd9bea861cca268956e04d1b573b6aa48ca4f193a218b28dd",
                },
            },
            ["0.0.80"] = "XLINGS_RES",
            ["0.0.79"] = "XLINGS_RES",
            ["0.0.78"] = "XLINGS_RES",
            ["0.0.77"] = "XLINGS_RES",
            ["0.0.76"] = "XLINGS_RES",
            ["0.0.75"] = "XLINGS_RES",
            ["0.0.74"] = "XLINGS_RES",
            ["0.0.73"] = "XLINGS_RES",
            ["0.0.72"] = "XLINGS_RES",
            ["0.0.70"] = "XLINGS_RES",
            ["0.0.68"] = "XLINGS_RES",
            ["0.0.67"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "8b851022a02f80062c3a4c752828d6c78a7be777e91a42287434219f8f8c8802",
                },
            },
            ["0.0.66"] = "XLINGS_RES",
            ["0.0.65"] = "XLINGS_RES",
            ["0.0.64"] = "XLINGS_RES",
            ["0.0.63"] = "XLINGS_RES",
            ["0.0.62"] = "XLINGS_RES",
            ["0.0.61"] = "XLINGS_RES",
            ["0.0.60"] = "XLINGS_RES",
            ["0.0.59"] = "XLINGS_RES",
            ["0.0.58"] = "XLINGS_RES",
            ["0.0.57"] = "XLINGS_RES",
            ["0.0.56"] = "XLINGS_RES",
            ["0.0.55"] = "XLINGS_RES",
            ["0.0.54"] = "XLINGS_RES",
            ["0.0.53"] = "XLINGS_RES",
            ["0.0.52"] = "XLINGS_RES",
            ["0.0.51"] = "XLINGS_RES",
            ["0.0.50"] = "XLINGS_RES",
            ["0.0.49"] = "XLINGS_RES",
            ["0.0.48"] = "XLINGS_RES",
            ["0.0.46"] = "XLINGS_RES",
            ["0.0.45"] = "XLINGS_RES",
            ["0.0.44"] = "XLINGS_RES",
            ["0.0.43"] = "XLINGS_RES",
            ["0.0.42"] = "XLINGS_RES",
            ["0.0.41"] = "XLINGS_RES",
            ["0.0.38"] = "XLINGS_RES",
            ["0.0.37"] = "XLINGS_RES",
            ["0.0.36"] = "XLINGS_RES",
            ["0.0.35"] = "XLINGS_RES",
            ["0.0.34"] = "XLINGS_RES",
            ["0.0.33"] = "XLINGS_RES",
            ["0.0.31"] = "XLINGS_RES",
            ["0.0.30"] = "XLINGS_RES",
            ["0.0.29"] = "XLINGS_RES",
            ["0.0.28"] = "XLINGS_RES",
            ["0.0.27"] = "XLINGS_RES",
            ["0.0.26"] = "XLINGS_RES",
            ["0.0.25"] = "XLINGS_RES",
            ["0.0.24"] = "XLINGS_RES",
            ["0.0.22"] = "XLINGS_RES",
            ["0.0.21"] = "XLINGS_RES",
            ["0.0.20"] = "XLINGS_RES",
            ["0.0.19"] = "XLINGS_RES",
            ["0.0.17"] = "XLINGS_RES",
            ["0.0.16"] = "XLINGS_RES",
        },
        windows = {
            -- res_versioned: version-bump bot tracks mcpp-community/mcpp releases
            -- and appends checked XLINGS_RES entries (see version-check.py).
            res_versioned = true,
            ["latest"] = { ref = "0.0.99" },
            ["0.0.99"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "265017a96eda114568781ce8a4ed6feaccebe2efe73c88d8a169b2817aea02e0",
                },
            },
            ["0.0.98"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "775e067236a472e982e14cd5d006292caf87bc95d60d0915d37d1f7d2e6298b5",
                },
            },
            ["0.0.97"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "45c52343bca1e7ffea232e5023cf0e8cfd7377688d3bd4ef71eb58d46de3fa71",
                },
            },
            ["0.0.96"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "821ecf4e2db18c5bd152a8fe1c3e9c2e8ac6ef72ffa239a538637acb87ad2382",
                },
            },
            ["0.0.95"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "b7a656c22d6a14fd5da6232fc062f9d642911cffda4557b52ba9008ed713aa2f",
                },
            },
            ["0.0.94"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "e42de624f8c0a94d68f3278529792d5690fae3180fccdb478128fb5e3872bdc3",
                },
            },
            ["0.0.93"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "5e6483878587fc22c76d4dec52a076a4d5420858b0569333d8ea40b8f4723081",
                },
            },
            ["0.0.92"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "b41014f67514c4aedf2e5f170b01412a1565067e46cd8306b8fd89ff1ac7a7ec",
                },
            },
            ["0.0.91"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "6823685a12df1b6f74c6932fc0028a64a8fa08ac5081ef1795c24be0570e0d98",
                },
            },
            ["0.0.90"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "3aff54e0bd16975c1adc101962d5feb6f158679c6c8704e9531a57a9aa6770e9",
                },
            },
            ["0.0.89"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "575058be33246d051734698b517b211787ccb6029598b70eaa0d502d3d4306d5",
                },
            },
            ["0.0.88"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "9c5e52beb1f866ab3edc40a24a12c8ff620540764d6eb1432f62097039c59a06",
                },
            },
            ["0.0.87"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "5fa21e75b3212614877c50d9aa3f230b6c5b68fe8fab46e1e46eb48729985929",
                },
            },
            ["0.0.86"] = "XLINGS_RES",
            ["0.0.85"] = "XLINGS_RES",
            ["0.0.84"] = "XLINGS_RES",
            ["0.0.83"] = "XLINGS_RES",
            ["0.0.82"] = "XLINGS_RES",
            ["0.0.81"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "19ce6993fa82043a9e79448635547f6127624568893fdd8e12e71b9e7d78bb43",
                },
            },
            ["0.0.80"] = "XLINGS_RES",
            ["0.0.79"] = "XLINGS_RES",
            ["0.0.78"] = "XLINGS_RES",
            ["0.0.77"] = "XLINGS_RES",
            ["0.0.76"] = "XLINGS_RES",
            ["0.0.75"] = "XLINGS_RES",
            ["0.0.74"] = "XLINGS_RES",
            ["0.0.73"] = "XLINGS_RES",
            ["0.0.72"] = "XLINGS_RES",
            ["0.0.70"] = "XLINGS_RES",
            ["0.0.68"] = "XLINGS_RES",
            ["0.0.67"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "60941ad9e1ff0b9fcc93c291d7accbb07f1b008285fc4f9d7c8e5375015e810f",
                },
            },
            ["0.0.66"] = "XLINGS_RES",
            ["0.0.65"] = "XLINGS_RES",
            ["0.0.64"] = "XLINGS_RES",
            ["0.0.63"] = "XLINGS_RES",
            ["0.0.62"] = "XLINGS_RES",
            ["0.0.61"] = "XLINGS_RES",
            ["0.0.60"] = "XLINGS_RES",
            ["0.0.59"] = "XLINGS_RES",
            ["0.0.58"] = "XLINGS_RES",
            ["0.0.57"] = "XLINGS_RES",
            ["0.0.56"] = "XLINGS_RES",
            ["0.0.55"] = "XLINGS_RES",
            ["0.0.54"] = "XLINGS_RES",
            ["0.0.53"] = "XLINGS_RES",
            ["0.0.52"] = "XLINGS_RES",
            ["0.0.51"] = "XLINGS_RES",
            ["0.0.50"] = "XLINGS_RES",
            ["0.0.49"] = "XLINGS_RES",
            ["0.0.48"] = "XLINGS_RES",
            ["0.0.46"] = "XLINGS_RES",
            ["0.0.45"] = "XLINGS_RES",
            ["0.0.44"] = "XLINGS_RES",
            ["0.0.43"] = "XLINGS_RES",
            ["0.0.42"] = "XLINGS_RES",
            ["0.0.41"] = "XLINGS_RES",
            ["0.0.38"] = "XLINGS_RES",
            ["0.0.37"] = "XLINGS_RES",
            ["0.0.36"] = "XLINGS_RES",
            ["0.0.35"] = "XLINGS_RES",
            ["0.0.34"] = "XLINGS_RES",
            ["0.0.33"] = "XLINGS_RES",
            ["0.0.31"] = "XLINGS_RES",
            ["0.0.30"] = "XLINGS_RES",
            ["0.0.29"] = "XLINGS_RES",
            ["0.0.28"] = "XLINGS_RES",
            ["0.0.27"] = "XLINGS_RES",
            ["0.0.26"] = "XLINGS_RES",
            ["0.0.25"] = "XLINGS_RES",
            ["0.0.24"] = "XLINGS_RES",
            ["0.0.22"] = "XLINGS_RES",
            ["0.0.21"] = "XLINGS_RES",
            ["0.0.20"] = "XLINGS_RES",
            ["0.0.19"] = "XLINGS_RES",
            ["0.0.17"] = "XLINGS_RES",
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

local function mcpp_bin()
    local exe = "mcpp"
    if os.host() == "windows" then
        exe = "mcpp.exe"
    end
    return path.join(pkginfo.install_dir(), "bin", exe)
end

local function ensure_runtime_dir()
    if os.isfile(mcpp_bin()) then
        return true
    end

    local archive = pkginfo.install_file()
    local mcpp_dir = archive
        :replace(".tar.gz", "")
        :replace(".zip", "")
    local runtime_dir = path.join(path.directory(archive), path.filename(mcpp_dir))
    if os.isdir(runtime_dir) then
        mcpp_dir = runtime_dir
    end
    os.tryrm(pkginfo.install_dir())
    os.mv(mcpp_dir, pkginfo.install_dir())
    return os.isfile(mcpp_bin())
end

function install()
    return ensure_runtime_dir()
end

function config()
    ensure_runtime_dir()
    xvm.add("mcpp", { bindir = path.join(pkginfo.install_dir(), "bin") })
    return true
end

function uninstall()
    xvm.remove("mcpp")
    return true
end
