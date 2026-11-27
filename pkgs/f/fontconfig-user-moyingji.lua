package = {
    spec = "3",

    -- base info
    name = "fontconfig-user-moyingji",
    description = "Basic user configuration for Linux Fontconfig written by MoYingJi",

    authors = {"MoYingJi"},
    licenses = {"Apache-2.0"},

    -- xim pkg info
    type = "config",
    namespace = "config",
    keywords = { "fontconfig", "font", "config" },

    xpm = {
        linux = { ["latest"] = { } },
    },
}



import("xim.libxpkg.log")
import("xim.libxpkg.fs")
import("xim.libxpkg.path")

local function get_config_file()
    local config_dir = os.getenv("XDG_CONFIG_HOME") or path.join(os.getenv("HOME"), ".config")
    return path.join(config_dir, "fontconfig/conf.d/71-fontsconfig-user-moyingji.conf")
end

function installed()
    local config_file = get_config_file()
    if fs.is_file(config_file) then return true end

    return false
end

function install()
    local config_file = get_config_file()
    local dir = path.directory(config_file)
    if not fs.is_dir(dir) then fs.mkdir(dir) end
    fs.write(config_file, content())

    log.warn("已安装字体配置文件：%s", config_file)
    log.warn("可在此处进行自定义字体，或禁用衬线字体等操作，有注释引导操作")
    log.warn("重启任意软件即可使对应软件的字体生效，重新登录安装了此配置的用户即可使字体对该用户全局生效")

    return true
end

function uninstall()
    fs.remove(get_config_file())

    return true
end



function content()
    local content = [[
<fontconfig>
    <!-- 本配置为基础配置 能用就行 -->

    <!-- 默认使用思源，回落到 Noto -->

    <!-- 默认使用无衬线字体 -->
    <match>
        <test name="family"><string>system-ui</string></test>
        <edit name="family" mode="prepend" binding="strong"><string>sans-serif</string></edit>
    </match>

    <!-- 将衬线字体替换为无衬线字体 -->
    <!-- 若不喜欢衬线字体 可以取消这里的注释 -->
    <!-- <match target="pattern">
        <test qual="any" name="family"><string>serif</string></test>
        <edit name="family" mode="assign" binding="strong"><string>sans-serif</string></edit>
    </match> -->

    <!-- 默认衬线字体 -->
    <!-- 若已经将衬线字体替换为无衬线字体 那么可以删除下面这段 -->
    <match>
        <test name="family"><string>serif</string></test>
        <edit name="family" mode="prepend" binding="strong">
            <!-- 可在此处新增或修改成你想要的字体 -->
            <string>Source Han Serif CN</string>
            <string>Noto Serif CJK SC</string>
        </edit>
    </match>

    <!-- 默认无衬线字体 -->
    <match>
        <test name="family"><string>sans-serif</string></test>
        <edit name="family" mode="prepend" binding="strong">
            <!-- 可在此处新增或修改成你想要的字体 -->
            <string>Source Han Sans CN</string>
            <string>Noto Sans CJK SC</string>
        </edit>
    </match>



    <!-- 字体替换 -->

    <!-- 微软雅黑 -->
    <match target="pattern">
        <test qual="any" name="family"><string>Microsoft YaHei</string></test>
        <edit name="family" mode="assign" binding="same">
            <!-- 可在此处新增或修改成你想要的字体 -->
            <string>Source Han Sans CN</string>
            <string>Noto Sans CJK SC</string>
        </edit>
    </match>



    <!-- 其他字形 -->
    %s

</fontconfig>
    ]]

    content = string.format(content, gen_other_glyphs_config())

    return content
end

function gen_other_glyphs_config()
    local glyphs = {
        {
            region = "tw",
            maps = {
                ["Source Han Sans CN"] = "Source Han Sans TW",
                ["Source Han Serif CN"] = "Source Han Serif TW",
                ["Noto Sans CJK SC"] = "Noto Sans CJK TC",
                ["Noto Serif CJK SC"] = "Noto Serif CJK TC",
            },
        },
        {
            region = "hk",
            maps = {
                ["Source Han Sans CN"] = "Source Han Sans HK",
                ["Source Han Serif CN"] = "Source Han Serif HK",
                ["Noto Sans CJK SC"] = "Noto Sans CJK HK",
                ["Noto Serif CJK SC"] = "Noto Serif CJK HK",
            },
        },
        {
            region = "jp",
            maps = {
                ["Source Han Sans CN"] = "Source Han Sans JP",
                ["Source Han Serif CN"] = "Source Han Serif JP",
                ["Noto Sans CJK SC"] = "Noto Sans CJK JP",
                ["Noto Serif CJK SC"] = "Noto Serif CJK JP",
            },
        },
        {
            region = "kr",
            maps = {
                ["Source Han Sans CN"] = "Source Han Sans KR",
                ["Source Han Serif CN"] = "Source Han Serif KR",
                ["Noto Sans CJK SC"] = "Noto Sans CJK KR",
                ["Noto Serif CJK SC"] = "Noto Serif CJK KR",
            },
        },
    }

    local output = {}

    for _, r in ipairs(glyphs) do
        table.insert(output, "")
        table.insert(output, "    <!-- " .. r.region .. " -->")
        for k, v in pairs(r.maps) do
            table.insert(output, '    <match target="pattern">')
            table.insert(output, string.format('        <test name="lang" compare="contains"><string>%s</string></test>', r.region))
            table.insert(output, string.format('        <test qual="any" name="family"><string>%s</string></test>', k))
            table.insert(output, string.format('        <edit name="family" mode="assign" binding="strong"><string>%s</string></edit>', v))
            table.insert(output, '    </match>')
        end
    end

    return table.concat(output, "\n")
end
