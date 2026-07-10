# dftracer-utils-prebuilds

Prebuilt, relocatable [dftracer-utils](https://github.com/LLNL/dftracer-utils)
bundles for macOS and Linux (x64 / arm64), published as GitHub Releases.

Each release asset `dftracer-utils-<version>-<os>-<arch>.tar.gz` extracts to a
self-contained tree that runs from anywhere:

```
bin/       all dftracer_* tools (dftracer_server, dftracer_index, ...)
lib/       shared + static libraries, plus the cmake package config
include/   headers
```

The `<version>` is the `setuptools_scm` version of the built dftracer-utils
commit (e.g. `1.2.3.post5`), so a bundle maps exactly to the source it came
from - the same version a `pip install dftracer-utils` of that commit would get.

## Use

```bash
tar xzf dftracer-utils-1.2.3.post5-linux-x64.tar.gz
./dftracer-utils-1.2.3.post5-linux-x64/bin/dftracer_server -d <trace-dir>
```

The `bin/` tools find `lib/` via an embedded relative rpath; no install needed.
Verify a download against `SHA256SUMS` in the same release.

## How it is built

`.github/workflows/build.yml` runs nightly (and on demand) against
`dftracer-utils@develop`:

- Version comes from `setuptools_scm`; if a release for that version already
  exists, the run is skipped (no rebuild when nothing changed).
- RocksDB is built once and cached (`scripts/ci/build_rocksdb.sh` from
  dftracer-utils); other deps are cached via `CPM_SOURCE_CACHE`.
- Release build; SIMD is selected at runtime by simdjson/RocksDB, so binaries
  stay portable (no `-march=native`).
- `cmake --install` produces the full tree; `scripts/bundle.sh` rewrites rpaths
  and pulls in stray non-system shared deps (dylibbundler on macOS, patchelf on
  Linux).
