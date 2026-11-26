# stern

Multi pod and container log tailing for Kubernetes (`stern` CLI, `status = "stable"`).

- Upstream: https://github.com/stern/stern (Apache-2.0)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`). Upstream also publishes `linux_arm` (32-bit ARM), omitted as outside the index's standard `x86_64`/`aarch64` matrix.

## Source

- Tier: upstream release (`https://github.com/stern/stern/releases`)
- GLOBAL: `https://github.com/stern/stern/releases/download/${tag}/stern_${version}_<os>_<arch>.<tar.gz|zip>`
- CN: none yet (`ci = { mirror = true }` requested for `xlings-res` mirroring)
- Checksums: all 6 SHA-256 hashes matched `checksums.txt` of `v1.35.0` and locally downloaded archives (`sha256sum -c`).
- Auto-update: yes (`extensions.autoupdate` with `${tag}` and `${version}`)

## Linking

Statically linked Go binaries on Linux (`CGO_ENABLED=0`); `readelf -d` shows no dynamic section and `ldd` reports "not a dynamic executable" on both `linux/amd64` and `linux/arm64`. Both Windows PE32+ executables (`amd64` / `arm64`) import only `kernel32.dll`. No `deps` declared.

## What the hooks do

- `install`: cleans `install_dir`, extracts the flat `.tar.gz` directly into `install_dir` on POSIX (`tar -xf ... -C ...` + `chmod +x`) or `.zip` via `libs/payload.lua` (`System32\tar.exe`) on Windows, and asserts `stern` / `stern.exe` + `LICENSE`.
- `config`: registers `stern` with `xvm.add("stern", { bindir = pkginfo.install_dir() })`.
- `uninstall`: removes `stern` via `xvm.remove("stern")`.
- System impact: none outside the package install directory and xvm registration.

## Verification

- Static & isolation tests (`pytest tests/s/test_stern.py -m "static or isolation" -v`), repository-wide checks, and `lint_exec_quoting.sh` on Linux x86_64.
- Real isolated/locked `xlings install local:stern -y`, `stern --version`, `stern --stdin --no-follow --color=never`, `verify` and `index` tests, and `xlings remove local:stern -y` on Linux x86_64.
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows` (`x86_64`, `aarch64`) live installs (checked archives, checksums, layout, ELF/PE headers, and Lua sandbox hooks instead).

## Revision log

- 2026-11-25 — added at `1.35.0`: initial spec-2 recipe with `extensions.autoupdate` and `ci = { mirror = true }`.
