# CI: Mirror and Update

**English** | [简体中文](zh/13-ci-mirror-and-update.md)

A package can ask the index's automation to mirror its declared versions and to
propose new ones. This is index maintenance only: xlings ignores it, and it never
changes how a package resolves.

## Opting in

```lua
package = {
    name = "foo",
    repo = "https://github.com/acme/foo",

    ci = {
        mirror = true,
        update = true,
    },

    xpm = {
        source = "https://github.com/acme/foo/releases/download/${version}/foo-${os}-${arch}.${ext}",
        linux = {
            ["latest"] = { ref = "1.2.0" },
            ["1.2.0"] = {
                sha256 = { x86_64 = "<sha256>", aarch64 = "<sha256>" },
            },
        },
    },
}
```

| Field | Default | Meaning |
|---|---|---|
| `ci.mirror` | `false` | once a declared version is verified, CI may create its `xlings-res` mirror release |
| `ci.update` | `false` | the package joins the periodic scan; a newer upstream version becomes a pull request |

The schedule is the repository's, in `.github/xpkg-ci.yml`, never a recipe's:

```yaml
version: 1
update:
  enabled: true
  interval: 3d
  wakeup_cron: "17 2 * * *"
  max_packages_per_run: 50
  request_budget: 500
```

The workflow wakes daily; a package is scanned when its interval has passed.

## What each does

```text
ci.mirror = true  ->  the versions already declared -> download, verify -> an xlings-res release
ci.update = true  ->  a newer upstream version -> its resource matrix and sha256s -> a pull request
```

The two are independent: `mirror` never discovers a version, and `update` never
edits the index without a pull request. With both, the order is: discover, hash,
pull request, its CI, merge, then the mirror release.

- `update` needs a URL template containing `${version}`; a fixed URL cannot be
  followed.
- `mirror` with `source = "xlings-res"` is a conflict (it is already the official
  mirror) and fails closed.
- A mirror release never changes where users download from on its own: routing
  installs to the mirror is a separate, reviewed index change.
- A self-built resource (a target sysroot, anything from `tools/res/`) sets no
  `ci`: mirroring would mirror itself, and an update would point `latest` at a
  URL nobody built yet.

## The tool

`tools/xpkg_ci.py` does each step, runnable locally:

| Command | Does | Network | Writes |
|---|---|---|---|
| `inspect` | reads every recipe's `ci`, source and matrix | no | a report |
| `scan` | queries upstream, expands templates, downloads, hashes | yes | a report and a cache |
| `verify <manifest>` | checks a manifest's matrix and hashes | yes | nothing |
| `mirror <manifest> --execute` | creates the release on GitHub and GitCode, verifies three ways | yes | releases |
| `propose --apply` | writes the minimal recipe change for a pull request | no | the recipe |

A release that already exists with identical content is success; any difference
fails, and a release is never overwritten.

## Legacy: `url_template` and `res_versioned`

Older recipes opt into updates with a per-platform `url_template` (a
`{version}` placeholder), or `res_versioned = true` for entries written
`"XLINGS_RES"`. Both still work; new recipes use `xpm.source`. Their contract is
[url-template](specs/url-template.md).

## The weekly sweep

`ci-test.yml` installs only what a push changed. `ci-sweep.yml` installs one slice
of every recipe each week, chosen by ISO week, so a hook nobody edited is still
exercised regularly; a dispatch re-runs one slice.
