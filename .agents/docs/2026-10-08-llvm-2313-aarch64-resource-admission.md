# LLVM 23.1.3 Linux aarch64 resource admission — 2026-10-08

The source build is commit `6ebe21794d2fb6b1bc3934738527949a627de5f1`,
[native run 37689904325](https://github.com/openxlings/xim-pkgindex/actions/runs/37689904325).
The unchanged builders were admitted at commit
`984d468bd205af1a41eed238157eed741de60fb9`,
[run 37695531148](https://github.com/openxlings/xim-pkgindex/actions/runs/37695531148),
which completed native managed-process library resolution, default timezone /
locale / gconv / host NSS policy, managed UAPI and CRT, the host-only header
negative control, std/std.compat and compile/link/run gates. GLOBAL upload
completed and every API asset digest and nonzero size matched the report.

CN byte identity and the installed-client / current mcpp candidate consumer
gates remain required before index activation. The machine-readable companion
records their pending status; successful build admission does not imply those
later gates passed.

Linux aarch64 first appears at LLVM/tools 23.1.3 and glibc 2.44.3-r1.
Earlier LLVM 20/22 and glibc entries remain x86_64-only. Therefore the existing
`glibc@>=2.39` dependency resolves to the only available ARM64 provider,
2.44.3, while x86_64 resource URLs and hashes remain unchanged. GCC runtime,
UAPI, zlib and both libxml2 recipe aliases expose matching native payloads.
The Linux LLVM `latest` alias stays 22.1.8 pending the separate post-mcpp-release
move; mcpp's native default requests LLVM 23.1.3 explicitly.

Catalog runtime metadata requires xlings 2026.10.8.1. Its published index
entry from main commit f8ad78a0 / PR939 was merged without rewriting candidate
history or changing the source-build ancestry.

## Immutable published archives

| Archive | Bytes | SHA256 |
| --- | ---: | --- |
| [gcc-runtime-15.1.0-linux-aarch64.tar.gz](https://github.com/xlings-res/gcc-runtime/releases/download/15.1.0/gcc-runtime-15.1.0-linux-aarch64.tar.gz) | 8518931 | `86aed3a2f78f623c48fa0dffa0eb377d405343ee5c733ee96f38f598e87d8b6e` |
| [glibc-2.44.3-r1-linux-aarch64.tar.gz](https://github.com/xlings-res/glibc/releases/download/2.44.3-r1/glibc-2.44.3-r1-linux-aarch64.tar.gz) | 35489903 | `25dbdec6bc40784f138028e2c7418f7522b2b96f4ef81be2e60d8b77f0944c66` |
| [libxml2-2.13.5-linux-aarch64.tar.gz](https://github.com/xlings-res/libxml2/releases/download/2.13.5/libxml2-2.13.5-linux-aarch64.tar.gz) | 2711313 | `723f97d01c6a7618ace30842e1a03cfbd99965a340c1df263d31ba217cfd1cee` |
| [linux-headers-5.11.1-linux-aarch64.tar.gz](https://github.com/xlings-res/linux-headers/releases/download/5.11.1/linux-headers-5.11.1-linux-aarch64.tar.gz) | 1443058 | `ffb294cc183e9ddb87af3411364ba09c9724390494c2f271a81e98a3d6ccfbd7` |
| [llvm-23.1.3-linux-aarch64.tar.gz](https://github.com/xlings-res/llvm/releases/download/23.1.3/llvm-23.1.3-linux-aarch64.tar.gz) | 279311767 | `8a4697b6f22703c1fb8d808a0ef6022f3a9e9111a70e7a02009b7814bdbe46a9` |
| [llvm-tools-23.1.3-linux-aarch64.tar.gz](https://github.com/xlings-res/llvm/releases/download/23.1.3/llvm-tools-23.1.3-linux-aarch64.tar.gz) | 78550793 | `e9c3675a170d6f1aaa21ee2fd9c8ba7c67813aab4721d87772f45a83c0c89ad2` |
| [zlib-1.3.1-linux-aarch64.tar.gz](https://github.com/xlings-res/zlib/releases/download/1.3.1/zlib-1.3.1-linux-aarch64.tar.gz) | 161801 | `84605519e53f272c998a92bf806abace459b10937037f27e4b993d9d161546b5` |
| [llvm-23.1.3-linux-aarch64.tar.xz](https://github.com/xlings-res/llvm/releases/download/23.1.3/llvm-23.1.3-linux-aarch64.tar.xz) | 167962376 | `fb763a21041d27ea6058df64e42dfb26456517e51f943e7caff8bed5310aa4c3` |
| [llvm-tools-23.1.3-linux-aarch64.tar.xz](https://github.com/xlings-res/llvm/releases/download/23.1.3/llvm-tools-23.1.3-linux-aarch64.tar.xz) | 47747036 | `39357154fcfaec5e8a12ab649814d1e05c167389311feff70c8c2a0bf30d0282` |

Only gzip routes are selected by these Linux recipes. The independently
verified xz variants remain published and recorded for both LLVM bundles.
Archive LICENSE / PROVENANCE / ELF-MANIFEST files document their source,
bootstrap and binary closure; glibc additionally includes the pinned IANA
2026e source identity and its license, compiled timezone data and C.utf8.

## 2026-10-08 dual-mirror verification update

Local gtc uploaded all nine ARM64 archives and their SHA256 sidecars to CN.
Each archive was independently downloaded from GLOBAL and CN; all nine
matched the native artifact bytes and the admission report above (9/9).
The companion JSON records the filenames, sizes, hashes and admission run.
Existing x86_64 assets were not replaced. Installed-client acceptance, native
GNU self-hosting and ecosystem consumers remain pending; the candidate
recipes are prepared for that admission without activating main.

## 2026-10-08 installed-client guard correction

[Candidate admission run 37697997630](https://github.com/mcpp-community/mcpp/actions/runs/37697997630)
selected and downloaded the ARM64 resources with released xlings 2026.10.8.1,
but failed the glibc install guard. Catalog loading exposes the process ABI;
the separate hook executor reloads the recipe without that LoaderContext.
Its top-level `os.arch()` fallback therefore cannot establish client compatibility.
The install guard now requires the catalog-resolved `_RUNTIME.self_exports`
to contain both `linux-aarch64-glibc` and the exact installed ARM64 loader path.
This preserves rejection of absent, x86 or inconsistent catalog exports while
accepting the current client whose hook architecture API is absent.
No resource bytes, hashes, client floor or catalog metadata changed.
Installed-client admission must be repeated against this correction.

## 2026-10-08 CI tooling and closure report correction

The original [Linux install job 113066636361](https://github.com/openxlings/xim-pkgindex/actions/runs/37701768143/job/113066636361)
entered the APT tooling step at 23:21:24 UTC and emitted no further APT output
before cancellation at 05:21:43 UTC. Its annotation states that the job exceeded
the six-hour maximum. The subsequent package installation step did not start.
These observations establish an unbounded tooling step; they do not identify
a network cause or distinguish which APT command remained blocked.
The step now bounds APT acquisition, lock waits and command duration while
retaining nonzero failures and all required ELF/Lua tools.

A separate exact x86_64 xlings 2026.8.10.1 installation accepted candidate
recipes at `84c27c3014e676f2175868627b93494d6bd442e8` in a pristine private
`XLINGS_HOME`, with the original HOME preserved and explicit global scope.
It installed glibc 2.44.3, gcc-runtime 15.1.0, linux-headers 5.11.1, zlib 1.3.1,
libxml2 2.13.5 and LLVM 23.1.3. The compiler ran with managed include paths,
compiled and executed a C++23/kernel-header probe, and passed the actual
dependency closure check: 31 ELF objects and six external sonames accounted for.
This supplementary result does not replace the required PR checks.

That investigation also exposed Bash 5.2's nounset diagnostic when taking the
length of an empty associative array: the checker could print an error yet
exit successfully without its closure summary. Counting the existing keys
with a scalar preserves the D1/D2/D3 assertions. A real ELF with zero external
dependencies now exercises that path in a regression test. Actual payload
checks also reported 293 ELF/zero external sonames for glibc and seven ELF/three
external sonames for gcc-runtime without the diagnostic. No package recipes,
builder inputs, published archive bytes or resource hashes changed in this batch.

## 2026-10-08: published glibc revision 2 integration and data admission

The normal merge of upstream commit `ebf1fbb3417ec513b923279044433887b3af8850` preserves the logical interpreter root cache/preload correction published by PR #940. Both runtime exports use `lib64`; ARM64 retains its process ABI validation and older unsupported version exclusion. The recipes in this preparation retain the actual published revision 2 URLs and hashes. No unavailable revision 3 resource is advertised.

Actual GLOBAL and CN GETs of both revision 2 archives matched their GitHub release digests and sizes. The upstream successful native build is run `37707873566`, source `02f81001447652161d482a15da50f2a720a60310`. The supplementary `2026-10-08-glibc-r2-data-inventory.json` records these identities separately from the immutable revision 1 admission record.

The executable offline inventory gate rejects both revision 2 archives: `share/zoneinfo/Asia/Tokyo`, `share/zoneinfo/Etc/UTC`, `lib/locale/C.utf8/LC_CTYPE`, `LICENSE`, `TZDATA-LICENSE`, `PROVENANCE.txt`, and `ELF-MANIFEST.txt` are absent. GBK conversion modules and the `lib64 -> lib` alias are present. This archive inspection establishes a data/provenance gap; it does not claim native runtime failure or infer the cause of the upstream packaging omission.

Revision 3 preparation combines the logical-root patch and runtime probe with the previously admitted pinned IANA 2026e data, native compiled C.utf8, managed conversion/NSS policy, licenses and provenance. The dedicated glibc workflow builds only glibc on both native architectures against hash-verified published kernel UAPI. All original runtime data and logical-root gates remain mandatory, followed by offline archive inventory. Existing LLVM and dependency archives are reused without rebuilding. Revision 3 recipe activation requires successful native evidence and real GLOBAL/CN byte identities.

The default source reuse guard still requires all builders and isolation patches to be identical. The explicitly selected published-glibc-only mode checks the same successful source ancestry and exact eight unchanged archive identities, keeps LLVM/dependency builder equality, and replaces only glibc with the current published recipe resource after release API and both mirror GET verification. Fresh native process, data, header, CRT and module admission remains required. During this preparation the known revision 2 inventory rejection is expected; it cannot count as final ecosystem admission.

The first revision 3 matrix run `37733525036` executed the default Tokyo/UTC, C.UTF-8, GBK/NSS and logical-root cache/preload probes successfully on both native architectures. Its subsequent offline inventory rejected `Etc/UTC` because the new checker treated tar hard links as absent regular files. This was a checker defect: the preceding runtime probe had loaded the same timezone successfully. The correction resolves hard links and relative symlinks to a nonempty file within the archive root, rejecting missing targets, external targets and cycles. Five real tar fixtures exercise these cases. Failed-build archive upload now retains generated payloads for diagnosis; successful build and admission remain mandatory for publication.

The preparation's actual pull-request package run `37733524995` completed successfully, including all seven changed recipes. Its bounded APT tooling step finished in nine seconds, and the corrected ELF closure report included glibc's 293 objects with zero external sonames. This is the package gate for the preparation revision, not final revision 3 acceptance. The separate preparation native reuse run `37733525032` failed before inventory because Lua was unavailable at reuse startup; prerequisites now precede recipe parsing. No LLVM/GCC source rebuild was performed by either preparation native lane.

Corrected source run `37734176881`, commit `e8f330d45b2b5ca57c608e7ec8d40d6170502cf1`, passed both native architecture jobs and all runtime/data/root-cache/inventory gates. The source ledger records the actual archive hashes from these successful job logs. Slow local Actions artifact transport motivated an explicit publication-only dispatch of the existing glibc workflow: it downloads these exact two artifacts on a native runner, validates the successful same-repository source, original job identities, ancestry, identical glibc builder/patch content, source ledger, checksums and inventory, and publishes only immutable GLOBAL glibc revision 3 assets. This mode skips source rebuilding and changes no package index pointer. CN transport and complete mirror GET identities remain required before recipe activation. The active native reuse exception is restricted to revision 3 and its final published provenance; earlier revision 2 diagnostic evidence remains historical.

## 2026-10-08: revision 3 publication and candidate activation

Publication-only run `37735409379`, source head `aab7df8c9d7a9cf19ae7497327984eccad47776a`, succeeded without rebuilding glibc or changing the index pointer. Local complete downloads from GLOBAL and CN matched the successful original native source hashes, GitHub asset digests and sizes. CN archives and sidecars were uploaded through the local authenticated `gtc` client; subsequent complete archive and sidecar GETs verified their identities. Both downloaded archive inventories pass.

| Architecture | Immutable archive | Bytes | SHA256 |
| --- | --- | ---: | --- |
| aarch64 | glibc-2.44.3-r3-linux-aarch64.tar.gz | 35500275 | 33d015ddd07c84d82b8c7cfbe6cf920222d0754c7c777f3818c78c764de5461e |
| x86_64 | glibc-2.44.3-r3-linux-x86_64.tar.gz | 38371568 | 2fe32c53a40885ec6d3322135df19dc4fe65835b093b03bfa41502c1eb7abffa |

The candidate recipe now selects these actual revision 3 resources on both architectures and retains the logical-root/lib64/runtime ABI/client-floor contract. The eight unchanged LLVM and dependency archive identities remain exactly those in the original source admission. Their bytes were not rebuilt or reuploaded. The final native reuse guard additionally compares the published glibc identity with its source ledger and checks the successful source ancestry and identical builder/patches before repeating fresh native admission.

The automatically triggered glibc-only build run `37735412929` was canceled because it would rebuild source-identical resources after the original successful native source and publication-only validation. The original native run `37734176881` remains successful and unchanged. This canceled redundant run is not an admission gate or substitute for final candidate package/native checks. The earlier slow local Actions artifact download was preserved during GLOBAL/CN verification.

The detailed identities and mirror checks are recorded in `2026-10-08-glibc-r3-resource-admission.json`. Final exact-head native and whole-PR package acceptance, followed by the mcpp consumer and release gates, remain outstanding at this activation record. Historical revision 1 and revision 2 evidence is retained separately.
