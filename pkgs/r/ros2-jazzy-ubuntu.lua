package = {
    spec = "1",

    name = "ros2-jazzy-ubnutu",
    description = "Config: one-click ROS 2 Jazzy Jalisco setup for Ubuntu 24.04",
    homepage = "https://docs.ros.org/en/jazzy/",
    maintainers = {"Open Robotics"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/ros2/ros2",
    docs = "https://docs.ros.org/en/jazzy/Installation/Ubuntu-Install-Debs.html",

    type = "config",
    archs = {"x86_64", "arm64"},
    status = "stable",
    categories = {"ros", "robotics", "config"},
    keywords = {"ros2", "jazzy", "robotics", "ubuntu"},

    xpm = {
        linux = {
            ["latest"] = { ref = "24.04" },
            ["24.04"] = { },
        },
    },
}

import("xim.libxpkg.system")
import("xim.libxpkg.log")

local ROS_DISTRO = "jazzy"
local ROS_SETUP = "/opt/ros/" .. ROS_DISTRO .. "/setup.bash"
local ROS_SETUP_FISH = "/opt/ros/" .. ROS_DISTRO .. "/setup.fish"
local ROS_APT_SOURCE_VERSION = "1.1.0"

-- forward declarations for local helpers
local ensure_supported_ubuntu
local append_line_if_missing
local append_ros_setup_profiles
local remove_line_if_present
local cleanup_ros_setup_profiles

function installed()
    if not os.isdir("/opt/ros/" .. ROS_DISTRO) then
        return false
    end
    return ROS_DISTRO
end

function install()
    local codename = ensure_supported_ubuntu()

    -- 1. locale
    log.debug("Setting up locale...")
    system.exec([[sudo apt update]])  -- elevation-ok: this package is the host's apt installing ROS 2
    system.exec([[sudo apt install -y locales]])  -- elevation-ok: this package is the host's apt installing ROS 2
    system.exec([[sudo locale-gen en_US en_US.UTF-8]])  -- elevation-ok: this package is the host's apt installing ROS 2
    system.exec([[sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8]])  -- elevation-ok: this package is the host's apt installing ROS 2

    -- 2. enable universe repo
    log.debug("Enabling Ubuntu Universe repository...")
    system.exec([[sudo apt install -y software-properties-common]])  -- elevation-ok: this package is the host's apt installing ROS 2
    system.exec([[sudo add-apt-repository -y universe]])  -- elevation-ok: this package is the host's apt installing ROS 2

    -- 3. add ROS 2 apt source
    log.debug("Adding ROS 2 apt repository...")
    system.exec([[sudo apt install -y curl]])  -- elevation-ok: this package is the host's apt installing ROS 2
    local deb_url = string.format(
        "https://github.com/ros-infrastructure/ros-apt-source/releases/download/%s/ros2-apt-source_%s.%s_all.deb",
        ROS_APT_SOURCE_VERSION, ROS_APT_SOURCE_VERSION, codename
    )
    system.exec(string.format([[curl -L -o /tmp/ros2-apt-source.deb "%s"]], deb_url))
    system.exec([[sudo dpkg -i /tmp/ros2-apt-source.deb]])  -- elevation-ok: this package is the host's apt installing ROS 2

    -- 4. install ROS 2 desktop (full)
    log.debug("Installing ros-jazzy-desktop (this may take a while)...")
    system.exec([[sudo apt update]])  -- elevation-ok: this package is the host's apt installing ROS 2
    system.exec(string.format([[sudo apt install -y ros-%s-desktop]], ROS_DISTRO))  -- exec-quoting-ok: a ROS distribution name  -- elevation-ok: this package is the host's apt installing ROS 2

    -- 5. install dev tools
    log.debug("Installing ros-dev-tools...")
    system.exec([[sudo apt install -y ros-dev-tools]])  -- elevation-ok: this package is the host's apt installing ROS 2

    return true
end

function config()
    log.debug("Adding ROS 2 environment to shell profile...")
    local appended = append_ros_setup_profiles()
    if appended > 0 then
        log.debug("Added ROS setup line to %d shell profile file(s).", appended)
    else
        log.debug("ROS setup line already exists in shell profiles.")
    end
    log.debug("ROS 2 Jazzy configured. Restart terminal or run: source %s", ROS_SETUP)
    return true
end

function uninstall()
    log.debug("Removing all ros-jazzy packages...")
    system.exec(string.format([[sudo apt remove -y '~nros-%s-*']], ROS_DISTRO))  -- exec-quoting-ok: a ROS distribution name  -- elevation-ok: this package is the host's apt installing ROS 2
    log.debug("Removing ros2-apt-source...")
    system.exec([[sudo apt remove -y ros2-apt-source]])  -- elevation-ok: this package is the host's apt installing ROS 2
    log.debug("Refreshing package index...")
    system.exec([[sudo apt update]])  -- elevation-ok: this package is the host's apt installing ROS 2
    log.debug("Auto-removing unused packages...")
    system.exec([[sudo apt autoremove -y]])  -- elevation-ok: this package is the host's apt installing ROS 2
    log.debug("Upgrading packages that may have been shadowed...")
    system.exec([[sudo apt upgrade -y]])  -- elevation-ok: this package is the host's apt installing ROS 2
    log.debug("Cleaning ROS setup lines from shell profiles...")
    cleanup_ros_setup_profiles()
    return true
end

ensure_supported_ubuntu = function()
    if os.host() ~= "linux" then
        error("ros2-jazzy only supports Ubuntu 24.04 (noble). Current host is not Linux.")
    end

    local codename = "noble"
    local output = os.iorun([[grep VERSION_CODENAME /etc/os-release]])
    if output then
        codename = output:match("VERSION_CODENAME=(%w+)") or codename
    end
    if codename ~= "noble" then
        error(string.format(
            "ros2-jazzy requires Ubuntu 24.04 (noble). Detected Ubuntu codename: %s",
            tostring(codename)
        ))
    end

    return codename
end

append_line_if_missing = function(filepath, line)
    if not os.isfile(filepath) then
        return false
    end
    local content = io.readfile(filepath) or ""

    if content:find(line, 1, true) then
        return false
    end

    local prefix = ""
    if #content > 0 and not content:match("\n$") then
        prefix = "\n"
    end
    io.writefile(filepath, content .. prefix .. line .. "\n")
    return true
end

append_ros_setup_profiles = function()
    local home = os.getenv("HOME")
    if not home or home == "" then
        return 0
    end

    local posix_line = string.format([[test -f "%s" && source "%s"]], ROS_SETUP, ROS_SETUP)
    local fish_line = string.format([[test -f "%s"; and source "%s"]], ROS_SETUP_FISH, ROS_SETUP_FISH)
    local appended = 0

    local bashrc = path.join(home, ".bashrc")
    if append_line_if_missing(bashrc, posix_line) then
        appended = appended + 1
    end

    local fish_config = path.join(home, ".config", "fish", "config.fish")
    if os.isfile(fish_config) and append_line_if_missing(fish_config, fish_line) then
        appended = appended + 1
    end

    return appended
end

remove_line_if_present = function(filepath, line)
    if not os.isfile(filepath) then
        return false
    end

    local content = io.readfile(filepath) or ""
    if content == "" then
        return false
    end

    local escaped = line:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
    local new_content = content
    new_content = new_content:gsub("^" .. escaped .. "\n?", "")
    new_content = new_content:gsub("\n" .. escaped .. "\n", "\n")
    new_content = new_content:gsub("\n" .. escaped .. "$", "")

    if new_content == content then
        return false
    end

    if #new_content > 0 and not new_content:match("\n$") then
        new_content = new_content .. "\n"
    end
    io.writefile(filepath, new_content)
    return true
end

cleanup_ros_setup_profiles = function()
    local home = os.getenv("HOME")
    if not home or home == "" then
        return 0
    end

    local posix_line = string.format([[test -f "%s" && source "%s"]], ROS_SETUP, ROS_SETUP)
    local fish_line = string.format([[test -f "%s"; and source "%s"]], ROS_SETUP_FISH, ROS_SETUP_FISH)
    local removed = 0

    local bashrc = path.join(home, ".bashrc")
    if remove_line_if_present(bashrc, posix_line) then
        removed = removed + 1
    end

    local fish_config = path.join(home, ".config", "fish", "config.fish")
    if remove_line_if_present(fish_config, fish_line) then
        removed = removed + 1
    end

    log.debug("Removed ROS setup line from %d shell profile file(s).", removed)
    return removed
end
