package = {
    spec = "1",

    name = "audio",
    namespace = "luban",
    description = "A Luban desktop's sound: PipeWire, WirePlumber and pipewire-pulse, played on the computer Luban OS runs on",

    homepage = "https://pipewire.org",
    repo = "https://gitlab.freedesktop.org/pipewire/pipewire",
    licenses = {"MIT", "LGPL-2.1-or-later"},

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"audio", "luban"},
    keywords = {"pipewire", "wireplumber", "pulseaudio", "sound", "audio", "luban"},

    -- A Luban desktop's sound (xlings design 2026-10-20 §20.1): PipeWire,
    -- its session manager (WirePlumber) and its Pulse server for the
    -- programs that speak Pulse (a browser), with one output of Luban's --
    -- the `luban` sink, the default: what is played goes into a named pipe
    -- (/tmp/luban-audio.pcm, 48 kHz stereo) that `luban __audio` reads and
    -- the Luban OS window plays on the computer it runs on (a machine's
    -- channel). A desktop's session starts it (luban-audio, from
    -- opensal-wlr's run_session) unless the session already has the host's
    -- sound server (a sandbox granted `audio`).
    --
    -- Form: a bundle (tools/res/build.sh audio): Alpine 3.24's programs, their
    -- libraries and the musl loader private in libexec/audio, run through
    -- bin/<program>; the modules and plugins in lib/pipewire-0.3, lib/spa-0.2
    -- and lib/wireplumber-0.5 and the configuration in share/, as Alpine lays
    -- them out under /usr -- a Luban system has them where the programs look.
    programs = {"luban-audio", "pipewire", "pipewire-pulse", "wireplumber", "pw-cat", "pw-cli", "wpctl", "pactl"},
    xvm_enable = true,

    xpm = {
        linux = {
            ["latest"] = { ref = "1.6.8-r1" },
            -- r1: without what a machine never plays through (video, Bluetooth, JACK, network streams).
            ["1.6.8-r1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "7971327ca9646c3fcc9d27957ab36c524e6e91555d5c8f9bb575f27b2b2530ad",
                    aarch64 = "51fc1526bb6c9e4d69250606fc7c0b815f2302fc7260924988fa9590487ef618",
                },
            },
        },
    },
}

import("xim.pkgindex.luban_component")

function install()
    return luban_component.install({ "bin/luban-audio", "bin/pipewire", "share/pipewire/pipewire.conf.d/luban.conf" })
end

function config()
    return luban_component.config(package.programs, {})
end

function uninstall()
    return luban_component.uninstall(package.programs)
end
