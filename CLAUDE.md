# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and test commands

- `make build` — default top-level build.
- `make check` — runs the standard check pipeline (`unitcheck`, `slowcheck`, `subsequentcheck`, and on Linux also `uicheck`).
- `make unitcheck`, `make slowcheck`, `make subsequentcheck`, `make uicheck`, `make screenshot` — run specific test/check targets.
- `make test-install` — assemble a runnable test installation.
- `make debugrun` — build and start the debug run flow.
- `make clean` — remove build/install outputs.
- `make distclean` — remove generated configuration and build outputs.
- `make help` / `make showmodules` — inspect available build targets and modules.

### Partial builds and single-module work

The top-level `Makefile` generates module shortcuts. Use them instead of inventing custom build entry points:

- `make sw` / `make sc` / `make sd` / `make desktop` / `make vcl` / `make sfx2` — build a single module.
- `make <module>.build` — build only that module.
- `make <module>.unitcheck` / `make <module>.slowcheck` / `make <module>.uicheck` — run one test target for that module when supported.
- `make <module>.clean` — clean outputs for one module.
- `make <module>.allbuild` / `make <module>.allcheck` — run the module through the shared gbuild path.

Examples:

- `make sw.build`
- `make sc.unitcheck`
- `make desktop.allbuild`

## Repository shape

This repository is a configured LibreOffice-style build tree. The top-level `Makefile` is the main orchestration layer: it expands high-level targets like `build`, `check`, and module-specific shortcuts into gbuild targets.

Key subsystem groupings:

- `sw`, `sc`, `sd` — the document applications (Writer, Calc, Impress/Draw).
- `desktop` — application bootstrap, packaging, and install/test-install flows.
- `sfx2` — shared application framework and shell/UI infrastructure used across the office apps.
- `vcl` — platform abstraction, windowing, and rendering toolkit.
- `solenv`, `config_*`, `instsetoo_native`, `bin` — shared build/configuration, packaging, and helper tooling.
- `test` and `uitest` — dedicated test areas, alongside the top-level `unitcheck` / `slowcheck` / `uicheck` entry points.

Module-local `Makefile`s in directories such as `sw/`, `sc/`, `sd/`, `desktop/`, `vcl/`, and `sfx2/` are generated partial-build stubs. They delegate back into the shared build logic instead of defining standalone workflows.

## Current build context

The current configuration was generated from `autogen.lastrun` with a macOS distro profile and custom branding. Notable active options include:

- `--with-distro=LibreOfficeMacOSX`
- `--with-branding=/Users/lu/kdoffice/libreoffice-core/downstream-branding`
- `--with-product-name=可圈office`
- `--without-java`
- `--disable-report-builder`
- `--disable-scripting-beanshell`
- `--disable-scripting-javascript`
- `--disable-ext-nlpsolver`
- `--disable-odk`
- `--disable-online-update`
- `--enable-release-build`

The generated files in this checkout still reference `libreoffice-core` as `SRCDIR`. When adding or changing commands, prefer the existing top-level make targets and generated module shortcuts rather than assuming a different source-tree layout.