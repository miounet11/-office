# V2 Source Archive Plan — L125

Generated: 2026-06-04

Purpose: split the dirty SRCDIR `/Users/lu/kdoffice-src` into reviewable, reproducible batches. Do not use `git add .`; stage explicit paths only.

## Current State

- Builddir `/Users/lu/可点office`: `main` is ahead of `origin/main` by 63 commits and carries status/docs/harness drift-cleanup edits.
- Srcdir `/Users/lu/kdoffice-src`: `master` is ahead of `origin/master` by 18 commits and has large uncommitted V2 product-loop changes.
- Contract gate: `bash bin/v2-harness-sweep.sh --with-fixtures` passes H1-H8 and 40/0 fixtures in the builddir.

## Batch A — W1 Provider Runtime

Tracked paths:
- `kqoffice/Library_kqoffice_ai.mk`
- `kqoffice/Module_kqoffice.mk`
- `kqoffice/qa/cppunit/test_provider.cxx`
- `kqoffice/source/ai/provider/Provider.cxx`
- `kqoffice/source/ai/provider/ServiceModePolicy.cxx`
- `kqoffice/source/ai/provider/ServiceModePolicy.hxx`

Untracked paths:
- `kqoffice/source/ai/provider/RuntimePlanStub.cxx`
- `kqoffice/source/ai/provider/RuntimePlanStub.hxx`

Evidence: `workdir/CppunitTest/kqoffice_provider.test.log` ends with `OK (54)`.

## Batch B — W2 Command Palette

Tracked paths:
- `cui/Library_cui.mk`
- `cui/Module_cui.mk`
- `cui/UIConfig_cui.mk`
- `cui/source/dialogs/commandpalette/CommandPalette.cxx`
- `cui/source/dialogs/commandpalette/RecentStore.cxx`
- `cui/source/inc/commandpalette/RecentStore.hxx`
- `cui/uiconfig/ui/commandpalette.ui`
- `include/sfx2/sfxsids.hrc`
- `officecfg/registry/data/org/openoffice/Office/Accelerators.xcu`
- `officecfg/registry/data/org/openoffice/Office/UI/GenericCommands.xcu`
- `sfx2/Library_sfx.mk`
- `sfx2/sdi/appslots.sdi`
- `sfx2/sdi/sfx.sdi`
- `sfx2/source/appl/appserv.cxx`

Untracked paths:
- `cui/CppunitTest_cui_dispatcher.mk`
- `cui/qa/unit/CommandPaletteDispatcherTest.cxx`
- `cui/source/dialogs/commandpalette/CommandPaletteLoader.cxx`
- `cui/source/inc/commandpalette/CommandPaletteLoader.hxx`
- `cui/source/inc/commandpalette/CommandPaletteUi.hxx`
- `cui/source/inc/commandpalette/PinyinHint.hxx`
- `sfx2/inc/dispatch/CommandPaletteDispatcher.hxx`
- `sfx2/source/dispatch/CommandPaletteDispatcher.cxx`

Evidence: commandpalette index/fuzzy/recent/controller logs are OK(8/8/10/7); `cui_dispatcher.test.log` is OK(5).

## Batch C — W3 Writer Apply Runtime

Tracked paths:
- `sw/CppunitTest_sw_uwriter.mk`
- `sw/Library_sw.mk`
- `sw/Module_sw.mk`
- `sw/inc/IntelligentWriterAnalyzer.hxx`
- `sw/inc/docsh.hxx`
- `sw/source/core/doc/IntelligentWriterAnalyzer.cxx`
- `sw/source/uibase/app/docst.cxx`

Untracked paths:
- `sw/CppunitTest_sw_apply_engine.mk`
- `sw/inc/IntelligentWriterApplyEngine.hxx`
- `sw/qa/core/test_apply_engine.cxx`
- `sw/qa/core/test_apply_engine_doc.cxx`
- `sw/source/core/doc/IntelligentWriterApplyEngine.cxx`
- `sw/source/core/inc/UndoApplyPatch.hxx`
- `sw/source/core/undo/UndoApplyPatch.cxx`

Evidence: `sw_apply_engine.test.log` ends with `OK (35)`; sw_uwriter evidence was recorded at L122-L123.

## Batch D — W4 Select-to-act + DiffReview

Tracked paths:
- `sc/Library_sc.mk`
- `sc/Module_sc.mk`
- `sc/UIConfig_scalc.mk`
- `sc/source/ui/view/tabview3.cxx`
- `sc/uiconfig/scalc/menubar/menubar.xml`
- `sd/Library_sd.mk`
- `sd/Module_sd.mk`
- `sd/UIConfig_simpress.mk`
- `sd/source/ui/view/drviews1.cxx`
- `sd/uiconfig/sdraw/menubar/menubar.xml`
- `sd/uiconfig/simpress/menubar/menubar.xml`
- `svx/Library_svx.mk`
- `svx/UIConfig_svx.mk`
- `sw/UIConfig_swriter.mk`
- `sw/source/uibase/wrtsh/wrtsh3.cxx`
- `sw/uiconfig/sglobal/menubar/menubar.xml`
- `sw/uiconfig/swriter/menubar/menubar.xml`

Untracked paths:
- `include/svx/sidebar/DiffReviewPanel.hxx`
- `sc/CppunitTest_sc_inline_actions.mk`
- `sc/qa/cppunit/`
- `sc/source/ui/inline-actions/`
- `sc/uiconfig/scalc/ui/cell-range-popover.ui`
- `sd/CppunitTest_sd_inline_actions.mk`
- `sd/qa/cppunit/`
- `sd/source/ui/inline-actions/`
- `sd/uiconfig/simpress/ui/slide-element-popover.ui`
- `svx/source/sidebar/diff-review/`
- `svx/uiconfig/ui/diff-review-panel.ui`
- `sw/CppunitTest_sw_inline_actions.mk`
- `sw/UITest_sw_select_to_act.mk`
- `sw/qa/cppunit/`
- `sw/qa/uitest/selectToAct/`
- `sw/source/uibase/ai/`
- `sw/source/uibase/inline-actions/`
- `sw/uiconfig/swriter/ui/select-to-act-popover.ui`

Evidence: `sw_inline_actions OK(9)`, `sc_inline_actions OK(6)`, `sd_inline_actions OK(5)`. UITest exits 0 but still records svp skips.

## Batch E — W5 Cowork

Tracked paths:
- `Library_merged.mk`
- `officecfg/registry/data/org/openoffice/Office/UI/Sidebar.xcu`

Untracked paths:
- `cui/source/dialogs/cowork/`
- `cui/source/inc/cowork/`
- `cui/uiconfig/ui/cowork-dialog.ui`
- `kqoffice/CppunitTest_kqoffice_cowork.mk`
- `kqoffice/qa/cppunit/test_cowork.cxx`
- `kqoffice/source/ai/cowork/`
- `sfx2/inc/dispatch/CoworkPanelDispatcher.hxx`
- `sfx2/source/dispatch/CoworkPanelDispatcher.cxx`

Evidence: `kqoffice_cowork.test.log` ends with `OK (10)`.

## Batch F — Build Infra / Local Config / Submodules

Tracked paths:
- `solenv/gbuild/ExternalProject.mk`
- `solenv/gbuild/UnpackedTarball.mk`
- `solenv/sanitizers/ui/cui.suppr`

Dirty submodules:
- `dictionaries`
- `helpcontent2`

Decision paths:
- Keep build infra separate from V2 feature batches.
- Inspect dirty submodules before staging; do not blindly add submodule pointers.
- `sysui/desktop/macosx/LaunchConstraint.plist` in builddir remains D8 release-policy work, not part of SRCDIR feature batching.

## Verification Before Each Batch

Run the smallest relevant target first, then the contract gate:

```bash
bash bin/v2-harness-sweep.sh --with-fixtures
```

For SRCDIR C++ batches, use the wrapper in this non-ASCII builddir:

```bash
make PKG_CONFIG=/tmp/kqoffice-pkgconf-utf8 <CppunitTest_target>
```
