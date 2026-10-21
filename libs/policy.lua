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

local policy = {}

function policy.write(json)
    local dir = pkginfo.install_dir()
    os.mkdir(dir)
    local file = dir .. "/policy.json"
    local f = io.open(file, "wb")
    if not f then error("cannot write " .. file) end
    assert(f:write(json))
    f:close()
    return os.isfile(file)
end

return policy
