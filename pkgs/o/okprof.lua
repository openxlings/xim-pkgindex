-- Written by `mcpp emit xpkg --package` from the four okprof-<version>-<os>-<arch>.zip
-- that openkal-image's `release binaries` workflow attaches to its release
-- (each `mcpp pack` of the tool over openkal-platform's hosted arrangement:
-- static on Linux, no SDK on macOS, no MSVC run-time on Windows), with the
-- index's own parts added: description, authors, license, the CN mirror.
--
-- GLOBAL is the upstream release; CN is the same bytes at
-- gitcode.com/xlings-res/okprof (uploaded with `gtc release upload` and verified
-- by download), so one sha256 serves both. A POSIX package holds the program
-- under bin/ (the root's `okprof` is a convenience script); a Windows one holds
-- okprof.exe at its root -- hence the per-system bindir in config().
package = {
    spec = "2",
    name = "okprof",
    description = "Record and report openkal image performance: calls, phases, samples, page touches, traces and folded stacks",

    authors = {"mcpplibs"},
    maintainers = {"https://github.com/mcpplibs/openkal-image/graphs/contributors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/mcpplibs/openkal-image",
    docs = "https://github.com/mcpplibs/openkal-image#readme",
    homepage = "https://github.com/mcpplibs/openkal-image",
    type = "package",
    status = "dev", -- 0.x: the ok-image format and its tools are pre-1.0
    categories = {"openkal", "runtime", "tools"},
    keywords = {"openkal", "profiler", "ok-image", "trace", "samples"},
    archs = {"aarch64", "x86_64"},
    programs = {"okprof"},
    xvm_enable = true,
    -- 0.5.0 selects the immutable jit1 asset revision. Its package version is
    -- unchanged; the runner retains debugger registration symbols when packed.
    xpm = {
        linux = {
            source = {
                GLOBAL = "https://github.com/mcpplibs/openkal-image/releases/download/${version}/okprof-${version}-linux-${arch}.zip",
                CN = "https://gitcode.com/xlings-res/okprof/releases/download/${version}/okprof-${version}-linux-${arch}.zip",
            },
            ["latest"] = { ref = "0.5.0" },
            ["0.5.0"] = {
                url = {
                    GLOBAL = "https://github.com/mcpplibs/openkal-image/releases/download/0.5.0/okprof-0.5.0-jit1-linux-${arch}.zip",
                    CN = "https://gitcode.com/xlings-res/okprof/releases/download/0.5.0/okprof-0.5.0-jit1-linux-${arch}.zip",
                },
                sha256 = {
                    ["aarch64"] = "f8557eca1716527ba600b37f59c2afccb61fb25cc86e57a9fca9bc006f4a2bc5",
                    ["x86_64"] = "37fc6d9e0c0344be1bb804568318cffa5d20bce123b9ee2c952656a30c86e990",
                },
            },
            ["0.4.4"] = {
                sha256 = {
                    ["aarch64"] = "d41b50d91b69c3618f4862f826fcfbac38bbb89e0e89c6e8a5d9c73571bf9721",
                    ["x86_64"] = "4489e0e4cedaa61867920bc3b4d63ab0fe498b3fe673fa93101e44e2532d7d53",
                },
            },
            ["0.4.3"] = {
                sha256 = {
                    ["aarch64"] = "367d4cb6b82da800c8261afe427de04871f32a17b2bb49714619e3430c17b731",
                    ["x86_64"] = "da416be43cf3ad4e26547412b979a1a8461b30ca3c67492280db6292e12623fa",
                },
            },
            ["0.4.2"] = {
                sha256 = {
                    ["aarch64"] = "0d77118726b416f3649538529e749626a64d0edd0493f47bc83d25c14e01e7e3",
                    ["x86_64"] = "0be3abb7e757c2f5605c0f1949c8bc0808367e5d4a43a54506d9d037135e5892",
                },
            },
        },
        macosx = {
            source = {
                GLOBAL = "https://github.com/mcpplibs/openkal-image/releases/download/${version}/okprof-${version}-macos-${arch}.zip",
                CN = "https://gitcode.com/xlings-res/okprof/releases/download/${version}/okprof-${version}-macos-${arch}.zip",
            },
            ["latest"] = { ref = "0.5.0" },
            ["0.5.0"] = {
                url = {
                    GLOBAL = "https://github.com/mcpplibs/openkal-image/releases/download/0.5.0/okprof-0.5.0-jit1-macos-${arch}.zip",
                    CN = "https://gitcode.com/xlings-res/okprof/releases/download/0.5.0/okprof-0.5.0-jit1-macos-${arch}.zip",
                },
                sha256 = {
                    ["aarch64"] = "3919d20de41bafb7cec4a2af16bd7ff80c32962b3df585663df0b0ff7d30b076",
                },
            },
            ["0.4.4"] = {
                sha256 = {
                    ["aarch64"] = "0bfc6ef381dd4000d9d525218afbf2e23aee804ea2386d96dbd100aa3ed92fac",
                },
            },
            ["0.4.3"] = {
                sha256 = {
                    ["aarch64"] = "84dfb64183718c34e5b7764daefe4972dc5a58831f4792a0c37407edba721f18",
                },
            },
            ["0.4.2"] = {
                sha256 = {
                    ["aarch64"] = "77451b7457c6ef57b8fd23511f6995f9a996c427043cc9525b4ad57bdef50267",
                },
            },
        },
        windows = {
            source = {
                GLOBAL = "https://github.com/mcpplibs/openkal-image/releases/download/${version}/okprof-${version}-windows-${arch}.zip",
                CN = "https://gitcode.com/xlings-res/okprof/releases/download/${version}/okprof-${version}-windows-${arch}.zip",
            },
            ["latest"] = { ref = "0.5.0" },
            ["0.5.0"] = {
                url = {
                    GLOBAL = "https://github.com/mcpplibs/openkal-image/releases/download/0.5.0/okprof-0.5.0-jit1-windows-${arch}.zip",
                    CN = "https://gitcode.com/xlings-res/okprof/releases/download/0.5.0/okprof-0.5.0-jit1-windows-${arch}.zip",
                },
                sha256 = {
                    ["x86_64"] = "545633dfa5d0815dacaab45efe318dc4596b50fbb621a75d545857485f68ce04",
                },
            },
            ["0.4.4"] = {
                sha256 = {
                    ["x86_64"] = "de47049762d9e979cb8e65aa9560eec0e9c82e3e2d59ace7606ca4e0ad1331f9",
                },
            },
            ["0.4.3"] = {
                sha256 = {
                    ["x86_64"] = "02ff0ed4ffbd5a6d0c953518ded703cea0778a0c9254abe826c43b90a61545b0",
                },
            },
            ["0.4.2"] = {
                sha256 = {
                    ["x86_64"] = "119e7f5ddf3dd8f696c7bb8d65a4e3b00fd0f74e47412a546c1121e12699f5d8",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    -- The archive's one top-level directory is the package; it is named
    -- after the archive, which xim unpacks beside it.
    local top = pkginfo.install_file()
    for _, ext in ipairs({ ".zip" }) do
        if top:sub(-#ext) == ext then top = top:sub(1, #top - #ext) break end
    end
    if not os.isdir(top) then return false end
    os.tryrm(pkginfo.install_dir())
    os.mv(top, pkginfo.install_dir())
    return os.isdir(pkginfo.install_dir())
end

function config()
    local bindir = { linux = "bin", macosx = "bin", windows = "." }
    local opts = { bindir = path.join(pkginfo.install_dir(), bindir[os.host()]) }
    xvm.add("okprof", opts)
    return true
end

function uninstall()
    xvm.remove("okprof")
    return true
end
