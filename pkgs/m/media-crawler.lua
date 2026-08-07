package = {
    spec = "1",

    name = "media-crawler",
    description = "Multi-platform social media crawler (XHS, Douyin, Kuaishou, Bilibili, Weibo, Tieba, Zhihu) using Playwright",

    authors = {"NanmiCoder"},
    maintainers = {"NanmiCoder"},
    licenses = {"NON-COMMERCIAL LEARNING LICENSE 1.1"},
    repo = "https://github.com/NanmiCoder/MediaCrawler",
    homepage = "https://github.com/NanmiCoder/MediaCrawler",

    type = "package",
    archs = {"x86_64", "arm64"},
    status = "dev",
    categories = {"tools", "crawler", "data"},
    keywords = {"crawler", "scraper", "social-media", "xiaohongshu", "douyin", "bilibili", "weibo", "playwright"},

    programs = {"media-crawler"},
    xvm_enable = true,

    -- Source archive from GitHub (pinned to commit).
    -- Requires Python >= 3.11 and Node.js >= 16 at runtime.
    xpm = {
        linux = {
            deps = {"xim:python", "xim:uv"},
            ["latest"] = { ref = "2026.4.30" },
            ["2026.4.30"] = {
                url = "https://github.com/NanmiCoder/MediaCrawler/archive/f328ee35b55e25e8aaeb9c847fe8b622e3f3447f.tar.gz",
                sha256 = "f11b00a9425cc89488054a395e27fc86d846372854b2d5d684cec6b5ce6576b2",
            },
        },
        macosx = {
            ["latest"] = { ref = "2026.4.30" },
            ["2026.4.30"] = {
                url = "https://github.com/NanmiCoder/MediaCrawler/archive/f328ee35b55e25e8aaeb9c847fe8b622e3f3447f.tar.gz",
                sha256 = "f11b00a9425cc89488054a395e27fc86d846372854b2d5d684cec6b5ce6576b2",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.system")

function __source_dir()
    local archive = pkginfo.install_file()
    local dir = path.directory(archive)
    return path.join(dir, "MediaCrawler-f328ee35b55e25e8aaeb9c847fe8b622e3f3447f")
end

function __has_uv()
    return os.iorun("uv --version") ~= nil
end

function install()
    os.tryrm(pkginfo.install_dir())
    os.cp(__source_dir(), pkginfo.install_dir())

    local installdir = pkginfo.install_dir()

    -- Try uv first; fall back to pip if uv fails or is absent
    local use_uv = __has_uv()
    if use_uv then
        local ok = os.exec(string.format(
            [[cd "%s" && UV_INDEX_URL=https://pypi.org/simple/ uv venv && UV_INDEX_URL=https://pypi.org/simple/ uv sync]],
            installdir), {try = true})
        if not ok then use_uv = false end
    end

    if not use_uv then
        system.exec(string.format([[cd "%s" && python3 -m venv .venv]], installdir))
        local pip = path.join(installdir, ".venv", "bin", "pip")
        system.exec(string.format([["%s" install --upgrade pip]], pip))
        system.exec(string.format([["%s" install -r "%s/requirements.txt"]], pip, installdir))
    end

    -- Install playwright chromium
    if use_uv then
        system.exec(string.format([[cd "%s" && uv run playwright install chromium]], installdir))
    else
        system.exec(string.format([[cd "%s" && .venv/bin/playwright install chromium]], installdir))
    end

    -- Create launcher script
    local bindir = path.join(installdir, "bin")
    os.mkdir(bindir)
    local launcher = path.join(bindir, "media-crawler")
    if use_uv then
        io.writefile(launcher, string.format([[#!/bin/bash
cd "%s"
exec uv run main.py "$@"
]], installdir))
    else
        io.writefile(launcher, string.format([[#!/bin/bash
cd "%s"
exec .venv/bin/python main.py "$@"
]], installdir))
    end
    os.exec(string.format([[chmod +x "%s"]], launcher))

    return true
end

function config()
    xvm.add("media-crawler", {
        bindir = path.join(pkginfo.install_dir(), "bin"),
    })
    return true
end

function uninstall()
    xvm.remove("media-crawler")
    return true
end
