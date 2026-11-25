# AGENTS.md

`xim-pkgindex` is the official package index of [xlings](https://github.com/openxlings/xlings)
(the `xim:` namespace). A package is defined by one **xpkg** (xpackage): a Lua file under `pkgs/`.
Whoever adds or updates one is usually **not** the upstream's author, and may be an agent: what
matters is that its information and resources are official (or from a well-known mirror) and that
you have run what you submit. This file holds only the rules that always apply; the how-to is in
the skills (see "Read next"), the reasons in `docs/`.

## Workflow

1. **No package named?** Ask the user: which package, add / bump / fix, its upstream URL, which
   platforms. Do not guess one.
2. Write the xpkg and its test; verify them in an isolated home.
3. Open the pull request and stay with it until CI is green: fix locally, push once, repeat.
4. **A tool problem** (xlings, libxpkg, the updater, CI)? Compare your `xlings --version` with CI's
   pin, search existing issues, analyse locally; for a real bug file an issue titled
   `[xpkg-report]: ...` (see `tooling-and-reporting.md`).
5. Finish by telling the user: the pull request, CI state, issues filed, what you could not run.

## Rules that always hold

- **Change only what the task needs.** Never edit `.github/**`, `libs/**`, `tools/**`,
  `.agents/tools/**`, `index-compat.json`, `tests/lib/**`, `tests/fixtures/**`, `docs/specs/**` or
  generated files unless you are a maintainer and the task is about them. If CI itself is broken,
  say so in the pull request with the log link.
- **A published version entry never changes**: a fix is a new `revision` or a new version.
- **Spec 2, from the template** (`docs/specs/xpackage-template.lua`), not from a neighbouring xpkg:
  many are older.
- **Source**: the upstream's own release (or its official repository's), then a well-known third
  party; within it prefer a static/musl artifact. CN only through a well-known mirror you
  verified, otherwise skip CN. Declare `ci = { mirror = true }` by default, unless you declare a
  well-known CN mirror (the pull-request lint rejects both). **`xlings-res` as `xpm.source` is
  written by maintainers**: do not use it; ask in an issue if a package needs it.
- **Install means unpack and place**: never compile, never use a host package manager, `sudo`, a
  shell profile or `PATH`.
- **Unofficial packaging** (a repack, a patched build, a personal packaging) sets
  `namespace = "<your handle>"`: its id is `<ns>:<name>@<version>`.
- **Luban OS** (`pkgs/luban/`, `libs/luban*.lua`): bug fixes only, verified locally; a feature
  starts as an issue.
- **Verify** in an isolated `XLINGS_HOME` (never your own), run the program, and say what you could
  not run.

## Pull requests and issues

- Never push to `main`; one concern per pull request; commits `<type>(<scope>): <description>`;
  contributors do not merge. Fill the pull request template.
- A **new** package adds `.agents/docs/<name>.md`; a version bump adds nothing.
- `Authorship: ai-and-human` or `by-human` in every description (agents write `ai-and-human`); `Agent:` and `Model:` are optional and may
  stay blank. A workflow turns these and the changed files into labels (hints, not checks): do not
  pass `--label`.
- **Before posting, remove** local absolute paths, usernames, hostnames, e-mail addresses and
  tokens from descriptions and logs: an edit keeps the old text in the history.
- A change to something many xpkgs depend on (`glibc`, `gcc-runtime`, `libs/**`, Luban) fans out
  CI: keep it minimal and push once.

## Read next

| You are... | Read |
|---|---|
| adding, bumping or fixing an xpkg | `.agents/skills/xpkg-creater/SKILL.md` |
| opening a pull request | `.agents/skills/pr-workflow/SKILL.md` |
| debugging, or filing an issue about a tool | `.agents/skills/xpkg-creater/references/troubleshooting.md`, `.../tooling-and-reporting.md` |
| touching Luban | `.agents/skills/luban-packages/SKILL.md` |
| carving an LLVM sub-package | `.agents/skills/llvm-subpackaging/SKILL.md` |
| maintaining the xlings-res mirror, or its tracking issue (label `mirror-failed`) | `.agents/skills/xlings-res-maintainer/SKILL.md` |

`AGENTS.md` and `.agents/skills/**` are English only.
