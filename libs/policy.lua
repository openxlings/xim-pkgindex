-- A SubOS policy package's one file (the subos policy design): policy.json,
-- written byte for byte into the package's install directory, which
-- `xlings subos config <n> --policy <package>` (and luban's `--policy`)
-- reads. Generic: any index's policy package uses it, Luban's and others'.
--
-- Loaded by package hooks via:
--     import("xim.pkgindex.policy")
--
--     function install() return policy.write(json) end

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.fs")

local policy = {}

function policy.write(json)
    local dir = pkginfo.install_dir()
    fs.mkdir(dir)
    local file = dir .. "/policy.json"
    fs.write(file, json)
    return fs.is_file(file)
end

return policy
