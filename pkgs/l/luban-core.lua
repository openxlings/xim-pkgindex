-- Luban Core (xlings SubOS design part 2 §9): `from` subos:luban-tiny@0.1.0, so its root
-- is that edition's plus what this one declares; a package or a file both
-- carry is this one's. Nothing to download -- install() writes the template.
--
--   xlings subos new mybox --rootfs --from subos:luban-core
package = {
    spec = "1",
    name = "luban-core",
    namespace = "subos",
    description = "Luban Core: luban-tiny plus GNU bash and coreutils, a C/C++ toolchain, TLS and curl",
    homepage = "https://github.com/openxlings/xlings",
    licenses = {"Apache-2.0"},
    type = "subos",
    archs = {"x86_64"},
    status = "stable",
    categories = {"subos", "distribution"},
    keywords = {"luban", "rootfs", "distribution", "core", "toolchain", "gcc"},

    xpm = {
        linux = {
            ["latest"] = { ref = "0.1.0" },
            ["0.1.0"] = {},
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.log")

local function write(rel, content)
    local file = path.join(pkginfo.install_dir(), rel)
    os.mkdir(path.directory(file))
    local f = io.open(file, "wb")
    f:write(content)
    f:close()
end

local manifest = [[
{
  "subos_kind": "rootfs",
  "from": "subos:luban-tiny@0.1.0",
  "packages": [
    "xim:bash@5.2.37",
    "xim:coreutils@9.5",
    "xim:gcc@16.1.0",
    "xim:binutils@2.42.1",
    "xim:make@4.3",
    "xim:openssl@3.1.5",
    "xim:curl@8.21.0",
    "xim:xz@5.8.3",
    "xim:zlib@1.3.1"
  ],
  "workspace": {}
}
]]

function install()
    os.tryrm(pkginfo.install_dir())
    os.mkdir(pkginfo.install_dir())
    write(".xlings.json", manifest)
    write("usr/share/factory/etc/os-release", [[
NAME="Luban"
ID=luban
VARIANT="Core"
VARIANT_ID=core
VERSION_ID=0.1.0
PRETTY_NAME="Luban Core 0.1.0"
HOME_URL="https://github.com/openxlings/xlings"
]])
    write("usr/share/factory/etc/shells", "/bin/sh\n/bin/bash\n")
    log.info("luban-core template at %s", pkginfo.install_dir())
    return true
end
