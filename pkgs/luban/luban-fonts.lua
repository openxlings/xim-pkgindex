package = {
    spec = "1",

    name = "luban-fonts",
    description = "The fonts the Luban OS window ships with: JetBrains Mono and Sarasa Mono SC (console), Inter and Noto Sans SC (text), Fusion Pixel (titles)",

    homepage = "https://github.com/openxlings/xlings",
    licenses = {"OFL-1.1"},

    type = "package",
    -- Data: the same files on every system and machine.
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"desktop", "luban", "font"},
    keywords = {"luban", "luban-os", "font", "monospace", "cjk", "pixel"},

    -- What luban-os draws with (xlings design 2026-10-16 L §13): the
    -- console's monospace (JetBrains Mono; Sarasa Mono SC for CJK, two cells
    -- wide), the text's sans (Inter; Noto Sans SC for CJK) and the titles'
    -- pixel font (Fusion Pixel 12px, Simplified Chinese), in share/fonts/luban
    -- -- where luban-os looks first -- with their licenses in
    -- share/licenses/luban-fonts; each under the SIL Open Font License 1.1.
    -- The version is the date the set was chosen; tools/res/inputs.txt names
    -- each font's release and digest (tools/res/build.sh luban-fonts).
    xpm = {
        linux = {
            ["latest"] = { ref = "2026.10.16" },
            ["2026.10.16"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/luban-fonts/releases/download/2026.10.16/luban-fonts-2026.10.16.tar.gz",
                    CN     = "https://gitcode.com/xlings-res/luban-fonts/releases/download/2026.10.16/luban-fonts-2026.10.16.tar.gz",
                },
                sha256 = "f12eb7c0e69926583e092862b35c47ce2c91e639c73b2ed063971e99ac222d3f",
            },
        },
        macosx = { ref = "linux" },
        windows = { ref = "linux" },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    local dir = pkginfo.install_dir()
    local payload = path.join(path.directory(pkginfo.install_file()), "luban-fonts-" .. pkginfo.version())
    if os.isdir(payload) then
        os.tryrm(dir)
        os.mv(payload, dir)
    end
    return os.isfile(path.join(dir, "share", "fonts", "luban", "JetBrainsMono-Regular.ttf"))
end

-- Data, not a program: the package name is registered so a home knows it has
-- it (a group: it names no program, so it has no shim).
function config()
    xvm.add(package.name, { type = "group" })
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end
