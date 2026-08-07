package = {
    spec = "1",

    name = "sing-box-helper",
    description = "Sing-Box Helper Tools - Simple commands for server and client configuration",
    licenses = {"GPL-3.0-or-later"},
    repo = "https://github.com/openxlings/xim-pkgindex",

    type = "script",
    status = "stable",
    categories = {"tools", "proxy", "sing-box"},
    keywords = {"sing-box", "helper", "proxy", "server", "client"},

    -- Linux-only: the start/stop/status commands drive systemd. The
    -- config-generation commands (server/client/import) work on any
    -- POSIX shell, but it isn't worth fanning out the platform table
    -- until someone asks for non-Linux deployment.
    xpm = {
        linux = {
            deps = {"xim:sing-box"},
            ["1.0.0"] = {},
        },
    },
}

import("xim.libxpkg.log")
import("xim.libxpkg.xvm")
import("xim.libxpkg.system")
import("xim.libxpkg.base64")
import("xim.libxpkg.json")

local SYSTEMD_SERVICE = "sing-box.service"
local SYSTEMD_UNIT_PATH = "/etc/systemd/system/" .. SYSTEMD_SERVICE

-- Resolve the installed sing-box binary at call time. The dependency
-- declaration in `xpm.linux.deps` guarantees it is registered with xvm
-- before any sing-box-helper command runs, but we still treat a nil
-- info as "not yet wired up" and bail with a friendly hint.
local function sing_box_bin()
    local info = xvm.info("sing-box")
    if not info or not info.SPath or info.SPath == "" then
        cprint("${red}✗${clear} sing-box not registered with xvm — run: xlings install sing-box")
        return nil
    end
    return info.SPath
end

local function get_config_dir()
    return path.join(system.xpkgdir(), "configs")
end

local function get_current_file()
    return path.join(get_config_dir(), ".current")
end

local function get_subscription_file()
    return path.join(get_config_dir(), ".subscription")
end

function ensure_config_dir()
    if not os.isdir(get_config_dir()) then
        os.mkdir(get_config_dir())
    end
end

function print_usage()
    cprint("\t${bright}Sing-Box Helper Tools - 1.0.0${clear}")
    cprint("")
    cprint("Usage: ${dim cyan}sing-box-helper <command> [options]")
    cprint("")
    cprint("Commands:")
    cprint("  ${dim cyan}server${clear}      - Generate server configuration")
    cprint("  ${dim cyan}client${clear}      - Generate client configuration")
    cprint("  ${dim cyan}config${clear}      - Manage configurations (list, current, etc.)")
    cprint("  ${dim cyan}start${clear}       - Start sing-box with a configuration")
    cprint("  ${dim cyan}stop${clear}        - Stop sing-box service")
    cprint("  ${dim cyan}status${clear}      - Show service status")
    cprint("  ${dim cyan}sub${clear}         - Generate & save subscription link (for server)")
    cprint("  ${dim cyan}getsub${clear}      - Show saved subscription link")
    cprint("  ${dim cyan}import${clear}      - Import configuration from subscription link")
    cprint("  ${dim cyan}help${clear}        - Show this help message")
    cprint("")
    cprint("Examples:")
    cprint("  ${dim cyan}# Server setup")
    cprint("  ${dim cyan}sing-box-helper server --name my-server --port 9875 --protocol shadowsocks --password mypass")
    cprint("  ${dim cyan}sing-box-helper start my-server")
    cprint("  ${dim cyan}sing-box-helper sub")
    cprint("  ${dim cyan}sing-box-helper getsub")
    cprint("")
    cprint("  ${dim cyan}# Client setup")
    cprint("  ${dim cyan}sing-box-helper import ss://YmFzZTI0LXRybWVkYXRlOm15cGFzc0AxLjIuMy40Ojk4NzUjc3MtY29uZmln")
    cprint("  ${dim cyan}sing-box-helper start imported-ss-20251209-120000")
    cprint("")
    cprint("  ${dim cyan}# Config management")
    cprint("  ${dim cyan}sing-box-helper config list")
    cprint("  ${dim cyan}sing-box-helper config current")
    cprint("")
    cprint("${dim}Local proxy (client):${clear}")
    cprint("  ${dim}SOCKS5: 127.0.0.1:1080${clear}")
    cprint("  ${dim}HTTP:   127.0.0.1:1087${clear}")
    cprint("")
end

function get_current_config()
    if os.isfile(get_current_file()) then
        local raw = io.readfile(get_current_file()) or ""
        return raw:match("^%s*(.-)%s*$")
    end
    return nil
end

function set_current_config(name)
    io.writefile(get_current_file(), name)
end

-- List configurations by enumerating *.json files in the config dir
-- via libxpkg's `os.dirs`/raw filesystem walk; replaces the previous
-- io.popen("ls ...") shell call.
local function list_config_files()
    ensure_config_dir()
    local files = {}
    local dir = get_config_dir()
    local f = io.popen('find "' .. dir .. '" -maxdepth 1 -type f -name "*.json" 2>/dev/null')
    if not f then return files end
    for line in f:lines() do
        local clean = line:match("^%s*(.-)%s*$")
        if clean ~= "" then table.insert(files, clean) end
    end
    f:close()
    return files
end

function list_configs()
    local configs = list_config_files()

    cprint("${bright}Available configurations:${clear}")
    if #configs == 0 then
        cprint("  ${dim}(none)${clear}")
        return
    end

    local current = get_current_config()
    for _, config_file in ipairs(configs) do
        local name = path.filename(config_file):gsub("%.json$", "")
        if name ~= ".current" then
            local marker = (current == name) and "${green}✓${clear}" or " "
            cprint(string.format("  %s %s", marker, name))
        end
    end
end

function show_current_config()
    local current = get_current_config()
    if current then
        cprint(string.format("${bright}Current configuration:${clear} ${yellow}%s${clear}", current))
    else
        cprint("${yellow}No configuration is currently selected${clear}")
    end
end

function generate_server_config(args)
    ensure_config_dir()

    local name = args.name or ("server-" .. os.date("%Y%m%d-%H%M%S"))
    local port = tonumber(args.port) or 9875
    local protocol = args.protocol or "shadowsocks"
    local method = args.method or "aes-256-gcm"

    -- Generate a random password if none was supplied. Falls back to a
    -- deterministic placeholder if sing-box isn't installed yet (rare —
    -- the package depends on sing-box, so this is mostly defensive).
    local password = args.password
    if not password then
        local sb = sing_box_bin()
        if sb then
            local out = io.popen(sb .. " generate rand --base64 18")
            if out then
                password = (out:read("*a") or ""):match("^%s*(.-)%s*$")
                out:close()
            end
        end
        if not password or password == "" then password = "changeme-please" end
    end

    log.info("Generating server configuration: %s (%s on port %d)", name, protocol, port)

    local config_tbl
    if protocol == "shadowsocks" then
        config_tbl = {
            log = { level = "info", timestamp = true },
            inbounds = { {
                type = "shadowsocks",
                tag = "ss-in",
                listen = "0.0.0.0",
                listen_port = port,
                method = method,
                password = password,
                network = { "tcp", "udp" },
            } },
            outbounds = { { type = "direct", tag = "direct" } },
        }
    elseif protocol == "trojan" then
        config_tbl = {
            log = { level = "info", timestamp = true },
            inbounds = { {
                type = "trojan",
                tag = "trojan-in",
                listen = "0.0.0.0",
                listen_port = port,
                password = password,
            } },
            outbounds = { { type = "direct", tag = "direct" } },
        }
    else
        cprint("${red}✗${clear} Unsupported protocol: %s", protocol)
        return false
    end

    local config_file = path.join(get_config_dir(), name .. ".json")
    json.savefile(config_file, config_tbl, { indent = true })
    log.info("Server config saved to: %s", config_file)
    cprint(string.format("${green}✓${clear} Server configuration saved: ${yellow}%s${clear}", name))

    return true
end

local function base_client_table()
    return {
        log = { level = "info", timestamp = true },
        dns = {
            servers = {
                { type = "https", server = "1.1.1.1", tag = "dns-remote" },
                { type = "local", tag = "dns-direct" },
            },
            rules = {},
            final = "dns-remote",
        },
        inbounds = {
            { type = "socks", tag = "socks-in", listen = "127.0.0.1", listen_port = 1080, sniff = true },
            { type = "http",  tag = "http-in",  listen = "127.0.0.1", listen_port = 1087, sniff = true },
        },
        outbounds = {},
        route = {
            rules = {
                { protocol = "dns", outbound = "direct" },
                { domain_suffix = { "local", "lan" }, outbound = "direct" },
            },
            final = "ss-out",
            auto_detect_interface = true,
            default_domain_resolver = {
                server = "dns-direct",
                strategy = "prefer_ipv4",
            },
        },
    }
end

function generate_client_config(args)
    ensure_config_dir()

    local name = args.name or ("client-" .. os.date("%Y%m%d-%H%M%S"))
    local server = args.server or "127.0.0.1"
    local port = tonumber(args.port) or 9875
    local protocol = args.protocol or "shadowsocks"
    local password = args.password or "example-password-123"
    local method = args.method or "aes-256-gcm"

    log.info("Generating client configuration: %s (%s to %s:%d)", name, protocol, server, port)

    local config_tbl = base_client_table()
    config_tbl.outbounds = {
        {
            type = protocol,
            tag = (protocol == "trojan" and "trojan-out" or "ss-out"),
            server = server,
            server_port = port,
            method = method,
            password = password,
            network = { "tcp", "udp" },
            domain_resolver = {
                server = "dns-direct",
                strategy = "prefer_ipv4",
            },
        },
        { type = "direct", tag = "direct" },
        { type = "block",  tag = "block"  },
    }
    config_tbl.route.final = (protocol == "trojan" and "trojan-out" or "ss-out")

    local config_file = path.join(get_config_dir(), name .. ".json")
    json.savefile(config_file, config_tbl, { indent = true })
    log.info("Client config saved to: %s", config_file)
    cprint(string.format("${green}✓${clear} Client configuration saved: ${yellow}%s${clear}", name))

    return true
end

function parse_args(...)
    local args = {}
    local cmds = {...}

    for i = 1, #cmds do
        local arg = cmds[i]
        if arg:sub(1, 2) == "--" then
            local key = arg:sub(3)
            if i < #cmds and cmds[i+1]:sub(1, 2) ~= "--" then
                args[key] = cmds[i+1]
            else
                args[key] = true
            end
        end
    end

    return args
end

function create_systemd_service(config_name)
    local config_file = path.join(get_config_dir(), config_name .. ".json")

    if not os.isfile(config_file) then
        log.warn("Configuration not found: %s", config_file)
        return false
    end

    local sb = sing_box_bin()
    if not sb then return false end

    local service_content = string.format([[
[Unit]
Description=Sing-Box Proxy Service (%s)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=%s
ExecStart=%s run -c %s
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
]], config_name, get_config_dir(), sb, config_file)

    -- Validate the configuration before deploying it as a unit. Any
    -- non-zero exit from `sing-box check` is a hard error — proceeding
    -- would just produce a broken service that fails on start.
    log.info("Checking configuration file...")
    local check_cmd = string.format('"%s" check -c "%s" 2>&1', sb, config_file)
    local check_out = io.popen(check_cmd)
    local check_text = ""
    if check_out then
        check_text = check_out:read("*a") or ""
        local ok = check_out:close()
        if not ok then
            cprint("${red}✗${clear} Configuration check failed:")
            cprint("%s", check_text)
            return false
        end
    end

    -- Write the unit file via a single privileged script. This avoids
    -- the previous `echo "%s" | sudo tee` pipeline, which double-quoted
    -- the (user-influenced) service_content into the shell — a real
    -- injection surface. system.run_in_script writes `content` to a
    -- temp file as a script and runs it with sudo, so we just have it
    -- shovel a heredoc at /etc/systemd via cat.
    log.info("Creating systemd service file...")
    local install_script = string.format([[#!/bin/sh
cat > %s <<'SBHELPER_UNIT_EOF'
%s
SBHELPER_UNIT_EOF
systemctl daemon-reload
]], SYSTEMD_UNIT_PATH, service_content)
    system.run_in_script(install_script, true)

    return true
end

function start_config(config_name)
    ensure_config_dir()

    local config_file = path.join(get_config_dir(), config_name .. ".json")

    if not os.isfile(config_file) then
        cprint(string.format("${red}✗${clear} Configuration not found: ${yellow}%s${clear}", config_name))
        return false
    end

    set_current_config(config_name)
    log.info("Selected configuration: %s", config_name)

    if not create_systemd_service(config_name) then
        return false
    end

    local ok, err = pcall(function()
        os.exec("sudo systemctl restart " .. SYSTEMD_SERVICE)
        os.exec("sudo systemctl enable " .. SYSTEMD_SERVICE)
        local cfg = parse_config_file(config_file)
        if cfg and cfg.port then
            cprint("checking port - [ sudo ss -lunp | grep :%s ]", tostring(cfg.port))
        end
        cprint(string.format("${green}✓${clear} Sing-box started with configuration: ${yellow}%s${clear}", config_name))
    end)
    if not ok then
        cprint("${red}✗${clear} Failed to start sing-box service: %s", tostring(err))
        return false
    end
    return true
end

function stop_service()
    log.info("Stopping sing-box service...")
    os.exec("sudo systemctl stop " .. SYSTEMD_SERVICE)
    cprint("${green}✓${clear} Sing-box service stopped")
    return true
end

function show_status()
    pcall(function()
        os.exec("sudo systemctl status " .. SYSTEMD_SERVICE)
    end)
end

function handle_config_command(subcmd, ...)
    if subcmd == "list" then
        list_configs()
    elseif subcmd == "current" then
        show_current_config()
    else
        cprint("${yellow}Unknown config subcommand: %s${clear}", subcmd or "none")
        cprint("Available: list, current")
    end
end

function parse_config_file(config_file)
    if not os.isfile(config_file) then
        return nil
    end

    local cfg = json.loadfile(config_file)
    if not cfg or not cfg.inbounds or #cfg.inbounds == 0 then
        return nil
    end

    local inbound = cfg.inbounds[1]
    return {
        protocol = inbound.type,
        port = inbound.listen_port,
        password = inbound.password,
        method = inbound.method,
        listen = inbound.listen,
    }
end

function url_encode(str)
    return (str:gsub("([^%w%-_%.~])", function(c)
        if c == " " then return "%20" end
        return string.format("%%%02X", string.byte(c))
    end))
end

function generate_subscription_link()
    local current = get_current_config()
    if not current then
        cprint("${yellow}No configuration is currently running${clear}")
        return
    end

    local config_file = path.join(get_config_dir(), current .. ".json")
    local config = parse_config_file(config_file)

    if not config then
        cprint("${red}✗${clear} Failed to parse configuration file")
        return
    end

    if config.listen ~= "0.0.0.0" then
        cprint("${yellow}Current configuration is not a server${clear}")
        return
    end

    -- Best-effort public IP lookup; falls back to a placeholder so the
    -- generated link is recognizable as needing manual fixup.
    local server_ip = "YOUR_SERVER_IP"
    local f = io.popen("curl -fsS ifconfig.me 2>/dev/null")
    if f then
        local out = (f:read("*a") or ""):match("^%s*(.-)%s*$")
        f:close()
        if out and out ~= "" then server_ip = out end
    end

    local sub_link
    local config_name = current
    local name_encoded = url_encode(config_name)

    if config.protocol == "shadowsocks" then
        local method = config.method or "aes-256-gcm"
        local auth_encoded = base64.encode(method .. ":" .. config.password)
        sub_link = string.format("ss://%s@%s:%d#%s", auth_encoded, server_ip, config.port, name_encoded)
    elseif config.protocol == "trojan" then
        sub_link = string.format("trojan://%s@%s:%d#%s", config.password, server_ip, config.port, name_encoded)
    else
        cprint("${yellow}Protocol '%s' subscription link generation not yet supported${clear}", config.protocol)
        return
    end

    io.writefile(get_subscription_file(), sub_link)

    cprint("")
    cprint("${bright}Subscription Link:${clear}")
    cprint("${green}%s${clear}", sub_link)
    cprint("")
    cprint("${dim}Server: %s:%d${clear}", server_ip, config.port)
    cprint("${dim}Protocol: %s${clear}", config.protocol)
    cprint("${dim}Method: %s${clear}", config.method or "aes-256-gcm")
    cprint("${dim}Config name: %s${clear}", config_name)
    cprint("")
    cprint("${yellow}Link saved to: %s${clear}", get_subscription_file())
    cprint("")
end

function show_subscription_link()
    if os.isfile(get_subscription_file()) then
        local raw = io.readfile(get_subscription_file()) or ""
        local sub_link = raw:match("^%s*(.-)%s*$")
        cprint("${bright}Saved Subscription Link:${clear}")
        cprint("${green}%s${clear}", sub_link)
        cprint("")
    else
        cprint("${yellow}No subscription link has been generated yet${clear}")
    end
end

function import_from_link(link)
    if not link then
        if os.isfile(get_subscription_file()) then
            local raw = io.readfile(get_subscription_file()) or ""
            link = raw:match("^%s*(.-)%s*$")
            cprint("${dim}Using saved subscription link...${clear}")
        else
            cprint("${yellow}Please provide a subscription link${clear}")
            cprint("Usage: sing-box-helper import <link>")
            cprint("       sing-box-helper import  (uses saved link)")
            return
        end
    end

    ensure_config_dir()

    cprint("link: " .. link)

    local protocol, data = link:match("^(%w+)://(.+)$")
    if not protocol then
        cprint("${red}✗${clear} Invalid subscription link format")
        return
    end

    local server, port, password, method, config_name

    if protocol == "ss" then
        local auth_encoded, host_port, name_part =
            data:match("^([^@]+)@([^#]+)#?(.*)$")
        if not auth_encoded or not host_port then
            cprint("${red}✗${clear} Invalid SS link format")
            return
        end

        server, port = host_port:match("^([^:]+):(%d+)$")
        if not server or not port then
            cprint("${red}✗${clear} Failed to parse server and port")
            return
        end

        local decoded = base64.decode(auth_encoded)
        method, password = decoded:match("^([^:]+):(.+)$")
        if not method or not password then
            cprint("${red}✗${clear} Failed to decode authentication info from: %s", auth_encoded)
            cprint("${dim}Decoded: %s${clear}", decoded)
            return
        end

        config_name = (name_part ~= "" and name_part)
            or ("imported-ss-" .. os.date("%Y%m%d-%H%M%S"))
    elseif protocol == "trojan" then
        local host_port, name_part
        password, host_port, name_part = data:match("^([^@]+)@([^#]+)#?(.*)$")
        if not password or not host_port then
            cprint("${red}✗${clear} Invalid Trojan link format")
            return
        end

        server, port = host_port:match("^([^:]+):(%d+)$")
        if not server or not port then
            cprint("${red}✗${clear} Failed to parse server and port")
            return
        end

        config_name = (name_part ~= "" and name_part)
            or ("imported-trojan-" .. os.date("%Y%m%d-%H%M%S"))
    else
        cprint("${red}✗${clear} Unsupported protocol: %s", protocol)
        return
    end

    local cfg_tbl = base_client_table()
    if protocol == "ss" then
        cfg_tbl.outbounds = {
            {
                type = "shadowsocks",
                tag = "ss-out",
                server = server,
                server_port = tonumber(port),
                method = method or "aes-256-gcm",
                password = password,
                network = { "tcp", "udp" },
                domain_resolver = {
                    server = "dns-direct",
                    strategy = "prefer_ipv4",
                },
            },
            { type = "direct", tag = "direct" },
            { type = "block",  tag = "block"  },
        }
        cfg_tbl.route.final = "ss-out"
    elseif protocol == "trojan" then
        cfg_tbl.outbounds = {
            {
                type = "trojan",
                tag = "trojan-out",
                server = server,
                server_port = tonumber(port),
                password = password,
                domain_resolver = {
                    server = "dns-direct",
                    strategy = "prefer_ipv4",
                },
            },
            { type = "direct", tag = "direct" },
            { type = "block",  tag = "block"  },
        }
        cfg_tbl.route.final = "trojan-out"
    end

    local config_file = path.join(get_config_dir(), config_name .. ".json")
    json.savefile(config_file, cfg_tbl, { indent = true })

    cprint("")
    cprint(string.format("${green}✓${clear} Configuration imported: ${yellow}%s${clear}", config_name))
    cprint("${dim}Server: %s:%s${clear}", server, port)
    cprint("${dim}Protocol: %s${clear}", protocol)
    if method then
        cprint("${dim}Method: %s${clear}", method)
    end
    cprint("")
    cprint("Start with: ${cyan}sing-box-helper start %s${clear}", config_name)
end

function xpkg_main(command, ...)
    if not command or command == "help" or command == "-h" or command == "--help" then
        print_usage()
        return
    end

    local args = parse_args(...)

    if command == "server" then
        generate_server_config(args)
    elseif command == "client" then
        generate_client_config(args)
    elseif command == "config" then
        handle_config_command(...)
    elseif command == "start" then
        local config_name = ({...})[1]
        if not config_name then
            cprint("${yellow}Please specify a configuration name${clear}")
            cprint("Usage: sing-box-helper start <config-name>")
            return
        end
        start_config(config_name)
    elseif command == "stop" then
        stop_service()
    elseif command == "status" then
        show_status()
    elseif command == "sub" or command == "subscription" then
        generate_subscription_link()
    elseif command == "getsub" or command == "show-sub" then
        show_subscription_link()
    elseif command == "import" then
        local link = ({...})[1]
        import_from_link(link)
    else
        log.warn("Unknown command: %s", command)
        print_usage()
    end
end
