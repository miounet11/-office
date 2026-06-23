# Source Hygiene Release Packet

Purpose: make the beta source-hygiene blocker actionable without deleting generated outputs, resetting user work, or weakening `source-hygiene-strict`.

## Operator sequence

1. Generate the advisory report:
   - `bin/source-hygiene-report.sh tmp/source-hygiene-report.md`
2. Read `tmp/source-hygiene-report.md` from the top down.
3. Resolve buckets in this order:
   - source review/stage
   - repo backup human-decision items
   - odd/local human-decision items
   - unresolved human-decision items
   - config/autoconf artifacts
   - install/test/release artifacts
   - generated/local clean-or-ignore
4. Re-run strict mode only after every bucket has an explicit action:
   - `bin/source-hygiene-report.sh --strict tmp/source-hygiene-report-strict.md`

Strict mode must fail while any working-tree entry remains. A strict failure is correct until the tree is intentionally clean.

## Bucket inspection commands

Use non-destructive inspection only. Do not use `git reset`, `git checkout --`, `git clean`, `rm -rf`, or manual deletion as part of this packet.

### Source review/stage

Intentional source/control edits that may belong in a commit or release branch.

Safe inspection:

```sh
git status --short -- .gitignore AUTORESEARCH_EXECUTION_TODOLIST.md docs bin
git diff -- .gitignore AUTORESEARCH_EXECUTION_TODOLIST.md docs bin
```

Stage only after the operator confirms each path is intentional release source/control work.

### Unresolved human-decision items

Untracked files, backup/reject/original files, and sensitive boundary files such as `.gitignore`, `autogen.lastrun`, and `config_host.mk` require explicit approval before staging, cleanup, or ignore changes.

Safe inspection:

```sh
git status --short
git diff -- .gitignore autogen.lastrun autogen.lastrun.bak config_host.mk
```

Stop if a file looks user-authored, credentials-like, externally supplied, or unrelated to the active beta round.

### Repo backup human-decision items

Local Git backup directories such as `.git.bak-*/` are not product source, but they may contain branch refs, reflogs, or recovery data. They require an explicit operator decision before archive, ignore, or cleanup.

Safe inspection:

```sh
git status --short -- '.git.bak-*'
find . -maxdepth 1 -type d -name '.git.bak-*' -print
```

Do not delete or move these directories inside this packet.

### Odd/local human-decision items

Odd local paths include top-level diagnostic files and configuration warning outputs that are not generated/build outputs by default.

Safe inspection:

```sh
git status --short -- ':(literal):-' config.warn config_host_lang.mk
git diff -- config.warn config_host_lang.mk
```

Stop before staging, ignoring, or cleaning these files unless the operator confirms they belong to the active release packet.

### Config/autoconf artifacts

Autoconf and configuration outputs include `autogen.lastrun`, `autogen.lastrun.bak`, `config.log`, `config.status`, `config_host.mk`, `autom4te.cache/`, and `config_host/`.

Safe inspection:

```sh
git status --short -- autogen.lastrun autogen.lastrun.bak config.log config.status config_host.mk autom4te.cache config_host
git diff -- autogen.lastrun autogen.lastrun.bak config_host.mk config_host
```

Do not regenerate or delete these files unless the operator decides the active configuration should be replaced or cleaned.

### Install/test/release artifacts

Install and test artifacts include `instdir/` and `test-install/` outputs. They are evidence/build products, not product source.

Safe inspection:

```sh
git status --short -- instdir test-install
```

Do not inspect app-bundle binary diffs as source changes. Confirm whether the artifact should be preserved as local evidence or cleaned in a separate approved cleanup step.

### Generated/local clean-or-ignore

Local generated outputs include `.clavue/`, `tmp/`, `workdir/`, and other generated entries that are not config/autoconf or install/test/release artifacts.

Safe inspection:

```sh
git status --short -- .clavue tmp workdir
```

These should be handled after source review is complete, either by approved cleanup or by local ignore policy.

## Stop rules

Stop and ask the release operator before any action that would:

- delete, reset, or overwrite files;
- stage untracked source/control files;
- change `.gitignore`, `autogen.lastrun`, `config_host.mk`, or build configuration;
- remove generated evidence under `tmp/` that may be referenced by a gate report;
- claim beta readiness while strict source hygiene, validator readiness, or live Workbench accessibility are still failing.

## Beta gate interpretation

`source-hygiene-strict` failing means the tree still has entries that need review, cleanup, or ignore decisions. It is not a vague dirty-tree complaint. Use the report's release-packet buckets to decide the next safe operator action.
