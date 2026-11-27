-- nginx - high-performance HTTP server, reverse proxy, and load balancer.
--
-- Platform and architecture coverage:
--   windows  x86_64   Official nginx.org 1.30.7 stable archive (`nginx-1.30.7.zip`)
--
-- Linux and macOS are intentionally not declared until an `xlings-res` factory
-- target (`tools/res/build.sh`) publishes a musl-static build from official
-- nginx.org sources: upstream distributes source tarballs only for POSIX, and
-- third-party static prebuilts without reproducible provenance are avoided.
package = {
    spec = "3",

    name = "nginx",
    description = "nginx - high-performance HTTP web server, reverse proxy and load balancer (official stable build)",
    homepage = "https://nginx.org",
    authors = {"Igor Sysoev", "NGINX, Inc."},
    maintainers = {"nginx.org"},
    licenses = {"BSD-2-Clause"},
    repo = "https://github.com/nginx/nginx",
    docs = "https://nginx.org/en/docs/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"network", "web", "server", "proxy", "tools"},
    keywords = {"nginx", "http", "https", "reverse-proxy", "web-server", "load-balancer"},

    programs = {"nginx"},
    xvm_enable = true,

    xpm = {
        windows = {
            strip = 1,
            ["latest"] = { ref = "1.30.7" },
            ["1.30"] = { ref = "1.30.7" },
            ["1.30.7"] = {
                x86_64 = {
                    url = "https://nginx.org/download/nginx-1.30.7.zip",
                    sha256 = "204bb1685b777d7124e9afba2a1dc51edb0eccdfb366262186eb55803a382e02",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

local REQUIRED_FILES = {
    "nginx.exe",
    "conf/nginx.conf",
    "conf/mime.types",
    "html/index.html",
}

function installed()
    return payload.present(REQUIRED_FILES)
end

function install()
    payload.require(REQUIRED_FILES)
    return true
end

function config()
    xvm.add("nginx", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("nginx")
    return true
end
