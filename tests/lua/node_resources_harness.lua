-- Load a recipe as a plain Lua chunk and print every resource it RESOLVES.
--
-- node.lua builds its resources with `_asset()` rather than writing URLs out,
-- so grepping the file cannot tell you what a version actually points at --
-- only evaluating it can. `import()` is stubbed and no hook is called, so this
-- reads exactly the `package` table the index would.
--
-- Output, one asset per line, tab separated:
--     ASSET <platform> <version> <arch> <global-url> <cn-url> <sha256>
-- plus one line per platform:
--     LATEST <platform> <ref>
-- Missing pieces are spelled NO-CN / NO-SHA / NOT-A-MIRROR-TABLE so the
-- caller asserts on them instead of on a nil that vanished from the output.

local recipe = ...
assert(recipe, "usage: lua node_resources_harness.lua <recipe.lua>")

local env = setmetatable({}, { __index = _G })
env.import = function() return {} end
assert(loadfile(recipe, "t", env))()

local pkg = assert(env.package, "recipe defines no `package` table")
local out = {}

for _, platform in ipairs({ "linux", "macosx", "windows" }) do
    local versions = pkg.xpm and pkg.xpm[platform]
    if versions then
        local latest = versions["latest"]
        print(string.format("LATEST\t%s\t%s", platform,
            (type(latest) == "table" and latest.ref) or "NO-LATEST"))

        for version, entry in pairs(versions) do
            -- skip `latest`/aliases (`{ref=...}`) and non-version keys (`deps`)
            if type(entry) == "table" and entry.ref == nil and version:match("^%d") then
                for _, arch in ipairs({ "x86_64", "aarch64" }) do
                    local res = entry[arch]
                    if res then
                        local url, cn = res.url, "NOT-A-MIRROR-TABLE"
                        if type(url) == "table" then
                            cn, url = url.CN or "NO-CN", url.GLOBAL or "NO-GLOBAL"
                        end
                        out[#out + 1] = string.format("ASSET\t%s\t%s\t%s\t%s\t%s\t%s",
                            platform, version, arch, url, cn, res.sha256 or "NO-SHA")
                    end
                end
            end
        end
    end
end

table.sort(out)
for _, line in ipairs(out) do print(line) end
