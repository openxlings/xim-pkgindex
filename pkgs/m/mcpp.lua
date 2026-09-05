package = {

    -- Platform version sets differ ON PURPOSE:
    -- the early 0.0.x entries are linux-only -- macOS and Windows builds begin later in the series.
    -- Declared so `tests/check_platform_version_parity.lua` can tell this
    -- apart from a bump that landed in one section and was forgotten in the
    -- others -- which reads as `<pkg>@<ver> not found` on the platforms that
    -- lack it, against a file that contains the version string.
    platform_versions_diverge = true,
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
            ["latest"] = { ref = "2026.9.5.3" },
            ["2026.9.5.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "9268478fdf8aa2030d9ad2873232ad0fce94a93d574f6c6c4e28c1b7ed606ff8",
                    x86_64 = "64a7b142ebc5c2605092bb7ceabae3a5e4145be53daababb7e6dd0263d6c470a",
                },
            },
            ["2026.9.5.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "c951346b51e7e6235b5feef40f48eb9e5d98d9ea6837a4f94e3361db6f78d278",
                    x86_64 = "64108849010d79656ac2231e974d2c6e9ccbf55fd5d011153e7bd37aa9f925ab",
                },
            },
            ["2026.9.5.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "95023236d1d09d775b2b26b0b88f7bcf2802ffd89998bb7aa2b1af1b62191b07",
                    x86_64 = "3c45aa236592c944968d370b84b12492c0f5744a84fea8cd43dacbf7fdef7c4f",
                },
            },
            ["2026.9.4.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "a216acdff1195907edfd8493c220a21d4cecb3e0c283446a84d9c727d6b09e77",
                    x86_64 = "2cda8629e0e8c9fad34c70ac8dd0e60ae4621ace0a18c29e79acba94b05a12cb",
                },
            },
            ["2026.9.4.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "3c1764d937a5972525df4c2d3d1381671f0035148f7089daa53a585c2aa11e02",
                    x86_64 = "118215911f019356a06d8db6e540f580d6195b9bbbc73b6816bc48aecca42a34",
                },
            },
            ["2026.9.4.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "a276465dacbc9a791766c0a6a1b64650704be50d8335c3876e5b07a135e72235",
                    x86_64 = "0554e3f4039d337c3eb974ac4d957c3660d6edb1b5287faf5af56856f71b0fb7",
                },
            },
            ["2026.9.3.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "97cae340690f9146df9e256c877abf7fbb995e148bd2667f99d43a3244b1b463",
                    x86_64 = "5c4c514db2dfa0f2ea2ae92f47d20e3568e846c78a8a00ed8d3ec56ad8080d4f",
                },
            },
            ["2026.9.3.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "9eeef8764483010430138a4b8d42f7371f0f7ebc40cdd6a982b35a257e558199",
                    x86_64 = "7b9ffbb71fbb703203ae3b7558d3b37178fe414c857ea230a7c51dd081e6ad4c",
                },
            },
            ["2026.9.2.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "45056785d39d4673d5195f5bb04df25f63ca2a2a7ed0c5d4e00b2514de361782",
                    x86_64 = "64bd391aecc16423e92bd78ed11e72b2d12f5110744b20d6a8014265dad736da",
                },
            },
            ["2026.9.1.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "d506fef975b51a96c2ee133c66d819d2650f36cc91c630d27bd269d9fa891303",
                    x86_64 = "68417d3bff7cadb554bc1434b49884bac69a8f53af970e39d3ec9721292d4847",
                },
            },
            ["2026.8.30.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "68a7219b2e398dd9ce4dab71a727d786e47f451a9ef5e1b985fa261838d6f887",
                    x86_64 = "5ea55cc7deeae75e9927a1de05ab6fdfba877d52ed7a641e02530a5c9e4bc494",
                },
            },
            ["2026.8.30.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "ad6440629aace3468ef48fe0199802f9bf86882853efd602bfa63bc279f403a7",
                    x86_64 = "12d75edbfe4e34b004942970a40834907f7905f895409954fd6efc27639e6fa4",
                },
            },
            ["2026.8.29.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "7c6de8c99868261edbe7cf2a2d73166cfb2e8a0d82d34b5e820f87f493a224a3",
                    x86_64 = "6d83c4a65238f84d2bdd952f7469477f918a1a9e1f1473bca56ebb697fd972a9",
                },
            },
            ["2026.8.28.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "903edec9baa714b1126532c186c2ca14d32dd7abff8e847b71b53c033591f560",
                    x86_64 = "a35aecf16ca4aeb0a6aa76b1e6875f9d98aa1d7e643cae0884a77eb34dac2f9a",
                },
            },
            ["2026.8.28.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "27b5d988ff94d2edddb12269571a2bcd3e18c3f294e2439483fff5c35d2e3b6e",
                    x86_64 = "9e55c8b41cc2ec479807095f6fb39dca11a3ed41b686ffa905ca5f8bb8e34ee9",
                },
            },
            ["2026.8.27.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "3dc7e0926f337aea6bdd3f8ddd1b987897901abf4f9990d9da6c3c67696a9c34",
                    x86_64 = "aea30cb4894bf0099f7903ce9ccaf02dbb019e6c24825f78d65de5de306751a9",
                },
            },
            ["2026.8.27.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "f0e331d05380cbccb1e1a1858c2afdb6855eef8ad78b7f40b1a71e3cae86b2c3",
                    x86_64 = "9c7c0c4b69afe66c54fe97121dbe509a6ed6039f248ecc5355ee0cf5a56808db",
                },
            },
            ["2026.8.26.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "3b3b5cc05ddbcb84ff9c6aade079ef2ac4dea5a4ee50f488398742ef79b6a6c0",
                    x86_64 = "aad70c63d716adfae5e09ad83198731578db1dc24437946bf17e3933b42c557c",
                },
            },
            ["2026.8.26.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "6881bafe2d339089a4453d36662419b32f833351646ce1fc542ebdd30139d51b",
                    x86_64 = "d649b820b30292ce80656e8b5e3ff98ecbb091143e21266cb73c42820ed23639",
                },
            },
            ["2026.8.25.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "2247420332401e94a94915ec676505081d0aec2da5adfb88d70a2afca9df0d43",
                    x86_64 = "612cdd0d49ff511fc505b96dea340d776515a92c9f629a397223a82699694129",
                },
            },
            ["2026.8.25.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "d9fea48d32082d87ef6101bc6be45826ae80c154dcba5241367724f001616320",
                    x86_64 = "147d541649c515dfcf9b7883730eb268a173298f58c9fd9aced706251f05004c",
                },
            },
            ["2026.8.24.6"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "6c7064ca17d0b0ba9d300e1f2ddb87623dc7bf7fc07e8eca24a25d7e4fbf7dd6",
                    x86_64 = "69424c3ac29747e6511f39c29ec1e3c8ffe673acfa7c93f6d8033e64ae3b90c2",
                },
            },
            ["2026.8.24.4"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "1c9d79169635e35e5147ec3820f38136a5a6ddbd2642834ba833515f718563f5",
                    x86_64 = "916993749aec4b29e6228f66c4c1f5e82eb1dfb17d3f90c079acc41a4310f844",
                },
            },
            ["2026.8.24.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "2834d015bfae09e20e5e22dc4a113c02611fbe126e692f49863f0f856595399f",
                    x86_64 = "0c023b879b77b596e52091c9f72f5f90c8ee5ac9274169c4ecbe244bd541b3f0",
                },
            },
            ["2026.8.24.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "5c5a44801567a972f3f04a9f4758985e93492ca50e297085a851aa7ba45c4dcb",
                    x86_64 = "f1004ebe68f4cf48daa8ae5675c8cbfbd0f8a242abdebbd3779eebc175e6bd66",
                },
            },
            ["2026.8.24.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "5c6dab50fb5ceefcbc836c9c51f1d33fac9e955eab40ed1b015b70d7efe9de54",
                    x86_64 = "a7cd10a36941e1e6c66b19f4d67ab01ae824e111187d02d300bdd4733d744f06",
                },
            },
            ["2026.8.21.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "56f1a9f253457bd9cc3c26146b18d4dc3f8b693ba02936d58042b1a93aa726b7",
                    x86_64 = "45e213e68c6817b74c816a196fbbd400b6b2ed5488b799cce5ff2e5e991a2c2d",
                },
            },
            ["2026.8.21.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "4763aedc2e2c0301aee392848c0755e468f5735c4c54c74f9ef0f4066c15fc7f",
                    x86_64 = "111031bc9eb0e639cf5c05a1cf3d3eb37a3ec35207d6a28e962a68c9fa711d71",
                },
            },
            ["2026.8.21.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "7e34a1006c12309c473ff0cc365ae69df33a585f01e8e5a5b3af4c6feb9b14de",
                    x86_64 = "bea9ed660900b148faffa12286f1dc79bf01a884a8afc89eb1ff6e5a2f19edba",
                },
            },
            ["2026.8.20.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "e5b7209dde1449e6049da5587e400142f9302ba523478d0118483292e0c364dd",
                    x86_64 = "329a960bf062b8852cf5cf598ed1dd35d8ed7dc79369ef2c03d72a102d3ea845",
                },
            },
            ["2026.8.20.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "dbb970e57087f730b322afc4141efd71a7b348a0afa42c422c76c9544ccf908d",
                    x86_64 = "3f734dec448104832d313e03297f678c040467885c17a05480438377c0f6a9bd",
                },
            },
            ["2026.8.20.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "a7421bd1de956c85626a3b750a6e9eddcbceec2263e3163b5e58259e7697f734",
                    x86_64 = "b328c40b9c3ae0b32dfc1cd3cdf9f9069d7df60f4572fd81ec0d6f8cb7ac635c",
                },
            },
            ["2026.8.19.4"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "3d5a2c114ab65a8ab2e5f2194e473c8d329e94591dedabcdd0bf95d798496e8f",
                    x86_64 = "6f6ddec523daeff5a3fe94648b55796826af485296b0d417d982304b27484e8e",
                },
            },
            ["2026.8.19.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "6f1aeb54e8057cde737feba5022799f6f42a218ac18bb00321691590b0f5a584",
                    x86_64 = "7a582a44d2c42f32770560bb2dbb37471b93ef1108734f7781316283580ee254",
                },
            },
            ["2026.8.19.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "c99baf4c14896a5f644affdb7d55089d77fbcd864617d9b0e9980e12f3283de5",
                    x86_64 = "dff233fb8ef9b2597e2a9bbf41b33bfc28a1c1fc282288e5c6cf4a0862a4cda5",
                },
            },
            ["2026.8.19.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "636f06a61ec4ea1edc1b0f7e8df61d12a64b2adda99c9fcba5d4f0d4ad162901",
                    x86_64 = "d327fba7a209bc72748e9149a85aeb348cfa7e0f30d5e7eec11eef6e530693f9",
                },
            },
            ["2026.8.18.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "5a0dfca9629dcf3e635f612925ff9356fc6019837c28e2e03617ce081bf30d29",
                    x86_64 = "c3e3c031f85c0add8d0b8993a76c73cf2d84d3e776ac0db77e50f4203959f212",
                },
            },
            ["2026.8.18.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "6b2ca04775fa1eb0f7e03d7fd70ee06e3ec9aea61aae391df6286c8209876c57",
                    x86_64 = "4e343568118ed496536350d7c0351d449b97fb693b82610c4cce84ca6b111564",
                },
            },
            ["2026.8.18.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "6088216d8844e1994249fff80bba3d93e02e44624e17af7986d655784a615c20",
                    x86_64 = "94d1bff4d7f75031578d905d77b680f2d9030165d8fd73c95b8a201f2c7a4880",
                },
            },
            ["2026.8.17.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "2ec9cd47a81802a2e9f6db8aa3c51b5c473d36192aead098b3abeb3fe363981f",
                    x86_64 = "f07052560ea246ac745cecb8963894b262e14a84b912d8b418a99ae72098726b",
                },
            },
            ["2026.8.16.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "b3f971c74d132b3dcf521309514d5d5fd07692f9ded9f91679de31aba579d387",
                    x86_64 = "686e7c067984a22df3f29a3a02be23af8841c5b96858c7f1241d40b560612889",
                },
            },
            ["2026.8.16.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "5ab14255a98a7b81a1494503405dda114746d0f7f1c3916807e1016b2b06cc34",
                    x86_64 = "299102dc47acbc8f1d34e7fcc69632863a4b2b94593d876ff268d3678a6ed174",
                },
            },
            ["2026.8.16.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "548c6248b4e13ad42aec1f530a444ebe862acc0cf502fbdcd6dca2933774ca78",
                    x86_64 = "8e2b81c2727364fd82d64b3b73316279f3140123710e7d5d0f41165c45074c06",
                },
            },
            ["2026.8.15.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "5b0c4286376b909ed4e5f761c757e833f3ba2f1c5423180671cfc97016ca71da",
                    x86_64 = "6229de06d400d0e1a9854b72d4082f7c1426ee7d4f271dcb14f5f2625f27d16a",
                },
            },
            ["2026.8.15.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "c84e6bd405e751fa3696b55256a957d2a3818bbe3e5952802f932462a5ad9f03",
                    x86_64 = "526dd718ab5d071ac32f89c22194209659d268e104967ed54f35c5141483e674",
                },
            },
            ["2026.8.15.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "fb534b1db0bc5c4958525251adde936292c5e8ff6bce96af116ddca97449e9dc",
                    x86_64 = "c6c536847afbc72f1e962698501f80b429b6a37ec01c2c2fc27ae96c9cc2bc2b",
                },
            },
            ["2026.8.11.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "7a7e9764775e983390fbc613eaca28022e34dfd74898dc84f29a0ab20bcc8234",
                    x86_64 = "b4754cf2a3e9542092ca4461c231de03a55f06a943d1040cbd6b2615a10deefb",
                },
            },
            ["2026.8.11.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "30c788dc52f1b6db7473ed83935fa15631581fa89549c16870eaeba243bd4b21",
                    x86_64 = "f3bdcf8181600fae037711d791cda948d66f0dcea120d3eb6a38e092cecec9bd",
                },
            },
            ["2026.8.11.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "5dfa35361a844a31ef27f98a4525e7dd0e9f55b23f74a1583af9744adb695d34",
                    x86_64 = "4e5caff36e20edec11e5d99bf2302d2b2e09cd934a82d3bcb4772d8b5e9a40a9",
                },
            },
            ["2026.8.10.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "2ab8a98e1342dd725ba943e2c9f185c35cc1eb0a4da7d8a44fa54cd73a5c83a3",
                    x86_64 = "201c784e58e55c966219ecc8c2a2515487d81db90589ea5ad36cc1f2a2f87514",
                },
            },
            ["2026.8.10.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "99405ece93dc2ac6921c1ed326685d9768e4d1af0e2fa25c8eeb11052120d1e4",
                    x86_64 = "588d6d3d31eacc80f07755ca163ce5db28f504178343d1ab8af4a5618c96af27",
                },
            },
            ["2026.8.10.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "991b6fd28cddcf478cbf018a5f837a130cec9bc15f2ae0c7b4069a7f5ab19259",
                    x86_64 = "b7e0d51c0c5a435d2c56f781812243a230f15b1ebeff2b081d75f8e1ef8b75b9",
                },
            },
            ["2026.8.8.4"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "e0d63de0f6e0111f47df00e9135baf437aed2bcdb883dbb658880d9ee4418e27",
                    x86_64 = "a8f30fc73fae75381cdd734d204e6c04a24c55365cdf8bb6da07c3aa663c8f9f",
                },
            },
            ["2026.8.8.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "cbfd110d626676de70f4e92de4e26898e5ba42726e8dc126b55c0248bc54cb0c",
                    x86_64 = "c7ce7cebf978e9ae06a06f36ca7186774d32d9d79ca931937dede79f3da25268",
                },
            },
            ["2026.8.8.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "a6a12e7869b908f45f773129d12d26de6a3ac6b20c918602112b5d014426884c",
                    x86_64 = "b71335b793d0d23c85c164e1a2fec95c791f6bc9d2067060c5d5279ebeedd1e1",
                },
            },
            ["2026.8.8.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "c82269b245034386d465bb496acaf86c1dc153245ad053e0b8e917e48249d076",
                    x86_64 = "6dda4845a19ae8748b1d3ee2752361e95a470728deb70bb73fcbfa2738bba5bf",
                },
            },
            ["2026.8.7.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "32d8b0accdf5201e6fa1cbdd58aa51f5e9f3df3e752239724079e7f3c4a3df08",
                    x86_64 = "f6db56b10859c4a9cb62de829f9714bdc6d0978d1c858a735c707c72b17b427f",
                },
            },
            ["2026.8.6.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "64d4b42b841fa08aa9514b5b1f5858c3e03445ce58f36015009c20e0573ef3ee",
                    x86_64 = "11eef36f00aa6a71c8ae4e58cf0d5655ce3f333902384f566863907ac60c79c7",
                },
            },
            ["2026.8.6.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "98059d9b84eeea59872d600524af5c0dafe0c4b89ca5063ad3d8cec920e1b94c",
                    x86_64 = "77ab7c6a22d939790068309e33a1f68323eaaf91d775c2afb782b5ab770e950a",
                },
            },
            ["2026.8.6.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "ac7bdd461f770eb40ac9e80e327aaf075e75f3dc1fc889c205359b4414829f58",
                    x86_64 = "459515e41ce81673e0e366d362a53990125a6bfaedf07c01b7343164293e7996",
                },
            },
            ["2026.8.5.4"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "1bb8942048217eb6438f291e49990104b3eb407f6512347b9b66974e3a4ce331",
                    x86_64 = "abfa37f67120e0284a37dffa8245e4eb240bd17aba6aeb021d81325aa6e6471a",
                },
            },
            ["2026.8.5.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "8a6c9fa7cf5fd5fed2c099a0545145a7c006f051791bb2db3da11852d93e7344",
                    x86_64 = "18a20f8abf35eaeaa364ef57789d3b566ad118f31bb6a145a8a2e0bfdaa8b277",
                },
            },
            ["2026.8.5.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "6880886f774705635d8bf65de6f5e5332b5693417763092e50bb42dd914c467a",
                    x86_64 = "24ab6eab7faf0f35bf19e35692b1e6bebe513c4791f9c00a56fbd828c68cc1ee",
                },
            },
            ["2026.8.5.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "03e2cb9a1ae99e0c7c241ebb163796d6fd0b6ecab9419a1bdc9ec746bad2c7e1",
                    x86_64 = "b3d75a206b70044b70f4a7dd1f1a556301b1691b1138f84e482987a82b0708a2",
                },
            },
            ["2026.8.4.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "8755f1651e81a864afeec095999920ebb16b6c4c7b64317d7ee130377a41ba1c",
                    x86_64 = "6df4070c16e98daff95ac225c34d2972c1f72e18cc1d3b55498e7d97d7562c0e",
                },
            },
            ["2026.8.3.5"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "7e2ef64af2dcd2bb2e1e7bd1e60eab543cf12e94c6ee5fa8d9b4ea642547971e",
                    x86_64 = "700f02c492fb8ce080bdaf36fd173aef549ca3f33359bcc17d56baa6ff10ac9d",
                },
            },
            ["2026.8.3.4"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "d9e7a0eeb7c48d970344c817cd5d9f3774f626eb65901227e7a7cfa3feaed606",
                    x86_64 = "7ab0dc4068d57cbe69beac0bf65d92c503ff67898af73a757817864bececd1bc",
                },
            },
            ["2026.8.3.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "e430f7fea648ec38c949f41a57b53c6f387aecf9f5123aa259b04e4ae36aa316",
                    aarch64 = "3fa085fb04341d1f984540f70d39d60bb44f12dea7d695454bd44e2c725bee6c",
                },
            },
            ["2026.8.3.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "46896794ea42d39c03d3f6d08e3dd12ea2662350fc6491ef48fe9aca26fb25af",
                    x86_64 = "380673bee4945cc457f4066af1e39da7dcfd4b9577c48303397ac3ea5a597572",
                },
            },
            ["2026.8.3.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "011be838a99282931c6ced9dc12bebf99a275ff08d206d1bfc1bea6a6b71545a",
                    x86_64 = "57a9fa3461bc7c85c51e073a17f6027179db3e8e8c16a6f247c6b3d504c8caad",
                },
            },
            ["2026.8.2.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "673b7e677b68be809d5807947f9842f321ebd9d1b3f946293685bcee70a68142",
                    x86_64 = "6b33f77ad76680a22d1552d32e0461369e7a7f08207e6462328fa35f0caaf72e",
                },
            },
            ["2026.8.2.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "5aa50ecdcf6b8b625adaa1a01c05ef98e152e9bd46110042bad140a5bd5e7654",
                    x86_64 = "25761921146b8651b5fa428684c470cae936e75a0a2e9057fc6d5a083641ce9b",
                },
            },
            ["2026.8.1.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "40a9cee0466d645d26820a47e065a8dd56768276ef01ff5289b6855580e32b78",
                    x86_64 = "3ff4e68544dd1c2d11b9a25e69ba70852ceeef7fb8cb12302da8b6ddc2e3e42a",
                },
            },
            ["2026.7.31.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "0a8302b16615d2390ebbc9fea052dafb2451c29a50e37a60dd467601afc4ca59",
                    x86_64 = "92b9f6e51e25e225258b83a4f21d39ec115804480bd67054e2654dec33edc0dd",
                },
            },
            ["2026.7.30.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "aff78e9e04d0dfc09ef828b9a5aad3e1e4afff19de47b493a88bbbf803a00d14",
                    x86_64 = "115cc537b17bfcaf5b5d13e0c7fcf9a591864cb6f18d10244e3828cfc1f8e1c4",
                },
            },
            ["2026.7.30.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "8a9f48720af833ab272aee35f51e9dc26642898e458d054093df50a33c333095",
                    x86_64 = "4b048875027731ed7d66f219b7fb4dd73a1bfe9427809e187a81e6121e96b8dc",
                },
            },
            ["2026.7.29.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "cade7f43f81df7bc35bbdc0753f542bfdbd96c01c91b6f8aa3c7529cc32c8077",
                    x86_64 = "5a8d18df47ec135afb24a8cdf263bf310baaa5b3454821f77988a6e519671676",
                },
            },
            ["2026.7.29.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "2b9889669b048c24d769920dfe53cd65eb584d2348c191e92efd08cc8b0bd6b7",
                    x86_64 = "3f0fc6b6653a6e8234d2e03c0daba5551978f6482cbb5eb6e7ce49464d062d3c",
                },
            },
            ["2026.7.28.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "525f09ba126fd445872cc6b0467926b6c1b936b80e4eda295f59a31caca1e95c",
                    x86_64 = "32ff7b36160686f5df56b015b3ea76828ea2a98b9bcff2f2526fca98a8d7d435",
                },
            },
            ["2026.7.27.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "60def21a78e27acb1c34df90de160c4b25f0d2d441c6d087d9dadaec39f8303b",
                    x86_64 = "11cf800652f419e89bd6c04b322f5b78d586f3a37ebf02cc39e0a8d69b050baf",
                },
            },
            ["0.0.109"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "b2fb4be76c01ba933771ef42ae8b79a1c508150e0a2d7b70f499db5aefc459c7",
                    x86_64 = "0fc5df34ac0dd838f33e36b033996650d06500bb88f76d691d92e2476c21ad14",
                },
            },
            ["0.0.108"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "444a9e30c292e5226c229a470ab48d3ba35e09c0afefb4698797cd974163c89f",
                    x86_64 = "12f3a52882bca114fa6cd16e66539224faca465bcf5bfd8871326177a167d0ff",
                },
            },
            ["0.0.107"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "dec61f9c9b51437e2ad53d7f0f7158e1be19378652034ebed53ac8f093b10d50",
                    x86_64 = "9af915519c078213559529b017494b8e9acbdad2b952dbabd4c16ca0bbffa349",
                },
            },
            ["0.0.106"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "9458484b03360ead2e730242bdc81efc6bbf7165771edfd1aa236eaf12e1ca4b",
                    x86_64 = "78aed4bd46f14b0b3ca05ecbf0afa269bf69f76ab10e54811f99262caf404dfc",
                },
            },
            ["0.0.105"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "b3f005b86632f50eb4052648084dec81d93744e4aa39ba1dd2e42c25be1297b2",
                    x86_64 = "568f3972206e19f1370fda6c3f638ee160079c4cc09f38b22d1aeba406d793d2",
                },
            },
            ["0.0.104"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "8c67ce6595d963fc99388feda7d1a7ac6aa67994e475df2d2383c65062b8bd5a",
                    x86_64 = "d89169e554fda828a5c0a04797d2385b8939e5452a14d1b1b943627e484b24d0",
                },
            },
            ["0.0.103"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "1b72ef07b4585fecddf2c90f03ac63716448c98db6dfb3e644be8c8b17055049",
                    x86_64 = "6a8a69a21bc120b1fe48a0ef91c454a5a06010ebf65b54226d3ef96699c41488",
                },
            },
            ["0.0.102"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "dec1cd1902f802b4901790e40bd0a47d58f7f9a1736ecb7c77cdda624f1698b5",
                    x86_64 = "80d5d9354b8ce8a4dab34642ccda1a056fc37cf2e5f2b31254365edc43893eca",
                },
            },
            ["0.0.101"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "3226ff19ba409901427f89aeb4e5a400876fa86142789b967ed19aa8f00ded1a",
                    x86_64 = "690e2f926118c5aa26e3d37cb5d5da11a50363cdf86f239fd78ed0a13f4cf7cf",
                },
            },
            ["0.0.100"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "99080bf2c368a8dbeba7e37795d1330a56527a2d1c919cc1ace1da677b439b40",
                    x86_64 = "d4cac259e9b5b9754620b1c9a5ff6669868d63ccb45ad56ca37e58d5b8eed1a8",
                },
            },
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
            ["latest"] = { ref = "2026.9.5.3" },
            ["2026.9.5.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "9613f70cd7c958ded773548b77865fc6ba673e9adacc01fb51c0caf681dad2d7",
                },
            },
            ["2026.9.5.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "463b311e23723a818c5dbddaff6c47f085d081043da44226993486d9d6d42b8a",
                },
            },
            ["2026.9.5.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "37a8b1c1ea84964683fb268c8363f4661014a7ce236d299af1f9bb88fd1f6f8f",
                },
            },
            ["2026.9.4.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "9c0033e69e372539486588ff8775d849cb6d8326ef0fe419a547b4ce30055099",
                },
            },
            ["2026.9.4.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "734d08546cc3cb012698b4c4f39871e8687d2d5ba80357f02d915c010b24d01e",
                },
            },
            ["2026.9.4.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "ca6c9105f4c2530dc21c7f3d57e21176b8ac3a7ef6107ac07052e8a4d6d77c4f",
                },
            },
            ["2026.9.3.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "9969815c45ae7c712cb1cb3307bbe2cef150031d03281372de8fc840c1cdc361",
                },
            },
            ["2026.9.3.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "e1e98cc63ecf6c43ded3eb1537f7c4195fa147bdc33a955f987234f380511a5b",
                },
            },
            ["2026.9.2.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "bdd989e8aa25c336bd2a1084efb8158945b40cc1cfc95b0a06628046ce2a3094",
                },
            },
            ["2026.9.1.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "e98021e8f17393a653a500dd991890c135454bc31456f748e6079117e52883dc",
                },
            },
            ["2026.8.30.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "a0c7c2f7ebc43d0611afcf465d0dc9530ad175db8026d23fb4b3754e35ba8910",
                },
            },
            ["2026.8.30.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "6c9bc330d45cf12251e7d23c4aa61c72460dbb2a146f751efe0894e7b2082b94",
                },
            },
            ["2026.8.29.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "fff1d5a25ddf6791623356ad2d5c2f058e1185522a318d12adb8dc2f28dc4b3f",
                },
            },
            ["2026.8.28.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "8cdf1551baed7fca4a1964bf94e8b467262f145267f3d215808c37fc57d57d7a",
                },
            },
            ["2026.8.28.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "afe13a9132209014a8f53c85839d8921f2b50fe311732805e93b90b079142bc6",
                },
            },
            ["2026.8.27.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "24304b445ad9e5c9e72690e09ce7987480be7b2be6518751ab2d56da1e15c04d",
                },
            },
            ["2026.8.27.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "665583e68b71e4d6cdd09b2c277239d757e158a6315baca61e792b701db64d4e",
                },
            },
            ["2026.8.26.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "e1cf0a6e0834bfa83561bf778249e5887d3b39cc1b3293d3ee450196040e90eb",
                },
            },
            ["2026.8.26.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "2994b5a675089ce01919d72cf8f6726b04e6bf5dbf5232412e2c4ce4e4236427",
                },
            },
            ["2026.8.25.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "2e7c577478133585d41a1447adc9d9a5305446ce71293e4de9f416c209afd8e9",
                },
            },
            ["2026.8.25.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "033703812c375c9b21a06952d6fc1182226f2a6c7ceaf90ae092844af66272fc",
                },
            },
            ["2026.8.24.6"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "6633771aa513ee8ab4502b12e7b937ef408a5649886cf97211283a5328ad954b",
                },
            },
            ["2026.8.24.4"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "84e53391a21220715c82478cd6d5d5e95688c549dc2d6e422728b1be0144b7d1",
                },
            },
            ["2026.8.24.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "c0d997660cfba02496b9d022741f48fab6e2e38875c4fee2f450528732fb12ff",
                },
            },
            ["2026.8.24.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "af0c4faff1dae246ef7971960234653b02504ca49877d78e2a585f2e65173a81",
                },
            },
            ["2026.8.24.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "a91ccb44b2c8f6251873e47b645e4ce0f28868a782bc2793d12e235c824b3e9e",
                },
            },
            ["2026.8.21.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "64849e860c9513d57f5ba590f20f213d243986592f4312586529ad45cdfe608c",
                },
            },
            ["2026.8.21.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "af3cbbcb62f629ba9f141422bb701822011804f9c9b4094590ae05ae2d3b7416",
                },
            },
            ["2026.8.21.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "e9f7d8d157cd569c446c8f0ef4f1b6d0011f3c385dbb338c0252c7aa24d90c22",
                },
            },
            ["2026.8.20.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "1370a70c07caf3ba146710b744ef75e75ee5bc90c9b74ed0a3a562084870423a",
                },
            },
            ["2026.8.20.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "752414330615c18cefb902495ed0f9c90f4b2bf75582d1e6c94643ece78cdf7c",
                },
            },
            ["2026.8.20.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "164abf2cdd11688448067e38b9092b6c96eb432d6423baaff4f99eae9ec8269e",
                },
            },
            ["2026.8.19.4"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "b22961e77ade182d71ea7ca9b31e669e7ba6da8578a667f9d57dbb7d490aee41",
                },
            },
            ["2026.8.19.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "85693a47a65c1473f6bd34a0887ebbed048f3ae9af045714c3f25df10806fa84",
                },
            },
            ["2026.8.19.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "e3090df6781d219f7137a2cdba615a62c9d5027bf8cabe88365c2d9fbb27d045",
                },
            },
            ["2026.8.19.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "7c6ed623a2e8892c5e089dde74b40a730c14480bf3a2e21217937ffc8d5a794b",
                },
            },
            ["2026.8.18.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "9a1f355b630531dd436dd9cca5cdbdb2c1a0ac3b163b094451089b90016329bb",
                },
            },
            ["2026.8.18.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "15b494e9eb5ad5a240546dd5c37ba58b96327f0b88ee3392ad726cd0b56e4329",
                },
            },
            ["2026.8.18.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "918b9abdc26553b6384d5507ec4b842f7dd8eef741011ad0ee89295b0b78e4b2",
                },
            },
            ["2026.8.17.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "8f1ae2cf991ad14c0d21d019c6a0a2e2265449aa125c0e3c6392647822a077b9",
                },
            },
            ["2026.8.16.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "44824a8d631dffd1ee6e0d008337097fab569918cca38a0018b3662e80f28e2a",
                },
            },
            ["2026.8.16.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "5139db702d389af5d473a8dda95989242ec1b0805c2c710ae61332401181eb7f",
                },
            },
            ["2026.8.16.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "c39642cb1b70dc32f76285702b3a3fdb95e8b51f22b3fb1e854236af69fca04c",
                },
            },
            ["2026.8.15.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "1b7ff80e73e830d7e40ae3d20fc7bd916a624d777d22ee43615b247e46274b75",
                },
            },
            ["2026.8.15.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "7bfaa4c69334220d9339503d36116ad83442758cc756691fa88be3d8238f3b79",
                },
            },
            ["2026.8.15.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "a4567df55ae6602d3045ce0f0cd0ff7d2f5f3936e33797039d36fd539b9af6e9",
                },
            },
            ["2026.8.11.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "ace3d70954a0203b180ead39398c521e6ef483ead0654a0b42a5747f8a4377cf",
                },
            },
            ["2026.8.11.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "c0747a2ebe4d6361ea90bb4964c9479f2d9acb13971f30e8ffd0b0268adacc8f",
                },
            },
            ["2026.8.11.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "6434582a0153e9aaf1bdc224c4bc6b309588087d0acdc645ce13fbf478d995fc",
                },
            },
            ["2026.8.10.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "245db9d0d727f96620dd41ed11a488552b31510dd27b97f4b61fcf486668b55d",
                },
            },
            ["2026.8.10.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "1674ee9ff8df21f03fea26c2c65652fd3754315e94132562b2e0ecebdba7a6b3",
                },
            },
            ["2026.8.10.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "72eeb3c8c998becde8b15a5510754f870538c0f1debeb1de4dcd3bd7397f0472",
                },
            },
            ["2026.8.8.4"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "7d05662996f5ba1550fe2b1677ca80236d01dbf4c9f3e30d41f63d472b986f3a",
                },
            },
            ["2026.8.8.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "c43eba6178296ad12a1c6218e775297a3ed0ee3cf762e91df1bdbfd1203054ed",
                },
            },
            ["2026.8.8.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "d9987aa8898db8a9a9c23bf51f21ceede16931007b1ca202f14680926c40190e",
                },
            },
            ["2026.8.8.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "8c78110629ceda5f7a6714c247ce8adfc02242f26be5fa259f69e1140dbf8e9c",
                },
            },
            ["2026.8.7.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "7221a2f13ea6d6fbf2ff4f152108be53ce343e4c15022bb177e33fd05aeb71b4",
                },
            },
            ["2026.8.6.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "893365716f491e0bdfa126e2d49f52eca264ec10259587e12c97d53c113d0284",
                },
            },
            ["2026.8.6.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "1ac9c443775ca7b4065516d1ab297c07778f5479c57ea040aae9d0174b7541b5",
                },
            },
            ["2026.8.6.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "777232842ca2e3e6b2cd7a2cfa96763c45b4f1157e30a4d52d6f93b80d4027dd",
                },
            },
            ["2026.8.5.4"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "00255cb6156b8349e11c6e35758f3b031e131c0dbea21bd154c81e2ff6f34abc",
                },
            },
            ["2026.8.5.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "f4818a73054732439de1ee5851d888d4aecea0be975a9a171c86f37f6fb8dc32",
                },
            },
            ["2026.8.5.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "a717de3de32c07d6484dfdf3efee76e212cfc57f405f3b9c43454622c8378ef0",
                },
            },
            ["2026.8.5.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "e83c5daff99fb3a9eb72d8ba1f265bf81c64c920f909f066c2dd127b57690fb8",
                },
            },
            ["2026.8.4.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "157f4a30cc78518938b8a6110e0738d6899cb39fca1f5dce8a2b6d11b83806b4",
                },
            },
            ["2026.8.3.5"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "ff289c7abdc46a510e7677d40cc91c3db1471b063cbb20d2bb30f36728d57639",
                },
            },
            ["2026.8.3.4"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "9924e8f2b6afa1f78c27fdd46e8ebee812281f6a1e56e7dead15ce256efd2e28",
                },
            },
            ["2026.8.3.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "4c477842f179375333825fdd5335d5892502b71faaa88cbdf5ba2aee05eabb62",
                },
            },
            ["2026.8.3.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "aba5689de59fe9daadf056314c5f86cccdccba3333e3c7c9207b36031d2f3975",
                },
            },
            ["2026.8.3.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "a32bd093089d4138a5e52fc988aba817f131064e5dab24e7ceed519cd7efa3d2",
                },
            },
            ["2026.8.2.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "0c2c455ccc5baddeed2cf96687d8410b352e2eaf91a0c023a52a66a6e8e2d8e6",
                },
            },
            ["2026.8.2.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "bffa6f6734a03211082e34c2e896eae69099be36a475a2726f0130bf3bc02963",
                },
            },
            ["2026.8.1.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "faa2e863bc730d55790a0ed370f7bddee6bef19451883993641bb17303994966",
                },
            },
            ["2026.7.31.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "c06c4c8bf636e7fd2871036057154ac6c423238743c77035ed8cc167a04b2492",
                },
            },
            ["2026.7.30.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "1659be17b3f54c495c224179a570dd220fcfead25bbcda0c6279b20afa6a4e18",
                },
            },
            ["2026.7.30.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "23ffd00bba91094d86d5a3a19ffb005f84b62f0309020035feaf1e129e1df838",
                },
            },
            ["2026.7.29.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "343c7af35c58467740728bf1cfee8bce8dc7a37576fb6b1260f396d95ab8090e",
                },
            },
            ["2026.7.29.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "ab722f38fd486689d7e59a9e2a2a7990fce68e878049e3a48bf90d9e4c13cd04",
                },
            },
            ["2026.7.28.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "6d9567222108dd3b5518a0e5af84797c8dc261f5e10bb429c31b31946e958ac1",
                },
            },
            ["2026.7.27.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "7f4e27ce06ac5c79aa2a8be335b3dc764b39cff1c8713b67bfa8ced757001dfe",
                },
            },
            ["0.0.109"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "327c8dabff0423bfc81c163989af1376ff8d456b9ce6bc5bf2e30805dd45c749",
                },
            },
            ["0.0.108"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "d561da44ea50040722f94105f490a52b52677089b8d7a9f44c95dbed003bc9d9",
                },
            },
            ["0.0.107"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "64bd83c494d4a34f7e28b889087e4057b480d92d6130d450ee8e2d3f04fc42ab",
                },
            },
            ["0.0.106"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "ce93233b9411825598d4d2f4a6b6210d3e79bdfdf17a6f24158929742527a76c",
                },
            },
            ["0.0.105"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "bba4e3cf6a0adc6ec7b19b90d195cb319eae6e93fa71ae6ae52686e61c5dd1fd",
                },
            },
            ["0.0.104"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "6800ec884c23a1d5dd4dc896a11fa4adc34b7fd6dd3ae4a2b68d0bbbba460332",
                },
            },
            ["0.0.103"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "03b34975a1166c49c14aef54ac0bdaedd6ff20afcd2b3f156f070bd3289d456f",
                },
            },
            ["0.0.102"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "f90c506e8bc08f9688d3c42ce72c8f423978d1163e9e47a815fd10339ae3fec0",
                },
            },
            ["0.0.101"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "8c6e2d433fe57b8ccaa43497b9cc57bb4b14e9d37e75e04e971e38f95c8f41f0",
                },
            },
            ["0.0.100"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "9aa16be7296137aea1efc0d8a692a9d184e9386cd4d3c312124be7ee3e741774",
                },
            },
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
            ["latest"] = { ref = "2026.9.5.3" },
            ["2026.9.5.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "38d8a5897acf2452c502c2467c8d8ec551a0aac55055bd8a4161717318bb202a",
                },
            },
            ["2026.9.5.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "aaad95254b138edd44b9e5084d68048c94e9e843e8e925a31d4c590aed0565f5",
                },
            },
            ["2026.9.5.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "fab242d0747c4ff8ddd69dd7354389a293919a5c426dc9e11ea5fcb856a02e9d",
                },
            },
            ["2026.9.4.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "5989cf7e12a822d94cc06c9788ddaa8c1a79a174aa5792346a160b1fff2785de",
                },
            },
            ["2026.9.4.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "009fd9c386956a38b9cda183227aacad2b01da946f3a5ea403f83471787a6d5b",
                },
            },
            ["2026.9.4.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "d9e1f1338d3383c7cbaaeb9998c70a8360992d95d13267c51c18f063973fdd5a",
                },
            },
            ["2026.9.3.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "d865929d82fe2f3ceb80e846f43bc43911a71f25e0546d2aae19c32fc29332db",
                },
            },
            ["2026.9.3.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "80dbc1bbfdc623194913132c662b93d4ad55280f7f497c21dd7677eecc542a5b",
                },
            },
            ["2026.9.2.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "1703434f0b47b43448e291e01b423ab27d3bffe3942e97a6aeea5fc720e938bb",
                },
            },
            ["2026.9.1.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "49057908ae8b95082f1155c3fc24e66ff1520b281c4a4d5eb82dccb9facbb3c0",
                },
            },
            ["2026.8.30.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "ab8e43e827bff876044d2084d3e5d470d460d1f5a084ae0484c846685dcfd663",
                },
            },
            ["2026.8.30.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "6ed4853fafd8e1431cbe324847cdede731f68d74d24522b94703e46963c4d984",
                },
            },
            ["2026.8.29.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "c6e3701c8484b0adde7eb91d97c381b216df53055c8889f92baa6783cc5d508b",
                },
            },
            ["2026.8.28.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "6a713553e86548e2f61e5791b3cfc08999aed86e29dcfd071fba6fab7d5ee377",
                },
            },
            ["2026.8.28.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "48fe0abdd939a7f114e2da8bc6115972d9e4e49e2aac2249454059694ffec660",
                },
            },
            ["2026.8.27.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "c9b575650e33a53662ed2ba9c6aa14f11e354e2b76b7c181b01bf9a369ad3a01",
                },
            },
            ["2026.8.27.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "1876bbc4715e7dcbd69c82ce07131fdd44b9aca5cc417952be68ac90e23a4c01",
                },
            },
            ["2026.8.26.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "93907c34e9d5a69e5975bee2b4d207e046f9ce958dd8576c3d1d84b5b7294d11",
                },
            },
            ["2026.8.26.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "fae278b4a67ba1d1ba2f3643b4a260ed02316b00201c353239a6b5f5f932a1e7",
                },
            },
            ["2026.8.25.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "26c0393df64d28eb656f67692fb99d7a7ddeec1cfeec56f93373e7f9b35ebcfa",
                },
            },
            ["2026.8.25.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "d81f172daa2e32e08ae3939821909a335077c5e0eab91676dee328ef22dc8b80",
                },
            },
            ["2026.8.24.6"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "a58a9845bbb78c6c899b3bbc2d564633780c518e448c0846d9f44705315271ba",
                },
            },
            ["2026.8.24.4"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "f9331cd0b266617db43a055c041649a3b70dd86465bbd2a74afae9e66c092759",
                },
            },
            ["2026.8.24.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "94fa911f75f2f589b19d75e7f4ccffc4f33ae6fad828d33300b718f7050a2cbf",
                },
            },
            ["2026.8.24.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "aba5fed969e0556b80acff0b54dcab15500d61e094e718a1dc9204eeb29524ad",
                },
            },
            ["2026.8.24.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "cf02602b3ea8b5084d4454d54395daf360503088df86097eee87309f1ca19330",
                },
            },
            ["2026.8.21.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "56adc7d94d6e640854faafea10e95d105dbd67672c32773a1924212a8fb76f5d",
                },
            },
            ["2026.8.21.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "18d7c4c023cdfa57d3fa47e65bdfff178e2f56ffd9eded6ebeaa17fdfeef3e53",
                },
            },
            ["2026.8.21.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "7ef1c8fe8fc2da58fe158704cfdf3bbd791b7b9201880e659b18ab83fcc98751",
                },
            },
            ["2026.8.20.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "c193bb7d48b38a74f80557ad248eb458119bea5567b2f7f5737a36a24337f9f2",
                },
            },
            ["2026.8.20.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "af5e8270d0e7d0de526076a792ebe31c9ed7212d4e124ffd036c7ce72d7a5c6f",
                },
            },
            ["2026.8.20.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "282d526d1af3c9c2d5f60fa25613ae4637d856e33c099600f79367794a0d4cd2",
                },
            },
            ["2026.8.19.4"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "7907b70157f96a12bbcc129bab8336fd8a9747f0a9acbbde323c6fa63ee42552",
                },
            },
            ["2026.8.19.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "693e11241982dd2d9d8ea965e629ec37afeab4b05ecb2d79e46b8853f446648a",
                },
            },
            ["2026.8.19.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "1e146af8046292d2f751dc894911be8df02e320804cdd68194637c98a2c7cf80",
                },
            },
            ["2026.8.19.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "e329668f50c984af22b4c6e484719511a9e1b1dbfee5634c07e73173b0acbf2b",
                },
            },
            ["2026.8.18.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "df4161ea53f84d08abb9cf3bbf751d642eada102a437d56e3cbe984e10bec767",
                },
            },
            ["2026.8.18.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "df4cfcbfe255c4d13ae88d0f61fcee2c75c4736878bea69ad349614d732eeb21",
                },
            },
            ["2026.8.18.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "a04a443f54ba3e51733086878d898ed31ccff09782d6cbbe4a63434fe2eda997",
                },
            },
            ["2026.8.17.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "35520f09b4c87d855711e172390ea0ecd0a7fd58c739e9a17d329d0fb6335c08",
                },
            },
            ["2026.8.16.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "1ceca92e3254d28ab97492ebf1a2ef36fa368f0b8fb87f7cdc8855453c093e81",
                },
            },
            ["2026.8.16.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "02ec6166f1ed68d4a380e98dfc01a93f516149a51ceb74bae2c00b33e93c0098",
                },
            },
            ["2026.8.16.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "e7144882fb003f3f73dc2200f36dc29e62caa7c83561860ba7ad10fe328132c1",
                },
            },
            ["2026.8.15.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "bc930213b9617207ac8914b60eac17c0aae0f1730aea4e44e9e96d82cb7378fd",
                },
            },
            ["2026.8.15.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "022073c07a9b46c8b5768d4a6e1dfbf3cd1d8bbe66730fd4c6a055226ef6c2aa",
                },
            },
            ["2026.8.15.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "d6b6ee094851b7c29c9befc8a354ca7be69ae33851af89c1933645c09a455b83",
                },
            },
            ["2026.8.11.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "4d26cf28b3ddee85794e4180c573fb733aaa5d1e74b82acd6fd0f3b4287f5151",
                },
            },
            ["2026.8.11.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "ac6baab0728274f173ba24ca292c96d7fec0c511b85987a6faea2cad0d568322",
                },
            },
            ["2026.8.11.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "63e5a0a4dbfff8a9d25352473405d648b4acab35fd2daa128af40d521773a54c",
                },
            },
            ["2026.8.10.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "51581b307f01395ffe6c5eb5e4a88166ed90f43eca56badff52330e11d9f8da9",
                },
            },
            ["2026.8.10.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "f6192bfc7d7e288292609456f14f80aa9b25b0bc488bd5937e50b6b6023640fa",
                },
            },
            ["2026.8.10.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "de04a0330d533fccf86e842703d851421de1c2ddf058a7cf6606bea463b9df31",
                },
            },
            ["2026.8.8.4"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "e0a6ad7b39dabb85bb97d2e989b3c50010f370c0594aeaeecf21b93b3f0760d3",
                },
            },
            ["2026.8.8.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "f8ba3571e2211ec176095cd04e236689f321c40b58116190b168f7f558d9a716",
                },
            },
            ["2026.8.8.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "4e606da2906a5d537b5b9a7969f508c0d1f569da4a7cbb053b896b1f80320979",
                },
            },
            ["2026.8.8.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "e8e7f87cb1f5bc84d50002119d1479a4c79abdf4c7d5b3c7044fa0e0d439b928",
                },
            },
            ["2026.8.7.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "85279387d5ab3c35f711d9d3eb74f4c02e549110c3c9a9f22847353347355432",
                },
            },
            ["2026.8.6.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "b1b502196d26dc73dd1f47fc0e640f3b696da43c83617642d7012fd1472609b4",
                },
            },
            ["2026.8.6.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "1647dfc6cae398763e6e41b015fd4d065a775aaf06dbd13ff2ee783fa12c0483",
                },
            },
            ["2026.8.6.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "d8f184c191f2542ad635a2c5dbe4d48cc93d6e4fe235f5a1f72e7ca4d7c6f19d",
                },
            },
            ["2026.8.5.4"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "ec6b32c7ab2696e812d38af844c20bcd9eb13f2946b330d09d70af33afb23623",
                },
            },
            ["2026.8.5.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "baf0842c71b9695cb8e1f3c33814333eff72ef370fe1d876b044e5c8536f352f",
                },
            },
            ["2026.8.5.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "d5bf02707750ca35ec3d30c5e6ded366e90618ffa6010e95c4d806945fe0bd03",
                },
            },
            ["2026.8.5.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "5ca8dc09a4e658c09c6c07c1316fde1f6c9ce155387f42e82b0314d389488f55",
                },
            },
            ["2026.8.4.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "cf213c058c673890621bdf3c44b3cc44783a30880c167fe09af4e9f5e697a2ab",
                },
            },
            ["2026.8.3.5"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "2c12b5ac04da27f465f72e77683c419700cfa517e507a9bd77ee34da2e00ba09",
                },
            },
            ["2026.8.3.4"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "fb10235480d422af9a0b74f52f5a72216a735a70367e9ca3be0a870722311882",
                },
            },
            ["2026.8.3.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "222cadb7cb9b2b9e62f467ac1668be93d0479a8bcfd848d82563f1aa1d28eb6c",
                },
            },
            ["2026.8.3.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "c7f4f07069a1a1d69011b975abd0b0ecf7aec8111e04e3e4e09234a3640de699",
                },
            },
            ["2026.8.3.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "aa57895b9cd676bd6340c6f51eb020677a7c3d5073327c8f352cb025ddb63c83",
                },
            },
            ["2026.8.2.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "5719084114c6b167fc3e71eaeae8f932416de9570618754d96dffc5ec5125afd",
                },
            },
            ["2026.8.2.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "1a2cd4466c62562c9920a2eac85907312de6c2f56aa9de3876586257db5034e0",
                },
            },
            ["2026.8.1.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "e81bb4250d7c5e803b43872146cbfd86a7020a17182560b9beba7b8ae1a6f22c",
                },
            },
            ["2026.7.31.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "6863df0b04cd1163c02dc60d4d57d467c2555216fdbe8171d45da60ff8a73f90",
                },
            },
            ["2026.7.30.3"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "32825bcc4c9778fbc434647d28d6f4cf27c360462d50083949360fb0e3e196a7",
                },
            },
            ["2026.7.30.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "1ee8b5d76cc12972b56ba99197f373986d01e06abe69f7b66bbfb3f3cf84f78e",
                },
            },
            ["2026.7.29.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "fc7b6c93079d89808b48336ca728dfb397e2ce7267b1b50ad672a7b9e8b081f4",
                },
            },
            ["2026.7.29.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "ba13855922fc3a618a53c2ef6cbf8fe54bca452ee2e506adc70b152fb2f792d4",
                },
            },
            ["2026.7.28.2"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "146d4a4eae272cc2be3e3004ddef93eef452cead780f0d379b9cecd0da7ef117",
                },
            },
            ["2026.7.27.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "78142bbeb84fe7e1b3abc4b8c96553ea619deb249b53596ad69301d66656a590",
                },
            },
            ["0.0.109"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "3cdd969235042d60e5afc18b124604a8739ded53ae8e6d655557faefa74f46ca",
                },
            },
            ["0.0.108"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "4eb5e42c72b36e306bfb3a690bcd02b28adb166f8922a672d8c8efdb977b203e",
                },
            },
            ["0.0.107"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "75aba4a5a01c568294c4a65dfa251bfa47418243c25dc57388d480c97087de36",
                },
            },
            ["0.0.106"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "fe52ff504a45f4487359af56d45220b7f6e2c769b077f1aa13642158a0ebdf57",
                },
            },
            ["0.0.105"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "d00ab1659e97c3f7258eb859f595cb8d904e6017086a4f1aa298c796406142cc",
                },
            },
            ["0.0.104"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "bc1bac6a9d2fb075f62e5c176e83769a3be4772401ed6ddff8bba8c0f6ac3d89",
                },
            },
            ["0.0.103"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "8043570bfebbc753c1dacf2fe36617aa0bc1eb1c674630192bfed176a5f7fb86",
                },
            },
            ["0.0.102"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "c15d891f8e0b885d059a919a172832c0d7e85adc04fb1ef592890d0103d31c8b",
                },
            },
            ["0.0.101"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "bff83b66d0c3a1318ca4d8d232d4d8223d1df91b94183e9d7ef1949d02bd7014",
                },
            },
            ["0.0.100"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "c327c3568288185f3551b040c1922082518e410c64d6831fd3d42d2cb8b51c28",
                },
            },
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
