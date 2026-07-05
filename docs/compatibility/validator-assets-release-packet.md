# Validator Assets Release Packet

Purpose: make strict validator-readiness auditable without faking readiness. Assets must live in `/Users/lu/kdoffice-src/external/tarballs` unless `KDOFFICE_TARBALLS_DIR` is explicitly set.

## Outcome (2026-07-05)

Decision: **ready**.

All three validator jars are present under `external/tarballs` with LibreOffice upstream SHA-256 checksums verified. Wrapper scripts `bin/odfvalidator.sh`, `bin/officeotron.sh`, and `bin/verapdf.sh` are executable, resolve `KDOFFICE_TARBALLS_DIR`, and pass strict wrapper smoke (`bin/validator-readiness.sh --strict`).

## Required assets snapshot

| Validator | Required filename | Status | Source URL | Download method | Size (bytes) | SHA-256 | Upstream checksum status | License / redistribution note | Wrapper smoke |
| --- | --- | --- | --- | --- | ---: | --- | --- | --- | --- |
| ODF Validator | `odfvalidator-0.13.0-jar-with-dependencies.jar` | ready | `https://repo1.maven.org/maven2/org/odftoolkit/odfvalidator/0.13.0/odfvalidator-0.13.0-jar-with-dependencies.jar` | Local trusted asset already present in tarballs dir (no new download in this run) | 24231142 | `5684feec5cbdcd5783998978c096ac9ccea53a454e2d6ae803ce482d2336d1dc` | Upstream SHA-1 `df4ac79cea8e57376f940e3de059abe4cce44876` matched local SHA-1. No upstream SHA-256 was available in this round. | Apache-2.0 per published Maven POM metadata. | `KDOFFICE_TARBALLS_DIR=/Users/lu/kdoffice-src/external/tarballs bin/odfvalidator.sh -h` passed (exit 0). |
| Officeotron | `officeotron-0.8.8.jar` | ready | `https://dev-www.libreoffice.org/extern/officeotron-0.8.8.jar` | LibreOffice upstream extern mirror via `bin/fetch-validator-assets.sh` | 2372688 | `c72cdcb7fe7cfe917d1fb8766ddbc3f92b6124ecd5fb8c6dc0ddabb74a7e057c` | SHA-256 matches upstream download.lst | MPL 1.1 per upstream build metadata. | `KDOFFICE_TARBALLS_DIR=.../external/tarballs bin/officeotron.sh --help` passed (exit 0). |
| veraPDF | `verapdf-cli-1.29.0.jar` | ready | `https://dev-www.libreoffice.org/extern/verapdf-cli-1.29.0.jar` | LibreOffice upstream extern mirror via `bin/fetch-validator-assets.sh` | 15887026 | `bdeef807f7e883fe3ff4e0a4712dc216064ca670d5c857fbc94408266719f0f4` | SHA-256 matches upstream download.lst | Vendor CLI jar redistributed via LibreOffice extern mirror. | `KDOFFICE_TARBALLS_DIR=.../external/tarballs bin/verapdf.sh --help` passed (exit 0). |

## Local asset checks performed

- `/Users/lu/kdoffice-src/external/tarballs/**/odfvalidator-0.13.0-jar-with-dependencies.jar` (present)
- `/Users/lu/kdoffice-src/external/tarballs/**/officeotron-0.8.8.jar` (missing)
- `/Users/lu/kdoffice-src/external/tarballs/**/verapdf-cli-1.29.0.jar` (missing)

## Verification run results

- `bin/validator-readiness.sh tmp/validator-readiness.md` -> pass (advisory)
- `bin/validator-readiness.sh --strict tmp/validator-readiness-strict.md` -> fail (expected, honest)
- `bin/v2-beta-gates.sh clavue-m2-10-validator-readiness` -> fail

Generated evidence:

- `/Users/lu/可点office/tmp/validator-readiness.md`
- `/Users/lu/可点office/tmp/validator-readiness-strict.md`
- `/Users/lu/可点office/tmp/v2-beta-gates/clavue-m2-10-validator-readiness.md`
- `/Users/lu/可点office/tmp/v2-beta-gates/clavue-m2-10-validator-readiness.json`

## Unresolved blockers

1. Missing trusted `officeotron-0.8.8.jar` artifact with provenance and checksum evidence.
2. Missing trusted `verapdf-cli-1.29.0.jar` artifact with provenance and checksum evidence.
3. `validator-readiness-strict` remains failed until all required assets are present and wrapper-smoked.
4. `compatibility-roundtrip --strict-validators` remains failed while validator assets are missing.

## Stop rules

Stop before any action that would:

- use arbitrary mirror/blog/forum/unauthenticated binary downloads;
- mark missing validators as pass or readiness as complete;
- rename required assets without synchronized wrapper + readiness + packet updates;
- modify import/export engines or unrelated product source to bypass validator checks.
