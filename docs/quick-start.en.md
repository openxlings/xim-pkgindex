# Quick start

**English** | [简体中文](quick-start.md)

Install xlings, then install your first package from this index.

## 1. Install xlings

```bash
# Linux / macOS
curl -fsSL https://d2learn.org/xlings-install.sh | bash
```

```powershell
# Windows · PowerShell
irm https://d2learn.org/xlings-install.ps1.txt | iex
```

## 2. Install a package

The name is the one shown on every package page in this index:

```bash
xlings install gcc -y
gcc --version
```

Another one:

```bash
xlings install mcpp -y
mcpp --version
```

Everything lands in xlings' own directory rather than in the system; `-y`
skips the confirmation prompt.

## 3. Find things, see what you have

```bash
xlings search gcc     # search
xlings list           # what is installed
xlings remove gcc     # uninstall
```

You can browse from this site too: each package page lists the commands it
provides (`programs`), the architectures it supports, and whether xvm manages
its versions.

## 4. When the index moves

```bash
xlings update
```

Pulls the latest package index. This site's [stats page](../stats/) shows how
many packages the index holds and what was added recently.

## Where to go next

**Using xlings**

- [Documentation](https://xlings.d2learn.org/documents/xim/intro.html) — the
  full command set, multi-version management, SubOS isolation
- [Forum](https://forum.d2learn.org/category/9/xlings) — questions and feedback

**Contributing a package**

- [Contributing guide](contributing.md) — the end-to-end procedure
- [XPackage V2 spec](V2/xpackage-spec.md) — descriptor fields and constraints
- [Adding a package](V1/add-xpackage.md) — writing a recipe from scratch

**Running your own index**

- [xim-pkgindex-template](https://github.com/openxlings/xim-pkgindex-template) —
  template repository for a self-hosted, mirrored or private package index
