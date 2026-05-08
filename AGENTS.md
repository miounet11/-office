# Repository Guidelines

## Project Structure & Module Organization

This is a configured LibreOffice-style build tree for 可圈office. The top-level `Makefile` and `GNUmakefile` orchestrate builds through gbuild and generated module shortcuts. Core modules include `sw/` for Writer, `sc/` for Calc, `sd/` for Draw/Impress, `desktop/` for bootstrap and packaging, `vcl/` for UI/rendering, and `sfx2/` for shared document framework code. Build and packaging glue lives in `solenv/`, `config_*`, `instsetoo_native/`, and `bin/`. Tests are primarily under module `qa/` trees plus top-level `test/`, `uitest/`, `smoketest/`, and `qadevOOo/`. Treat `workdir/`, `instdir/`, `test-install/`, `tmp/`, and generated `config_*` files as build outputs, not source.

## Build, Test, and Development Commands

- `gmake build` builds the configured product.
- `gmake check` runs the standard check pipeline: `unitcheck`, `slowcheck`, `subsequentcheck`, and Linux `uicheck` when applicable.
- `gmake unitcheck`, `gmake slowcheck`, `gmake subsequentcheck`, `gmake uicheck`, and `gmake screenshot` run targeted check categories.
- `gmake test-install` assembles a runnable test installation, including the macOS app bundle in this build.
- `gmake <module>.build`, for example `gmake sw.build` or `gmake vcl.build`, builds a single module.
- `gmake <module>.unitcheck` runs supported module-level tests.
- `gmake help` and `gmake showmodules` inspect available targets.

Use the existing top-level targets instead of adding ad hoc build scripts.

## Coding Style & Naming Conventions

Follow LibreOffice conventions already present in the touched module. Makefiles use tabs for recipes. C++ source generally uses descriptive `CamelCase` types, local-variable style from nearby code, and module-specific prefixes. Keep UI resources in `*/uiconfig/ui/*.ui` and controller logic in the owning module’s `source/` tree. Avoid editing generated stubs or build outputs unless regenerating configuration intentionally.

## Testing Guidelines

Prefer the smallest relevant target before full validation: run `gmake sw.unitcheck` for Writer changes, `gmake sc.unitcheck` for Calc changes, or the corresponding module check target. For broad changes, run `gmake check`. Installer/package changes should also validate `gmake test-install` and `.github/workflows/build-installers.yml`.

## Commit & Pull Request Guidelines

Recent history uses short imperative commit subjects, sometimes with Conventional Commit prefixes such as `chore:`. Keep subjects concise, for example `Add installer build workflow` or `chore: ignore local worktrees`. Pull requests should describe the affected module, list verification commands, link related issues, and include screenshots or installer artifact notes for UI or packaging changes.

## Security & Configuration Tips

Do not commit signing identities, certificates, local paths with secrets, or generated logs. The current local configuration is recorded in `autogen.lastrun`; update it only when intentionally changing build configuration.
