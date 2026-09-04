package = {
    spec = "2",

    name = "mcpp-hooks-audioplayer",
    description = "Play embedded audio for mcpp build hooks",
    homepage = "https://github.com/helantianshen/mcpp-hooks-audioplayer",
    authors = {"helantianshen"},
    licenses = {"MIT"},
    repo = "https://github.com/helantianshen/mcpp-hooks-audioplayer",
    docs = "https://github.com/helantianshen/mcpp-hooks-audioplayer#readme",

    type = "package",
    archs = {"x86_64"},
    status = "dev",
    categories = {"cpp", "tools"},
    keywords = {"mcpp", "hooks", "audio", "notification"},

    programs = {"mcpp-hooks-audioplayer"},
    xvm_enable = true,

    xpm = {
        linux = {
            ["latest"] = { ref = "0.0.3" },
            ["0.0.3"] = {
                x86_64 = {
                    url = "https://github.com/helantianshen/mcpp-hooks-audioplayer/releases/download/v0.0.3/mcpp-hooks-audioplayer-0.0.3-x86_64-linux-musl-static.tar.gz",
                    sha256 = "a4bf169924b56c53521d78a029a506d90c85932d3a8d73720b1eb6091c62ae5b",
                },
            },
            ["0.0.2"] = {
                x86_64 = {
                    url = "https://github.com/helantianshen/mcpp-hooks-audioplayer/releases/download/v0.0.2/mcpp-hooks-audioplayer-0.0.2-x86_64-linux-musl-static.tar.gz",
                    sha256 = "9b8ef6c840ca070736ba0f9052102feba19d00b75944ec399e879f3041c6fe33",
                },
            },
            ["0.0.1"] = {
                x86_64 = {
                    url = "https://github.com/helantianshen/mcpp-hooks-audioplayer/releases/download/v0.0.1/mcpp-hooks-audioplayer-0.0.1-x86_64-linux-musl-static.tar.gz",
                    sha256 = "aaa92c604e012cda101629dffe4c51d0f43b31ec77e62218c2f746d96dbd3c5f",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "0.0.3" },
            ["0.0.3"] = {
                x86_64 = {
                    url = "https://github.com/helantianshen/mcpp-hooks-audioplayer/releases/download/v0.0.3/mcpp-hooks-audioplayer-0.0.3-x86_64-w64-mingw32.zip",
                    sha256 = "9dac343431b989b226b8b881b2568d66dc0d46f38c17bcdb16b4ccbb9483a09a",
                },
            },
            ["0.0.2"] = {
                x86_64 = {
                    url = "https://github.com/helantianshen/mcpp-hooks-audioplayer/releases/download/v0.0.2/mcpp-hooks-audioplayer-0.0.2-x86_64-w64-mingw32.zip",
                    sha256 = "29ccef955b14b2c728bbeea7f329ce076285de4ca070b1fb26794af98f98f73d",
                },
            },
            ["0.0.1"] = {
                x86_64 = {
                    url = "https://github.com/helantianshen/mcpp-hooks-audioplayer/releases/download/v0.0.1/mcpp-hooks-audioplayer-0.0.1-x86_64-w64-mingw32.zip",
                    sha256 = "f114cc4fc670a74dd8d8ff754983de849381762c2c48dba6787d496196c689ec",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    local extracted = pkginfo.install_file()
        :replace(".tar.gz", "")
        :replace(".zip", "")
    local install_dir = pkginfo.install_dir()
    os.tryrm(install_dir)
    os.mv(extracted, install_dir)

    local executable = os.host() == "windows"
        and "mcpp-hooks-audioplayer.exe"
        or "mcpp-hooks-audioplayer"
    return os.isfile(path.join(install_dir, executable))
end

function config()
    xvm.add(package.name, { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
