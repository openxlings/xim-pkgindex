# xim-pkgindex: mcpp GL Runtime Rollout Plan

> 状态: active
> 分支: `codex/gl-runtime-closure-rollout`
> PR: pending
> Last updated: 2026-06-03
> 目标: 在 mcpp 和 mcpp-index 完成标准运行时闭包能力后,按现有 xlings 发布流程更新可安装版本和必要镜像资产。

## Scope

This repository owns xlings package descriptors and release rollout coordination.
It should not implement GL runtime behavior directly. It participates only when
there is a released mcpp version, xlings bootstrap dependency, or mirror asset
that must be made installable through `xlings install`.

## Current Expected Role

- Track upstream mcpp release that contains runtime metadata/run environment
  support.
- Update `pkgs/m/mcpp.lua` when a new mcpp version is required by xlings or
  users.
- Mirror mcpp release assets to the xlings resource channel if the existing
  package policy requires mirrored downloads.
- Run local install smoke tests through `xlings install local:mcpp@<version>`.
- Open PR, wait for package-index CI, and squash merge after required checks.

## Related Index Signals

The current repository already has GUI runtime dependency gaps that should be
handled after mcpp/mcpp-index provide the standard runtime model:

- `pkgs/g/griddycode.lua` has comments pointing at undeclared GUI runtime
  dependencies such as GL, X11, GLFW, and Xi.
- `pkgs/k/khistory.lua` has a Linux runtime TODO around `libglfw.so.3`.

These are package-index follow-ups, not blockers for the mcpp core runtime
metadata design. They should become concrete package fixes only after the
runtime requirement surface is available.

## xlings-res Participation

No direct `xlings-res` repository change is required for the design checkpoint.
Resource mirror work becomes active only if a new mcpp release is published and
the package descriptor points at mirrored assets.

When that happens, the process should follow the existing release/mirror
pattern:

- publish or refresh GitHub release assets for the relevant resource package;
- publish or refresh GitCode mirror assets when the package requires them;
- record asset URL, size, and sha256 in the package descriptor;
- do not include local absolute paths or private operator details in PR text.

## Implementation Plan

- [x] Create this repository-level rollout checkpoint.
- [ ] Wait for mcpp runtime metadata support PR to merge and release.
- [ ] Wait for mcpp-index GL runtime package/metadata PR to merge.
- [ ] Decide whether xlings bootstrap or user-facing install requires a new
      `pkgs/m/mcpp.lua` version.
- [ ] If required, update `pkgs/m/mcpp.lua`.
- [ ] If required, refresh mirrored mcpp assets and checksums.
- [ ] After the tool/index model lands, audit GUI packages with known runtime
      gaps and decide whether to add explicit runtime dependencies.
- [ ] Run local mcpp install smoke:

```bash
xlings search mcpp
xlings install local:mcpp@<version> -y
mcpp --version
```

- [ ] Open PR and wait for CI.
- [ ] Squash merge after required checks pass.

## Verification

- [ ] `xlings search mcpp`
- [ ] `xlings install local:mcpp@<version> -y`
- [ ] `mcpp --version`
- [ ] Repository CI: package-index tests and xpkg tests
- [ ] Release/mirror evidence if assets are refreshed

## PR / CI / Merge Notes

- [ ] Commit this plan as the first checkpoint.
- [ ] PR body must be sanitized: no local absolute paths, no private usernames,
      no operator prompt content.
- [ ] Record upstream PR/release links only after they are public.
- [ ] Poll CI without serially blocking unrelated repository work.
- [ ] Squash merge after checks pass, using repository policy.

## Cross-Repository Dependencies

- Blocked on `mcpp` release for tool behavior.
- Blocked on `mcpp-index` merge for package metadata.
- Does not block `imgui-m` documentation or example work.
