-- https://github.com/orgs/community/discussions/174283#discussioncomment-14533335

-- One version table, which each platform names (a platform-level `ref` is
-- not read by xlings before 2026.10.16.2).
local versions = {
    ["latest"] = { ref = "0.0.1" },
    ["0.0.1"] = {},
}

package = {
    spec = "1",

    -- base info
    name = "github-notifications-clear",
    description = "Clear github's notifications (unread)",

    maintainers = {"d2learn"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/openxlings/xim-pkgindex",
    docs = "https://github.com/orgs/community/discussions/174283",

    -- xim pkg info
    type = "script",
    status = "stable", -- dev, stable, deprecated
    categories = { "tools", "github", "notifications" },

    xpm = {
        linux = versions,
        windows = versions,
        macosx = versions,
    },
}

import("xim.libxpkg.json")
import("xim.libxpkg.log")

function xpkg_main(person_access_token)
    if not person_access_token then
        log.error("need provide your github PERSONAL_ACCESS_TOKEN(PAT Classic)")
        cprint("\n\t${bright dim cyan}github-notifications-clear ${green}PERSONAL_ACCESS_TOKEN\n")
        log.warn(" -> https://github.com/settings/tokens <-")
        return
    end

    -- Check curl is available
    local curl_check = os.iorun("which curl 2>/dev/null") or os.iorun("where curl 2>nul")
    if not curl_check or curl_check:trim() == "" then
        log.error("curl not found, please install curl first")
        return
    end

    log.info("start get unread message list...")

    local unread_msg_list_json = os.iorun(string.format([[curl -s -H "Authorization: token %s" https://api.github.com/notifications]],
        person_access_token
    ))

    cprint(unread_msg_list_json)

    local unread_msg_list = json.decode(unread_msg_list_json)

    for _, msg in ipairs(unread_msg_list) do
        log.info("try to clearing notification: [ %s, %s ]", msg.id, msg.subject.title)
        local response = os.iorun(string.format([[curl -s -X DELETE -H "Authorization: token %s" https://api.github.com/notifications/threads/%s]],
            person_access_token, msg.id
        ))
        cprint("\n" .. tostring(response) .. "\n")
    end

    log.info("All notifications cleared")
end
