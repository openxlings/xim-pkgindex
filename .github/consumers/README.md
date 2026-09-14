# Consumer fixtures

Each directory is an mcpp project that consumes one or more recipes of this
index, built by `.github/workflows/consumer-through-index-override.yml` in a
fresh mcpp home whose `config.toml` names the pull request's checkout as the
`xim` index:

```toml
[index.repos.xim]
url = "<the checkout>"
```

so every `xim:` address the project declares resolves against the recipes the
pull request proposes, the state a consumer's own CI reaches with the same two
lines before its first `mcpp` command.

A fixture directory holds:

| file | content |
|---|---|
| `consumes` | the repository paths the fixture exercises, one per line; the fixture is built when the pull request changes one of them, or the fixture itself |
| `mcpp.toml`, `src/` | the project |
| `check.sh` | the criteria, run after `mcpp build` with `MCPP`, `MCPP_HOME` and `REGISTRY` set; it exits non-zero on the first criterion that does not hold |
