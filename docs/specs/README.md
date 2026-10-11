# Specifications

The recipe format and its conventions, for whoever writes or reads recipes
mechanically. Specifications are in English only. The chapters explain how to
use them; these say exactly what is accepted.

| Specification | What it governs |
|---|---|
| [XPackage V2](xpackage-v2.md) | the current recipe format: architectures, sources, revisions, the seven rules, capability probing |
| [V2 changelog](xpackage-v2-changelog.md) | what changed in V2 and in its tooling |
| [Template](xpackage-template.lua) | a V2 recipe to copy |
| [url-template](url-template.md) | the legacy opt-in for automatic version updates |
| [Legacy V1](legacy/V1/xpackage-spec.md), [V0](legacy/V0/xpackage-spec.md) | earlier formats, still read by clients; deprecated, not translated |

How an index is distributed to clients, and how a snapshot names the clients it
needs, are xlings's specifications:
[index distribution](https://github.com/openxlings/xlings/blob/main/docs/specs/index-distribution.md),
[index version contract](https://github.com/openxlings/xlings/blob/main/docs/specs/index-version-contract.md).
The base manifest format both versions extend is
[xpkg manifest v1](https://github.com/openxlings/xlings/blob/main/docs/specs/xpkg-manifest-v1.md).
