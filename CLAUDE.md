# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository nature

This is a **configured LibreOffice-style build tree** for 可圈office (product name) — not a clean source checkout. Two facts that trip up everyone on day one:

- The top-level `Makefile` is generated. It pins `SRCDIR` (the actual source tree, currently `/Users/lu/kdoffice-src`) and `BUILDDIR` (this directory, `/Users/lu/可点office`). Module subdirs like `sw/`, `sc/`, `vcl/`, `desktop/` contain only a one-line stub that delegates to `$(SRCDIR)/<module>/` via `solenv/gbuild/partial_build.mk`. **Edit source under `SRCDIR`, not the stubs here.** Read `sw/Makefile` to confirm the pattern.
- The repo dir name is `可点office`; the configured product name is `可圈office` (different character). The macOS app bundle lands at `instdir/可圈office.app/`. Don't "fix" the discrepancy — it's intentional.

`autogen.lastrun` records the active configure flags. Re-running `./autogen.sh` from `SRCDIR` regenerates this build tree; `GNUmakefile` forwards non-GNU `make` invocations to GNU make.

## Build and test commands

Use `make` locally; CI uses `gmake` (Homebrew GNU make on macOS-14 runners). Both work.

- `make build` — default top-level build.
- `make check` — standard pipeline: `unitcheck`, `slowcheck`, `subsequentcheck`, plus `uicheck` on Linux.
- `make unitcheck` / `slowcheck` / `subsequentcheck` / `uicheck` / `screenshot` — targeted check categories.
- `make test-install` — assemble runnable test installation; on this macOS build it produces the app bundle.
- `make debugrun` — build and start the debug run flow.
- `make clean` / `make distclean` — outputs only / outputs + generated config.
- `make help` / `make showmodules` — inspect available targets.
- `make clang-format-check` — last-commit format check (requires LibreOffice compiler-plugin/LODE prereqs).

### Single-module and single-test work

Always prefer the smallest viable target. The generated `Makefile` exposes module shortcuts; don't invent custom build entry points.

- `make sw` / `make sc` / `make sd` / `make desktop` / `make vcl` / `make sfx2` — build one module (alias for `<module>.build`).
- `make <module>.build` / `<module>.clean` / `<module>.unitcheck` / `<module>.slowcheck` / `<module>.uicheck` — per-module operations.
- `make <module>.allbuild` / `<module>.allcheck` — run module through the shared gbuild path.

For a **single gbuild test target**, name the `*Test_*.mk` directly:

- `make CppunitTest_sw_core_doc`
- `make CppunitTest_sc_core`
- `make UITest_demo_ui`
- `make PythonTest_dbaccess_python`

After changing `officecfg/`, run the affected module build then `make postprocess`.

## Architecture (big-picture only — read source for detail)

LibreOffice is a stack of gbuild modules. The layers that matter for navigating unfamiliar code:

- **Foundation:** `sal` (system abstraction), `tools` (geometry/color primitives), `comphelper`, `cppu`/`cppuhelper` (UNO infrastructure).
- **Graphics & UI toolkit:** `vcl` (widgets, windowing, platform backends, event loop, rendering, PDF). Platform backends live in `vcl/osx`, `vcl/quartz`, `vcl/win`, `vcl/unx`; entry points implement `CreateSalInstance`, and the `SalInstance` vtable is the platform gateway.
- **Graphics primitives:** `basegfx`, `canvas`, `cppcanvas`, `drawinglayer`.
- **Application framework:** `framework` (UNO toolbars/menus/status bars driven by `*/uiconfig/`), `sfx2` (legacy MVC, dispatch slots, document load/save — slot IDs are generated from module `sdi/` files via `svidl`; load/save corner cases concentrate in `sfx2/source/doc/docfile.cxx` around `SfxMedium`), `svx` (shared draw-model UI).
- **Apps:** `sw` (Writer), `sc` (Calc), `sd` (Draw/Impress; Impress layered on Draw, slideshow engine in `slideshow/`), `desktop` (bootstrap, `soffice` binary, splash, packaging glue).
- **Filters & formats:** `filter` (registration + simple filters; types in `filter/source/config/fragments/types/`, definitions in `.../filters/`), `oox` (OOXML/DrawingML; PPTX export split between `sd/source/filter/eppt` and `oox/source/export`), `xmloff` (ODF; ODP paths in `xmloff/source/draw`).
- **Configuration:** `officecfg` (schema/defaults), `configmgr` (config DB).
- **Build/packaging glue:** `solenv/`, `config_*`, `instsetoo_native/`, `bin/`, `RepositoryModule_host.mk`.

UI resources are `*/uiconfig/ui/*.ui`; controller code lives in the owning module's `source/`. Example: Start Center UI is in `sfx2/source/dialog/backingwindow.cxx`; main bootstrap is in `desktop/`.

### Per-app landmarks

- **Writer (`sw`):** broad headers in `sw/inc`, tests in `sw/qa`, UI in `sw/uiconfig`, document/layout core in `sw/source/core`, filters in `sw/source/filter`, UI code in `sw/source/uibase` and `sw/source/ui`.
- **Calc (`sc`):** spreadsheet model centric; dbgutil builds expose dump shortcuts (see `sc/README.md`).
- **Draw/Impress (`sd`):** presentation/drawing UI and non-shared filters; PPT import/export is split across `sd`, `svx`, `oox`.

## Product context

This tree is the macOS 可圈office build with custom branding. Active flags (from `autogen.lastrun`):

- `--with-distro=LibreOfficeMacOSX`
- `--with-branding=...downstream-branding` (path varies by worktree)
- `--with-product-name=可圈office`
- `--with-macosx-bundle-identifier=com.kdoffice.app`
- `--enable-release-build`, `--enable-macosx-code-signing`, `--enable-bogus-pkg-config`
- Disabled: `--without-java`, `--disable-{report-builder,scripting-beanshell,scripting-javascript,ext-nlpsolver,odk,online-update}`

The product/design direction documented under `docs/superpowers/` (plans + specs) is a "premium business calm" redesign: restrained business UI, quieter chrome, stronger brand surfaces, **no disruptive changes to core office workflows**.

## CI and release artifacts

Installers are built via `.github/workflows/build-installers.yml` (manual `workflow_dispatch` only):

- Targets: `both` / `macos` / `windows`.
- macOS job (`macos-14`, `gmake -j3`) configures with the same flags as `autogen.lastrun` minus signing, then runs `gmake build` and `gmake PKGFORMAT=dmg ... instsetoo_native`. Artifacts: `kdoffice-macos-installers` (`.dmg`/`.pkg`).
- Windows job produces `.msi` as `kdoffice-windows-installers`.
- Currently produces **unsigned** installers — Developer ID / Authenticode signing is not yet wired in.

When changing installer/packaging behavior, validate `make test-install` locally and the workflow file together.

## Repo-specific helpers in `bin/`

Custom quality/compatibility scripts (not stock LibreOffice) gate releases:

- `compatibility-roundtrip*.sh`, `compatibility-layout-evidence.sh`, `compatibility-manifest-audit.sh` — format roundtrip evidence.
- `quality-baseline.sh`, `v2-beta-gates.sh`, `v2-p0-gates.sh`, `v2-upgrade-dashboard.sh` — release gating.
- `validator-readiness*.sh`, `odfvalidator.sh`, `officeotron.sh`, `verapdf.sh`, `bffvalidator.sh` — external validator wrappers.
- `workbench-{accessibility-check,template-check,template-smoke}.sh` — workbench smokes.
- `gui-smoke-timing.sh`, `clavue-passive-monitor.sh`, `intelligent-*` — operational/observability harnesses.

Prefer running these via the existing top-level make targets when one exists; touch a script directly only for ad-hoc diagnostics.

## Companion docs

- `AGENTS.md` — coding style, testing discipline, commit/PR conventions. Read before opening a PR.
- `README.md` — end-user-facing installer download instructions.
- `clavue.md` — older, longer-form version of this file; if it diverges, this `CLAUDE.md` wins.
- `docs/{architecture,compatibility,accessibility,product,schemas,superpowers}/` — design specs and plans.

No `.cursor/rules/`, `.cursorrules`, or `.github/copilot-instructions.md` are present.
