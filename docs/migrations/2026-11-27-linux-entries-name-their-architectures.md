# 2026-11-27 — Linux entries name their architectures

A Linux host is x86_64 or aarch64. An entry with one URL and one `sha256`
string said nothing about which: an aarch64 client installed the x86_64
bytes (with one warn line when `package.archs` did not list aarch64, and
without any when it did: `archs` is the union over every platform). Every
Linux entry with an artifact now names the architectures it is for
(check K1, `tools/xpkg_ci.py arch-check`), in one of three forms:

```lua
["1.0.0"] = { url = "...", sha256 = { x86_64 = "<h>" } },                    -- only x86_64
["1.0.0"] = { url = "...", sha256 = { x86_64 = "<h>", aarch64 = "<h>" } },    -- no machine code
["1.0.0"] = { x86_64 = { url = ..., sha256 = ... }, aarch64 = { url = ..., sha256 = ... } },
```

and `package.archs` is the union of what the entries name (K3).

## How it was decided

`tools/arch-migrate` (with the census, `tools/arch_census.py`):

1. **The bytes.** Each artifact was downloaded and every ELF member of the
   archive read (machine, 32/64-bit, system, program or library; a static
   PIE is a program) -- never unpacked to disk, never run. No ELF: the same
   bytes serve both architectures. Linux programs of one machine: that
   machine. Anything else is left to step 2.
2. **An install on each architecture** with a client that checks the
   machine of the files a payload exposes (rule M): the index's full sweep,
   or `arch-install.yml` on `ubuntu-24.04-arm`.
3. **Upstream's other artifact.** For an entry whose programs are x86_64
   only, the URL with its architecture word swapped (`x86_64`/`aarch64`,
   `amd64`/`arm64`, `x64`/`arm64`) was requested; one that exists was
   downloaded, its sha256 taken from that download and its bytes read like
   step 1. The entry then has an artifact per architecture, its `revision`
   raised where the revision gate asks (the aarch64 artifact changed what an
   aarch64 client installs; `floor` stays), and its autoupdate declaration
   names both URLs.

A recipe that declares only x86_64 had its digests written for x86_64
without reading anything (§5.6 of the design: the mechanical group);
`XLINGS_RES` entries name the assets xlings-res publishes, with the
digests GitHub reports. What a person decided is in
`tools/arch-decisions.json`, each with its reason.

Reproduce: `python3 tools/arch-migrate plan --json plan.json`, then
`evidence --plan plan.json --out evidence.json`, `apply --evidence
evidence.json`, `bump-flagged`, `table --evidence evidence.json`.

## The evidence

The mechanical group (110 entries in 87 recipes declaring only x86_64,
written `{ x86_64 = "<h>" }` without reading) is not listed row by row.

### Decided by the bytes (165)

| recipe | version | what the bytes hold | decision | why | other architecture |
|---|---|---|---|---|---|
| `aarch64-freebsd-disk-image` | 14.5 | no ELF (tar?) | independent | no ELF file in the artifact |  |
| `aarch64-freebsd-disk-image` | 14.5-1 | no ELF (tar?) | independent | no ELF file in the artifact |  |
| `aarch64-netbsd-disk-image` | 10.2 | no ELF (tar?) | independent | no ELF file in the artifact |  |
| `aarch64-openbsd-disk-image` | 8.0 | no ELF (tar?) | independent | no ELF file in the artifact |  |
| `adwaita-cursors` | 49.0 | no ELF (tar?) | independent | no ELF file in the artifact |  |
| `android-build-tools` | 37.0.0 | 12 x86_64 linux? library; 9 x86_64 linux program; 6 aarch64 linux? library; 6 arm linux? library ... | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (0 names tried) |  |
| `android-debug-keystore` | 1.0.0 | no ELF (other) | independent | no ELF file in the artifact |  |
| `android-emulator` | 37.1.11 | 101 x86_64 linux? library; 25 x86_64 linux program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (1 names tried) |  |
| `android-emulator` | 37.1.11-2 | 101 x86_64 linux? library; 25 x86_64 linux program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (1 names tried) |  |
| `android-ndk-libcxx-modules` | 30.0.16248370 | no ELF (tar?) | independent | no ELF file in the artifact |  |
| `android-platform-tools` | 37.0.1 | 8 x86_64 linux program; 1 x86_64 linux? library | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (0 names tried) |  |
| `android-platform-tools` | 37.0.1-2 | 8 x86_64 linux program; 1 x86_64 linux? library | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (0 names tried) |  |
| `android-platform-tools` | 37.0.1-3 | 8 x86_64 linux program; 1 x86_64 linux? library | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (0 names tried) |  |
| `android-platform-tools` | 37.0.1-4 | 8 x86_64 linux program; 1 x86_64 linux? library | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (0 names tried) |  |
| `android-platform` | 34-r3 | no ELF (zip) | independent | no ELF file in the artifact |  |
| `android-platform` | 35-r2 | no ELF (zip) | independent | no ELF file in the artifact |  |
| `android-platform` | 36-r2 | no ELF (zip) | independent | no ELF file in the artifact |  |
| `android-system-image` | 24-default-arm64-v8a | no ELF (zip) | independent | no ELF file in the artifact |  |
| `android-system-image` | 24-default-x86_64 | no ELF (zip) | independent | no ELF file in the artifact |  |
| `android-system-image` | 34-default-arm64-v8a | no ELF (zip) | independent | no ELF file in the artifact |  |
| `android-system-image` | 34-default-x86_64 | no ELF (zip) | independent | no ELF file in the artifact |  |
| `bat` | 0.26.1 | 1 x86_64 linux? program, 1 static-pie | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has an aarch64 artifact (bat-v0.26.1-aarch64-unknown-linux-musl.tar.gz) | `bat-v0.26.1-aarch64-unknown-linux-musl.tar.gz`: 1 aarch64 linux? program |
| `bundletool` | 1.18.3 | 2 x86 linux? library; 2 x86_64 linux? library; 2 arm linux? library; 1 aarch64 linux? library ... | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (0 names tried) |  |
| `ca-certificates` | 2025.07.15 | no ELF (other) | independent | no ELF file in the artifact |  |
| `ca-certificates` | 2026.03.19 | no ELF (other) | independent | no ELF file in the artifact |  |
| `cc-connect` | 1.3.2 | 1 x86_64 linux? program | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has an aarch64 artifact (cc-connect-v1.3.2-linux-arm64.tar.gz) | `cc-connect-v1.3.2-linux-arm64.tar.gz`: 1 aarch64 linux? program |
| `cc-connect` | 1.3.3-beta.1 | 1 x86_64 linux? program | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has an aarch64 artifact (cc-connect-v1.3.3-beta.1-linux-arm64.tar.gz) | `cc-connect-v1.3.3-beta.1-linux-arm64.tar.gz`: 1 aarch64 linux? program |
| `cc-connect` | 1.5.0 | 1 x86_64 linux? program | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has an aarch64 artifact (cc-connect-v1.5.0-linux-arm64.tar.gz) | `cc-connect-v1.5.0-linux-arm64.tar.gz`: 1 aarch64 linux? program |
| `cc-connect` | 1.5.3 | 1 x86_64 linux? program | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has an aarch64 artifact (cc-connect-v1.5.3-linux-arm64.tar.gz) | `cc-connect-v1.5.3-linux-arm64.tar.gz`: 1 aarch64 linux? program |
| `code` | 1.100.1 | 20 x86_64 linux? library; 5 x86_64 linux program; 1 x86_64 linux? program, 1 static-pie | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has linux-arm64 (digests: the downloads read here, else the VS Code update API sha256hash where the proxy cut the download short) | `stable`: 20 aarch64 linux? library; 5 aarch64 linux program; 1 aarch64 linux? program |
| `code` | 1.106.1 | 20 x86_64 linux? library; 5 x86_64 linux program; 1 x86_64 linux? program, 1 static-pie | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has linux-arm64 (digests: the downloads read here, else the VS Code update API sha256hash where the proxy cut the download short) | `stable`: 20 aarch64 linux? library; 5 aarch64 linux program; 1 aarch64 linux? program |
| `code` | 1.108.0 | 22 x86_64 linux? library; 5 x86_64 linux program; 1 x86_64 linux? program, 1 static-pie | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has linux-arm64 (digests: the downloads read here, else the VS Code update API sha256hash where the proxy cut the download short) | `stable`: 20 aarch64 linux? library; 5 aarch64 linux program; 1 aarch64 linux? program |
| `code` | 1.108.1 | 22 x86_64 linux? library; 5 x86_64 linux program; 1 x86_64 linux? program, 1 static-pie | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has linux-arm64 (digests: the downloads read here, else the VS Code update API sha256hash where the proxy cut the download short) | `stable`: no ELF (None) |
| `code` | 1.125.1 | 28 x86_64 linux? library; 7 x86_64 linux program; 5 x86_64 linux? program, 4 static-pie; 2 aarch64 linux program | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has linux-arm64 (digests: the downloads read here, else the VS Code update API sha256hash where the proxy cut the download short) |  |
| `code` | 1.132.0 | 26 x86_64 linux? library; 7 x86_64 linux program; 7 x86_64 linux? program, 6 static-pie | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has linux-arm64 (digests: the downloads read here, else the VS Code update API sha256hash where the proxy cut the download short) | `stable`: no ELF (None) |
| `code` | 1.93.1 | 19 x86_64 linux? library; 5 x86_64 linux program; 1 x86_64 linux? program, 1 static-pie | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has linux-arm64 (digests: the downloads read here, else the VS Code update API sha256hash where the proxy cut the download short) | `stable`: 19 aarch64 linux? library; 5 aarch64 linux program; 1 aarch64 linux? program |
| `code` | 1.96.2 | 20 x86_64 linux? library; 5 x86_64 linux program; 1 x86_64 linux? program, 1 static-pie | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has linux-arm64 (digests: the downloads read here, else the VS Code update API sha256hash where the proxy cut the download short) | `stable`: 20 aarch64 linux? library; 5 aarch64 linux program; 1 aarch64 linux? program |
| `composer` | 2.11.2 | no ELF (other) | independent | no ELF file in the artifact |  |
| `composer` | 2.11.3 | no ELF (other) | independent | no ELF file in the artifact |  |
| `cubism-sdk-web` | 5-r.5 | no ELF (zip) | independent | no ELF file in the artifact |  |
| `dotnet` | 8.0 | no ELF (other) | independent | no ELF file in the artifact |  |
| `dotnet` | 9.0 | no ELF (other) | independent | no ELF file in the artifact |  |
| `edk2-firmware` | 9.2.4 | no ELF (tar?) | independent | no ELF file in the artifact |  |
| `fd` | 10.4.2 | 1 x86_64 linux? program, 1 static-pie | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has an aarch64 artifact (fd-v10.4.2-aarch64-unknown-linux-musl.tar.gz) | `fd-v10.4.2-aarch64-unknown-linux-musl.tar.gz`: 1 aarch64 linux? program |
| `fd` | 10.5.0 | 1 x86_64 linux? program, 1 static-pie | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has an aarch64 artifact (fd-v10.5.0-aarch64-unknown-linux-musl.tar.gz) | `fd-v10.5.0-aarch64-unknown-linux-musl.tar.gz`: 1 aarch64 linux? program |
| `fd` | 10.5.2 | 1 x86_64 linux? program, 1 static-pie | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has an aarch64 artifact (fd-v10.5.2-aarch64-unknown-linux-musl.tar.gz) | `fd-v10.5.2-aarch64-unknown-linux-musl.tar.gz`: 1 aarch64 linux? program |
| `freebsd-disk` | 14.5 | no ELF (tar?) | independent | no ELF file in the artifact |  |
| `freebsd-vm` | 14.5 | no ELF (tar?) | independent | no ELF file in the artifact |  |
| `fzf` | 0.71.0 | 1 x86_64 linux? program | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has an aarch64 artifact (fzf-0.71.0-linux_arm64.tar.gz) | `fzf-0.71.0-linux_arm64.tar.gz`: 1 aarch64 linux? program |
| `fzf` | 0.72.0 | 1 x86_64 linux? program | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has an aarch64 artifact (fzf-0.72.0-linux_arm64.tar.gz) | `fzf-0.72.0-linux_arm64.tar.gz`: 1 aarch64 linux? program |
| `fzf` | 0.74.3 | 1 x86_64 linux? program | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has an aarch64 artifact (fzf-0.74.3-linux_arm64.tar.gz) | `fzf-0.74.3-linux_arm64.tar.gz`: 1 aarch64 linux? program |
| `fzf` | 0.74.5 | 1 x86_64 linux? program | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has an aarch64 artifact (fzf-0.74.5-linux_arm64.tar.gz) | `fzf-0.74.5-linux_arm64.tar.gz`: 1 aarch64 linux? program |
| `git` | 2.53.0 | 10 x86_64 linux? program | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has an aarch64 artifact (git-2.53.0-linux-aarch64.tar.gz) | `git-2.53.0-linux-aarch64.tar.gz`: 10 aarch64 linux? program |
| `github-gh` | 2.86.0 | 1 x86_64 linux? program | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has an aarch64 artifact (gh_2.86.0_linux_arm64.tar.gz) | `gh_2.86.0_linux_arm64.tar.gz`: 1 aarch64 linux? program |
| `github-gh` | 2.91.0 | 1 x86_64 linux? program | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has an aarch64 artifact (gh_2.91.0_linux_arm64.tar.gz) | `gh_2.91.0_linux_arm64.tar.gz`: 1 aarch64 linux? program |
| `github-gh` | 2.92.0 | 1 x86_64 linux? program | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has an aarch64 artifact (gh_2.92.0_linux_arm64.tar.gz) | `gh_2.92.0_linux_arm64.tar.gz`: 1 aarch64 linux? program |
| `glew` | 2.2.0 | no ELF (tar?) | independent | no ELF file in the artifact |  |
| `gradle` | 9.7.1 | no ELF (zip) | independent | no ELF file in the artifact |  |
| `gradle` | 9.8.2 | no ELF (zip) | independent | no ELF file in the artifact |  |
| `griddycode` | 1.2.2 | 5 x86_64 linux? library; 1 x86_64 linux program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (0 names tried) |  |
| `hermes-agent` | 2026.4.16 | no ELF (tar?) | independent | no ELF file in the artifact |  |
| `hermes-agent` | 2026.4.23 | no ELF (tar?) | independent | no ELF file in the artifact |  |
| `hip-nvidia` | 7.2.4 | no ELF (tar?) | independent | no ELF file in the artifact |  |
| `iphoneos-sdk` | 26.5 | no ELF (zip) | independent | no ELF file in the artifact |  |
| `jetbrainsmono-nerd-font` | 3.4.0 | no ELF (zip) | independent | no ELF file in the artifact |  |
| `jq` | 1.8.1 | 1 x86_64 linux? program | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has an aarch64 artifact (jq-linux-arm64) | `jq-linux-arm64`: 1 aarch64 linux? program |
| `khistory` | pre-v0.0.5 | 1 x86_64 linux program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (3 names tried) |  |
| `libcxx-headers` | 22.1.8 | no ELF (tar?) | independent | no ELF file in the artifact |  |
| `linux-headers` | 7.3.5 | no ELF (tar?) | independent | no ELF file in the artifact |  |
| `cursors` | 2026.10.19 | no ELF (tar?) | independent | no ELF file in the artifact |  |
| `cursors` | 2026.10.20 | no ELF (tar?) | independent | no ELF file in the artifact |  |
| `cursors` | 2026.10.21.1 | no ELF (tar?) | independent | no ELF file in the artifact |  |
| `luban-fonts` | 2026.10.16 | no ELF (tar?) | independent | no ELF file in the artifact |  |
| `sample-music` | 2026.10.22 | no ELF (tar?) | independent | no ELF file in the artifact |  |
| `maven` | 3.9.16 | no ELF (zip) | independent | no ELF file in the artifact |  |
| `mcpp-android-runner` | 0.1.0 | no ELF (tar?) | independent | no ELF file in the artifact |  |
| `mdbook` | 0.4.40 | 1 x86_64 linux? program, 1 static-pie | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has an aarch64 artifact (mdbook-v0.4.40-aarch64-unknown-linux-musl.tar.gz) | `mdbook-v0.4.40-aarch64-unknown-linux-musl.tar.gz`: 1 aarch64 linux? program |
| `mdbook` | 0.4.43 | 1 x86_64 linux? program, 1 static-pie | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has an aarch64 artifact (mdbook-v0.4.43-aarch64-unknown-linux-musl.tar.gz) | `mdbook-v0.4.43-aarch64-unknown-linux-musl.tar.gz`: 1 aarch64 linux? program |
| `mdbook` | 0.5.2 | 1 x86_64 linux? program, 1 static-pie | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has an aarch64 artifact (mdbook-v0.5.2-aarch64-unknown-linux-musl.tar.gz) | `mdbook-v0.5.2-aarch64-unknown-linux-musl.tar.gz`: 1 aarch64 linux? program |
| `mdbook` | 0.5.4 | 1 x86_64 linux? program, 1 static-pie | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has an aarch64 artifact (mdbook-v0.5.4-aarch64-unknown-linux-musl.tar.gz) | `mdbook-v0.5.4-aarch64-unknown-linux-musl.tar.gz`: 1 aarch64 linux? program |
| `media-crawler` | 2026.4.30 | no ELF (tar?) | independent | no ELF file in the artifact |  |
| `mingw-w64-sysroot` | 20261104 | no ELF (tar?) | independent | no ELF file in the artifact |  |
| `mingw-w64-sysroot` | 20261104-1 | no ELF (tar?) | independent | no ELF file in the artifact |  |
| `mingw-w64-sysroot` | 20261104-2 | no ELF (tar?) | independent | no ELF file in the artifact |  |
| `nvm` | 0.40.4 | no ELF (tar?) | independent | no ELF file in the artifact |  |
| `nvm` | 0.40.6 | no ELF (tar?) | independent | no ELF file in the artifact |  |
| `nvm` | 0.40.7 | no ELF (tar?) | independent | no ELF file in the artifact |  |
| `ovmf` | 9.2.4 | no ELF (tar?) | independent | no ELF file in the artifact |  |
| `ovmf` | 9.2.4-1 | no ELF (tar?) | independent | no ELF file in the artifact |  |
| `ovmf` | 9.2.4-2 | no ELF (tar?) | independent | no ELF file in the artifact |  |
| `ovmf` | 9.2.4-3 | no ELF (tar?) | independent | no ELF file in the artifact |  |
| `ovmf` | 9.2.4-4 | no ELF (tar?) | independent | no ELF file in the artifact |  |
| `project-graph` | 1.0.0 | 1 x86_64 linux program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (2 names tried) |  |
| `project-graph` | 1.1.0 | 1 x86_64 linux program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (2 names tried) |  |
| `project-graph` | 1.2.0 | 1 x86_64 linux program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (2 names tried) |  |
| `project-graph` | 1.2.5 | 1 x86_64 linux program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (2 names tried) |  |
| `project-graph` | 1.2.6 | 1 x86_64 linux program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (2 names tried) |  |
| `project-graph` | 1.2.7 | 1 x86_64 linux program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (2 names tried) |  |
| `project-graph` | 1.4.0 | 1 x86_64 linux program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (2 names tried) |  |
| `project-graph` | 1.5.0 | 1 x86_64 linux program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (2 names tried) |  |
| `project-graph` | 1.5.1 | 1 x86_64 linux program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (2 names tried) |  |
| `project-graph` | 1.6.0 | 1 x86_64 linux program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (2 names tried) |  |
| `project-graph` | 1.7.0 | 1 x86_64 linux program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (2 names tried) |  |
| `project-graph` | 1.7.10 | 1 x86_64 linux program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (2 names tried) |  |
| `python` | 3.12.13 | 10 x86_64 linux? library; 1 x86_64 linux program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (3 names tried) |  |
| `ripgrep` | 15.1.0 | 1 x86_64 linux? program, 1 static-pie | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has an aarch64 artifact (ripgrep-15.1.0-aarch64-unknown-linux-gnu.tar.gz) | `ripgrep-15.1.0-aarch64-unknown-linux-gnu.tar.gz`: 1 aarch64 linux program |
| `ripgrep` | 15.2.0 | 1 x86_64 linux? program, 1 static-pie | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has an aarch64 artifact (ripgrep-15.2.0-aarch64-unknown-linux-musl.tar.gz) | `ripgrep-15.2.0-aarch64-unknown-linux-musl.tar.gz`: 1 aarch64 linux? program |
| `rosdep` | 0.26.0 | no ELF (zip) | independent | no ELF file in the artifact |  |
| `rustup` | 1.28.2 | 1 x86_64 linux program | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has an aarch64 artifact (rustup-init) | `rustup-init`: 1 aarch64 linux program |
| `rustup` | 1.29.2 | 1 x86_64 linux program | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has an aarch64 artifact (rustup-init) | `rustup-init`: 1 aarch64 linux program |
| `rustup` | 1.29.3 | 1 x86_64 linux program | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has an aarch64 artifact (rustup-init) | `rustup-init`: 1 aarch64 linux program |
| `sing-box` | 1.13.11 | 1 x86_64 linux program; 1 x86_64 linux? library | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has an aarch64 artifact (sing-box-1.13.11-linux-arm64.tar.gz) | `sing-box-1.13.11-linux-arm64.tar.gz`: 1 aarch64 linux program; 1 aarch64 linux? library |
| `sing-box` | 1.13.20 | 1 x86_64 linux? library; 1 x86_64 linux program | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has an aarch64 artifact (sing-box-1.13.20-linux-arm64.tar.gz) | `sing-box-1.13.20-linux-arm64.tar.gz`: 1 aarch64 linux? library; 1 aarch64 linux program |
| `sing-box` | 1.14.4 | 1 x86_64 linux program; 1 x86_64 linux? library | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has an aarch64 artifact (sing-box-1.14.4-linux-arm64.tar.gz) | `sing-box-1.14.4-linux-arm64.tar.gz`: 1 aarch64 linux program; 1 aarch64 linux? library |
| `sourcetrail` | 2021.4.19 | 91 x86_64 linux? library; 4 x86_64 linux program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (0 names tried) |  |
| `terminfo` | 6.6.20261010 | no ELF (tar?) | independent | no ELF file in the artifact |  |
| `trendradar` | 6.11.0 | no ELF (tar?) | independent | no ELF file in the artifact |  |
| `trendradar` | 6.12.0 | no ELF (tar?) | independent | no ELF file in the artifact |  |
| `trendradar` | 6.6.1 | no ELF (tar?) | independent | no ELF file in the artifact |  |
| `uv` | 0.11.28 | 2 x86_64 linux? program, 2 static-pie | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has an aarch64 artifact (uv-aarch64-unknown-linux-musl.tar.gz) | `uv-aarch64-unknown-linux-musl.tar.gz`: 2 aarch64 linux? program |
| `uv` | 0.11.7 | 2 x86_64 linux? program, 2 static-pie | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has an aarch64 artifact (uv-aarch64-unknown-linux-musl.tar.gz) | `uv-aarch64-unknown-linux-musl.tar.gz`: 2 aarch64 linux? program |
| `uv` | 0.11.8 | 2 x86_64 linux? program, 2 static-pie | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has an aarch64 artifact (uv-aarch64-unknown-linux-musl.tar.gz) | `uv-aarch64-unknown-linux-musl.tar.gz`: 2 aarch64 linux? program |
| `uv` | 0.12.7 | 2 x86_64 linux? program, 2 static-pie | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has an aarch64 artifact (uv-aarch64-unknown-linux-musl.tar.gz) | `uv-aarch64-unknown-linux-musl.tar.gz`: 2 aarch64 linux? program |
| `uv` | 0.13.9 | 2 x86_64 linux? program, 2 static-pie | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has an aarch64 artifact (uv-aarch64-unknown-linux-musl.tar.gz) | `uv-aarch64-unknown-linux-musl.tar.gz`: 2 aarch64 linux? program |
| `vcstool` | 0.3.0 | no ELF (zip) | independent | no ELF file in the artifact |  |
| `vim` | 8.1.1045 | 1 x86_64 linux? program, 1 static-pie | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (0 names tried) |  |
| `xlings` | 0.4.10 | 1 x86_64 linux? program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (3 names tried) |  |
| `xlings` | 0.4.12 | 1 x86_64 linux? program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (3 names tried) |  |
| `xlings` | 0.4.13 | 1 x86_64 linux? program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (3 names tried) |  |
| `xlings` | 0.4.14 | 1 x86_64 linux? program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (3 names tried) |  |
| `xlings` | 0.4.15 | 1 x86_64 linux? program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (3 names tried) |  |
| `xlings` | 0.4.16 | 1 x86_64 linux? program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (3 names tried) |  |
| `xlings` | 0.4.17 | 1 x86_64 linux? program | x86_64 | x86_64 like every 0.4.x; the release asset was replaced (GitHub digest 951d3e67...) and no longer matches the entry |  |
| `xlings` | 0.4.19 | 1 x86_64 linux? program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (3 names tried) |  |
| `xlings` | 0.4.20 | 1 x86_64 linux? program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (3 names tried) |  |
| `xlings` | 0.4.21 | 1 x86_64 linux? program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (3 names tried) |  |
| `xlings` | 0.4.22 | 1 x86_64 linux? program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (3 names tried) |  |
| `xlings` | 0.4.23 | 1 x86_64 linux? program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (3 names tried) |  |
| `xlings` | 0.4.24 | 1 x86_64 linux? program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (3 names tried) |  |
| `xlings` | 0.4.25 | 1 x86_64 linux? program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (3 names tried) |  |
| `xlings` | 0.4.26 | 1 x86_64 linux? program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (3 names tried) |  |
| `xlings` | 0.4.28 | 1 x86_64 linux? program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (3 names tried) |  |
| `xlings` | 0.4.29 | 1 x86_64 linux? program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (3 names tried) |  |
| `xlings` | 0.4.30 | 1 x86_64 linux? program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (3 names tried) |  |
| `xlings` | 0.4.31 | 1 x86_64 linux? program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (3 names tried) |  |
| `xlings` | 0.4.32 | 1 x86_64 linux? program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (3 names tried) |  |
| `xlings` | 0.4.33 | 1 x86_64 linux? program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (3 names tried) |  |
| `xlings` | 0.4.34 | 1 x86_64 linux? program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (3 names tried) |  |
| `xlings` | 0.4.35 | 1 x86_64 linux? program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (3 names tried) |  |
| `xlings` | 0.4.36 | 1 x86_64 linux? program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (3 names tried) |  |
| `xlings` | 0.4.37 | 1 x86_64 linux? program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (3 names tried) |  |
| `xlings` | 0.4.38 | 1 x86_64 linux? program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (3 names tried) |  |
| `xlings` | 0.4.39 | 1 x86_64 linux? program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (3 names tried) |  |
| `xlings` | 0.4.4 | 1 x86_64 linux? program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (3 names tried) |  |
| `xlings` | 0.4.5 | 1 x86_64 linux? program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (3 names tried) |  |
| `xlings` | 0.4.6 | 1 x86_64 linux? program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (3 names tried) |  |
| `xlings` | 0.4.7 | 1 x86_64 linux? program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (3 names tried) |  |
| `xlings` | 0.4.8 | 1 x86_64 linux? program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (3 names tried) |  |
| `xmake` | 3.0.7 | 1 x86_64 linux? program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (3 names tried) |  |
| `xmake` | 3.1.0 | 1 x86_64 linux program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (3 names tried) |  |
| `xmake` | 3.1.1 | 1 x86_64 linux program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (3 names tried) |  |
| `xmake` | 3.1.2 | 1 x86_64 linux program | x86_64 | its Linux programs are x86_64 only; no aarch64 artifact upstream (3 names tried) |  |
| `zoxide` | 0.10.0 | 1 x86_64 linux? program, 1 static-pie | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has an aarch64 artifact (zoxide-0.10.0-aarch64-unknown-linux-musl.tar.gz) | `zoxide-0.10.0-aarch64-unknown-linux-musl.tar.gz`: 1 aarch64 linux? program |
| `zoxide` | 0.9.7 | 1 x86_64 linux? program, 1 static-pie | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has an aarch64 artifact (zoxide-0.9.7-aarch64-unknown-linux-musl.tar.gz) | `zoxide-0.9.7-aarch64-unknown-linux-musl.tar.gz`: 1 aarch64 linux? program |
| `zoxide` | 0.9.9 | 1 x86_64 linux? program, 1 static-pie | x86_64+aarch64 | its Linux programs are x86_64 only; upstream has an aarch64 artifact (zoxide-0.9.9-aarch64-unknown-linux-musl.tar.gz) | `zoxide-0.9.9-aarch64-unknown-linux-musl.tar.gz`: 1 aarch64 linux? program |

### Decided by a person (tools/arch-decisions.json) (6)

| recipe | version | what the bytes hold | decision | why | other architecture |
|---|---|---|---|---|---|
| `aarch64-linux-gnu-sysroot` | 2.44.3 | 284 aarch64 linux? library; 17 aarch64 linux program; 17 aarch64 linux? rel; 2 aarch64 linux? program, 2 static-pie | independent | decided: a sysroot for aarch64-linux-gnu targets: its aarch64 programs (bin/getconf, sbin/ldconfig) are the target's, no host runs them and the recipe registers none; an x86_64 host cross-compiles with it (bytes: aarch64) |  |
| `android-ndk` | 30.0.16248370 | 463 x86_64 linux? library; 374 aarch64 linux? library; 374 x86 linux? library; 371 arm linux? library ... | x86_64 | decided: the host toolchain is toolchains/llvm/prebuilt/linux-x86_64 (x86_64 programs); the aarch64, arm, riscv64 and x86 ELF files are its targets' (Android, lldb-server, simpleperf); Google publishes no linux-aarch64 NDK (bytes: sweep) |  |
| `mcpp-ide` | 0.1.0 | 1 aarch64 linux? library; 1 x86_64 linux? library; 1 aarch64 linux? program; 1 x86_64 linux? program | independent | decided: the archive carries the runtime and the module for each machine (libexec/okrun/linux-x86_64 and linux-aarch64, lib/<arch>/mcpp-ide.oke): one artifact for both (bytes: sweep) |  |
| `musl` | 1.2.6 | 5 x86_64 linux? rel; 1 x86_64 linux? library | x86_64 | decided: its lib/libc.so is the x86_64 musl loader the package exports, with x86_64 start files (bytes: sweep) |  |
| `x86_64-hurd-sysroot` | 20260314 | 41 x86_64 linux? library; 38 x86_64 linux? rel; 1 x86_64 linux? program | sweep | decided: a sysroot for x86_64-gnu (Hurd) targets: its x86_64 programs are the target's (the reader cannot tell Hurd's loader from Linux's); no program registered, like the other systems' sysroots (bytes: x86_64) |  |
| `x86_64-hurd-sysroot` | 20261118 | 41 x86_64 linux? library; 38 x86_64 linux? rel; 1 x86_64 linux? program | sweep | decided: a sysroot for x86_64-gnu (Hurd) targets: its x86_64 programs are the target's (the reader cannot tell Hurd's loader from Linux's); no program registered, like the other systems' sysroots (bytes: x86_64) |  |

### XLINGS_RES: the assets xlings-res publishes (122)

| recipe | version | what the bytes hold | decision | why | other architecture |
|---|---|---|---|---|---|
| `aarch64-linux-musl-gcc` | 15.1.0 | linux-aarch64: `e25fb0a2813a`, linux-x86_64: `b40e2c66d989` | res:x86_64+aarch64 | xlings-res publishes linux-x86_64, linux-aarch64 |  |
| `aarch64-linux-musl-gcc` | 16.1.0 | linux-aarch64: `12ce9a1a5cd7`, linux-x86_64: `e08c2d58ff6d` | res:x86_64+aarch64 | xlings-res publishes linux-x86_64, linux-aarch64 |  |
| `binutils` | 2.42 | linux-aarch64: `6d74f5678595`, linux-x86_64: `32ec131327cd` | res:x86_64+aarch64 | xlings-res publishes linux-x86_64, linux-aarch64 |  |
| `cmake` | 4.0.2 | linux-x86_64: `80940e81de61` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `d2x` | 0.1.0 | linux-x86_64: `c38d7c877625` | res:x86_64 | xlings-res publishes linux-x86_64 on GitCode only (no GitHub release 0.1.0) |  |
| `d2x` | 0.1.1 | linux-x86_64: `55dc4ced7969` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `d2x` | 0.1.2 | linux-x86_64: `658525600764` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `d2x` | 0.1.3 | linux-x86_64: `844d71c201bd` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `d2x` | 0.1.4 | linux-x86_64: `d0810ae26ca2` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `d2x` | 0.1.5 | linux-x86_64: `d98d77a179e0` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `d2x` | 2026.07.24.1 | linux-x86_64: `594edfd58e2a` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `d2x` | 2026.08.02.1 | linux-x86_64: `c3ff3eeb02da` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `d2x` | 2026.08.02.2 | linux-x86_64: `37f16ef8ee7b` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `gcc` | 11.5.0 | linux-x86_64: `9c8aec30d50e` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `gcc` | 13.3.0 | linux-x86_64: `cea00bd896e6` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `gcc` | 15.1.0 | linux-x86_64: `b42ae0051dce` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `gcc` | 9.4.0 | linux-x86_64: `0605a8c2cd6c` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.1 | linux-x86_64: `60200fe2dbf6` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.10 | linux-x86_64: `5f6674993ca1` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.11 | linux-x86_64: `d61d80a9114f` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.13 | linux-x86_64: `1e329bf6c0fe` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.14 | linux-x86_64: `2922d300e9e9` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.15 | linux-x86_64: `4d8e591f7a9b` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.16 | linux-x86_64: `567ffc14b99a` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.17 | linux-x86_64: `4305fba40b53` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.19 | linux-x86_64: `3f87ce31927c` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.2 | linux-x86_64: `053a3be4ec0c` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.20 | linux-x86_64: `04652f4f7135` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.21 | linux-x86_64: `ae768e8a24c7` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.22 | linux-x86_64: `b433e327569d` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.24 | linux-x86_64: `843518c3f8e0` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.25 | linux-x86_64: `0d137240d61d` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.26 | linux-x86_64: `43989d772a61` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.27 | linux-x86_64: `89dda9cb5d78` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.28 | linux-x86_64: `42dd87cc1f86` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.29 | linux-x86_64: `31b94a69079d` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.3 | linux-x86_64: `f7a5c4357a3d` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.30 | linux-x86_64: `e0cf769afe1d` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.31 | linux-x86_64: `c074dbaebf88` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.33 | linux-x86_64: `c13cee9e0961` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.34 | linux-x86_64: `acbda854f525` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.35 | linux-x86_64: `91dcc7de202c` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.36 | linux-x86_64: `a508ecfd23cf` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.37 | linux-x86_64: `cf4509f0841a` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.38 | linux-x86_64: `4187fde1423c` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.4 | linux-x86_64: `c575dce7b9dd` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.41 | linux-x86_64: `8fbc3375d38f` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.42 | linux-x86_64: `5221329f168d` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.43 | linux-x86_64: `f42d382c7f67` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.44 | linux-x86_64: `972d0cd41af6` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.45 | linux-x86_64: `e4eea1ea674f` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.46 | linux-x86_64: `3ad90aa55098` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.48 | linux-x86_64: `e5dde29aa76e` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.49 | linux-x86_64: `3132315c4808` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.5 | linux-x86_64: `d545912d13bb` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.50 | linux-x86_64: `b39781310f19` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.51 | linux-x86_64: `1bd80f00f59c` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.52 | linux-x86_64: `97c29a5d98b8` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.53 | linux-x86_64: `e2a33c3b6c52` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.54 | linux-x86_64: `b194d6f4911a` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.55 | linux-x86_64: `b5f6381167f2` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.56 | linux-x86_64: `cc2424b58905` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.57 | linux-x86_64: `1fe4a775b535` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.58 | linux-aarch64: `3ad697c3b82b`, linux-x86_64: `af55516d2cc8` | res:x86_64+aarch64 | xlings-res publishes linux-x86_64, linux-aarch64 |  |
| `mcpp` | 0.0.59 | linux-aarch64: `ed62c478948d`, linux-x86_64: `0d4a2b6b5f3f` | res:x86_64+aarch64 | xlings-res publishes linux-x86_64, linux-aarch64 |  |
| `mcpp` | 0.0.6 | linux-x86_64: `0e6d876871e4` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.60 | linux-aarch64: `1b9c835eedc0`, linux-x86_64: `bf8c6949a56a` | res:x86_64+aarch64 | xlings-res publishes linux-x86_64, linux-aarch64 |  |
| `mcpp` | 0.0.61 | linux-aarch64: `8bd6031587fb`, linux-x86_64: `fc44d7518233` | res:x86_64+aarch64 | xlings-res publishes linux-x86_64, linux-aarch64 |  |
| `mcpp` | 0.0.62 | linux-aarch64: `a0a385e5a115`, linux-x86_64: `c31a6f104ede` | res:x86_64+aarch64 | xlings-res publishes linux-x86_64, linux-aarch64 |  |
| `mcpp` | 0.0.63 | linux-aarch64: `f5558679dd2e`, linux-x86_64: `6157f8a4fbf8` | res:x86_64+aarch64 | xlings-res publishes linux-x86_64, linux-aarch64 |  |
| `mcpp` | 0.0.64 | linux-aarch64: `cb6e266b51ef`, linux-x86_64: `79bb4790b210` | res:x86_64+aarch64 | xlings-res publishes linux-x86_64, linux-aarch64 |  |
| `mcpp` | 0.0.65 | linux-aarch64: `20dd7a8be657`, linux-x86_64: `0d1d16aae05e` | res:x86_64+aarch64 | xlings-res publishes linux-x86_64, linux-aarch64 |  |
| `mcpp` | 0.0.66 | linux-aarch64: `5d2982ce3754`, linux-x86_64: `a73dd3ce28da` | res:x86_64+aarch64 | xlings-res publishes linux-x86_64, linux-aarch64 |  |
| `mcpp` | 0.0.68 | linux-aarch64: `674e0be1dd8b`, linux-x86_64: `a072cca7f635` | res:x86_64+aarch64 | xlings-res publishes linux-x86_64, linux-aarch64 |  |
| `mcpp` | 0.0.7 | linux-x86_64: `00f8fd531680` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.70 | linux-aarch64: `58d76221fb6c`, linux-x86_64: `c4c26a5d5bf9` | res:x86_64+aarch64 | xlings-res publishes linux-x86_64, linux-aarch64 |  |
| `mcpp` | 0.0.72 | linux-aarch64: `c1af41993bfa`, linux-x86_64: `3d7de2411160` | res:x86_64+aarch64 | xlings-res publishes linux-x86_64, linux-aarch64 |  |
| `mcpp` | 0.0.73 | linux-aarch64: `d6b5441e4d61`, linux-x86_64: `e5d1ee50bbd8` | res:x86_64+aarch64 | xlings-res publishes linux-x86_64, linux-aarch64 |  |
| `mcpp` | 0.0.74 | linux-aarch64: `18910fb03bb6`, linux-x86_64: `22eb02bfcd9f` | res:x86_64+aarch64 | xlings-res publishes linux-x86_64, linux-aarch64 |  |
| `mcpp` | 0.0.75 | linux-aarch64: `ab476f6a9373`, linux-x86_64: `df24aeba297f` | res:x86_64+aarch64 | xlings-res publishes linux-x86_64, linux-aarch64 |  |
| `mcpp` | 0.0.76 | linux-aarch64: `32e192e8eabc`, linux-x86_64: `d8bec582ee61` | res:x86_64+aarch64 | xlings-res publishes linux-x86_64, linux-aarch64 |  |
| `mcpp` | 0.0.77 | linux-aarch64: `ea5c2d6ae150`, linux-x86_64: `02498f79f4b2` | res:x86_64+aarch64 | xlings-res publishes linux-x86_64, linux-aarch64 |  |
| `mcpp` | 0.0.78 | linux-aarch64: `079c23321773`, linux-x86_64: `73f3560c955d` | res:x86_64+aarch64 | xlings-res publishes linux-x86_64, linux-aarch64 |  |
| `mcpp` | 0.0.79 | linux-aarch64: `45067de866dd`, linux-x86_64: `812be758cb65` | res:x86_64+aarch64 | xlings-res publishes linux-x86_64, linux-aarch64 |  |
| `mcpp` | 0.0.8 | linux-x86_64: `3957a4243404` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `mcpp` | 0.0.80 | linux-aarch64: `5f9a26402bdb`, linux-x86_64: `d381c27a62d5` | res:x86_64+aarch64 | xlings-res publishes linux-x86_64, linux-aarch64 |  |
| `mcpp` | 0.0.82 | linux-aarch64: `78218ae6fd9c`, linux-x86_64: `b4728eb45dee` | res:x86_64+aarch64 | xlings-res publishes linux-x86_64, linux-aarch64 |  |
| `mcpp` | 0.0.83 | linux-aarch64: `8aaa60967757`, linux-x86_64: `43e6f3e6bcb7` | res:x86_64+aarch64 | xlings-res publishes linux-x86_64, linux-aarch64 |  |
| `mcpp` | 0.0.84 | linux-aarch64: `9c40025dfcdc`, linux-x86_64: `1af427877ece` | res:x86_64+aarch64 | xlings-res publishes linux-x86_64, linux-aarch64 |  |
| `mcpp` | 0.0.85 | linux-aarch64: `b973a277075f`, linux-x86_64: `2d18c3c67aa1` | res:x86_64+aarch64 | xlings-res publishes linux-x86_64, linux-aarch64 |  |
| `mcpp` | 0.0.86 | linux-aarch64: `70f20999a0ab`, linux-x86_64: `dfa8bc7e330a` | res:x86_64+aarch64 | xlings-res publishes linux-x86_64, linux-aarch64 |  |
| `mcpp` | 0.0.9 | linux-x86_64: `904037996f74` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `musl-gcc` | 11.5.0 | linux-x86_64: `8281b2932623` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `musl-gcc` | 13.3.0 | linux-x86_64: `1f9c221b601a` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `musl-gcc` | 15.1.0 | linux-aarch64: `2277f07cd4ff`, linux-x86_64: `5f45eca0992c` | res:x86_64+aarch64 | xlings-res publishes linux-x86_64, linux-aarch64 |  |
| `musl-gcc` | 16.1.0 | linux-aarch64: `cefb261c7ef3`, linux-x86_64: `8ee9f6581624` | res:x86_64+aarch64 | xlings-res publishes linux-x86_64, linux-aarch64 |  |
| `musl-gcc` | 9.4.0 | linux-x86_64: `8cef0681b88d` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `nvim` | 0.12.2 | linux-x86_64: `31cf85945cb6` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `patchelf` | 0.18.0 | linux-aarch64: `a2ddd162d9a2`, linux-x86_64: `13659e8da5c0` | res:x86_64+aarch64 | xlings-res publishes linux-x86_64, linux-aarch64 |  |
| `xlings` | 0.3.0 | linux-x86_64: `72b98f11b53a` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `xlings` | 0.3.1 | linux-x86_64: `babad8e8fc6e` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `xlings` | 0.4.40 | linux-x86_64: `02e47440aae7` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `xlings` | 0.4.41 | linux-x86_64: `196ffcdc1961` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `xlings` | 0.4.42 | linux-x86_64: `1abed59e0d96` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `xlings` | 0.4.43 | linux-x86_64: `679a899d87d8` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `xlings` | 0.4.44 | linux-x86_64: `8f18b0a1b36b` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `xlings` | 0.4.46 | linux-x86_64: `fb7cc4c2eaa6` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `xlings` | 0.4.47 | linux-x86_64: `8b79d3ac150a` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `xlings` | 0.4.48 | linux-x86_64: `0a13d849c13e` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `xlings` | 0.4.49 | linux-x86_64: `bcefa77762c2` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `xlings` | 0.4.50 | linux-x86_64: `1535ffc376ec` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `xlings` | 0.4.51 | linux-x86_64: `3814667c9265` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `xlings` | 0.4.52 | linux-x86_64: `abfbe088c2ff` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `xlings` | 0.4.53 | linux-x86_64: `fac322ac2d10` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `xlings` | 0.4.54 | linux-x86_64: `e046ed9f6fb8` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `xlings` | 0.4.55 | linux-aarch64: `7584a15a05f7`, linux-x86_64: `b03a9d345dd6` | res:x86_64+aarch64 | xlings-res publishes linux-x86_64, linux-aarch64 |  |
| `xlings` | 0.4.60 | linux-aarch64: `6bcd686cb7e5`, linux-x86_64: `0323f588a078` | res:x86_64+aarch64 | xlings-res publishes linux-x86_64, linux-aarch64 |  |
| `xlings` | 0.4.62 | linux-aarch64: `93f32dbe3650`, linux-x86_64: `fe8c4941bde3` | res:x86_64+aarch64 | xlings-res publishes linux-x86_64, linux-aarch64 |  |
| `xvm` | 0.0.2 | linux-x86_64: `fa66931ddab9` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `xvm` | 0.0.3 | linux-x86_64: `c7068ebbd5b2` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `xvm` | 0.0.4 | linux-x86_64: `975c9f16b369` | res:x86_64 | xlings-res publishes linux-x86_64 |  |
| `xvm` | 0.0.5 | linux-x86_64: `8fc2a1393312` | res:x86_64 | xlings-res publishes linux-x86_64 |  |

### Left to the install on each architecture (step 2) (16)

| recipe | version | what the bytes hold | decision | why | other architecture |
|---|---|---|---|---|---|
| `aarch64-freebsd-sysroot` | 14.5 | 196 aarch64 freebsd library; 10 aarch64 freebsd rel | sweep | no Linux program (aarch64 freebsd library; aarch64 freebsd rel) |  |
| `aarch64-netbsd-sysroot` | 10.2 | 221 aarch64 linux? library; 8 aarch64 linux? rel | sweep | no Linux program (aarch64 linux? library; aarch64 linux? rel) |  |
| `aarch64-openbsd-sysroot` | 8.0 | 36 aarch64 openbsd library; 7 aarch64 openbsd rel | sweep | no Linux program (aarch64 openbsd library; aarch64 openbsd rel) |  |
| `coursier` | 2.1.24 | 4 arm linux? library; 3 ppc64 linux? library; 2 x86_64 freebsd library; 2 x86 freebsd library ... | sweep | no Linux program (aarch64 linux? library; arm linux? library; loongarch64 linux? library; mips linux? library; ppc64 linux? library; riscv64 linux? library; s390 linux? library; x86 freebsd library; x86 linux? library; x86_64 freebsd library; x86_64 linux? library) |  |
| `cubism-sdk-native` | 5-r.5 | 3 x86_64 linux? library; 3 aarch64 linux? library; 2 arm linux? library; 1 x86 linux? library | sweep | no Linux program (aarch64 linux? library; arm linux? library; x86 linux? library; x86_64 linux? library) |  |
| `freebsd-sysroot` | 14.5 | 198 x86_64 freebsd library; 196 aarch64 freebsd library; 10 x86_64 freebsd rel; 10 aarch64 freebsd rel | sweep | no Linux program (aarch64 freebsd library; aarch64 freebsd rel; x86_64 freebsd library; x86_64 freebsd rel) |  |
| `picolibc-aarch64` | 1.8.12 | 18 aarch64 linux? rel | sweep | no Linux program (aarch64 linux? rel) |  |
| `picolibc-arm` | 1.8.12 | 63 arm linux? rel | sweep | no Linux program (arm linux? rel) |  |
| `picolibc-riscv` | 1.8.12 | 11 riscv64/32 linux? rel; 11 riscv64 linux? rel | sweep | no Linux program (riscv64 linux? rel; riscv64/32 linux? rel) |  |
| `picolibc-x86` | 1.8.12 | 9 x86_64 linux? rel | sweep | no Linux program (x86_64 linux? rel) |  |
| `x86_64-freebsd-sysroot` | 14.5 | 198 x86_64 freebsd library; 10 x86_64 freebsd rel | sweep | no Linux program (x86_64 freebsd library; x86_64 freebsd rel) |  |
| `x86_64-haiku-sysroot` | hrev60431 | 34 x86_64 linux? library; 9 x86_64 linux? rel | sweep | no Linux program (x86_64 linux? library; x86_64 linux? rel) |  |
| `x86_64-hurd-sysroot` | 20260314 | 41 x86_64 linux? library; 38 x86_64 linux? rel; 1 x86_64 linux? program | sweep | decided: a sysroot for x86_64-gnu (Hurd) targets: its x86_64 programs are the target's (the reader cannot tell Hurd's loader from Linux's); no program registered, like the other systems' sysroots (bytes: x86_64) |  |
| `x86_64-hurd-sysroot` | 20261118 | 41 x86_64 linux? library; 38 x86_64 linux? rel; 1 x86_64 linux? program | sweep | decided: a sysroot for x86_64-gnu (Hurd) targets: its x86_64 programs are the target's (the reader cannot tell Hurd's loader from Linux's); no program registered, like the other systems' sysroots (bytes: x86_64) |  |
| `x86_64-netbsd-sysroot` | 10.2 | 224 x86_64 linux? library; 8 x86_64 linux? rel | sweep | no Linux program (x86_64 linux? library; x86_64 linux? rel) |  |
| `x86_64-openbsd-sysroot` | 8.0 | 36 x86_64 openbsd library; 7 x86_64 openbsd rel | sweep | no Linux program (x86_64 openbsd library; x86_64 openbsd rel) |  |

### Not migrated, and why

| recipe | entry | why |
|---|---|---|
| `dpcpp` | `build` | not a version: `build = { "xim:patchelf@0.18.0" }` sits at the Linux platform level, where the loader reads it as a version entry named `build` (its source URL 404s). The patchelf build dependency was meant to be `deps = { build = ... }` and is never installed. |
| `project-graph` | `nightly` | no artifact: `url = "%.deb$"` is a pattern with `github_release_tag = "nightly"`. |
| `luban:cursors`, `luban:luban-fonts` | every version | the entries are one `local versions` table shared by the three platforms; the updater's guard (`lua_edit`) cannot parse that recipe shape, so a change to them fails the candidate guard. Their bytes have no machine code (both architectures); written by Luban's release. |
| sysroots of other systems, picolibc, coursier, cubism-sdk-native | the rows of step 2 above | no Linux program in the bytes; an install on each architecture decides (expected: both, nothing is exposed to the host). |

Hook-only recipes that declare only x86_64 have no artifact and no entry
to name (K1 does not apply); their `archs` is the install sweep's to settle:
dsh, graphics, libcuda-host-link, luban-boot-generic, luban-desktop-xdesk,
luban:xdesk, npm, nvidia-gl-host-link, nvidia-video-host-link, qt5,
wsl-gl-host-link.
