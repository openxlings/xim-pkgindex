# Eden

`xlings install eden --yes` installs the official Eden 0.2.1 desktop release.
Run `eden` to open it. Linux and Windows also expose `eden-cli`.

Linux and Windows support x86_64 and aarch64. Linux keeps the official
AppImage intact and uses its extract-and-run mode, so FUSE is unnecessary.
The standard amd64 Linux build requires the x86-64-v3 instruction set
(Ryzen / Intel Haswell or newer); the legacy build is not included.
The macOS release supports Apple Silicon only and is experimental upstream.
The macOS application stays in the package store, outside /Applications.

## Android

`xlings install eden-android --yes` downloads the official standard ARM64 APK
on Linux, Windows or macOS. This is a data package; it creates no command and
never installs to or removes anything from a phone implicitly.

Use `xlings info eden-android` to find the installation directory. Copy
`eden.apk` from that directory to the phone and open it to install, or use
an existing Android Debug Bridge installation explicitly:

```sh
adb devices -l
adb -s <phone-serial> install -r <installation-directory>/eden.apk
```

Removing `eden-android` removes the computer's managed APK and registration;
it does not uninstall Eden or delete saves on the phone. Removing the desktop
package removes its registrations and managed files, preserving user saves,
keys and configuration. Neither package distributes games, keys or firmware.

## Verification boundary

Package CI checks resource selection, installation, registrations and removal.
The Linux/Windows CLI can be checked with `eden-cli --version`. Running a
commercial game requires a separate, manual compatibility test with the user's
own game dump, keys and any necessary firmware. A successful package install
or CLI launch does not establish game compatibility or Android frame rates.
