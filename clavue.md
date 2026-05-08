# clavue.md

This file provides guidance to Clavue (claude.ai/code) when working with code in this repository.

## Build and test commands

- `make build` — default top-level build.
- `make check` — standard check pipeline: `unitcheck`, `slowcheck`, `subsequentcheck`, and on Linux also `uicheck`.
- `make unitcheck`, `make slowcheck`, `make subsequentcheck`, `make uicheck`, `make screenshot` — run specific check categories.
- `make test-install` — assemble a runnable test installation; on this macOS build it produces a runnable app bundle under the test install directory.
- `make debugrun` — build and start the debug run flow.
- `make clean` — remove generated build/install outputs.
- `make distclean` — remove generated configuration plus build outputs.
- `make help` / `make showmodules` — inspect available targets and modules.
- `make clang-format-check` — run LibreOffice's last-commit formatting check when the compiler-plugin/LODE prerequisites are available.

### Partial builds and targeted tests

The top-level generated `Makefile` creates module shortcuts from source modules. Use those rather than inventing custom entry points:

- `make sw.build`, `make sc.build`, `make sd.build`, `make desktop.build`, `make vcl.build`, `make sfx2.build` — build one module.
- `make <module>` is also a generated module shortcut; prefer the explicit `.build` form in automation because it documents intent.
- `make <module>.unitcheck`, `make <module>.slowcheck`, `make <module>.uicheck` — run one module's supported check category.
- `make <module>.clean` — clean one module's outputs.
- `make <module>.allbuild` / `make <module>.allcheck` — run the module through the shared gbuild path.

Single gbuild targets can be invoked directly from the build root when a matching `*Test_*.mk` exists in the source tree:

- `make CppunitTest_sw_core_doc`
- `make CppunitTest_sc_core`
- `make UITest_demo_ui`
- `make PythonTest_dbaccess_python`

`GNUmakefile` forwards old or non-GNU make invocations to GNU Make when needed. Prefer the repository's top-level `make` commands; they already carry the configured source/build directory wiring.

## Repository shape

This checkout is a configured LibreOffice-style build tree for 可圈office, not only a clean source checkout. The top-level `Makefile` is generated and orchestrates high-level targets like `build`, `check`, and module shortcuts through gbuild.

Important layout points:

- Many top-level module directories in this build tree, such as `sw/`, `sc/`, and `desktop/`, contain generated partial-build `Makefile` stubs that delegate into the source tree and shared `solenv/gbuild/partial_build.mk` logic.
- `workdir/` contains generated build outputs and unpacked external tarballs.
- `instdir/` contains install outputs; `instdir/可圈office.app` is the built macOS app bundle.
- `autogen.lastrun` records the active configuration used to regenerate this build tree.
- `libreoffice-core` and several top-level paths may be symlinks into the local source checkout; do not assume generated files are authoritative source files.

## High-level architecture

LibreOffice is organized as many gbuild modules. Useful big-picture groupings:

- `sal` — system abstraction layer.
- `tools` — basic internal utility types such as geometry and color primitives.
- `vcl` — Visual Class Library: widgets, windowing, platform backends, event loop, rendering, printing/PDF infrastructure.
- `framework` — UNO framework for toolbars, menus, status bars, and document chrome described by `/uiconfig/` resources.
- `sfx2` — legacy application framework used by Writer/Calc/Draw/Impress for document model/view/controller infrastructure, load/save paths, dispatch slots, and the Start Center controller.
- `svx` — drawing-model helpers and shared UI/components used heavily by Draw/Impress and other apps.
- `basegfx`, `canvas`, `cppcanvas`, `drawinglayer` — graphics primitives, canvas abstraction, metafile handling, and rendering decomposition.
- `desktop` — application bootstrap and main `soffice` binary; also owns splash/startup-related packaging paths.
- `sw`, `sc`, `sd` — Writer, Calc, and Draw/Impress application modules.
- `filter` — filter registration and simple format filters; filter type definitions live under `filter/source/config/fragments/types/` and filter definitions under `filter/source/config/fragments/filters/`.
- `oox` — OOXML import support and shared DrawingML/custom-shape handling; PPTX export is split between `sd/source/filter/eppt` and `oox/source/export`.
- `xmloff` — shared ODF XML import/export paths, including ODP import/export used by Draw/Impress.
- `officecfg` and `configmgr` — schema/default settings and configuration database handling. After changing `officecfg`, run the relevant module build and then `make postprocess`.
- `solenv`, `config_*`, `bin`, `RepositoryModule_host.mk` — shared build/configuration glue and module registration.

UI resources generally live under `*/uiconfig/ui/*.ui`; controller code is usually in the owning module's `source/` tree. For example, the Start Center is in `sfx2/source/dialog/backingwindow.cxx`, while the main binary/bootstrap path is in `desktop`.

### Application module landmarks

- Writer (`sw`) keeps broad module headers in `sw/inc`, tests in `sw/qa`, UI definitions in `sw/uiconfig`, core document/layout code under `sw/source/core`, filters under `sw/source/filter`, and loaded UI code under `sw/source/uibase` / `sw/source/ui`.
- Calc (`sc`) centers on spreadsheet document behavior; dbgutil builds expose Calc-specific dump shortcuts documented in `sc/README.md`.
- Draw/Impress (`sd`) owns presentation/drawing UI and non-shared filters. Impress is layered on Draw; the slideshow engine lives in `slideshow`, PPT import/export code is split between `sd`, `svx`, and `oox`, and ODP XML paths are mostly in `xmloff/source/draw`.
- VCL (`vcl`) is the widget/windowing/rendering abstraction. Platform backends live under `vcl/osx`, `vcl/quartz`, `vcl/win`, `vcl/unx`, etc.; backend entry points implement `CreateSalInstance`, and the `SalInstance` vtable is the main platform gateway.
- SFX2 (`sfx2`) is the legacy document/view/controller and dispatch-slot framework used by Writer/Calc/Draw/Impress. Slot IDs are generated from module `sdi/` files by `svidl`; document load/save corner cases concentrate around `SfxMedium` in `sfx2/source/doc/docfile.cxx`.

## Product-specific context

This tree is configured as a macOS 可圈office build with custom branding. Current notable `autogen.lastrun` options include:

- `--with-distro=LibreOfficeMacOSX`
- `--with-branding=/Users/lu/可点office/.worktrees/libreoffice-core-premium-business-calm-redesign/downstream-branding`
- `--with-product-name=可圈office`
- `--enable-release-build`
- `--enable-macosx-code-signing`
- `--enable-bogus-pkg-config`
- `--without-java`
- `--disable-report-builder`
- `--disable-scripting-beanshell`
- `--disable-scripting-javascript`
- `--disable-ext-nlpsolver`
- `--disable-odk`
- `--disable-online-update`

The product/design direction documented under `docs/superpowers/` is a "premium business calm" redesign: restrained business UI, quieter chrome, stronger brand surfaces, and no disruptive changes to core office-suite workflows.

No Cursor rules or Copilot instruction file were found in the top-level repository or the active source worktree during initialization.
