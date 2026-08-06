-- TODO: Linux 运行时缺 libwebkit2gtk-4.1.so.0，pmwrapper 中 webkit2gtk 映射的是 4.0 版本(libwebkit2gtk-4.0-37)
--       需要更新 pmwrapper.lua 或 deps 中的系统依赖为 libwebkit2gtk-4.1-dev

function _linux_donwload_url(version) return string.format("https://github.com/LiRenTech/project-graph/releases/download/v%s/Project.Graph_%s_amd64.deb", version, version) end

package = {

    -- Platform version sets differ ON PURPOSE:
    -- windows tracks its own `latest` (1.2.7) and stops there.
    -- Declared so `tests/check_platform_version_parity.lua` can tell this
    -- apart from a bump that landed in one section and was forgotten in the
    -- others -- which reads as `<pkg>@<ver> not found` on the platforms that
    -- lack it, against a file that contains the version string.
    platform_versions_diverge = true,
    spec = "1",
    homepage = "https://project-graph.top",
    name = "project-graph",
    description = "快速绘制节点图的桌面工具 - 项目进程拓扑图绘制、头脑风暴草稿",

    maintainers = {"LiRenTech"},
    contributors = "https://github.com/LiRenTech/project-graph/graphs/contributors",
    licenses = {"MIT"},
    repo = "https://github.com/LiRenTech/project-graph",
    docs = "https://project-graph.top/getting-started",
    forum = "https://forum.d2learn.org/category/16/project-graph",

    -- xim pkg info
    type = "package", -- package, config
    archs = {"x86_64", "aarch64"},
    status = "stable", -- dev, stable, deprecated
    categories = {"desktop-tools", "graph-tools"},
    keywords = { "project", "topology", "drawing", "graph" },

    xpm = {
        windows = {
            ["latest"] = { ref = "1.2.7" },
            ["nightly"] = {
                url = "%.exe$", -- url pattern
                github_release_tag = "nightly",
            },
            ["1.2.7"] = {
                url = "https://github.com/LiRenTech/project-graph/releases/download/v1.2.7/Project.Graph_1.2.7_x64-setup.exe",
                sha256 = nil,
            },
            ["1.1.0"] = {
                url = "https://github.com/LiRenTech/project-graph/releases/download/v1.1.0/Project.Graph_1.1.0_x64-setup.exe",
                sha256 = nil,
            },
            ["1.0.0"] = { 
                url = "https://github.com/LiRenTech/project-graph/releases/download/v1.0.0/Project.Graph_1.0.0_x64-setup.exe",
                sha256 = nil,
            }
        },
        linux = {
            deps = { "webkit2gtk" },
            ["latest"] = { ref = "1.7.10" },
            ["nightly"] = {
                url = "%.deb$", -- url pattern
                github_release_tag = "nightly",
            },
            ["1.7.10"] = { url = _linux_donwload_url("1.7.10"), sha256 = nil },
            ["1.7.0"] = { url = _linux_donwload_url("1.7.0"), sha256 = nil },
            ["1.6.0"] = { url = _linux_donwload_url("1.6.0"), sha256 = nil },
            ["1.5.1"] = { url = _linux_donwload_url("1.5.1"), sha256 = nil },
            ["1.5.0"] = { url = _linux_donwload_url("1.5.0"), sha256 = nil },
            ["1.4.0"] = { url = _linux_donwload_url("1.4.0"), sha256 = nil },
            ["1.2.7"] = { url = _linux_donwload_url("1.2.7"), sha256 = nil },
            ["1.2.6"] = { url = _linux_donwload_url("1.2.6"), sha256 = nil },
            ["1.2.5"] = { url = _linux_donwload_url("1.2.5"), sha256 = nil },
            ["1.2.0"] = { url = _linux_donwload_url("1.2.0"), sha256 = nil },
            ["1.1.0"] = {
                url = "https://github.com/LiRenTech/project-graph/releases/download/v1.1.0/Project.Graph_1.1.0_amd64.deb",
                sha256 = "220ffb27c20f15008b77138612a237eefea22691638f09b351d276085af02d32",
            },
            ["1.0.0"] = {
                url = "https://github.com/LiRenTech/project-graph/releases/download/v1.0.0/Project.Graph_1.0.0_amd64.deb",
                sha256 = nil,
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.log")

local binname = {
    windows = "project-graph.exe",
    linux = "project-graph",
}

function install()
    if os.host() == "windows" then
        log.debug("安装tips:")
        log.debug("\t 0.打开安装提示")
        log.debug("\t 1.选择对应语言")
        log.debug('\t 2.点击"下一步"直到安装完成')
        os.exec(pkginfo.install_file() .. " /SILENT")
    elseif os.host() == "linux" then
        os.tryrm("project-graph")
        os.tryrm(pkginfo.install_dir())
        os.mkdir("project-graph")
        os.cd("project-graph")
        os.exec("ar x " .. pkginfo.install_file())
        os.exec("tar -xvf data.tar.gz")
        os.mv("usr", pkginfo.install_dir())
        os.tryrm(pkginfo.install_file())
    end
    return true
end

function config()
    local project_graph_path = path.join(pkginfo.install_dir(), "bin")
    if os.host() == "windows" then
        log.debug("remove old version...")
        xvm.remove("project-graph")
        project_graph_path = "C:\\Users\\" .. os.getenv("USERNAME") .. "\\AppData\\Local\\Project Graph"
    else
        _config_desktop_shortcut("create")
    end
    xvm.add("project-graph", { bindir = project_graph_path })
    return true
end

function uninstall()
    if os.host() == "windows" then
        os.exec("\"C:\\Users\\" .. os.getenv("USERNAME") .. "\\AppData\\Local\\Project Graph\\uninstall.exe\"")
    elseif os.host() == "linux" then
        _config_desktop_shortcut("delete")
    end
    xvm.remove("project-graph")
    return true
end

function _config_desktop_shortcut(action)
    action = action or "delete" -- create, delete
    if os.host() == "linux" then
        local filename = "project-graph-" .. pkginfo.version() .. ".xvm.desktop"
        local shortcut_file = path.join(os.getenv("HOME"), ".local/share/applications", filename)
        local desktop_entry = [[
[Desktop Entry]
Name=Project Graph - [%s]
Comment=Diagram creator
Exec=%s
Icon=%s
Type=Application
StartupNotify=false
StartupWMClass=project-graph
        ]]

        log.debug("[%s] - %s", action, shortcut_file)

        if action == "create" then
            io.writefile(filename, string.format(
                desktop_entry,
                pkginfo.version(),
                path.join(pkginfo.install_dir(), "bin", "project-graph"),
                path.join(pkginfo.install_dir(), "share/icons/hicolor/128x128/apps/project-graph.png"
            )))
            os.mv(filename, shortcut_file)
        elseif action == "delete" then
            os.tryrm(shortcut_file)
        end
    end
end
