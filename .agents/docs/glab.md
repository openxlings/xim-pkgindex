# glab

GLab (`glab`) is GitLab's official command-line tool (`status = "stable"`).

- Upstream: https://gitlab.com/gitlab-org/cli (MIT)
- Namespace: `xim`
- Platforms: `linux` (`x86_64`, `aarch64`), `macosx` (`x86_64`, `aarch64`), `windows` (`x86_64`, `aarch64`).

## Source

- Tier: upstream release (GitLab Releases of `gitlab-org/cli`)
- GLOBAL:
  - `linux`: `https://gitlab.com/gitlab-org/cli/-/releases/v${version}/downloads/glab_${version}_linux_${arch_alias}.tar.gz` (`amd64` / `arm64`)
  - `macosx`: `https://gitlab.com/gitlab-org/cli/-/releases/v${version}/downloads/glab_${version}_darwin_${arch_alias}.tar.gz` (`amd64` / `arm64`)
  - `windows`: `https://gitlab.com/gitlab-org/cli/-/releases/v${version}/downloads/glab_${version}_windows_${arch_alias}.zip` (`amd64` / `arm64`)
- CN: none yet (`ci = { mirror = true }`)
- Checksums: `checksums.txt` from the `v1.133.0` release; all 6 downloaded archives matched their published SHA-256 digests.
- Auto-update: no — upstream is hosted on `gitlab.com` (not GitHub Releases or a Sparkle XML appcast, which `xpkgindex-update` supports).

## Linking

Static Go executables on Linux (`x86_64` and `aarch64`): `file` reports `statically linked`, `readelf -d` reports `There is no dynamic section in this file.`, and `ldd` reports not a dynamic executable — zero runtime dependencies (`xim:glibc` is not declared). On Windows (`x86_64` and `aarch64`), PE32+ console binaries import only `kernel32.dll`.

## What the hooks do

- install: Every upstream archive is flat at root (`bin/glab` or `bin/glab.exe`, `CHANGELOG.md`, `LICENSE`, `README.md`). To avoid leaking files from other flat archives in shared `runtimedir`, `install()` extracts directly from `pkginfo.install_file()` into a clean `pkginfo.install_dir()` (`payload.unpack{}` on Windows `.zip`; `tar -xzf` + `chmod +x` on POSIX `.tar.gz`), then asserts all 4 files via `payload.require(...)`.
- config: Registers `glab` via `xvm.add("glab", { bindir = pkginfo.install_dir() .. "/bin" })`.
- uninstall: Removes `glab` via `xvm.remove("glab")`.
- System impact: none.

## Verification

- Static & isolation pytest suites (`tests/g/test_glab.py`, repo-wide `static or isolation`), `tools/lint_exec_quoting.sh`, `.github/scripts/check-*.sh`, and `tools/xpkg_ci.py inspect/materialize` passed locally.
- Isolated `XLINGS_HOME` & `HOME` lifecycle/verify on Linux `x86_64` passed (`xlings config --add-xpkg`, `xlings search glab`, `xlings install local:glab -y`, `glab version`, `glab completion -s bash`, `tests/g/test_glab.py -m "index or lifecycle or verify"`, `xlings remove local:glab -y`, repeat remove, `xlings config --remove-xpkg glab`).
- Not run locally: `linux/aarch64`, `macosx` (`x86_64`, `aarch64`), and `windows` (`x86_64`, `aarch64`) runtime execution (verified archives, checksums, and Lua hook mocks locally; native execution delegated to CI).

## Revision log

- 2026-11-26 — added at 1.133.0: initial packaging with flat-archive direct extraction and full payload file verification (`bin/glab`/`bin/glab.exe`, `CHANGELOG.md`, `LICENSE`, `README.md`).
