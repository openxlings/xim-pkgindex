# Getting Started

**English** | [简体中文](zh/01-getting-started.md)

Install xlings, then install your first package from this index.

## Install xlings

```bash
curl -fsSL https://d2learn.org/xlings-install.sh | bash
```

```powershell
irm https://d2learn.org/xlings-install.ps1.txt | iex
```

The first is for Linux and macOS, the second for Windows PowerShell.

## Install a package

The name is the one on each package's page:

```bash
xlings install gcc -y
gcc --version
```

Another one:

```bash
xlings install mcpp -y
mcpp --version
```

Everything goes into xlings's own directory, not the system; `-y` answers the
confirmation.

## Find things, see what you have

```bash
xlings search gcc     # search
xlings list           # what is installed
xlings remove gcc     # uninstall
```

Each package's page on [index.xlings.org](https://index.xlings.org) lists the
commands it provides, the architectures it supports, and whether its versions are
switchable with `xlings use`.

## When the index moves

```bash
xlings update
```

fetches the newest snapshot of the index. The site's
[stats page](https://index.xlings.org/stats/) shows how many packages the index
holds and what was added recently.

## Where to go next

- Using xlings: [the xlings docs](https://github.com/openxlings/xlings/tree/main/docs) —
  versions, projects, SubOS
- Contributing a package: [Adding a package](10-adding-a-package.md)
- Running your own index: [xim-pkgindex-template](https://github.com/openxlings/xim-pkgindex-template)
- Questions: [the forum](https://forum.d2learn.org/category/9/xlings)
