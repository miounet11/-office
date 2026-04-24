# Office Upgrade Rounds

This repository is being advanced using an `autoresearch`-style loop: establish the editable surface, make a narrowly scoped product change, verify it, then queue the next round based on visible gaps instead of writing a vague long-term wishlist.

## Baseline

- The checked-in tree under `/Users/lu/可点office` is a configured LibreOffice wrapper, not the full source tree.
- The real source tree is `/Users/lu/kdoffice-src`.
- The wrapper previously pointed at a missing `libreoffice-core` path, which blocked source-level work.
- Existing custom work was mostly branding and packaging, not user workflow improvement.

## Round 1

Goal: make the product feel closer to a China-market office suite on first launch, especially for document, spreadsheet, and presentation creation.

Changes:

- Restored `/Users/lu/可点office/libreoffice-core` as a symlink to `/Users/lu/kdoffice-src`.
- Simplified the Start Center around Chinese labels and core creation flows.
- Defaulted first-run users to the template view when there are no recent files.
- Hid secondary Start Center actions that distract from the core office workflows.
- Switched Impress to template-first behavior by default for new users.
- Replaced upstream-facing factory names with task-oriented user names for the primary document types.

## What Round 1 Does Not Solve

- Deep Word/Excel/PPT compatibility gaps.
- China-specific built-in templates for resumes, notices, reports, teaching decks, and business presentations.
- Contextual Chinese typography defaults.
- AI writing, AI tables, or AI-assisted PPT generation.
- Packaging polish beyond the currently customized branding surface.

## Next Rounds

Round 2:

- Add China-oriented built-in templates for Writer, Calc, and Impress.
- Review default fonts, page sizes, and typography choices for Chinese office usage.
- Audit the Start Center template categories and prioritize the templates users actually need.

## Round 2

Goal: make the template-first entry path immediately useful for common China-office writing tasks instead of dropping users into mostly upstream generic templates.

Changes:

- Added bundled Chinese Writer templates for notices, meeting minutes, work reports, and project plans in the real source tree at `/Users/lu/kdoffice-src`.
- Registered those templates in the shared template package so they ship with the suite instead of living as loose source-only assets.
- Localized template categories, template-manager actions, welcome copy, and built-in template names to reduce English leakage in the Start Center and template browser.
- Kept the new Writer templates minimal and editable so they act as practical starting documents instead of fixed demos.

What Round 2 Does Not Solve:

- Calc and Impress still need China-oriented default templates beyond the existing upstream bundles.
- Chinese typography defaults still rely on the upstream base template and installed fonts.
- AI-assisted drafting and PPT generation are still future rounds, not part of the core document workflow yet.

## Round 3

Goal: turn the template-first Impress flow into something closer to a practical China-office PPT starting point instead of a gallery of generic upstream theme names.

Changes:

- Added three China-task presentation templates in the real source tree by repackaging stable upstream master decks as Chinese-first starting points: business pitch, teaching courseware, and project report.
- Registered those new `.otp` templates and their thumbnails in the presentation packaging rules so they ship with the suite.
- Localized the presentation template titles directly in `meta.xml`, which avoids adding more hard-coded template string IDs while still surfacing Chinese names in the template picker.

What Round 3 Does Not Solve:

- The deck structures are still theme-based starters, not AI-generated slide outlines or domain-specific presentation wizards.
- DOCX/XLSX/PPTX compatibility work is still pending.
- Calc still lacks China-oriented built-in spreadsheet templates for budgets, schedules, and tracking sheets.

## Round 4

Goal: close the biggest remaining template gap in the core office workflow by giving Calc a dedicated spreadsheet category and Chinese task-oriented starter files.

Changes:

- Added a dedicated spreadsheet template category so Calc templates are no longer hidden under generic office-document buckets.
- Added three Chinese spreadsheet templates in the real source tree: budget overview, sales tracking, and project scheduling.
- Reused stable upstream wizard spreadsheet structures, but localized the visible sheet content, sheet names, metadata, and category surface for China-office tasks.
- Normalized the copied spreadsheet templates away from broken thumbnail manifest entries and switched their Asian font hints toward Chinese CJK fonts.

What Round 4 Does Not Solve:

- These Calc templates are compact starter dashboards, not full multi-sheet accounting or ERP-style workbooks.
- DOCX/XLSX/PPTX compatibility work is still pending.
- AI-assisted writing and PPT generation are still future rounds, not yet part of the product.

## Round 5

Goal: remove the remaining English leakage around template operations and quick entry points so the newly added Chinese-first templates do not sit inside an obviously upstream interaction shell.

Changes:

- Localized the remaining template-manager actions, confirmations, and error messages that still appeared in English.
- Localized the template-update prompt so documents created from templates no longer bounce users back into English when the base template changes.
- Localized quickstart and entry labels such as template manager, recent documents, and start center naming.

What Round 5 Does Not Solve:

- This is still UI copy cleanup, not deep compatibility engineering.
- DOCX/XLSX/PPTX import-export work is still pending.
- AI-assisted writing and PPT generation are still future rounds, not yet part of the product.

## Round 6

Goal: improve the Office-format collaboration path so China-market users are not pushed through an ODF-first warning and save-order experience when they mostly exchange DOCX, XLSX, and PPTX files.

Changes:

- Localized the save/open/export strings around the main save path, hidden-content warning, and signing prompts so this workflow no longer leaks English in the core document loop.
- Reframed the alien-format warning from an upstream “non-standard file format” message into a compatibility reminder with clearer action labels for keeping the current Office format or switching to the default internal format.
- Tightened the warning dialog code so the fallback option shows a concrete default extension like `ODT`, `ODS`, or `ODP` instead of the generic label `ODF`.
- Reordered the Writer, Calc, and Impress filter lists so DOCX, XLSX, and PPTX family formats appear before the internal ODF formats in the main visible filter ordering.
- Added Chinese labels for the primary Writer, Calc, and Impress filter classes plus the core OOXML and ODF save targets, reducing English leakage in file-type selection.

What Round 6 Does Not Solve:

- This is a collaboration-UX pass, not a new import-export engine; deep layout, formula, macro, and animation fidelity limits still depend on the upstream compatibility code.
- The suite still defaults internally to ODF behavior rather than globally changing every new document to save as Office formats.
- Chinese typography defaults and AI-assisted writing or PPT generation are still outside this round.

## Round 7

Goal: make blank Simplified Chinese documents and UI surfaces feel more coherent with the bundled China-oriented templates by tightening the default Chinese font priority instead of relying on older Song/Hei fallbacks too early.

Changes:

- Reordered the `zh-cn` and `zh-sg` locale font stacks in `VCL.xcu` so the Simplified Chinese defaults prefer the Noto CJK SC families and then the aligned Source Han families before older legacy fallbacks.
- Moved the fixed-width Chinese defaults toward `Noto Sans Mono CJK SC` first, so editor-like surfaces and monospace fallbacks are more consistent with the broader CJK stack.
- Shifted the Simplified Chinese UI sans stack to prefer native mainstream UI fonts such as Microsoft YaHei and PingFang SC before falling back through the bundled/open-source CJK families.
- Kept the change inside locale font-priority configuration only, which means systems that do not have the preferred fonts installed still fall through to the existing downstream-compatible Chinese fonts.

What Round 7 Does Not Solve:

- This does not add bundled fonts or guarantee identical rendering across Windows, macOS, and Linux; it only improves the order in which existing installed fonts are chosen.
- Writer default-style sizing and deeper document-style typography rules are still largely upstream-driven unless overridden by templates.
- AI-assisted writing and PPT generation are still future work.

## Next Rounds

Round 8:

- Introduce AI-assisted writing and PPT generation on top of a stable core office workflow.
- Keep AI additive, not on the critical path for document open/edit/save reliability.

## Round 8

Goal: turn the existing Writer outline export into a visible Chinese-first PPT drafting workflow instead of promising an in-tree AI generator that does not actually exist in this codebase.

Changes:

- Reframed Writer’s legacy outline-export command as a task-oriented PPT action, with clearer English and Simplified Chinese labels and tooltip copy for generating a presentation draft from heading structure.
- Promoted the main PPT draft action into the Writer File menu family plus the compact notebookbar File menu so it is discoverable without digging through the legacy Send submenu.
- Added a bundled Chinese Writer template named `PPT 提纲初稿`, giving users a heading-based deck-outline starter that maps cleanly onto the existing Writer-to-Impress generation pipeline.
- Kept the implementation grounded in the real in-tree Writer to Impress outline workflow, avoiding fake cloud or LLM integration paths that are not present in the repository.

What Round 8 Does Not Solve:

- This is still structured outline-to-slide generation, not a model that automatically writes slide content, notes, charts, or page design.
- Generated decks still need user editing for theme choice, visual polish, and detailed copy.
- Deep PPTX fidelity work, advanced animation support, and any real AI assistant stack remain future engineering rather than shipped capability in this round.

## Next Rounds

Round 9:

- Continue tightening Chinese-first collaboration and review flows where the codebase already has real product hooks.
- Reassess whether the next highest-value work is Office-format fidelity, document-review productivity, or deeper template and onboarding polish.

## Round 9

Goal: remove the leftover mixed branding surface so the product stops presenting a half-renamed identity and instead consistently ships as `可圈office`.

Changes:

- Normalized the product name across source packaging metadata, Start Center branding, template creator metadata, and the checked-in build/config stubs so the old `可圈Office`, misspelled `可圈offie`, and historical `KDOffice` tokens no longer drive visible product output.
- Updated desktop and appstream metadata around Writer, Calc, Impress, Draw, Base, and KDE integration so package stores and launcher metadata identify the suite as `可圈office` instead of mixing in LibreOffice-branded descriptions and contacts.
- Disabled the Start Center extension, donation, and volunteer web-entry points when no downstream `可圈office` URL is configured, which avoids routing users from a renamed product into upstream LibreOffice-branded web surfaces.
- Kept low-level upstream technical identifiers such as `libreoffice-*` desktop IDs and `org.openoffice.*` configuration namespaces unchanged, because those are implementation plumbing rather than end-user branding and changing them would create disproportionate packaging risk.

What Round 9 Does Not Solve:

- This round does not redesign the logo artwork itself; it normalizes the naming and metadata surfaces around the existing downstream branding assets.
- The current build tree was updated for consistency, but a full rebuild and packaging pass is still needed to confirm there are no regenerated artifacts that reintroduce old branding strings.
- No official `可圈office` website, support portal, or update service was added in this round, so some non-core upstream service URLs remain until a real brand-owned destination exists.

## Next Rounds

Round 10:

- Rebuild and audit the packaged app end-to-end for remaining brand leakage in About, Finder metadata, DMG/package names, and first-run surfaces.
- Then return to core product work on compatibility, review, and AI-assisted office workflows.

## Round 10

Goal: close the remaining obvious English leakage in Chinese user-facing metadata so the launcher, app-store surface, and New/Wizard entry paths match the rest of the Chinese-first product direction.

Changes:

- Added Simplified Chinese factory names in `Setup.xcu` for the remaining visible document families and advanced Base-related factories, including Draw, Math, Writer/Web, database design views, chart, bibliography, and report-builder surfaces.
- Localized the remaining `File -> New` and wizard menu titles in `Common.xcu`, including drawing, formula, database, web document, XML form document, labels, business cards, master document, templates, letter, fax, agenda, document converter, and address data source.
- Added `zh_CN` launcher metadata across the main desktop entries for Writer, Calc, Impress, Draw, Base, Math, and the Start Center, covering app names, generic names, comments, keywords, quick actions, and start-center action labels.
- Added `zh-CN` appstream names, summaries, and descriptions for Writer, Calc, Impress, Draw, Base, and KDE integration so Linux software centers no longer present the customized suite as English-only metadata.

What Round 10 Does Not Solve:

- This still does not prove the full packaged app is Chinese-clean end to end, because no full rebuild or first-run manual UI audit has been completed after the latest source changes.
- Deeper advanced surfaces still inherit large upstream string catalogs; this round targets the most visible metadata and entry-path leakage, not every possible English string in the full office codebase.
- Office-format compatibility, review productivity, and any real AI-assisted writing or PPT-generation stack are still separate engineering tracks.

## Next Rounds

Round 11:

- Rebuild the product and audit the actual packaged app for remaining Chinese or branding regressions across About, Finder metadata, installer/package names, first-run dialogs, and software-center output.
- Then resume core product work on compatibility, review flows, and deeper presentation-generation capabilities.

## Round 11

Goal: turn the brand refresh into a packaged, user-visible asset system instead of leaving `可圈office` with one updated launcher icon but many upstream module and document icons plus inconsistent Simplified Chinese font fallback chains.

Changes:

- Fixed the installer product-key packaging issue and the stale generated filelist typo so the packaged app and help payload consistently resolve to `可圈office` instead of mixed or broken bundle names.
- Upgraded the primary app icon, regenerated the macOS launcher iconset, and verified the bundled `main.icns` matches the source installer icon material.
- Added a reusable downstream icon generator and used it to replace the main user-visible icon families across Linux-style hicolor app icons, hicolor document/mimetype icons, and the macOS `generic-*` and `oasis-*` document `icns` resources.
- Tightened Simplified Chinese font defaults in `VCL.xcu` around Mainland/macOS-friendly stacks such as `PingFang SC`, `Microsoft YaHei`, `Noto CJK SC`, and `Source Han`, and fixed the remaining duplicate `zh-sg` fallback block that still contained older spellings and ordering.
- Updated the Simplified Chinese default Writer template so heading and table-heading typography use a more modern sans choice while body text keeps a document-oriented serif baseline.
- Rebuilt the focused `officecfg`, `postprocess`, and `sysui` module outputs and verified the generated registry plus bundled document `icns` resources picked up the new assets.

What Round 11 Does Not Solve:

- This still does not mean every obscure upstream icon asset in the repository has been redrawn; the work covers the main launcher, module, document, and macOS file-icon families that users actually see first.
- A full `gmake build` currently stops in an unrelated Writer UI accessibility check under `sw/uiconfig/swriter/ui`, so final verification used targeted module rebuilds rather than a clean end-to-end green build.
- Legacy upstream strings such as internal framework names, XML public IDs, and low-level `LibreOffice` or `OpenOffice.org` identifiers still exist in technical/runtime internals where changing them blindly would be risky.

## Next Rounds

Round 12:

- Continue the remaining historical-string triage inside the packaged app, separating harmless technical identifiers from user-visible brand leakage.
- Audit first-run dialogs, About surfaces, Finder document metadata, and the highest-frequency Chinese editing workflows in the actual app bundle.
- Then return to product-depth work on Office-format fidelity, review productivity, and stronger PPT drafting/generation flows.

## Round 12

Goal: close the remaining high-visibility icon and typography gaps so `可圈office` looks more deliberate for Chinese users in both packaged templates and macOS document resources.

Changes:

- Updated the new Simplified Chinese presentation templates `Business_Pitch_CN`, `Project_Report_CN`, and `Teaching_Courseware_CN` to use `Noto Sans CJK SC` instead of the generic multi-region `Noto Sans CJK` alias for Asian text, so packaged PPT templates are more explicitly tuned for Simplified Chinese.
- Extended the downstream icon generator to emit macOS `web` and `web-template` iconsets and wired `Package_osxicons.mk` with an explicit `sysui/icns` custom target so the generated `icns` files are built through the normal dependency graph instead of relying on stale incremental outputs.
- Rebuilt the focused `extras` and `sysui` modules and verified the packaged app bundle now contains `generic-web.icns`, `oasis-web.icns`, `generic-web-template.icns`, and `oasis-web-template.icns`.
- Verified the installed `.otp` presentation templates inside the built app bundle resolve to `Noto Sans CJK SC` in `styles.xml`, not the older generic `Noto Sans CJK` face.

What Round 12 Does Not Solve:

- This still does not justify claiming every last upstream icon or historical brand string in the repository is finished; the work continues to focus on the main packaged and user-visible surfaces.
- macOS still does not have a dedicated `text-web` document registration in `Info.plist`, so the new `web` `icns` resources are now packaged and ready, but not newly attached to Finder file-type associations in this round.
- A full end-to-end `gmake build` was not rerun here; verification remained targeted to the affected modules and the produced app bundle.

## Next Rounds

Round 13:

- Audit the actual packaged app for remaining user-visible brand leakage in About, Finder metadata, and first-run flows.
- Decide whether the macOS `text-web` document type should get an explicit Finder registration now that the branded `web` icon resources exist.
- Continue the Chinese-first product work on templates, review productivity, and presentation-generation depth.

## Round 13

Goal: push the macOS rebrand/localization work from source-only edits into the packaged bundle, and separate true remaining product issues from rebuild and metadata-cache noise.

Changes:

- Updated the macOS source-side document-kind names in `Info.plist.in` so Finder-facing `UTTypeDescription` and `CFBundleDocumentTypes` labels now use `可圈office` and `ODF` Chinese names instead of old `OpenOffice.org` and `OpenDocument` wording.
- Updated the macOS Spotlight/Quick Look source mapping in `OOoSpotlightAndQuickLookImporter.m` so the importer code will emit the new Chinese-first kind names after a successful rebuild.
- Localized the packaged Quick Look extension display names to `可圈office 快速预览` and `可圈office 缩略图`, and localized the Spotlight importer display/name surface to `可圈office Spotlight 导入器`.
- Manually synced the built app bundle plist layer under `/Users/lu/kdoffice-build2/instdir/可圈office.app` so the current packaged app no longer exposes old plist-level `Legacy`, `OpenDocument`, `Flat ODF`, `3rd party formats`, or `OOoSpotlightImporter` labels in the user-facing metadata we can patch safely without a rebuild.
- Updated `sysui/desktop/share/documents.ulf` to remove old `OpenOffice.org` and `OpenDocument` document names from the shared desktop resource and added `zh-CN` entries so future desktop integration builds keep the Chinese-first naming.
- Refreshed local LaunchServices and Quick Look registration and verified that the new Chinese descriptions are registered for the current `可圈office.app` bundle, while also removing stale app registrations that could confuse macOS metadata resolution.

What Round 13 Does Not Solve:

- `mdls` still reports `OpenDocument Text` and `OpenDocument Spreadsheet` for real files because the packaged Spotlight importer binary was not rebuilt; `strings` on `OOoSpotlightImporter` confirms it still embeds the old `OpenOffice.org 1.0 ...` and `OpenDocument ...` kind strings.
- A normal rebuild remains blocked by the unrelated `config.status` / `autogen.sh` regression, so the importer executable and any other compiled resources could not be regenerated in this round.
- This round improves the packaged plist layer and source truth, but it still does not justify claiming every user-visible brand string, About dialog, or first-run flow is fully finished across all platforms.

## Next Rounds

Round 14:

- Fix or route around the current macOS build-system regression so the Spotlight importer and other compiled branding surfaces can actually be rebuilt.
- Rebuild the macOS importer binary and verify `mdls` / Finder `Kind` strings switch from `OpenDocument ...` to the new `可圈office` and `ODF` labels on real files.
- Continue the broader Chinese-surface audit for About, start-center, first-run, and high-frequency document workflows.

## Round 14

Goal: turn the earlier macOS metadata edits into real rebuilt binaries instead of stopping at plist-only fixes, and verify which document types now actually emit `可圈office` / `ODF` names at Spotlight-import time.

Changes:

- Recovered the broken `kdoffice-build2` configuration path enough for focused module builds by replacing the corrupted generated `config.status` with a structurally healthy version, retargeting it to `/Users/lu/kdoffice-src` and the current `可圈office` build paths, and then letting `autogen.sh` regenerate the normal build files with `MAKE=/opt/homebrew/bin/gmake`.
- Rebuilt the focused macOS `extensions` module successfully with GNU Make so the packaged `OOoSpotlightImporter`, `QuickLookPreview`, and `QuickLookThumbnail` binaries now come from the current source tree instead of stale outputs.
- Rebuilt the focused macOS `sysui` module successfully so the generated `sysui/desktop/macosx/Info.plist` and packaged app metadata are once again coming from source rather than only from direct bundle patching.
- Fixed a real runtime bug in `extensions/source/macosx/common/OOoSpotlightAndQuickLookImporter.m`: the ODF lookup table used `org.oasis.opendocument.*` keys while macOS passes `org.oasis-open.opendocument.*`, so the customized `ODF ...` names were never used for Spotlight import. After correcting those keys and rebuilding, Spotlight test-import now returns `ODF 电子表格` for `.ods` and `ODF 演示文稿` for valid `.odp` files.

Verification:

- `gmake extensions.build` and `gmake sysui.build` both completed successfully in `/Users/lu/kdoffice-build2` after the build-path repair.
- The packaged app plist surfaces now show the expected Chinese-first names for main document types, Quick Look display names, and the Spotlight importer bundle metadata.
- `mdimport -t -d2` on a real `.ods` file now reports `kMDItemKind = "ODF 电子表格"` from `/Users/lu/kdoffice-build2/instdir/可圈office.app/Contents/Library/Spotlight/OOoSpotlightImporter.mdimporter`.
- `mdimport -t -d2` on a real non-empty `.odp` file now reports `kMDItemKind = "ODF 演示文稿"` from the same rebuilt importer.

What Round 14 Does Not Solve:

- `mdls` still reports older `OpenDocument ...` kind names even for fresh copied samples, so the on-disk Spotlight metadata cache or LaunchServices/Finder fallback is still ahead of the just-fixed importer output.
- `.odt` test-import on this machine is handled by Apple’s `/System/Library/Spotlight/RichText.mdimporter`, not by the rebuilt `可圈office` importer, so Writer-format `Kind` strings remain partly governed by Apple’s own importer precedence.
- Disk space is critically low in the current environment, so broader rebuilds or repeated full reconfiguration remain risky until space is freed.

## Next Rounds

Round 15:

- Audit whether `.odt` and other ODF text formats can realistically be re-claimed from Apple’s RichText importer or whether Finder-kind localization for text documents must rely on LaunchServices metadata only.
- Investigate the remaining `mdls` / Spotlight cache mismatch so rebuilt importer output becomes visible in ordinary metadata reads, not only in `mdimport -t` test-import.
- Continue into About, first-run, and other high-visibility Chinese/brand surfaces now that focused macOS builds are working again.

## Round 15

Goal: separate macOS platform-owned metadata behavior from repo-owned branding leaks, then keep cleaning the real packaged `可圈office.app` where source changes can still produce user-visible wins.

Changes:

- Confirmed the remaining macOS `Kind` mismatch is not a missing downstream plist string: `UTType.localizedDescription` and LaunchServices still resolve `org.oasis-open.opendocument.text` to Apple/CoreTypes plus TextEdit ownership, and `org.oasis-open.opendocument.spreadsheet` to Apple/CoreTypes plus Microsoft Excel ownership on this machine.
- Removed a stale broken LaunchServices registration for `/Users/lu/可点office/instdir/可圈office.app` and force-registered `/Users/lu/kdoffice-build2/instdir/可圈office.app`, which cleaned the registration state but also proved that the surviving `.odt` / `.ods` kind-name mismatch is a platform precedence issue, not just a stale local bundle record.
- Updated the About dialog source strings in `cui/inc/strings.hrc` so the visible copyright and lineage copy no longer says `LibreOffice contributors`, `LibreOffice was based on OpenOffice.org`, or `%PRODUCTNAME is derived from LibreOffice which was based on OpenOffice.org`.
- Updated the legal-information dialog body in `sfx2/uiconfig/ui/licensedialog.ui` so it now uses neutral `可圈office`-compatible wording and points users to the bundled `LICENSE.html` instead of the upstream LibreOffice website.
- Cleared the default `ExtensionManager` website link in `officecfg/registry/data/org/openoffice/Office/ExtensionManager.xcu`, which prevents the product from advertising the upstream extensions portal by default when no downstream replacement URL exists.
- Updated `cui/source/options/optlingu.cxx` so the “Get more dictionaries online” entry points in the linguistic options UI are hidden automatically whenever the extension website config is empty, which removes that visible upstream escape hatch without changing the broader Additions dialog behavior yet.
- Updated `readlicense_oo/license/license.xml` so the generated bundled `LICENSE` and `LICENSE.html` files no longer open with the old LibreOffice/OpenOffice top banner, then rebuilt the affected packaging content.
- Rebuilt the focused `officecfg`, `cui`, `sfx2`, `postprocess`, and `readlicense_oo` modules in `/Users/lu/kdoffice-build2` and verified the packaged app now contains the cleaned legal dialog plus the updated `LICENSE` and `LICENSE.html` header text.

What Round 15 Does Not Solve:

- `.odt` and `.ods` Finder/`mdls` kind names still do not fully follow the downstream `可圈office` / `ODF` naming on this macOS install, because LaunchServices and importer precedence remain dominated by Apple/TextEdit for text and Microsoft Excel for spreadsheets.
- The generic Additions dialog backend still targets the upstream LibreOffice extensions API for themes, icons, templates, and similar online-additions flows when those surfaces are invoked elsewhere, so a broader downstream replacement or disablement policy is still needed beyond the dictionary-specific UI hiding added here.
- The deeper body of `LICENSE` / `LICENSE.html` still contains `OpenOffice.org` references inside third-party notices and historical attribution paragraphs for bundled components; those are legal provenance records, not current product-brand surfaces, so they should not be blanket-rewritten as if they were ordinary UI copy.

## Next Rounds

Round 16:

- Continue removing remaining repo-controlled upstream web-entry points such as the generic Additions dialog, selected Tip-of-the-Day outbound URLs, and other visible brand-redirect surfaces that still send users to LibreOffice properties.
- Decide whether themes/icons/templates/extensions online surfaces should be disabled by default until a real `可圈office` destination exists, or replaced with a downstream placeholder/help flow.
- Keep the macOS ODF kind-name issue documented as a platform-precedence limit unless a safe install-time LaunchServices strategy is found that can demonstrably beat Apple/TextEdit and Excel on real machines.

## Round 16

Goal: remove more repo-controlled upstream web exits from the packaged `可圈office` app, fail closed when no downstream online destination exists, and clear the last obvious visible legacy labels in the touched option dialogs.

Changes:

- Cleared the shared product web-entry defaults in `officecfg/registry/data/org/openoffice/Office/Common.xcu` for Start Center info, feedback, Q&A, documentation, get-involved, release notes, credits, hyphenation help, and Java-install help so the downstream build no longer ships LibreOffice-hosted URLs for those surfaces by default.
- Updated `postprocess/CustomTarget_registry.mk` so generated registry output no longer hardcodes `https://www.libreoffice.org/` back into `InfoURL` during packaging.
- Added runtime fail-closed handling in `sfx2/source/appl/appserv.cxx`: URL-based Help/About actions now show a neutral “online service not configured” info dialog instead of trying to open malformed or upstream URLs when the downstream config is empty.
- Added the same fail-closed guard in `sfx2/source/dialog/AdditionsDialogHelper.cxx`, so generic Additions entry points do not open the upstream online catalog when no downstream extension website is configured.
- Updated `cui/source/dialogs/about.cxx` to hide Credits / Website / Release Notes buttons whenever their configured URLs are empty, and cleared the baked-in fallback website URI in `cui/uiconfig/ui/aboutdialog.ui`.
- Updated `cui/source/dialogs/welcomedlg.cxx` so the first page action button is hidden when Credits or Release Notes have no downstream URL, and updated `sfx2/source/view/viewfrm.cxx` so the “What’s New” infobar and “Get involved” infobar are not shown when those destinations are unset.
- Updated `svx/source/dialog/SafeModeDialog.cxx` to hide the bug-report link when no feedback URL is configured, instead of keeping a dead or upstream link visible.
- Updated `svtools/source/java/javainteractionhandler.cxx` so missing-Java warnings no longer inject a broken help URL when the downstream Java-install page is unset, but this specific path remains a source-side change in this round because the incremental `svtools` rebuild did not relink the packaged `libsvtlo.dylib`.
- Cleared the baked-in dictionary portal URI in `cui/uiconfig/ui/editmodulesdialog.ui` and changed two visible leftover labels:
  - `cui/uiconfig/ui/opthtmlpage.ui`: `LibreOffice _Basic` -> `%PRODUCTNAME _Basic`
  - `sc/uiconfig/scalc/ui/optcompatibilitypage.ui`: `OpenOffice.org legacy` -> `Legacy`
- Rebuilt the focused `officecfg`, `postprocess`, `sfx2`, `cui`, `sc`, and `svx` modules in `/Users/lu/kdoffice-build2` after fixing one compile issue in the new Additions helper include set.

Verification:

- `gmake -C /Users/lu/kdoffice-build2 officecfg.build postprocess.build` completed successfully.
- `gmake -C /Users/lu/kdoffice-build2 sfx2.build cui.build sc.build svx.build svtools.build` completed successfully after adding the missing `vcl/vclenum.hxx` include for `AdditionsDialogHelper.cxx`, but that incremental `svtools.build` pass did not visibly relink `libsvtlo.dylib`.
- The packaged app registry at `/Users/lu/kdoffice-build2/instdir/可圈office.app/Contents/Resources/registry/main.xcd` now shows empty values for `InfoURL`, `SendFeedbackURL`, `QA_URL`, `DocumentationURL`, `GetInvolvedURL`, `ReleaseNotesURL`, `CreditsURL`, `HyphenationMissingURL`, and `InstallJavaURL`.
- The packaged UI payload now reflects the cleanup:
  - `.../cui/ui/aboutdialog.ui` contains an empty website `uri`
  - `.../cui/ui/editmodulesdialog.ui` contains an empty dictionary-link `uri`
  - `.../cui/ui/opthtmlpage.ui` contains `%PRODUCTNAME _Basic`
  - `.../modules/scalc/ui/optcompatibilitypage.ui` contains `Legacy`
- A direct `rg` scan across those rebuilt packaged files no longer finds `https://www.libreoffice.org/`, `https://hub.libreoffice.org/`, or `https://extensions.libreoffice.org/`.

What Round 16 Does Not Solve:

- `cui/inc/tipoftheday.hrc` still contains multiple outbound LibreOffice help/community/template/extensions/donation URLs, so Tip-of-the-Day remains a visible upstream-link class that still needs explicit downstream policy.
- `cui/source/dialogs/AdditionsDialog.cxx` still contains the hardcoded upstream `extensions.libreoffice.org/api/v0/` backend string in source, although the user-facing dialog entry points are now blocked when no downstream website is configured.
- The `svtools/source/java/javainteractionhandler.cxx` cleanup is not yet verified inside the packaged app binary, because a direct `Library_svt` rebuild attempt expanded into a much broader dependency sweep and was intentionally stopped.
- `sfx2/source/appl/sfxhelp.cxx` still contains `https://www.libreoffice.org/` in a macOS Safari detection workaround; this is technical fallback logic rather than the packaged registry/UI destination we removed here, but it remains historical upstream residue in source.
- The macOS `.odt` / `.ods` Finder kind-name mismatch remains a LaunchServices / importer-precedence problem outside the scope of this round’s repo-controlled UI and registry cleanup.

## Next Rounds

Round 17:

- Remove or replace the remaining Tip-of-the-Day entries that still point to LibreOffice properties, especially community, extensions, donation, and documentation links.
- Decide whether the hardcoded Additions backend in `AdditionsDialog.cxx` should be fully downstream-configurable or removed entirely until `可圈office` has a real catalog endpoint.
- Continue the Chinese-first product audit beyond branding cleanup: first-run copy, PPT-generation workflows, review/collaboration ergonomics, and high-frequency document-editing defaults for Chinese users.

## Round 17

Goal: remove the last repo-controlled upstream additions backend, strip Tip-of-the-Day web exits from both runtime behavior and compiled payloads, and clear one more user-visible wiki link in the Base migration flow.

Changes:

- Added a new downstream config property `CatalogURLBase` in `officecfg/registry/schema/org/openoffice/Office/ExtensionManager.xcs` and `officecfg/registry/data/org/openoffice/Office/ExtensionManager.xcu` so online additions can be driven by an explicit downstream catalog base instead of the old hardcoded LibreOffice API.
- Updated `cui/source/dialogs/AdditionsDialog.cxx` to build additions JSON URLs from `CatalogURLBase`, and to fail closed by not launching the fetch thread when no downstream catalog is configured.
- Updated `sfx2/source/dialog/AdditionsDialogHelper.cxx` and `cui/source/options/optlingu.cxx` to key their online-additions availability checks off `CatalogURLBase`, keeping the dictionary/extensions entry points hidden unless a real downstream catalog exists.
- Updated `cui/source/dialogs/tipofthedaydlg.cxx` so Tip of the Day never exposes external `http(s)` links at runtime in this downstream build.
- Cleared every quoted external `http(s)` URL in `cui/inc/tipoftheday.hrc`, which removes the remaining LibreOffice/help/documentfoundation/extensions/donation/rollApp/third-party Tip-of-the-Day targets from the compiled merged library payload instead of only hiding them at runtime.
- Cleared the embedded migration-help URI in `dbaccess/uiconfig/ui/migrwarndlg.ui` and updated `dbaccess/source/core/misc/migrwarndlg.cxx` plus `dbaccess/source/core/inc/migrwarndlg.hxx` so the migration warning dialog hides its link when no downstream destination is configured.
- Rebuilt the focused `officecfg`, `postprocess`, `cui`, `sfx2`, `dbaccess`, and `Library_merged` targets in `/Users/lu/kdoffice-build2`.

Verification:

- `gmake -C /Users/lu/kdoffice-build2 officecfg.build`, `postprocess.build`, `cui.build`, `sfx2.build`, `dbaccess.build`, and `Library_merged` all completed successfully.
- The packaged registry at `/Users/lu/kdoffice-build2/instdir/可圈office.app/Contents/Resources/registry/main.xcd` now contains both `WebsiteLink` and `CatalogURLBase` with empty values.
- The packaged merged library at `/Users/lu/kdoffice-build2/instdir/可圈office.app/Contents/Frameworks/libmergedlo.dylib` no longer contains:
  - `https://extensions.libreoffice.org/api/v0/`
  - Tip-of-the-Day outbound domains such as `ask.libreoffice`, `extensions.libreoffice.org`, `documentation.libreoffice.org`, `rollapp`, `wiki.documentfoundation`, `techrepublic`, and `fridrich.blogspot`
- The packaged Base migration warning UI no longer contains `https://wiki.documentfoundation.org/Documentation/HowTo/MigrateFromHSQLDB`.

What Round 17 Does Not Solve:

- The packaged app still contains many historical LibreOffice / Document Foundation references inside bundled legal, credits, macro-library, and developer-reference resources such as `LICENSE.html`, `CREDITS.fodt`, ScriptForge/Basic source files, and other provenance or help-text assets; these are broader content-cleanup tasks, not the specific user-facing runtime exits removed in this round.
- Some source comments, protocol namespaces, and technical compatibility identifiers still mention LibreOffice / OpenOffice / Document Foundation lineage where changing them may be risky or semantically incorrect.
- The Chinese-first UX/product pass is still incomplete: template curation, PPT-generation defaults, Chinese typography, review workflows, and localized first-run guidance still need dedicated downstream product work beyond branding cleanup.

## Next Rounds

Round 18:

- Audit the remaining user-visible packaged resources outside the core runtime paths, especially `CREDITS.fodt`, migration/help dialogs, and any residual visible wiki/help links in `.ui` payloads.
- Decide how far to downstream-clean bundled macro/documentation assets versus keeping legal/provenance content intact.
- Continue the Chinese productization pass: defaults, templates, fonts, PPT generation flow, and document ergonomics for Chinese users.

## Round 18

Goal: remove the last non-essential promo/onboarding surfaces that were still shipping in `可圈office`, so the product bundle and source tree are both cleaner instead of merely hiding those paths at runtime.

Changes:

- Removed the dedicated `What’s New` welcome page from `cui` and simplified the remaining welcome dialog into a setup flow focused only on user-interface mode and appearance, with neutral labels such as `Welcome to %PRODUCTNAME` and `Show this setup again`.
- Stopped building and packaging the Tip-of-the-Day implementation from `cui`, changed the dialog factory to return `nullptr`, and deleted the now-dead Tip-of-the-Day / What’s-New source files, headers, UI definitions, and related sanitizer / IWYU leftovers from the source tree.
- Removed Help-system donation and tracking plumbing in `helpcontent2`, including the `DonationFrame` HTML injection, the `tdf_matomo.js` analytics script, the `piwik.documentfoundation.org` CSP allowance, the bundled `helpimg/donate.png` asset, and the promotional books/legal footer blocks generated by the XSL templates.
- Removed the obsolete Help topics and bookmarks that documented stripped promo commands and tip flows:
  - deleted `helpcontent2/source/text/shared/01/TipOfTheDay.xhp`
  - removed the `TipOfTheDay` entry from `AllLangHelp_shared.mk`
  - removed the `Tip of the Day`, `Send Feedback`, `Get Involved`, and `Donation` sections from `helpcontent2/source/text/shared/main0108.xhp`
  - removed the `Show "Tip of the Day" on startup` help section from `helpcontent2/source/text/shared/optionen/01010600.xhp`
- Rebuilt the focused `cui`, `helpcontent2`, `postprocess`, and `Library_merged` targets in `/Users/lu/kdoffice-build2`, then removed two stale incremental bundle files (`tipofthedaydialog.ui` and `whatsnewtabpage.ui`) from the already-built app so the deliverable matches the new source packaging rules.

Verification:

- `gmake -C /Users/lu/kdoffice-build2 cui.build` completed successfully after the welcome-dialog cleanup and again after deleting the dead source files.
- `gmake -C /Users/lu/kdoffice-build2 helpcontent2.build` completed successfully after the Help cleanup.
- `gmake -C /Users/lu/kdoffice-build2 postprocess.build` and `gmake -C /Users/lu/kdoffice-build2 Library_merged` completed successfully.
- A packaged-resource scan no longer finds:
  - `.uno:TipOfTheDay`, `.uno:SendFeedback`, `.uno:GetInvolved`, or `.uno:Donation` in shipped menu resources or `libmergedlo.dylib`
  - `DonationFrame`, `tdf_matomo`, `piwik.documentfoundation.org`, `libreoffice.org/donate`, `books.libreoffice.org`, or the old legal/promo footer copy in the installed Help payload
  - `TipOfTheDay.html`, Tip-of-the-Day bookmarks, or Help entries for `Send Feedback`, `Get Involved`, or `Donation`
- The packaged welcome dialog now contains `Welcome to %PRODUCTNAME` and `Show this setup again`, and the stale packaged `tipofthedaydialog.ui` / `whatsnewtabpage.ui` files are absent from the app bundle.

What Round 18 Does Not Solve:

- `cui/ui/optgeneralpage.ui` still contains the hidden `Show "Tip of the Day" dialog on start-up` checkbox resource string, but the options code already hides that control and there is no longer a shipped tip dialog, Help topic, or active dispatch path behind it.
- Registry schema and config metadata still contain technical property names such as `DonationURL`, `ShowDonation`, `ShowTipOfTheDay`, and `WhatsNew`; these are inactive plumbing/config fields, not remaining user-visible promo surfaces.
- Broader content cleanup is still open for historical legal/provenance and upstream-reference assets such as `CREDITS.fodt`, bundled license/history text, ScriptForge/help developer references, and other non-core documentation content that may still mention LibreOffice or The Document Foundation.

## Round 19

Goal: remove the last visible dead-end Help/community actions from shipped UI resources, strip the hidden Tip/crash-report residue from the General options page, and clean the help bundle so it no longer carries those menu paths or the upstream debug/source footer.

Changes:

- Removed `.uno:Documentation` and `.uno:QuestionAnswers` from the remaining shipped Help menus across the Start Center, Basic IDE, Chart, Base relation/query/table/data/app views, bibliography, report designer, Math, Writer/Web/Form/Report/Global Writer, Calc, Impress, and Draw.
- Removed the same dead-end Help actions from the shipped notebookbar Help menus in Writer, Calc, Impress, and Draw, including compact and grouped notebookbar variants.
- Removed the hidden `Tip of the Day` and crash-report controls from the General options implementation by deleting the obsolete weld members, config save/reset handling, and the corresponding widgets from `cui/ui/optgeneralpage.ui`.
- Rewrote the affected Help topics so they match the downstream product behavior instead of describing removed community or branded flows:
  - removed `User Guides` / `Get Help Online` from `text/shared/main0108.xhp`
  - rewrote `text/shared/05/00000001.xhp` into local built-in-help / deployment-support guidance
  - removed the crash-report section from `text/shared/optionen/01010600.xhp`
  - normalized `text/shared/guide/error_report.xhp` away from upstream support/privacy wording
- Removed the global `opengrok.libreoffice.org` “This page is” debug footer from the Help XSL transform so every shipped Help page stops exposing an upstream source-code link that does not help end users.
- Normalized a small cluster of obvious remaining Help-brand/example residue, including:
  - `shared/help/browserhelp.xhp`: `LibreOffice Books` -> `Help Library`, `Please support us!` -> `Documentation and Support`
  - `simpress/guide/impress_remote.xhp`: removed the TDF publisher instruction
  - `sbasic/shared/03090413.xhp`, `scalc/01/func_proper.xhp`, `sbasic/shared/03/sf_platform.xhp`, and `scalc/01/04060111.xhp`: replaced legacy brand/example strings with neutral examples
- Rebuilt the affected targets in `/Users/lu/kdoffice-build2`, including `framework.build`, `basctl.build`, `chart2.build`, `dbaccess.build`, `extensions.build`, `reportdesign.build`, `starmath.build`, `sw.build`, `sc.build`, `sd.build`, `cui.build`, `helpcontent2.build`, `postprocess.build`, and `Library_merged`, then reran `helpcontent2.build` and `postprocess.build` after the Help-template cleanup.

Verification:

- The focused rebuilds completed successfully in `/Users/lu/kdoffice-build2`; the `Library_merged` link step emitted the same transient missing-response-file warning pattern seen in earlier incremental builds but still exited successfully and produced the updated packaged app.
- A packaged-resource scan of `/Users/lu/kdoffice-build2/instdir/可圈office.app/Contents/Resources/config/soffice.cfg/modules` no longer finds `.uno:Documentation` or `.uno:QuestionAnswers`.
- The packaged General options UI at `.../config/soffice.cfg/cui/ui/optgeneralpage.ui` no longer contains `cbShowTipOfTheDay`, `crashreport`, or the removed help-improvement section.
- The installed Help bundle no longer contains `User Guides`, `Get Help Online`, `Help - User Guides`, `Help - Get Help Online`, `cbShowTipOfTheDay`, `crashreport`, `Help Improve`, or `The Document Foundation` in the touched Help pages.
- The installed Help bundle no longer contains the global `This page is:` / `opengrok.libreoffice.org/xref/help/source...` footer on generated Help pages.
- The regenerated Help browser strings now show `Help Library` and `Documentation and Support`, and the updated sample/example pages now contain neutral downstream-friendly examples such as `Example Company`, `Managed Build`, and `Example secret message`.

What Round 19 Does Not Solve:

- The bundled Help and documentation set still contains many broader historical upstream references outside the specific high-visibility pages cleaned here, including API/developer references, some feature-specific examples, and provenance/legal material. Those need a wider content-policy pass rather than isolated UI cleanup.
- The `Check for Updates` and extension-update flows were intentionally left intact and documented, because they remain functional product mechanisms rather than pure marketing/community funnels in this downstream build.
- The larger China-product work is still open: Office-format fidelity, Chinese-first review/collaboration ergonomics, stronger presentation-generation workflows, and deeper default-template/document-behavior tuning.

## Next Rounds

Round 20:

- Audit the remaining directly user-openable historical content surfaces, especially `CREDITS.fodt`, `need_help.xhp`, Help pages with upstream source/community references, and other bundled docs that still leak old brand lineage without helping ordinary office work.
- Decide whether the Help debug block itself should be reduced further now that the upstream source footer is gone, or kept as a minimal diagnostics surface for internal builds only.
- Return from cleanup into product-depth work for Chinese users: Office-format fidelity, review flows, and a stronger real PPT-generation path beyond template and outline-first improvements.

## Round 20

Goal: keep cleaning the directly user-openable Help content by removing the remaining globally injected debug footer, replacing the upstream placeholder “please help LibreOffice” note, and deleting the Help-menu Credits section that no longer reflects a visible downstream product surface.

Changes:

- Removed the remaining Help-page debug footer block from `helpcontent2/help3xsl/online_transform.xsl`, so generated Help pages no longer carry `Help content debug info`, `Title is`, or the empty debug metadata fields in ordinary output.
- Hardened `helpcontent2/help3xsl/help2.js` so the optional `Debug` query parameter now fails safely when the footer block is absent instead of assuming the debug DOM nodes always exist.
- Rewrote `helpcontent2/source/text/shared/need_help.xhp` from the old upstream contributor-recruitment warning into a neutral downstream note that tells users the topic is not fully documented in this build and points them back to nearby Help or local support materials.
- Removed the `%PRODUCTNAME Credits` section from `helpcontent2/source/text/shared/main0108.xhp`, eliminating the remaining Help-menu description that pointed users to `CREDITS.odt` and historical `OpenOffice.org` lineage text even though this is not a visible core-product path in the downstream UI.
- Rebuilt the focused `helpcontent2` and `postprocess` targets in `/Users/lu/kdoffice-build2` so the installed `可圈office.app` Help payload matches the new source state.

Verification:

- `gmake -C /Users/lu/kdoffice-build2 helpcontent2.build postprocess.build` completed successfully.
- A packaged-resource scan of `/Users/lu/kdoffice-build2/instdir/可圈office.app/Contents/Resources/help` no longer finds:
  - `Help content debug info`
  - `Title is:`
  - `This help page needs further work`
  - `Please join the LibreOffice project and help us out`
  - `ShowCredits`, `CREDITS.odt`, or `OpenOffice.org source code` inside the shipped Help-menu page
- The installed `text/shared/need_help.html` now shows the neutral downstream wording about missing detailed documentation instead of the old upstream contributor message.
- The installed `text/shared/main0108.html` now goes directly from `License Information` to `Check for Updates`, with no remaining Credits help block in between.

What Round 20 Does Not Solve:

- The bundled app still contains broader historical documents and technical/help assets that users can open directly, especially `CREDITS.fodt` itself plus other provenance, developer-reference, and legacy documentation pages that still mention LibreOffice / OpenOffice / The Document Foundation.
- The underlying `SID_SHOW_CREDITS` implementation still exists in source as an internal document-opening command, even though the visible downstream Help/about surfaces for credits were already removed or hidden.
- This round is still cleanup, not core product-depth work for Chinese office users. Office-format fidelity, review/collaboration ergonomics, and stronger real document/PPT generation remain the bigger product tracks.

## Next Rounds

Round 21:

- Audit the remaining directly openable bundled documents and Help assets with low user value, especially `CREDITS.fodt`, developer-oriented Help pages, and other historical lineage text that still leaks old branding without helping normal office work.
- Decide whether the internal credits document path should now be removed or fail-closed downstream, given that the visible Help/about entry points are already gone.
- Return from cleanup into deeper product work for Chinese users: file-format fidelity, collaboration/review ergonomics, and stronger presentation-generation workflows.

## Round 21

Goal: remove the last shipped credits surface end-to-end so `可圈office` no longer carries a user-openable bundled credits document, a dead About entry point, or credits commands that still leak into customization flows.

Changes:

- Removed the About-dialog credits control from source and shipped UI resources:
  - deleted `btnCredits` from `cui/uiconfig/ui/aboutdialog.ui`
  - removed the corresponding weld member and setup code from `cui/source/inc/about.hxx` and `cui/source/dialogs/about.cxx`
- Fail-closed the remaining credits dispatch paths in `sfx2/source/appl/appserv.cxx`:
  - `SID_CREDITS` now does nothing downstream instead of trying to open a configured credits URL
  - `SID_SHOW_CREDITS` now does nothing downstream instead of opening the bundled `CREDITS` document
- Stopped packaging the bundled credits document in `readlicense_oo/Package_files.mk`, so new builds no longer install `CREDITS.fodt`.
- Removed the remaining visible command-description entry for `.uno:ShowCredits` from `officecfg/registry/data/org/openoffice/Office/UI/GenericCommands.xcu`.
- Hid both credits commands from customization surfaces by switching their slot config flags off in `sfx2/sdi/sfx.sdi`:
  - `SID_CREDITS`: `AccelConfig = FALSE`, `MenuConfig = FALSE`
  - `SID_SHOW_CREDITS`: `AccelConfig = FALSE`, `MenuConfig = FALSE`, `ToolBoxConfig = FALSE`
- Updated the accelerator UI test fixture in `cui/qa/uitest/dialogs/accelerators.py` to use `.uno:ShowLicense` instead of the removed credits command so the test logic still exercises configurable application commands.
- Rebuilt the affected targets in `/Users/lu/kdoffice-build2`:
  - `sfx2.build`
  - `cui.build`
  - `readlicense_oo.build`
  - `officecfg.build`
  - `postprocess.build`
  - `Library_merged`
- Removed the stale `Contents/Resources/CREDITS.fodt` file from the already-built `.app` bundle after the rebuild, because this incremental install tree does not automatically prune files that were removed from packaging rules.

Verification:

- `gmake -C /Users/lu/kdoffice-build2 sfx2.build cui.build readlicense_oo.build officecfg.build postprocess.build Library_merged` completed successfully.
- The same familiar transient `ld` response-file warning appeared during `Library_merged`, but the link still exited `0`.
- The installed app no longer contains `CREDITS.fodt` or `CREDITS.odt` anywhere under `/Users/lu/kdoffice-build2/instdir/可圈office.app`.
- The shipped About dialog UI at `.../config/soffice.cfg/cui/ui/aboutdialog.ui` no longer contains `btnCredits`.
- A packaged scan of `Contents/Resources/config` and `Contents/Resources/help` no longer finds:
  - `btnCredits`
  - `%PRODUCTNAME Credits`
  - `.uno:ShowCredits`
  - `.uno:Credits`
  - `CREDITS.fodt`
- A framework-string scan of `libmergedlo.dylib` and `libsfxlo.dylib` no longer finds the removed credits markers above.

What Round 21 Does Not Solve:

- The source tree and shipped resources still contain many non-user-visible technical comment headers and DTD identifiers such as `This file is part of the LibreOffice project` or `OpenOffice.org//DTD OfficeDocument 1.0`, which are not the same as live product branding but still contribute to historical residue in raw package files.
- The Help bundle still contains broader user-visible historical references in feature docs, API examples, compatibility notes, and wiki links that were outside the focused credits cleanup here.
- This round was product-cleanup work, not the deeper China-product capability work around fonts, templates, file-format fidelity, review/collaboration, or PPT-generation workflow quality.

## Round 22

Goal: clean the next small cluster of directly user-visible Help-brand residue that remained after the credits removal, especially wrong options-path branding and an upstream credits pointer in version/build documentation.

Changes:

- Updated the three Writer Spotlight Help topics so their options path now matches the downstream product brand instead of saying `LibreOffice – General`:
  - `helpcontent2/source/text/swriter/01/SpotlightCharStyles.xhp`
  - `helpcontent2/source/text/swriter/01/SpotlightParaStyles.xhp`
  - `helpcontent2/source/text/swriter/guide/spotlight_styles.xhp`
- Rewrote the second list item in `helpcontent2/source/text/shared/guide/version_number.xhp` so it no longer sends users to the upstream LibreOffice credits page and instead tells them to use the About-dialog copy button for support/troubleshooting records.
- Rebuilt the focused Help pipeline in `/Users/lu/kdoffice-build2`:
  - `helpcontent2.build`
  - `postprocess.build`

Verification:

- `gmake -C /Users/lu/kdoffice-build2 helpcontent2.build postprocess.build` completed successfully.
- The installed Help pages now show `可圈office – General` in:
  - `.../help/en-US/text/swriter/01/SpotlightCharStyles.html`
  - `.../help/en-US/text/swriter/01/SpotlightParaStyles.html`
  - `.../help/en-US/text/swriter/guide/spotlight_styles.html`
- The installed `.../help/en-US/text/shared/guide/version_number.html` now tells users to copy version/build details from the About dialog and no longer links to `libreoffice.org/about-us/credits/`.

What Round 22 Does Not Solve:

- The Help system still contains many broader historical references to `LibreOffice`, `OpenOffice.org`, old compatibility labels, API docs, and upstream wiki pages across advanced/technical topics, examples, and legacy file-format documentation.
- Some of that remaining content is legitimate compatibility or technical reference material, so it needs a policy-based cleanup pass instead of blind string replacement.
- The broader visible-product work remains open: deeper Chinese defaults, font choices, templates, icons, PPT-generation ergonomics, and high-frequency office workflows.

## Next Rounds

Round 23:

- Audit the remaining user-visible Help pages that still mention `LibreOffice`, `OpenOffice.org`, or upstream wiki/credits links, and separate true compatibility/reference content from low-value historical branding that should be rewritten.
- Continue checking live product surfaces, not just Help, for visible old-brand labels in options, dialogs, start-center text, templates, and onboarding copy.
- Return from branding cleanup into higher-value China-product work: Chinese font defaults, template quality, document/presentation generation flow, and day-to-day office usability.

## Round 23

Goal: continue the Chinese-first Help overhaul by fixing the most visible remaining English in the Help shell, replacing inherited English entry content with Chinese task-navigation pages, and removing the old embedded YouTube/video behavior from the Help homepages.

Changes:

- Localized repeated shared Help labels that affect a wide portion of the shipped Help tree:
  - `helpcontent2/source/text/shared/00/00000004.xhp`
    - `To access this command...` -> `如何找到此命令`
    - command-access section headings -> Chinese
    - `Related Topics` -> `相关主题`
    - `Open file with example:` -> `打开示例文件：`
  - `helpcontent2/source/text/shared/05/00000002.xhp`
    - rewrote the icon legend block into Chinese so the Help homepage no longer embeds `Icons in the Documentation` in English
  - `helpcontent2/source/text/shared/help/browserhelp.xhp`
    - localized Xapian/search-result labels such as next/previous, match summaries, and search timing
    - localized the external-video consent text so any remaining legacy video prompt is Chinese
- Removed the old `youtubevideos.xhp` embed from every Help landing page touched in this workflow:
  - `helpcontent2/source/text/shared/05/new_help.xhp`
  - `helpcontent2/source/text/swriter/main0000.xhp`
  - `helpcontent2/source/text/scalc/main0000.xhp`
  - `helpcontent2/source/text/simpress/main0000.xhp`
  - `helpcontent2/source/text/sdraw/main0000.xhp`
  - `helpcontent2/source/text/smath/main0000.xhp`
  - `helpcontent2/source/text/schart/main0000.xhp`
  - `helpcontent2/source/text/sdatabase/main.xhp`
  - `helpcontent2/source/text/sbasic/shared/main0601.xhp`
- Replaced the shared general-guide landing page with a Chinese task-navigation page:
  - `helpcontent2/source/text/shared/guide/main.xhp`
  - now serves as a Chinese-first hub for getting started, interface/navigation, accessibility, copy/paste, databases, revision history, configuration, charts, and help-center/module entry points
- Added or rewrote Chinese-first module landing pages for the remaining high-traffic Help entry points:
  - `helpcontent2/source/text/sdraw/main0000.xhp`
  - `helpcontent2/source/text/smath/main0000.xhp`
  - `helpcontent2/source/text/sdatabase/main.xhp`
  - `helpcontent2/source/text/sbasic/shared/main0601.xhp`
  - `helpcontent2/source/text/schart/main0000.xhp`
- Reworked the Chart landing page carefully instead of deleting its hidden command-ahelp payload:
  - kept the hidden command bookmarks/ahelp blocks for chart commands
  - replaced the visible English body with Chinese task links and Chinese usage guidance
  - removed the inherited visible English embeds at the bottom and replaced them with a Chinese `更多参考` section
- Normalized the standalone module-specific `00/00000004.xhp` header pages so they no longer start with English:
  - `helpcontent2/source/text/swriter/00/00000004.xhp`
  - `helpcontent2/source/text/scalc/00/00000004.xhp`
  - `helpcontent2/source/text/simpress/00/00000004.xhp`
  - `helpcontent2/source/text/sdraw/00/00000004.xhp`
  - `helpcontent2/source/text/schart/00/00000004.xhp`
  - `helpcontent2/source/text/smath/00/00000004.xhp`
  - also translated the top Calc-function note block in `scalc/00/00000004.xhp`

Verification:

- `xmllint --noout` passed for all changed `.xhp` files in this round, including:
  - shared fragments
  - Help shell pages
  - new/rewritten landing pages
  - the module-specific `00/00000004.xhp` pages
- Rebuilt the Help pipeline multiple times during the round:
  - `gmake -C /Users/lu/kdoffice-build2 helpcontent2.build postprocess.build`
  - all rebuilds completed successfully
- Confirmed in the installed app bundle under `/Users/lu/kdoffice-build2/instdir/可圈office.app/Contents/Resources/help` that:
  - `help2.js` still shows the Chinese module labels and `可圈office 帮助中心`
  - `shared/help/browserhelp.html` now shows Chinese Xapian labels such as `匹配全部关键词`
  - shared and module Help pages now render `相关主题` and `如何找到此命令`
  - `shared/guide/main.html` ships as a Chinese-first general guide page
  - `sdraw/main0000.html`, `smath/main0000.html`, `sdatabase/main.html`, `sbasic/shared/main0601.html`, and `schart/main0000.html` now ship with Chinese-first landing content
  - the visible Help homepage/module homepages no longer contain `video/youtube`, `Please accept this video`, or `Accept YouTube Content`
  - the module-specific `00/00000004.html` pages now start with `如何找到此功能` or `如何找到此函数` instead of the old English header

What Round 23 Does Not Solve:

- This build still does not contain a real `zh-CN` translated Help corpus; the build config still ships the `en-US` Help tree, now heavily wrapped with Chinese-first navigation and selective Chinese rewrites.
- A large number of deep technical Help pages, wizard pages, dialog references, API docs, macro docs, file-format references, and compatibility pages still remain partly or mostly English.
- Some advanced/legacy pages contain legitimate technical English terminology or compatibility notes and should not be mass-rewritten without a policy pass.
- The old `shared/06/youtubevideos.xhp` asset and related support code still exist in source, but the visible Help landing pages no longer embed it.

## Next Rounds

Round 24:

- Audit the next band of directly user-openable high-frequency Help pages that still remain English, especially:
  - `shared/00/00000001.xhp` and similar common wizard/info fragments
  - Base wizard pages
  - Math/Chart command pages that are still highly visible from the Chinese landing pages
- Continue replacing inherited English embed blocks inside high-traffic Help pages with Chinese task lists or Chinese summaries instead of deep embedded English prose.
- After the Help-center pass, resume higher-value product work for Chinese users: Chinese font defaults, better template quality, and stronger Writer/Calc/Impress day-to-day usability.

## Round 24

Goal: finish the high-traffic Chinese Help pass for the shared button fragment, Base wizard path, and Chart wizard/type path, then verify the installed app bundle instead of stopping at source edits.

Changes:

- Finalized the shared high-frequency button/help fragment:
  - `helpcontent2/source/text/shared/00/00000001.xhp`
  - standardized the page to `常用按钮与控件`
  - translated the remaining visible `OK` labels to `确定`
  - localized the shrink/expand icon alt text
- Completed the Base entry and wizard-step path in Chinese:
  - entry pages:
    - `helpcontent2/source/text/sdatabase/dabawiz01.xhp`
    - `helpcontent2/source/text/sdatabase/tablewizard00.xhp`
    - `helpcontent2/source/text/sdatabase/querywizard00.xhp`
  - embedded Table Wizard step pages:
    - `helpcontent2/source/text/sdatabase/tablewizard01.xhp`
    - `helpcontent2/source/text/sdatabase/tablewizard02.xhp`
    - `helpcontent2/source/text/sdatabase/tablewizard03.xhp`
    - `helpcontent2/source/text/sdatabase/tablewizard04.xhp`
  - embedded Query Wizard step pages:
    - `helpcontent2/source/text/sdatabase/querywizard01.xhp`
    - `helpcontent2/source/text/sdatabase/querywizard02.xhp`
    - `helpcontent2/source/text/sdatabase/querywizard03.xhp`
    - `helpcontent2/source/text/sdatabase/querywizard04.xhp`
    - `helpcontent2/source/text/sdatabase/querywizard05.xhp`
    - `helpcontent2/source/text/sdatabase/querywizard06.xhp`
    - `helpcontent2/source/text/sdatabase/querywizard07.xhp`
    - `helpcontent2/source/text/sdatabase/querywizard08.xhp`
  - rewrote visible titles, headings, intros, help paragraphs, and next-step links into Chinese-first wording for 可圈office Base users while preserving bookmarks and wizard structure
- Completed the Chart wizard/type path in Chinese:
  - localized the chart access fragment that the wizard/type pages embed:
    - `helpcontent2/source/text/schart/00/00000004.xhp`
  - localized the wizard/chooser pages:
    - `helpcontent2/source/text/schart/01/choose_chart_type.xhp`
    - `helpcontent2/source/text/schart/01/wiz_chart_type.xhp`
    - `helpcontent2/source/text/schart/01/wiz_data_range.xhp`
    - `helpcontent2/source/text/schart/01/wiz_data_series.xhp`
    - `helpcontent2/source/text/schart/01/wiz_chart_elements.xhp`
  - localized the embedded chart-type reference pages:
    - `helpcontent2/source/text/schart/01/type_column_bar.xhp`
    - `helpcontent2/source/text/schart/01/type_pie.xhp`
    - `helpcontent2/source/text/schart/01/type_area.xhp`
    - `helpcontent2/source/text/schart/01/type_line.xhp`
    - `helpcontent2/source/text/schart/01/type_xy.xhp`
    - `helpcontent2/source/text/schart/01/type_bubble.xhp`
    - `helpcontent2/source/text/schart/01/type_net.xhp`
    - `helpcontent2/source/text/schart/01/type_stock.xhp`
    - `helpcontent2/source/text/schart/01/type_column_line.xhp`
    - `helpcontent2/source/text/schart/01/type_ofpie.xhp`
  - rewrote visible headings, intros, subtype descriptions, labels, and icon alt text so the chart chooser no longer drops back into English after entering the Chinese landing path
- Integrated the Math page rewrites already completed in parallel:
  - `helpcontent2/source/text/smath/01/03090000.xhp`
  - `helpcontent2/source/text/smath/01/03090900.xhp`

Verification:

- `xmllint --noout` passed for every file touched in this round, including:
  - the shared fragment
  - Base entry pages
  - Base wizard step pages
  - Chart access fragment
  - Chart wizard pages
  - Chart type pages
  - Math pages integrated from the worker
- Rebuilt the Help pipeline twice after integration:
  - `gmake -C /Users/lu/kdoffice-build2 helpcontent2.build postprocess.build`
  - both rebuilds completed successfully
- Verified in the installed app bundle under `/Users/lu/kdoffice-build2/instdir/可圈office.app/Contents/Resources/help` that:
  - `shared/00/00000001.html` now shows `常用按钮与控件` and `确定`
  - `sdatabase/tablewizard00.html` now embeds Chinese step headings such as `表向导 - 选择字段`
  - `sdatabase/querywizard00.html` now embeds Chinese step headings such as `查询向导 - 搜索条件`
  - the checked Chart pages no longer show `Choose Insert - Chart - Chart Type...`
  - the checked Chart wizard/type pages now show Chinese titles and descriptions such as `选择图表类型`, `图表向导 - 图表类型`, `柱形图与条形图`, `XY 散点图`, `股票图`, and `柱线组合图`

What Round 24 Does Not Solve:

- The Math pages `smath/01/03090000.html` and `smath/01/03090900.html` are still only partially finished in the installed output because they embed deeper child sections whose visible headings and example summaries remain English.
- Some unrelated deep Help pages still contain visible `OK`, old upstream wording, or English technical content outside the shared/Base/Chart path touched in this round.
- This is still a Chinese-first rewrite layer on top of the shipped `en-US` Help corpus, not a full native `zh-CN` Help pack.

## Next Rounds

Round 25:

- Patch the embedded Math child pages that still surface English inside:
  - `smath/01/03090000.html`
  - `smath/01/03090900.html`
- Continue the installed-output-driven audit for remaining visible English on the Chinese Help path instead of only patching source entry pages.
- After the Help-center pass is materially complete, resume product-level Chinese work: font defaults, template quality, and stronger Writer/Calc/Impress/PPT day-to-day workflows.

## Round 25

Goal: finish the remaining visible English in the Math Help path that still leaked through the Chinese landing pages, then verify the installed `可圈office.app` output instead of stopping at source edits.

Changes:

- Completed the embedded Math example-page batch with parallel worker help:
  - `helpcontent2/source/text/smath/01/03090901.xhp`
  - `helpcontent2/source/text/smath/01/03090902.xhp`
  - `helpcontent2/source/text/smath/01/03090903.xhp`
  - `helpcontent2/source/text/smath/01/03090904.xhp`
  - `helpcontent2/source/text/smath/01/03090905.xhp`
  - `helpcontent2/source/text/smath/01/03090906.xhp`
  - `helpcontent2/source/text/smath/01/03090907.xhp`
  - `helpcontent2/source/text/smath/01/03090908.xhp`
  - `helpcontent2/source/text/smath/01/03090909.xhp`
  - `helpcontent2/source/text/smath/01/03090910.xhp`
  - localized the visible titles, headings, summaries, and image alt text for the embedded formula examples so `smath/01/03090900.html` no longer falls back to English
- Completed the visible embedded Math category/reference path:
  - `helpcontent2/source/text/smath/01/03090100.xhp`
  - `helpcontent2/source/text/smath/01/03090200.xhp`
  - `helpcontent2/source/text/smath/01/03090300.xhp`
  - `helpcontent2/source/text/smath/01/03090400.xhp`
  - `helpcontent2/source/text/smath/01/03090500.xhp`
  - `helpcontent2/source/text/smath/01/03090600.xhp`
  - `helpcontent2/source/text/smath/01/03090700.xhp`
  - `helpcontent2/source/text/smath/01/03090800.xhp`
  - `helpcontent2/source/text/smath/01/03091500.xhp`
  - `helpcontent2/source/text/smath/01/03091600.xhp`
  - localized the visible page titles, main headings, intro paragraphs, and first section labels that feed the embedded output shown from `smath/01/03090000.html`
- Fixed the shared Math helper fragment that was still injecting English navigation text:
  - `helpcontent2/source/text/smath/00/00000004.xhp`
  - translated `Choose View - Elements`, the context-menu instructions, and related Math command-path text into Chinese
- Fixed the shared help icon alt text used by generated note/tip/warning blocks:
  - `helpcontent2/source/text/shared/00/icon_alt.xhp`
  - changed `Note Icon`, `Tip Icon`, and `Warning Icon` to Chinese alt text

Verification:

- `xmllint --noout` passed for:
  - the full Round 25 Math batch under `helpcontent2/source/text/smath/01/`
  - `helpcontent2/source/text/smath/00/00000004.xhp`
  - `helpcontent2/source/text/shared/00/icon_alt.xhp`
- Rebuilt the Help pipeline twice after integrating the Math and shared-source fixes:
  - `gmake -C /Users/lu/kdoffice-build2 helpcontent2.build postprocess.build`
  - both rebuilds completed successfully
- Verified in the installed app bundle under `/Users/lu/kdoffice-build2/instdir/可圈office.app/Contents/Resources/help` that:
  - `smath/01/03090000.html` now shows Chinese headings and summaries for:
    - `一元/二元运算符`
    - `关系符`
    - `集合运算`
    - `函数`
    - `运算符`
    - `属性`
    - `括号`
    - `格式`
    - `其他符号`
    - `公式参考表`
  - `smath/01/03090900.html` now shows Chinese embedded example titles and summaries such as:
    - `带上下标的符号`
    - `矩阵`
    - `不同字号的矩阵`
    - `粗体矩阵`
    - `函数`
    - `平方根`
    - `积分与求和范围（字号示例）`
    - `属性`
  - the previously visible English helper text `Choose View - Elements` is now rendered as `选择 视图 - 元素`
  - the previously visible English alt text `Note Icon` is now rendered as `备注图标`

What Round 25 Does Not Solve:

- Many direct-open deep Math reference pages still contain large English operator/function tables below the now-Chinese top sections.
- Other unrelated Help modules and deep reference pages outside this Math/shared path may still contain inherited English strings.
- This remains a Chinese-first rewrite layer on the shipped `en-US` Help tree, not a real standalone `zh-CN` Help corpus.

## Next Rounds

Round 26:

- Continue the installed-output-driven sweep for remaining visible English in directly opened Help pages, prioritizing the deep Math reference tables and other high-traffic task pages.
- Decide whether to fully translate the long Math operator/reference tables or replace parts of them with shorter Chinese-first summaries when that improves usability more than literal coverage.
- After the high-traffic Help path is materially clean, resume product-level Chinese work: font defaults, Chinese templates, and stronger Writer/Calc/Impress/PPT daily workflows.

## Round 26

Goal: convert the direct-open Math formula reference family under `smath/01/03091500.html` from English into Chinese, then verify the installed app bundle instead of stopping at source-only changes.

Changes:

- Completed the Math formula reference landing page and its embedded child reference tables:
  - `helpcontent2/source/text/smath/01/03091500.xhp`
  - `helpcontent2/source/text/smath/01/03091501.xhp`
  - `helpcontent2/source/text/smath/01/03091502.xhp`
  - `helpcontent2/source/text/smath/01/03091503.xhp`
  - `helpcontent2/source/text/smath/01/03091504.xhp`
  - `helpcontent2/source/text/smath/01/03091505.xhp`
  - `helpcontent2/source/text/smath/01/03091506.xhp`
  - `helpcontent2/source/text/smath/01/03091507.xhp`
  - `helpcontent2/source/text/smath/01/03091508.xhp`
  - `helpcontent2/source/text/smath/01/03091509.xhp`
- Rewrote the visible user-facing English in the reference-table family into Chinese-first wording:
  - page titles and top headings
  - embedded reference-category labels
  - table headers such as `Typed command(s)`, `Symbol in Elements pane`, and `Meaning`
  - table meaning/description cells
  - image alt text such as generic `Icon` and function-specific alt labels
- Finished the previously untouched bracket reference child page locally:
  - `helpcontent2/source/text/smath/01/03091508.xhp`
  - translated the full bracket reference table so `03091500.html` no longer embeds one remaining English category page inside an otherwise Chinese reference section

Verification:

- `xmllint --noout` passed for the full `03091500` reference family:
  - `03091500.xhp`
  - `03091501.xhp`
  - `03091502.xhp`
  - `03091503.xhp`
  - `03091504.xhp`
  - `03091505.xhp`
  - `03091506.xhp`
  - `03091507.xhp`
  - `03091508.xhp`
  - `03091509.xhp`
- Rebuilt the Help pipeline:
  - `gmake -C /Users/lu/kdoffice-build2 helpcontent2.build postprocess.build`
  - rebuild completed successfully
- Verified in the installed app bundle under `/Users/lu/kdoffice-build2/instdir/可圈office.app/Contents/Resources/help` that:
  - `smath/01/03091500.html` now shows Chinese embedded reference labels:
    - `一元与二元运算符`
    - `关系运算符`
    - `集合运算符`
    - `函数`
    - `运算符`
    - `属性`
    - `其他符号`
    - `括号`
    - `格式`
  - `smath/01/03091508.html` now renders Chinese table headers and bracket meanings such as:
    - `输入命令`
    - `“元素”窗格中的符号`
    - `含义`
    - `普通左右圆括号`
    - `左右方括号`
    - `左右双层方括号`
  - a direct string sweep on the installed `03091500.html` and `03091508.html` no longer finds the old visible English headings or table-header vocabulary
  - spot-checks of installed child pages like `03091501.html`, `03091504.html`, and `03091509.html` show Chinese headings, Chinese table headers, Chinese meanings, and Chinese icon alt text

What Round 26 Does Not Solve:

- The separate direct-open Math topic pages such as `03090100.html`, `03090200.html`, `03090400.html`, `03090600.html`, and `03091600.html` still contain substantial deeper English tables below their already-Chinese top sections.
- Some non-visible metadata keywords in the generated Help HTML still remain English because this pass targeted user-visible output first.
- This is still a Chinese-first rewrite layer on top of the shipped `en-US` Help corpus, not a native standalone `zh-CN` Help pack.

## Next Rounds

Round 27:

- Continue the installed-output-driven cleanup on the direct-open Math category pages themselves, prioritizing the deepest remaining English tables in:
  - `03090200`
  - `03090400`
  - `03090600`
  - `03090800`
  - `03091600`
- After the Math deep-table pass, continue the same installed-bundle audit across other high-traffic Help pages outside `smath`.

## Round 27

Goal: convert the direct-open Math category pages from mixed Chinese headers plus English deep tables into installed Chinese-first help pages, and verify the app bundle with an output-based sweep instead of stopping at source edits.

Changes:

- Completed a deep user-visible localization pass on these Math Help source pages:
  - `helpcontent2/source/text/smath/01/03090200.xhp`
  - `helpcontent2/source/text/smath/01/03090400.xhp`
  - `helpcontent2/source/text/smath/01/03090600.xhp`
  - `helpcontent2/source/text/smath/01/03090800.xhp`

## Round 28

Goal: pivot from cleanup into product-depth work by turning the Start Center into a task-first `可圈办公工作台` that prioritizes common Chinese office workflows over module-first entry points.

Changes:

- Reworked the main Start Center copy in `sfx2/uiconfig/ui/startcenter.ui` so the page now presents itself as `可圈办公工作台` with a task-oriented subtitle instead of a generic document/template surface.
- Renamed the left-rail module heading from `快速开始` to `基础入口` and kept the blank-document buttons as secondary fallback entry points rather than the dominant first-screen message.
- Promoted the scenario block to the top of the main workbench area by moving `scenario_box` above the filter/actions row, so task cards appear before template-browse controls.
- Tightened the scenario section title to `按任务开始` and kept the existing Start Center scenario plumbing grounded in real bundled templates instead of inventing new fake workflows.
- Reordered the scenario-grid cards by business priority in `startcenter.ui` so the first two rows now emphasize the top office tasks:
  - row 1: `工作汇报`, `会议纪要`, `预算总览`, `项目排期`
  - row 2: `PPT 初稿`, `项目汇报`, `商务路演`, `教学课件`
  - row 3: `项目方案`, `销售跟进`, `通知`
- Fixed the `local_view_label` text-attribute span so the softened subtitle styling still covers the full updated second line after the longer Chinese workbench copy was introduced.
- Kept the Start Center focused on the V1 Writer/Calc/Impress workbench by continuing to hide remote/recent/extensions and the secondary module-first buttons in `sfx2/source/dialog/backingwindow.cxx`, while leaving the real scenario button handlers mapped to bundled Writer/Calc/Impress templates.

Verification:

- Read back `sfx2/uiconfig/ui/startcenter.ui` after the layout move and corrected one accidental duplicate grid cell introduced during the reorder (`scenario_budget` and `scenario_sales` had briefly overlapped at row 2 column 2 before the final pass).
- Verified the moved `actions` grid still contains `lbFilter`, `cbFilter`, and `mbActions` and now sits directly below `scenario_box`.
- `gmake -C /Users/lu/kdoffice-build2 sfx2.build` completed successfully after the final `startcenter.ui` updates.
- The same pre-existing sfx accessibility warnings remained in unrelated UI files such as `documentinfopage.ui` and `password.ui`; no new fatal was introduced by the Start Center change.

What Round 28 Does Not Solve:

- This is still a task-first Start Center reshaping pass, not a full workflow engine: there is no new cloud layer, no real AI orchestration, and no cross-document automation beyond the existing bundled template/open flows.
- The scenario ordering is a product judgment call for the current China-office V1; it still needs real runtime UX review in the packaged app to confirm spacing, visual hierarchy, and whether the chosen priority order matches user expectations.
- The deeper product gaps identified earlier remain open: stronger DOCX/XLSX/PPTX fidelity, richer Chinese defaults, better review/collaboration ergonomics, and a stronger real PPT-generation path beyond template and outline-first entry.

## Next Rounds

Round 29:

- Open and visually inspect the rebuilt Start Center in the packaged app to validate the new task-first hierarchy, spacing, and card prominence instead of stopping at source and build verification.
- If the visual balance holds, document the current V1 task-pack rationale in the product audit and then continue into the next workflow-depth layer: better template quality, Start Center card wording, and stronger Writer-to-PPT / report-to-deck handoff.
- Keep the scope product-real: iterate on the task-first workbench and high-frequency Chinese office flows rather than drifting back into broad cleanup work.
  - `helpcontent2/source/text/smath/01/03091600.xhp`
- Rewrote the remaining visible English in the large direct-open category tables into Simplified Chinese, including:
  - relation/operator descriptions and icon alt text in `03090200`
  - function names, explanatory text, icon alt text, and closing tip/warning text in `03090400`
  - attribute names, descriptions, icon alt text, color/font notes, sizing guidance, and related-link text in `03090600`
  - set-operation descriptions plus the remaining non-command label cleanup in `03090800`
  - proper-name labels and symbol descriptions in `03091600`
- Preserved IDs, bookmarks, anchors, XML structure, `localize="false"` entries, and user-facing command literals such as `neq`, `sin`, `nroot`, `widehat`, `setn`, `backepsilon`, and similar Math command syntax.
- Removed two residual untranslated labels after the first rebuild:
  - changed the `n`-root row to `任意次根`
  - changed the visible `aleph` row title to `阿列夫`

Verification:

- `xmllint --noout` passed for:
  - `03090200.xhp`
  - `03090400.xhp`
  - `03090600.xhp`
  - `03090800.xhp`
  - `03091600.xhp`
- Rebuilt the Help pipeline twice during the round to verify installed output:
  - `gmake -C /Users/lu/kdoffice-build2 helpcontent2.build postprocess.build`
  - rebuilds completed successfully
- Verified in the installed app bundle under `/Users/lu/kdoffice-build2/instdir/可圈office.app/Contents/Resources/help` that the target pages dropped from deep English-table pages to mostly command-literal residue:
  - `smath/01/03090200.html`: `93` -> `13`
  - `smath/01/03090400.html`: `77` -> `26`
  - `smath/01/03090600.html`: `82` -> `28`
  - `smath/01/03090800.html`: `67` -> `7`
  - `smath/01/03091600.html`: `26` -> `18`
- Spot-checked the remaining installed matches and confirmed they are now dominated by required command syntax or math tokens rather than untranslated prose, for example:
  - `sin`, `cos`, `fact`, `nroot`, `aleph`, `setn`, `widehat`, `backepsilon`
  - color/font command tokens such as `color`, `Serif`, `Sans`, `Fixed`

What Round 27 Does Not Solve:

- The remaining regex matches in these pages are not zero because the Help content still needs literal Math command names to teach actual usage.
- Some English metadata and index keywords remain in source/bookmark data because this pass continued to prioritize installed user-visible Help output first.
- Other Help areas outside this Math cluster still need the same installed-bundle audit and cleanup approach.

## Next Rounds

Round 28:

- Continue the Math Help audit with the remaining direct-open page `03090100` and any adjacent `smath` pages whose installed output still contains visible English prose rather than command syntax.
- Then expand the same installed-output cleanup method into higher-traffic non-Math Help areas so the broader Help Center moves toward Chinese-first consistency instead of improving only `smath`.

## Round 28

Goal: move beyond Math and localize high-value Help Center pages that ordinary Chinese users actually see first: common shared-format help, Writer shortcuts, and the shared onboarding/open/save workflow.

Changes:

- Localized these non-Math Help source pages:
  - `helpcontent2/source/text/shared/00/00040502.xhp`
  - `helpcontent2/source/text/shared/01/05020301.xhp`
  - `helpcontent2/source/text/swriter/04/01020000.xhp`
  - `helpcontent2/source/text/shared/guide/startcenter.xhp`
  - `helpcontent2/source/text/shared/guide/doc_open.xhp`
  - `helpcontent2/source/text/shared/guide/doc_save.xhp`
- Reworked the shared `Format Menu` page into Chinese across many high-visibility sections, including:
  - page title and heading
  - major `Choose ...` navigation lines
  - common line/area/transparency/text-format sections
  - icon labels and visible UI names where they were still English
- Converted the opening sections of `Number Format Codes` to Chinese-first wording:
  - title and primary heading
  - introductory rules for number-format sections
  - decimal-place/significant-digit explanation
  - examples table
  - thousands separator section
  - text-in-format, spaces, color, conditions, percentages, scientific notation, fractions, currency, and date/time lead-in sections
- Localized the high-use Writer shortcut page so users no longer land on an English-first keyboard-help page:
  - page title and description
  - major section headings
  - many action/effect labels
  - visible note text and key task descriptions
- Fully localized the shared onboarding and core document-flow Help pages:
  - `startcenter`: title, headings, onboarding text, templates section, recent documents section, create-document descriptions, and note text
  - `doc_open`: title, headings, major guidance prose, open/open-remote steps, file-type filter guidance, cursor-position explanation, and new-document guidance
  - `doc_save`: title, save behavior, save-as guidance, backup note, file-extension section, examples table, and visible related-link labels
- Preserved XML structure, IDs, bookmarks, anchors, switch blocks, hrefs, and functional literals like shortcuts, file-format acronyms, and command/menu semantics where they are required for accurate product guidance.

Verification:

- `xmllint --noout` passed for:
  - `00040502.xhp`
  - `05020301.xhp`
  - `01020000.xhp`
  - `startcenter.xhp`
  - `doc_open.xhp`
  - `doc_save.xhp`
- Rebuilt the Help pipeline multiple times during the round:
  - `gmake -C /Users/lu/kdoffice-build2 helpcontent2.build postprocess.build`
  - all rebuilds completed successfully
- Verified in the installed app bundle under `/Users/lu/kdoffice-build2/instdir/可圈office.app/Contents/Resources/help` that the targeted pages improved as follows:
  - `shared/00/00040502.html`: `340` -> `207`
  - `shared/01/05020301.html`: `428` -> `370`
  - `swriter/04/01020000.html`: `280` -> `145`
  - `shared/guide/startcenter.html`: `22` -> `0`
  - `shared/guide/doc_open.html`: `21` -> `5`
  - `shared/guide/doc_save.html`: `30` -> `9`
- Spot-checks confirm the remaining matches now fall into narrower categories:
  - still-untranslated embedded child-page titles not yet patched
  - shortcut literals like `Ctrl`, `Command`, or `Shift+F5`
  - unavoidable format acronyms such as `ODF`, `XML`, or product/module identifiers in specific technical contexts

What Round 28 Does Not Solve:

- The large shared reference pages `00040502` and `05020301` still contain substantial deeper English below the high-visibility sections translated in this round.
- Some remaining English on `doc_open` and `doc_save` is inherited from embedded related-topic pages that were not patched yet.
- Calc and Impress guide hub pages and other common shared workflow pages still need the same installed-output-first treatment.

## Next Rounds

Round 29:

- Continue the shared Help cleanup with the highest-ROI user workflow pages:
  - `shared/guide/template_manager`
  - `shared/01/ref_pdf_export_general`
  - `swriter/guide/pageorientation`
  - `swriter/guide/pagenumbers`
- After that, localize the Calc and Impress guide hub pages (`scalc/guide/main`, `simpress/guide/main`) so the Help Center navigation surface itself becomes Chinese-first.

## Round 29

Goal: keep the shared Help cleanup focused on everyday office workflows by translating template management, PDF export, and common Writer page-layout guidance, then verify the installed app bundle rather than stopping at source edits.

Changes:

- Localized these Help source pages:
  - `helpcontent2/source/text/shared/guide/template_manager.xhp`
  - `helpcontent2/source/text/shared/01/ref_pdf_export_general.xhp`
  - `helpcontent2/source/text/swriter/guide/pageorientation.xhp`
  - `helpcontent2/source/text/swriter/guide/pagenumbers.xhp`
- Reworked the visible user-facing English in the template-management page into Chinese-first wording, including:
  - page title and top-level guidance
  - template search, filter, import, export, move, and delete explanations
  - thumbnail/list-view help and other main workflow text
- Localized the visible PDF-export guidance on the General tab page, including:
  - page title and overview wording
  - option descriptions for range, images, forms, tagged PDF, comments, and watermark-related choices
  - other user-facing explanatory text that appears directly on the page
- Localized the Writer page-orientation workflow page so users no longer land on English instructions when switching between portrait and landscape layouts.
- Localized the Writer page-number workflow page so the common footer/page-number setup path is Chinese-first in the installed Help output.
- Preserved IDs, anchors, bookmarks, XML structure, and required functional literals such as key names, command tokens, and related-topic links where they still serve a product-guidance purpose.

Verification:

- `xmllint --noout` passed for:
  - `template_manager.xhp`
  - `ref_pdf_export_general.xhp`
  - `pageorientation.xhp`
  - `pagenumbers.xhp`
- Rebuilt the Help pipeline:
  - `gmake -C /Users/lu/kdoffice-build2 helpcontent2.build postprocess.build`
  - rebuild completed successfully
- Verified in the installed app bundle under `/Users/lu/kdoffice-build2/instdir/可圈office.app/Contents/Resources/help` that the target pages improved as follows:
  - `shared/guide/template_manager.html`: `103` -> `13`
  - `shared/01/ref_pdf_export_general.html`: `92` -> `19`
  - `swriter/guide/pageorientation.html`: `47` -> `25`
  - `swriter/guide/pagenumbers.html`: `48` -> `11`
- Spot-checks confirm the remaining matches are now mostly narrow residue rather than main prose, for example:
  - key literals such as `Ctrl`, `Command`, `Enter`, `Delete`, `Ctrl+F9`, and `Ctrl+Enter`
  - still-untranslated menu-path or dialog-label literals on a few reference pages
  - embedded related-topic titles whose child pages were not yet translated in this round

What Round 29 Does Not Solve:

- `template_manager`, `ref_pdf_export_general`, and `pageorientation` still retain some visible English through embedded child-topic titles, menu-path literals, and shortcut keys.
- The larger Help Center navigation surface is still mixed because many shared workflow pages and guide hubs remain English-heavy.
- This is still an installed-output cleanup of the shipped `en-US` Help corpus, not a full standalone `zh-CN` Help pack.

## Next Rounds

Round 30:

- Continue the shared Help cleanup on pages that ordinary Chinese users hit across multiple modules:
  - `shared/guide/language_select`
  - `shared/guide/manage_templates`
  - `shared/guide/standard_template`
  - `shared/guide/import_ms`
  - `shared/guide/pasting`
- After the shared-workflow batch, re-evaluate whether the next biggest win is:
  - deeper shared workflow pages such as `insert_bitmap`, `paintbrush`, and `keyboard`
  - or linked child pages that dominate the Writer/Calc/Impress guide hubs

## Round 30

Goal: push the Help Center deeper into Chinese-first daily usage by translating shared workflow pages that users encounter across multiple modules, especially language settings, templates, Office-format opening, paste behavior, and the formatting brush.

Changes:

- Localized these shared Help source pages:
  - `helpcontent2/source/text/shared/guide/language_select.xhp`
  - `helpcontent2/source/text/shared/guide/manage_templates.xhp`
  - `helpcontent2/source/text/shared/guide/standard_template.xhp`
  - `helpcontent2/source/text/shared/guide/import_ms.xhp`
  - `helpcontent2/source/text/shared/guide/pasting.xhp`
  - `helpcontent2/source/text/shared/guide/paintbrush.xhp`
- Reworked the visible user-facing English in the language-selection page into Chinese-first wording, including:
  - document language scope and priority rules
  - paragraph-style, character-style, and direct-formatting steps
  - dictionary-extension guidance
  - UI-language setup and extra-language installation guidance across Windows, Linux, and macOS branches
- Localized the template-management workflow pages so the Chinese template strategy is backed by Chinese help instead of English operational text:
  - template-file and extension explanations
  - template naming and title-field behavior
  - default/custom template creation and modification
  - template paths, categories, and save-location rules
- Localized the Office-format opening help page so common migration guidance is Chinese-first:
  - opening files in other formats
  - default file-format settings
  - document-converter wizard guidance
  - Writer-specific HTML-open behavior
- Localized the shared paste-behavior help page and the formatting-brush page:
  - special paste behavior, options, and shortcut explanation
  - format brush usage flow, warnings, and the selection-type capability table
- Preserved IDs, anchors, bookmarks, XML structure, and required literals such as file extensions, app names, keyboard keys, and technical filenames where they remain necessary for accurate product guidance.

Verification:

- `xmllint --noout` passed for:
  - `language_select.xhp`
  - `manage_templates.xhp`
  - `standard_template.xhp`
  - `import_ms.xhp`
  - `pasting.xhp`
  - `paintbrush.xhp`
- Rebuilt the Help pipeline:
  - `gmake -C /Users/lu/kdoffice-build2 helpcontent2.build postprocess.build`
  - rebuild completed successfully
- Verified in the installed app bundle under `/Users/lu/kdoffice-build2/instdir/可圈office.app/Contents/Resources/help` that the target pages improved as follows:
  - `shared/guide/language_select.html`: `57` -> `0`
  - `shared/guide/manage_templates.html`: `40` -> `10`
  - `shared/guide/standard_template.html`: `28` -> `3`
  - `shared/guide/import_ms.html`: `21` -> `5`
  - `shared/guide/pasting.html`: `18` -> `2`
  - `shared/guide/paintbrush.html`: `36` -> `5`
- Spot-checks confirm that the remaining matches are now narrow residue rather than untranslated body prose, for example:
  - keyboard literals such as `Command`, `Ctrl`, and `Command+Option`
  - technical path/file literals such as `groupuinames.xml`, `template`, and `Paths`
  - embedded child-topic titles not yet patched, such as:
    - `Templates and Styles`
    - `XML File Formats`
    - `Saving Documents in Other Formats`
    - `Clone Formatting`

What Round 30 Does Not Solve:

- The remaining English on `manage_templates`, `standard_template`, `import_ms`, and `paintbrush` is now dominated by linked child-page titles, key names, and technical path labels rather than page-local prose.
- The large guide hubs for Writer, Calc, and Impress still inherit many English child-topic titles, so the Help Center navigation surface is not yet fully Chinese-first.
- Deeper shared pages such as `insert_bitmap`, `keyboard`, and other broad workflow references still contain sizable visible English and remain high-value cleanup targets.

## Next Rounds

Round 31:

- Localize the next highest-yield shared workflow pages:
  - `shared/guide/insert_bitmap`
  - `shared/guide/keyboard`
  - `shared/guide/dragdrop`
  - `shared/guide/accessibility`
- Then attack the child-topic pages that dominate cross-module navigation residue, starting with:
  - `shared/02/paintbrush`
  - `shared/guide/ms_import_export_limitations`
  - the highest-frequency child topics linked from `swriter/guide/main`, `scalc/guide/main`, and `simpress/guide/main`

## Round 31

Goal: keep the Help cleanup moving with a high-yield, tractable shared-workflow batch by translating image handling, drag-and-drop, accessibility overview, Office-conversion limitations, and the `Clone Formatting` child page that still leaked English into already cleaned parent pages.

Changes:

- Localized these Help source pages:
  - `helpcontent2/source/text/shared/guide/insert_bitmap.xhp`
  - `helpcontent2/source/text/shared/guide/dragdrop.xhp`
  - `helpcontent2/source/text/shared/guide/accessibility.xhp`
  - `helpcontent2/source/text/shared/guide/ms_import_export_limitations.xhp`
  - `helpcontent2/source/text/shared/02/paintbrush.xhp`
- Reworked the visible English in the bitmap workflow page into Chinese-first wording, including:
  - insert/link/embed guidance
  - image-bar, filter, and image-dialog explanations
  - Draw/Impress export steps
  - Writer bitmap-export help text
- Localized the shared drag-and-drop overview:
  - page title and main explanation
  - mouse-pointer table headers, row labels, and image alt text
  - modifier-key guidance
  - Navigator note and drag-cancel tip
- Localized the shared accessibility overview page:
  - page title and intro
  - feature bullet list
  - zoom/scaling explanation
  - Java/accessive-tools note
  - related menu-path labels
- Localized the Office-conversion limitations page:
  - title and overview paragraphs
  - Microsoft Word / PowerPoint / Excel compatibility lists
  - Calc-vs-Excel boolean example explanation
  - password-protected document section and encryption table labels
  - related-link label for default file format
- Localized the `shared/02/paintbrush` child page so the remaining `Clone Formatting` residue drops from already cleaned pages that embed or link to this command page.
- Preserved IDs, anchors, bookmarks, XML structure, menu-path semantics, formulas, file-format/version literals, and technical tokens where they still serve actual product guidance.

Verification:

- `xmllint --noout` passed for:
  - `insert_bitmap.xhp`
  - `dragdrop.xhp`
  - `accessibility.xhp`
  - `ms_import_export_limitations.xhp`
  - `shared/02/paintbrush.xhp`
- Rebuilt the Help pipeline:
  - `gmake -C /Users/lu/kdoffice-build2 helpcontent2.build postprocess.build`
  - rebuild completed successfully
- Verified in the installed app bundle under `/Users/lu/kdoffice-build2/instdir/可圈office.app/Contents/Resources/help` that the target pages improved as follows:
  - `shared/guide/insert_bitmap.html`: `65` -> `6`
  - `shared/guide/dragdrop.html`: `27` -> `11`
  - `shared/guide/accessibility.html`: `21` -> `4`
  - `shared/guide/ms_import_export_limitations.html`: `53` -> `16`
  - `shared/02/paintbrush.html`: `13` -> `0`
- Verified spillover improvements on already localized parent pages:
  - `shared/guide/paintbrush.html`: `5` -> `4`
  - `shared/guide/import_ms.html`: `5` -> `4`
- Spot-checks confirm that the remaining matches are now mainly:
  - embedded child-topic titles such as image-insertion or gallery topics
  - keyboard literals such as `Command` and `Ctrl`
  - product/version literals such as `Microsoft Word`, `Microsoft Excel`, `Word 97`, `Excel XP`, and formula tokens like `TRUE`

What Round 31 Does Not Solve:

- The large shared `keyboard` page is still one of the biggest remaining English hotspots and needs a dedicated round rather than a sidecar patch.
- `insert_bitmap`, `dragdrop`, `accessibility`, and `ms_import_export_limitations` still inherit some English from linked child pages, product/version names, or required key literals.
- The Help Center navigation surface remains mixed because many child pages behind Writer/Calc/Impress guide hubs are still English-heavy.

## Next Rounds

Round 32:

- Localize the child/help dependency pages that now dominate residue on the Office-conversion and accessibility paths:
  - `shared/guide/ms_user`
  - `shared/guide/ms_doctypes`
  - `shared/guide/assistive`
  - `swriter/01/accessibility_check`
- After that, decide between:
  - a dedicated `shared/guide/keyboard` round
  - or another shared child-topic pass around `XML File Formats`, `Saving Documents in Other Formats`, and image-related child pages

## Round 32

Goal: remove the next layer of English inherited through child-topic pages so previously cleaned parent help pages stop reintroducing English around Microsoft Office usage and accessibility support.

Changes:

- Localized these Help source pages:
  - `helpcontent2/source/text/shared/guide/ms_user.xhp`
  - `helpcontent2/source/text/shared/guide/ms_doctypes.xhp`
  - `helpcontent2/source/text/shared/guide/assistive.xhp`
  - `helpcontent2/source/text/swriter/01/accessibility_check.xhp`
- Localized the Microsoft Office usage guide:
  - open/save guidance
  - default-format settings
  - document-converter wizard explanation
  - macro-compatibility guidance and VBA-handling instructions
- Localized the Microsoft Office file-association page for Windows users so the child title no longer leaks English into related Office-format help.
- Localized the assistive-tools page and the Writer accessibility-check page so the shared accessibility surface becomes more Chinese-first beyond the parent landing page.
- Preserved IDs, bookmarks, formulas, product/version/file-extension literals, and functional menu-path structure where the literal content is still useful for accurate product guidance.

Verification:

- `xmllint --noout` passed for:
  - `ms_user.xhp`
  - `ms_doctypes.xhp`
  - `assistive.xhp`
  - `accessibility_check.xhp`
- Rebuilt the Help pipeline:
  - `gmake -C /Users/lu/kdoffice-build2 helpcontent2.build postprocess.build`
  - rebuild completed successfully
- Verified in the installed app bundle under `/Users/lu/kdoffice-build2/instdir/可圈office.app/Contents/Resources/help` that the target pages improved as follows:
  - `shared/guide/ms_user.html`: `48` -> `7`
  - `shared/guide/ms_doctypes.html`: `9` -> `0`
  - `shared/guide/assistive.html`: `13` -> `3`
  - `swriter/01/accessibility_check.html`: `32` -> `10`
- Verified spillover improvements on parent pages:
  - `shared/guide/accessibility.html`: `4` -> `2`
  - `shared/guide/import_ms.html`: `4` -> `2`
  - `shared/guide/ms_import_export_limitations.html`: `16` -> `14`
- Spot-checks confirm that the remaining matches are now dominated by:
  - still-untranslated child pages such as `General Shortcut Keys in 可圈office`
  - keyboard/menu literals in `Accessibility Check`
  - product/version literals such as `Microsoft Word`, `Microsoft Excel`, and file-extension examples
  - technical/editor identifiers such as `Basic IDE`

What Round 32 Does Not Solve:

- The shared shortcut/keyboard family remains the biggest unresolved accessibility/help hotspot:
  - `shared/guide/keyboard`
  - `shared/04/01010000`
- `import_ms` still inherits English from child topics like `XML File Formats` and `Saving Documents in Other Formats`.
- Image-related child pages still dominate the remaining English on `insert_bitmap`.

## Next Rounds

Round 33:

- Do a dedicated high-depth cleanup on the shared keyboard/accessibility stack:
  - `shared/guide/keyboard`
  - `shared/04/01010000`
- Then continue the Office-format child-topic path:
  - `shared/00/00000021` (`XML File Formats`)
  - `shared/guide/export_ms`
- After that, return to the image-related child pages behind `insert_bitmap` and the Writer/Calc/Impress guide hubs.

## Round 33

Goal: finish the blocking shared shortcut/accessibility stack and remove shared embedded English notes that were still leaking into otherwise localized help pages.

Changes:

- Carried the previously partial `shared/guide/keyboard.xhp` localization forward into a validated rebuild, keeping the page XML-valid and user-facing Chinese-first instead of leaving the unfinished mixed state unverified.
- Localized the large shared shortcut reference page:
  - `helpcontent2/source/text/shared/04/01010000.xhp`
  - translated the unified-code/automatic-completion mixed paragraphs
  - translated the `Gallery` shortcut headings and labels into Chinese
  - translated the database-table shortcut section
  - translated the drawing-object shortcut section
  - normalized user-visible English connectors such as `or` to Chinese
- Localized the shared note source that is embedded across multiple shortcut/help pages:
  - `helpcontent2/source/text/shared/00/00000099.xhp`
  - translated the desktop-system shortcut warning
  - translated the `X Window Manager` availability note
- Cleaned the last visible English URL-style label on:
  - `helpcontent2/source/text/shared/guide/assistive.xhp`
- Preserved IDs, anchors, bookmarks, XML structure, key combinations, shortcut semantics, and technical literals where those literals are still useful for actual keyboard guidance.

Verification:

- `xmllint --noout` passed for:
  - `keyboard.xhp`
  - `01010000.xhp`
  - `00000099.xhp`
  - `assistive.xhp`
- Rebuilt the Help pipeline:
  - `gmake -C /Users/lu/kdoffice-build2 helpcontent2.build postprocess.build`
  - rebuild completed successfully
- Verified in the installed app bundle under `/Users/lu/kdoffice-build2/instdir/可圈office.app/Contents/Resources/help` that the target pages improved as follows:
  - `shared/guide/keyboard.html`: `247` -> `69`
  - `shared/04/01010000.html`: `383` -> `103`
  - `shared/guide/accessibility.html`: `2` -> `0`
  - `shared/guide/assistive.html`: `3` -> `0`
- Spot-checks confirm that the remaining matches are now mainly:
  - shortcut key literals such as `Ctrl`, `Alt`, `Tab`, `Enter`, `Home`, and `Page Up/Page Down`
  - module or technical literals such as `Writer`, `Calc`, and `OLE`
  - a smaller set of arrow-key names and key labels on the keyboard-heavy pages

What Round 33 Does Not Solve:

- The shared keyboard family is not yet at true zero-English; the remaining residue is mostly key-label vocabulary rather than long untranslated prose blocks.
- The Office-format child-topic path still remains:
  - `shared/00/00000021`
  - `shared/guide/export_ms`
- Image-related child pages behind `insert_bitmap` are still pending.
- This round improves the Help Center substantially, but it does not by itself prove that the entire app UI, icon set, font stack, and brand migration are all completely finished.

## Next Rounds

Round 34:

- Choose between a strict key-label cleanup pass on:
  - `shared/guide/keyboard`
  - `shared/04/01010000`
- Or move to the next highest-value Chinese help pages:
  - `shared/00/00000021`
  - `shared/guide/export_ms`
  - image-related child pages behind `insert_bitmap`
- Then continue the Writer/Calc/Impress guide-hub child pages.

## Round 34

Goal: keep shortcut labels intact while removing the remaining user-facing explanatory English that still leaks through related shortcut topics.

Changes:

- Localized the explanatory text in:
  - `helpcontent2/source/text/shared/04/01020000.xhp`
- Preserved shortcut cells and key labels such as `Delete`, `Tab`, `Ctrl`, `Alt`, `PgUp`, `PgDn`, and arrow-key names.
- Translated:
  - page title and H1
  - introductory paragraphs
  - section headings
  - table headers
  - all effect/explanation cells
- This removes the visible `Database Shortcut Keys` leak from the related-topics area of `01010000`.

Verification:

- `xmllint --noout` passed for:
  - `01020000.xhp`
- Rebuilt the Help pipeline:
  - `gmake -C /Users/lu/kdoffice-build2 helpcontent2.build postprocess.build`
  - rebuild completed successfully
- Verified in the installed app bundle under `/Users/lu/kdoffice-build2/instdir/可圈office.app/Contents/Resources/help` that the target pages improved as follows:
  - `shared/04/01010000.html`: `103` -> `102`
  - `shared/04/01020000.html`: visible explanatory English removed; remaining matches are shortcut labels

What Round 34 Does Not Solve:

- The remaining counts on shortcut-heavy pages are now overwhelmingly shortcut labels rather than untranslated explanatory prose.
- `shared/guide/keyboard.html`, `shared/04/01010000.html`, and `shared/04/01020000.html` still contain English key names by design under the current rule.
- The next unmet Chinese-help priorities remain:
  - `shared/00/00000021`
  - `shared/guide/export_ms`
  - image-related child pages behind `insert_bitmap`

## Round 35

Goal: continue the Chinese Help Center cleanup on the next highest-value Office-format and image-related child pages, translating user-facing explanation while preserving file extensions, standard identifiers, and other genuinely useful technical literals.

Changes:

- Localized the Office-format help pair:
  - `helpcontent2/source/text/shared/guide/export_ms.xhp`
  - `helpcontent2/source/text/shared/00/00000021.xhp`
- For `export_ms.xhp`, translated:
  - page title and H1
  - the step-by-step save instructions
  - the default-format explanation
  - the visible related link label for `Save As`
- For `00000021.xhp`, translated:
  - page title and H1
  - the OpenDocument explanation note
  - section headings and table headers
  - human-readable file-format names
  - OpenDocument evolution section labels
  - XML file structure explanation
  - related link label for `Document Converter Wizard`
- Preserved file extensions, ODF version numbers, and product/version identifiers such as `OpenOffice.org`, `StarOffice`, `LibreOffice`, `ODF`, `HTML`, and `OpenDocument` where those identifiers still carry real product meaning.
- Localized the image-related child pages that were leaking English into `insert_bitmap`:
  - `helpcontent2/source/text/shared/guide/imagemap.xhp`
  - `helpcontent2/source/text/shared/guide/gallery_insert.xhp`
  - `helpcontent2/source/text/swriter/guide/insert_graphic_dialog.xhp`
  - `helpcontent2/source/text/swriter/guide/insert_graphic_scan.xhp`
  - `helpcontent2/source/text/swriter/guide/insert_graphic_fromdraw.xhp`
  - `helpcontent2/source/text/swriter/guide/insert_graphic_fromchart.xhp`
- This image batch translated the visible page titles and main instructional text so `insert_bitmap` no longer inherits raw English child-topic titles.

Verification:

- `xmllint --noout` passed for:
  - `export_ms.xhp`
  - `00000021.xhp`
  - `imagemap.xhp`
  - `gallery_insert.xhp`
  - `insert_graphic_dialog.xhp`
  - `insert_graphic_scan.xhp`
  - `insert_graphic_fromdraw.xhp`
  - `insert_graphic_fromchart.xhp`
- Rebuilt the Help pipeline successfully after each change batch:
  - `gmake -C /Users/lu/kdoffice-build2 helpcontent2.build postprocess.build`
- Verified in the installed app bundle under `/Users/lu/kdoffice-build2/instdir/可圈office.app/Contents/Resources/help` that the target pages improved as follows:
  - `shared/guide/export_ms.html`: `7` -> `0`
  - `shared/00/00000021.html`: `65` -> `56`
  - `shared/guide/insert_bitmap.html`: `6` -> `0`
  - `shared/guide/imagemap.html`: `28` -> `16`
  - `shared/guide/gallery_insert.html`: `29` -> `6`
  - `swriter/guide/insert_graphic_dialog.html`: `7` -> `1`
  - `swriter/guide/insert_graphic_scan.html`: `11` -> `2`
  - `swriter/guide/insert_graphic_fromdraw.html`: `11` -> `3`
  - `swriter/guide/insert_graphic_fromchart.html`: `13` -> `2`
- Verified spillover improvement on the Office-format parent page:
  - `shared/guide/import_ms.html`: `2` -> `1`

What Round 35 Does Not Solve:

- `shared/00/00000021.html` still carries many standard identifiers that the regex counts as English, including:
  - `ODF`
  - `OpenDocument`
  - `HTML`
  - file extensions such as `*.odt`
  - product/version identifiers such as `OpenOffice.org` and `LibreOffice`
- `shared/guide/imagemap.html` still embeds English from deeper shared definition/help pages around `ImageMap`, `URL`, client/server-side explanations, and HTML-related definitions.
- `shared/guide/gallery_insert.html` still inherits English from deeper related topics such as:
  - `Gallery`
  - `Adding Graphics to the Gallery`
  - `Copying Graphics Between Documents`
  - `Copying Spreadsheet Areas to Text Documents`
  - `Moving and Copying Text in Documents`

## Round 36

Goal: continue the image/help dependency chain behind `shared/guide/imagemap` and `shared/guide/gallery_insert`, reducing inherited English on the Gallery and drag-and-drop child pages while keeping shortcut labels and technical literals intact.

Changes:

- Localized the following help sources:
  - `helpcontent2/source/text/shared/00/00000002.xhp`
  - `helpcontent2/source/text/shared/01/gallery.xhp`
  - `helpcontent2/source/text/shared/guide/dragdrop_gallery.xhp`
  - `helpcontent2/source/text/shared/guide/dragdrop_graphic.xhp`
  - `helpcontent2/source/text/shared/guide/dragdrop_table.xhp`
  - `helpcontent2/source/text/swriter/guide/dragdroptext.xhp`
- In `00000002.xhp`, translated the glossary sections that were directly leaking into the ImageMap help chain:
  - `Frames`
  - `HTML`
  - `Hyperlink`
  - `ImageMap`
  - `ImageMap Formats`
  - `Server Side ImageMaps`
  - `Client Side ImageMap`
  - `Search Engines`
  - `Tags`
  - `URL`
- In `gallery.xhp`, translated the page title, H1, visible gallery UI/help text, and object/theme descriptions.
- In the drag-and-drop pages, translated the visible titles, headings, instructional paragraphs, and relevant image `alt` text.
- Preserved shortcut key names such as `Option`, `Alt`, and `Ctrl` where they are useful as direct user guidance.

Verification:

- `xmllint --noout` passed for:
  - `00000002.xhp`
  - `gallery.xhp`
  - `dragdrop_gallery.xhp`
  - `dragdrop_graphic.xhp`
  - `dragdrop_table.xhp`
  - `dragdroptext.xhp`
- Rebuilt the Help pipeline successfully:
  - `gmake -C /Users/lu/kdoffice-build2 helpcontent2.build postprocess.build`
- Verified in the installed app bundle under `/Users/lu/kdoffice-build2/instdir/可圈office.app/Contents/Resources/help` that the target pages improved as follows:
  - `shared/guide/imagemap.html`: `16` -> `9`
  - `shared/guide/gallery_insert.html`: `6` -> `1`
  - `shared/00/00000002.html`: `52` -> `32`
  - `shared/01/gallery.html`: `51` -> `23`
  - `shared/guide/dragdrop_gallery.html`: `11` -> `1`
  - `shared/guide/dragdrop_graphic.html`: `13` -> `1`
  - `shared/guide/dragdrop_table.html`: `13` -> `0`
  - `swriter/guide/dragdroptext.html`: `11` -> `1`

What Round 36 Does Not Solve:

- `shared/guide/imagemap.html` still retained mostly technical literals rather than raw explanatory English, including:
  - `ImageMap`
  - `URL`
  - `HTML`
  - `W3C (CERN) HTTP Server`
  - `NCSA HTTP Server`
  - `SIP - StarView ImageMap`
- `shared/01/gallery.html` was still inheriting untranslated common command/help snippets from:
  - `shared/00/00000010`
  - `shared/00/01050000`
- `shared/00/00000002.html` still remained mixed because many standalone glossary entries were still English at that point, especially technical acronyms and standards entries.

## Round 37

Goal: clean the remaining shared Gallery command/help snippets and the ImageMap editor/help chain, translating visible explanatory English while preserving useful shortcuts and true technical format names.

Changes:

- Localized shared Gallery command/help pages:
  - `helpcontent2/source/text/shared/00/00000010.xhp`
  - `helpcontent2/source/text/shared/00/01050000.xhp`
- Localized the remaining standalone glossary prose in:
  - `helpcontent2/source/text/shared/00/00000002.xhp`
- Specifically translated the glossary entries or explanations for:
  - `CMIS`
  - `DOI`
  - `EPUB`
  - `WebDAV`
  - `HTTP`
  - `Java`
  - `Proxy`
  - `SGML`
- Localized the ImageMap editor/help chain:
  - `helpcontent2/source/text/shared/01/02220000.xhp`
  - `helpcontent2/source/text/shared/00/00000406.xhp` (ImageMap subsection only)
  - `helpcontent2/source/text/shared/guide/imagemap.xhp`
- Replaced visible explanatory `ImageMap` / `ImageMap 编辑器` wording with Chinese `图像映射` / `图像映射编辑器` where the term was being used as prose or help-label text.
- Preserved shortcut labels and technical literals where they still carry real product meaning, including:
  - `Option`
  - `Alt`
  - `Ctrl`
  - `URL`
  - `HTML`
  - `MAP-CERN`
  - `MAP-NCSA`
  - `SIP StarView ImageMap`

Verification:

- `xmllint --noout` passed for:
  - `00000010.xhp`
  - `01050000.xhp`
  - `00000002.xhp`
  - `02220000.xhp`
  - `00000406.xhp`
  - `imagemap.xhp`
- Rebuilt the Help pipeline successfully after both shared and ImageMap passes:
  - `gmake -C /Users/lu/kdoffice-build2 helpcontent2.build postprocess.build`
- Verified in the installed app bundle under `/Users/lu/kdoffice-build2/instdir/可圈office.app/Contents/Resources/help` that the target pages improved as follows:
  - `shared/01/gallery.html`: `23` -> `1`
  - `shared/00/00000002.html`: `32` -> `27`
  - `shared/guide/imagemap.html`: `9` -> `6`
  - `shared/01/02220000.html`: `77` -> `2`
- Verified shared-page cleanup results:
  - `shared/00/00000010.html`: reduced to `1` remaining match, caused by the literal placeholder example `xxx`
  - `shared/00/01050000.html`: visible explanatory English removed
  - `shared/guide/gallery_insert.html`: remains at `1`, now only a shortcut-key label line

What Round 37 Does Not Solve:

- `shared/00/00000002.html` still contains many regex matches, but they are now dominated by preserved technical acronyms, standards names, and mixed technical literals such as:
  - `CMIS`
  - `DOI`
  - `EPUB`
  - `HTML`
  - `HTTP`
  - `Java`
  - `SGML`
  - `URL`
  - `WebDAV`
- `shared/guide/imagemap.html` is now mostly clean Chinese help prose, with the remaining matches coming from preserved technical terms such as `URL`, `HTML`, `MAP - CERN`, `MAP - NCSA`, and `SIP - StarView ImageMap`.
- `shared/00/00000406.html` remains broadly English because only the ImageMap-related subsection was localized in this round; the file as a whole is a much larger shared tools-menu reference page and would require a separate dedicated pass.

## Round 38

Goal: reduce the remaining English in the shared View help chain feeding `shared/main0103.html`, focusing on direct user-visible explanatory text while preserving shortcuts, command literals, and XML structure.

Changes:

- Localized the shared View-related pages:
  - `helpcontent2/source/text/shared/01/notebook_bar.xhp`
  - `helpcontent2/source/text/shared/01/03990000.xhp`
  - `helpcontent2/source/text/shared/01/03060000.xhp`
  - `helpcontent2/source/text/shared/01/scrollbars.xhp`
  - `helpcontent2/source/text/shared/01/grid_and_helplines.xhp`
  - `helpcontent2/source/text/shared/01/menu_view_sidebar.xhp`
  - `helpcontent2/source/text/shared/01/03110000.xhp`
  - `helpcontent2/source/text/shared/guide/floating_toolbar.xhp`
  - `helpcontent2/source/text/shared/guide/autohide.xhp`
- Localized shared menu/help fragments embedded by those pages:
  - `helpcontent2/source/text/shared/00/00000403.xhp`
  - `helpcontent2/source/text/shared/00/00000004.xhp` (`displaygrid` / `snaptogrid` sections only)
- Localized related grid/baseline child pages:
  - `helpcontent2/source/text/shared/02/01171200.xhp`
  - `helpcontent2/source/text/shared/02/01171300.xhp`
  - `helpcontent2/source/text/shared/02/gridtofront.xhp`
  - `helpcontent2/source/text/shared/02/01171400.xhp`
  - `helpcontent2/source/text/shared/optionen/01050100.xhp` (`snap_to_grid` paragraph only)
  - `helpcontent2/source/text/swriter/01/baseline_grid.xhp`
- Replaced English explanatory prose in notebook bar, sidebar, scrollbars, floating toolbar, auto-hide, grid, and baseline-grid help with Chinese help text aligned to the current `可圈office` product branding.
- Corrected the sidebar related-topic link in `menu_view_sidebar.xhp` to:
  - `text/shared/01/sidebar_customization.xhp`

Verification:

- `xmllint --noout` passed for all edited files in this round.
- Rebuilt the help pipeline successfully:
  - `gmake -C /Users/lu/kdoffice-build2 helpcontent2.build postprocess.build`
- Verified in the installed app bundle under `/Users/lu/kdoffice-build2/instdir/可圈office.app/Contents/Resources/help/en-US` that the target pages improved as follows:
  - `shared/01/notebook_bar.html`: `31` -> `0`
  - `shared/01/03990000.html`: `12` -> `0`
  - `shared/01/03060000.html`: `9` -> `0`
  - `shared/01/scrollbars.html`: `19` -> `0`
  - `shared/01/menu_view_sidebar.html`: `11` -> `1`
  - `shared/guide/floating_toolbar.html`: `2` -> `1`
  - `shared/guide/autohide.html`: remains `1`
  - `shared/01/grid_and_helplines.html`: `23` -> `2`
  - `shared/01/03110000.html`: `10` -> `4`
  - `shared/02/01171300.html`: `5` -> `4`
  - `swriter/01/baseline_grid.html`: remains `3`
  - `shared/main0103.html`: `209` -> `158`

What Round 38 Does Not Solve:

- The remaining matches in `menu_view_sidebar`, `floating_toolbar`, and `autohide` are shortcut-key literals such as `Command`, `Ctrl`, or menu-key combinations, which are intentionally preserved.
- The remaining matches in `grid_and_helplines`, `03110000`, `01171300`, and `baseline_grid` are dominated by shortcut labels, product/module names, or technical literals such as `Writer`, `Calc`, `Esc`, `Option`, `Alt`, `HTML`, and `XML`.
- `shared/main0103.html` is significantly cleaner, but it still inherits English from deeper child pages including `03010000`, `view_comments`, `styles`, `navigator`, `04180100`, and several Writer/Calc view topics that require additional dedicated passes.

## Round 39

Goal: clear the next high-impact shared View dependencies behind `shared/main0103.html`, especially `Zoom`, `Comments`, `Data Sources`, and the large `Styles` help chain.

Changes:

- Localized these shared/user-facing help pages:
  - `helpcontent2/source/text/shared/01/03010000.xhp`
  - `helpcontent2/source/text/shared/01/view_comments.xhp`
  - `helpcontent2/source/text/shared/01/04180100.xhp`
  - `helpcontent2/source/text/shared/01/graphic_styles.xhp`
  - `helpcontent2/source/text/shared/01/styles.xhp`
- Localized embedded/shared menu fragments feeding those pages:
  - `helpcontent2/source/text/shared/00/00040500.xhp` (`stylewindow` section)
  - `helpcontent2/source/text/shared/00/00000403.xhp` (`data_sources` section)
  - `helpcontent2/source/text/swriter/00/00000405.xhp` (`loadstyles` section)
- Localized the first linked child topics under `Styles`:
  - `helpcontent2/source/text/swriter/01/05130000.xhp`
  - `helpcontent2/source/text/swriter/01/05170000.xhp`
  - `helpcontent2/source/text/shared/01/new_style.xhp`
  - `helpcontent2/source/text/shared/01/edit_style.xhp`
  - `helpcontent2/source/text/shared/01/delete_style.xhp`
- Replaced several embedded related-topic titles with explicit Chinese links in parent pages to eliminate installed-output English without waiting for full downstream topic translation.

Verification:

- `xmllint --noout` passed for all edited files in this round.
- Rebuilt successfully:
  - `gmake -C /Users/lu/kdoffice-build2 helpcontent2.build postprocess.build`
- Verified in the installed app bundle under `/Users/lu/kdoffice-build2/instdir/可圈office.app/Contents/Resources/help/en-US`:
  - `shared/01/03010000.html`: `36` -> `0`
  - `shared/01/view_comments.html`: `13` -> `0`
  - `shared/01/04180100.html`: `16` -> `1`
  - `shared/01/styles.html`: `142` -> `2`
  - `shared/01/graphic_styles.html`: `46` -> `29`
  - `swriter/01/05130000.html`: `50` -> `3`
  - `swriter/01/05170000.html`: `42` -> `3`
  - `shared/01/new_style.html`: `88` -> `83`
  - `shared/01/edit_style.html`: `94` -> `84`
  - `shared/01/delete_style.html`: `9` -> `2`
  - `shared/main0103.html`: `158` -> `138`

What Round 39 Does Not Solve:

- `shared/01/04180100.html` now only leaves shortcut-key literals such as `Command` / `Ctrl` plus untranslated downstream related-topic pages.
- `shared/01/styles.html` is reduced to shortcut literals and the preserved technical literal `HTML`.
- `shared/01/new_style.html` and `shared/01/edit_style.html` remain English-heavy because they embed many deeper style-dialog topic pages that were not translated in this round.
- `shared/01/graphic_styles.html` remains English-heavy for the same reason: most remaining residue comes from many embedded formatting-tab pages, not the top-level topic itself.

## Round 40

Goal: continue reducing `shared/main0103.html` by localizing the next Writer-side View menu shell and its first linked child pages.

Changes:

- Localized the shared View entry page itself:
  - `helpcontent2/source/text/shared/main0103.xhp`
- Localized the next Writer child pages feeding that menu:
  - `helpcontent2/source/text/swriter/01/03130000.xhp`
  - `helpcontent2/source/text/swriter/01/03120000.xhp`
  - `helpcontent2/source/text/shared/02/19090000.xhp`
- Localized the corresponding Writer View-menu fragment sections in:
  - `helpcontent2/source/text/swriter/00/00000403.xhp`
- Specifically translated the direct `View` shell labels and explanations for:
  - `View`
  - `Zoom`
  - `Gallery`
  - `Function List`
  - `Handout`
  - `Object Moving Helplines`
  - `Comments`
  - `Master Background`
  - `Master Objects`
  - `Clip Art Gallery`
  - Draw-specific `Normal`, `Master`, `User Interface`, `Shift`
- Translated the Writer `Normal Layout`, `Web Layout`, and `HTML Source` page bodies and how-to-get text.

Verification:

- `xmllint --noout` passed for:
  - `shared/main0103.xhp`
  - `swriter/01/03130000.xhp`
  - `swriter/01/03120000.xhp`
  - `shared/02/19090000.xhp`
  - `swriter/00/00000403.xhp`
- Rebuilt successfully:
  - `gmake -C /Users/lu/kdoffice-build2 helpcontent2.build postprocess.build`
- Verified in the installed app bundle:
  - `shared/main0103.html`: `138` -> `104`
  - `swriter/01/03130000.html`: `8` -> `0`
  - `swriter/01/03120000.html`: `8` -> `0`
  - `shared/02/19090000.html`: `7` -> `4`

What Round 40 Does Not Solve:

- `shared/main0103.html` still contains many untranslated child pages, especially:
  - `swriter/menu/pageLayoutMenu`
  - `swriter/01/03050000`
  - `swriter/01/03100000`
  - `swriter/01/03070000`
  - `swriter/01/show_whitespace`
  - `swriter/01/view_resolved_comments`
  - `swriter/01/03090000`
  - `swriter/01/03140000`
  - several Calc/Impress view pages
- `shared/02/19090000.html` still inherits English from the shared `View Menu` fragment `shared/00/00000403.xhp#htmlsource`, which was not yet translated in this round.

## Round 41

Goal: clear the remaining Writer-side and shared View-help residue that still dominated `shared/main0103.html` after Round 40.

Changes:

- Localized the next Writer View child pages and menu shells:
  - `helpcontent2/source/text/swriter/menu/pageLayoutMenu.xhp`
  - `helpcontent2/source/text/swriter/01/03050000.xhp`
  - `helpcontent2/source/text/swriter/01/03100000.xhp`
  - `helpcontent2/source/text/swriter/01/03070000.xhp`
  - `helpcontent2/source/text/swriter/01/show_whitespace.xhp`
  - `helpcontent2/source/text/swriter/01/view_resolved_comments.xhp`
  - `helpcontent2/source/text/swriter/01/03090000.xhp`
  - `helpcontent2/source/text/swriter/01/03140000.xhp`
- Localized the remaining direct shared/view dependencies feeding those pages:
  - `helpcontent2/source/text/shared/00/00000403.xhp` (`htmlsource` section)
  - `helpcontent2/source/text/shared/00/edit_menu.xhp` (`anzeigen` and `navigator` sections)
  - `helpcontent2/source/text/shared/01/02230200.xhp`
  - `helpcontent2/source/text/shared/01/navigator.xhp` direct visible prose blocks
  - `helpcontent2/source/text/swriter/00/00000403.xhp` (`field_shadings` section)
  - `helpcontent2/source/text/swriter/01/03080000.xhp`
  - `helpcontent2/source/text/swriter/01/view_images_charts.xhp`
- Replaced several `embedvar`-driven related-topic labels with explicit Chinese links where that removed installed-output English immediately without waiting for downstream topic translation.

Verification:

- `xmllint --noout` passed for all edited files in this round.
- Rebuilt successfully:
  - `gmake -C /Users/lu/kdoffice-build2 helpcontent2.build postprocess.build`
- Verified in the installed app bundle:
  - `shared/main0103.html`: `104` -> `73`
  - `swriter/menu/pageLayoutMenu.html`: `17` -> `0`
  - `swriter/01/03050000.html`: `17` -> `1`
  - `swriter/01/03100000.html`: `6` -> `1`
  - `swriter/01/03070000.html`: `5` -> `0`
  - `swriter/01/show_whitespace.html`: `3` -> `0`
  - `swriter/01/view_resolved_comments.html`: `5` -> `0`
  - `swriter/01/03090000.html`: `7` -> `1`
  - `swriter/01/03140000.html`: `6` -> `0`
  - `shared/01/02230200.html`: `42` -> `17`
  - `swriter/01/view_images_charts.html`: `7` -> `0`
  - `swriter/01/03080000.html`: `9` -> `1`
  - `shared/01/navigator.html`: `177` -> `149`

What Round 41 Does Not Solve:

- The remaining matches in `03050000`, `03100000`, `03090000`, and `03080000` are shortcut-key literals such as `Command`, `Ctrl`, or other technical tokens intentionally preserved.
- `shared/01/02230200.html` and `shared/01/navigator.html` still inherit a lot of English from deeper embedded Calc/Writer/Impress topic pages that were not translated yet in this round.
- After this round, `shared/main0103.html` no longer primarily depends on Writer-side view topics; the remaining hotspot shifts to the Calc and Impress view chains.

## Round 42

Goal: remove the newly dominant Calc-side View-help residue from `shared/main0103.html` and clean the corresponding Calc help pages at the same time.

Changes:

- Localized the Calc View-menu fragment sections that feed the affected help pages:
  - `helpcontent2/source/text/scalc/00/00000403.xhp`
  - specifically `normalview`, `seumvo1`, `formulabar`, `viewheaders`, `viewgridlines`, `awehe1`, `hiddenindicator`, `showformula`, `splitwindow`, `freezerowcol`, `freezecells`, and `functionlist1`
- Localized the short Calc command/help pages that were directly embedded by `shared/main0103.xhp`:
  - `helpcontent2/source/text/scalc/01/NormalViewMode.xhp`
  - `helpcontent2/source/text/scalc/01/03100000.xhp`
  - `helpcontent2/source/text/scalc/01/03090000.xhp`
  - `helpcontent2/source/text/scalc/01/03070000.xhp`
  - `helpcontent2/source/text/scalc/01/ToggleSheetGrid.xhp`
  - `helpcontent2/source/text/scalc/01/03080000.xhp`
  - `helpcontent2/source/text/scalc/01/ViewHiddenColRow.xhp`
  - `helpcontent2/source/text/scalc/01/ToggleFormula.xhp`
  - `helpcontent2/source/text/scalc/01/07080000.xhp`
  - `helpcontent2/source/text/scalc/01/07090000.xhp`
  - `helpcontent2/source/text/scalc/01/07090100.xhp`
  - `helpcontent2/source/text/scalc/01/04080000.xhp`
- Localized the shared Calc-facing zoom shell:
  - `helpcontent2/source/text/shared/01/ZoomMenu.xhp`

Verification:

- `xmllint --noout` passed for all edited files in this round.
- Rebuilt successfully:
  - `gmake -C /Users/lu/kdoffice-build2 helpcontent2.build postprocess.build`
- Verified in the installed app bundle:
  - `shared/main0103.html`: `73` -> `48`
  - `scalc/01/NormalViewMode.html`: `9` -> `0`
  - `scalc/01/03100000.html`: `16` -> `2`
  - `scalc/01/03090000.html`: `10` -> `0`
  - `scalc/01/03070000.html`: `10` -> `0`
  - `scalc/01/ToggleSheetGrid.html`: `9` -> `0`
  - `scalc/01/03080000.html`: `14` -> `1`
  - `scalc/01/ViewHiddenColRow.html`: `5` -> `0`
  - `scalc/01/ToggleFormula.html`: `9` -> `1`
  - `scalc/01/07080000.html`: `11` -> `1`
  - `scalc/01/07090000.html`: `10` -> `1`
  - `scalc/01/07090100.html`: `9` -> `1`
  - `scalc/01/04080000.html`: `15` -> `0`
  - `shared/01/ZoomMenu.html`: `23` -> `19`

What Round 42 Does Not Solve:

- The remaining matches in many Calc pages are now mostly shortcut-key literals such as `Command`, `Ctrl`, or a few preserved technical tokens.
- `shared/01/ZoomMenu.html` still inherits English from deeper embedded zoom subpages, so translating the top-level shell was not enough to fully clear it.
- `shared/main0103.html` is now mostly blocked by Impress-side View pages, some Math-side view/help fragments, and preserved literals like `Esc`, rather than Writer or Calc view pages.

## Round 43

Goal: clear the remaining Impress-side and Math-side View/help residue from `shared/main0103.html`, then chase the newly exposed embedded follow-up pages until only preserved shortcut literals remained.

Changes:

- Localized the remaining Impress View menu fragments and direct child pages feeding `shared/main0103.xhp`:
  - `helpcontent2/source/text/simpress/00/00000403.xhp`
  - `helpcontent2/source/text/simpress/01/03080000.xhp`
  - `helpcontent2/source/text/simpress/01/03090000.xhp`
  - `helpcontent2/source/text/simpress/01/03100000.xhp`
  - `helpcontent2/source/text/simpress/01/03110000.xhp`
  - `helpcontent2/source/text/simpress/01/03120000.xhp`
  - `helpcontent2/source/text/simpress/01/03150100.xhp`
  - `helpcontent2/source/text/simpress/01/03150300.xhp`
  - `helpcontent2/source/text/simpress/01/03060000.xhp`
  - `helpcontent2/source/text/simpress/01/slidesorter.xhp`
  - `helpcontent2/source/text/simpress/01/03180000.xhp`
  - `helpcontent2/source/text/simpress/01/03151000.xhp`
- Localized the shared and Math view fragments that were still feeding the main View hub:
  - `helpcontent2/source/text/shared/00/00000403.xhp`
  - `helpcontent2/source/text/shared/01/ZoomOptimal.xhp`
  - `helpcontent2/source/text/shared/01/03170000.xhp`
  - `helpcontent2/source/text/shared/01/guides.xhp`
  - `helpcontent2/source/text/smath/00/00000004.xhp`
  - `helpcontent2/source/text/smath/01/03040000.xhp`
  - `helpcontent2/source/text/smath/01/03050000.xhp`
  - `helpcontent2/source/text/smath/01/03070000.xhp`
  - `helpcontent2/source/text/smath/01/03080000.xhp`
- Followed the newly exposed embedded help chains and localized the linked Impress/Draw support pages that were still surfacing visible English:
  - `helpcontent2/source/text/shared/00/00000004.xhp`
  - `helpcontent2/source/text/shared/optionen/01070500.xhp`
  - `helpcontent2/source/text/simpress/02/13020000.xhp`
  - `helpcontent2/source/text/simpress/02/13050000.xhp`
  - `helpcontent2/source/text/simpress/02/13060000.xhp`
  - `helpcontent2/source/text/simpress/02/13090000.xhp`
  - `helpcontent2/source/text/simpress/02/13100000.xhp`
  - `helpcontent2/source/text/simpress/02/13140000.xhp`
  - `helpcontent2/source/text/simpress/02/13150000.xhp`
  - `helpcontent2/source/text/simpress/02/13160000.xhp`
  - `helpcontent2/source/text/simpress/02/13170000.xhp`
  - `helpcontent2/source/text/simpress/02/13180000.xhp`
  - `helpcontent2/source/text/simpress/02/13190000.xhp`
  - `helpcontent2/source/text/simpress/guide/arrange_slides.xhp`
  - `helpcontent2/source/text/simpress/guide/keyboard.xhp`
  - `helpcontent2/source/text/simpress/guide/individual.xhp`
  - `helpcontent2/source/text/simpress/04/01020000.xhp`
  - `helpcontent2/source/text/sdraw/main0213.xhp`
  - `helpcontent2/source/text/sdraw/guide/keyboard.xhp`
  - `helpcontent2/source/text/sdraw/04/01020000.xhp`

Verification:

- `xmllint --noout` passed for every edited file across all Round 43 batches.
- Rebuilt successfully after each wave:
  - `gmake -C /Users/lu/kdoffice-build2 helpcontent2.build postprocess.build`
- Verified in the installed app bundle:
  - `shared/main0103.html`: `48` -> `3`
  - `simpress/01/03080000.html`: `4` -> `0`
  - `simpress/01/03090000.html`: `12` -> `2`
  - `simpress/01/03100000.html`: `6` -> `0`
  - `simpress/01/03110000.html`: `4` -> `0`
  - `simpress/01/03120000.html`: `5` -> `0`
  - `simpress/01/03150100.html`: `4` -> `0`
  - `simpress/01/03150300.html`: `4` -> `0`
  - `simpress/01/03060000.html`: `5` -> `0`
  - `simpress/01/slidesorter.html`: `6` -> `0`
  - `shared/01/guides.html`: `23` -> `1`
  - `simpress/01/03180000.html`: `10` -> `0`
  - `simpress/01/03151000.html`: `4` -> `0`
  - `shared/01/03170000.html`: `7` -> `1`
  - `shared/01/ZoomOptimal.html`: `10` -> `0`
  - `smath/01/03040000.html`: `7` -> `0`
  - `smath/01/03050000.html`: `7` -> `0`
  - `smath/01/03070000.html`: `9` -> `1`
  - `smath/01/03080000.html`: `3` -> `0`
  - `simpress/guide/arrange_slides.html`: `2` -> `1`
  - `simpress/guide/keyboard.html`: visible non-shortcut English removed; remaining regex matches are shortcut literals and modifier keys only
  - `sdraw/main0213.html`: visible non-shortcut English removed; remaining regex match is `Ctrl` only

What Round 43 Does Not Solve:

- The remaining matches in `shared/main0103.html`, `shared/01/guides.html`, `shared/01/03170000.html`, `smath/01/03070000.html`, `simpress/01/03090000.html`, `simpress/guide/arrange_slides.html`, `simpress/guide/keyboard.html`, and `sdraw/main0213.html` are now shortcut or modifier literals intentionally preserved, such as `Esc`, `Ctrl`, `Command`, `Tab`, `Shift+F5`, `Alt`, `Option`, `Enter`, or `F9`.
- Round 43 substantially improves the Chinese help surface for the main View hub and its linked child pages, but it does not claim that the entire help corpus is fully localized; longer-tail guide pages and deep shortcut reference tables still need additional sweep rounds outside this hotspot chain.

## Round 44

Goal: establish a repeatable product-quality baseline before continuing deeper development, and separate source candidates from generated build/install noise in the current configured tree.

Changes:

- Added local ignore rules for generated configured-tree outputs so future `git status` review is not dominated by `workdir/`, `instdir/`, `test-install/`, `tmp/`, autoconf cache/config outputs, Python bytecode, and macOS `.DS_Store` noise.
- Produced a non-destructive source/generated boundary report at `tmp/source-generated-boundary.md`, explicitly classifying likely source candidates, generated/local outputs, and high-risk manual-review files.
- Verified the three quality scaffold scripts are present, executable, and shell-syntax clean:
  - `bin/quality-baseline.sh`
  - `bin/compatibility-lab.sh`
  - `bin/compatibility-roundtrip.sh`
- Generated the first current-tree quality baseline report at `tmp/world-class-quality-baseline.md`.
- Generated the compatibility lab inventory at `tmp/compatibility-lab-baseline.md`.
- Ran the first smoke compatibility round-trip against the packaged app with `bin/compatibility-roundtrip.sh --format smoke --limit 1 --run-name baseline-smoke-20260424`.

Verification:

- `bash -n bin/quality-baseline.sh bin/compatibility-lab.sh bin/compatibility-roundtrip.sh` passed.
- `make -C /Users/lu/可点office help` passed and showed the expected gbuild target inventory.
- `bin/quality-baseline.sh tmp/world-class-quality-baseline.md` passed.
- `bin/compatibility-lab.sh tmp/compatibility-lab-baseline.md` passed.
- `bin/compatibility-roundtrip.sh --format smoke --limit 1 --run-name baseline-smoke-20260424` passed with 3 samples, 3 successes, and 0 failures:
  - DOCX: `chart2/qa/extras/data/docx/3d-bar-label.docx` -> ODT -> DOCX
  - XLSX: `chart2/qa/extras/chart2dump/data/tdf118150.xlsx` -> ODS -> XLSX
  - PPTX: `chart2/qa/extras/chart2dump/data/date-categories.pptx` -> ODP -> PPTX
- Validator wrappers were invoked where applicable, but ODF validators reported `skipped:missing-asset`; therefore this round proves conversion smoke success, not full validator-backed conformance.

What Round 44 Does Not Solve:

- The working tree is still very dirty because many tracked build/install outputs are modified or deleted; this round does not clean, reset, or delete anything.
- The baseline smoke pack is intentionally small and does not prove broad DOCX/XLSX/PPTX fidelity.
- Full `make build`, `make test-install`, `make check`, Start Center runtime visual inspection, and the next Help hotspot sweep remain pending.

## Round 45

Goal: close the smallest visible Start Center identity inconsistency discovered during source inspection, without changing the task-first workbench flow.

Changes:

- Normalized the Start Center frame label from `可圈Office` to the product identity `可圈office` in `sfx2/uiconfig/ui/startcenter.ui`.
- Kept the existing task-first `可圈办公工作台` layout and scenario buttons unchanged:
  - 工作汇报
  - 会议纪要
  - 预算总览
  - 项目排期
  - PPT 初稿
  - 商务路演 / 项目汇报 / 教学课件
- Confirmed scenario buttons are backed by real packaged template filenames in `sfx2/source/dialog/backingwindow.cxx`, not fake workflows.

Verification:

- `xmllint --noout /Users/lu/kdoffice-src/sfx2/uiconfig/ui/startcenter.ui` passed.
- `make -C /Users/lu/可点office sfx2.build` passed.
- The `sfx2.build` UI sanitizer reported 5 existing accessibility warnings in unrelated SFX2 UI files and 0 new fatals.

What Round 45 Does Not Solve:

- This is source/build verification only; it does not replace runtime visual inspection of the packaged app.
- The scenario cards still depend on the template inventory being present and correctly packaged in the installed app.
- Broader Start Center spacing, card hierarchy, and first-run interaction polish still need runtime review.

## Round 46

Goal: make the high-frequency Print Help page Chinese-first in the installed Help output, including the visible embedded print-related topic links.

Changes:

- Localized the main Print dialog Help page at `helpcontent2/source/text/shared/01/01130000.xhp`, covering command access, preview, printer selection, page ranges, copies, page layout, booklet, and module-specific print options while preserving technical identifiers and keyboard shortcuts.
- Localized the embedded print command access surface in `helpcontent2/source/text/shared/00/00000401.xhp` so the installed Print page no longer opens with English menu/toolbar guidance.
- Localized the visible embedded topic titles for the Print page's Writer, Calc, Impress, and shared print links, including brochure printing, reverse order, paper trays, print ranges, sheet details, handouts/slides, reduced-data printing, black-and-white printing, and maximum printable area.
- Fixed a mojibake typo in `print_selection.xhp` so its topic title and installed related-topic link render as `选择要打印的内容`.

Verification:

- `xmllint --noout` passed for the touched Print Help XML set: `shared/01/01130000.xhp`, `shared/00/00000401.xhp`, six Writer print guide pages, five Calc print guide pages, two Impress print guide pages, and three shared print guide pages.
- `make -C /Users/lu/可点office helpcontent2.build postprocess.build` passed after the main page edit and again after the embedded-title sweep.
- Inspected `/Users/lu/可点office/instdir/可圈office.app/Contents/Resources/help/en-US/text/shared/01/01130000.html`; the main body and embedded print-topic link cluster now render Chinese-first.
- A targeted installed-output scan for common English print-help phrases (`Choose`, `Click`, `Print`, `Printing`, `Defining`, `Page`, `Sheet`, `Brochure`, `Presentations`, and related terms) found no remaining user-visible sentence/link matches on the Print page; remaining ASCII tokens are structural HTML/CSS/JS, keyboard literals such as `Ctrl`/`Command`, product/module names, or metadata identifiers.

What Round 46 Does Not Solve:

- This round does not fully localize every linked child Help page body; it prioritizes the installed Print page and the embedded visible surfaces users see from that page.
- The installed Help language path remains `en-US` because this build is using the current configured Help packaging layout; this round improves the visible Chinese-first content inside that output, not the locale-packaging architecture.
- Longer-tail Help pages for advanced printing, printer drivers, Calc page-break editing, and full Help index/search metadata still need additional hotspot sweeps.

## Round 47

Goal: identify the release-grade build/install verification gap without changing keychain state, signing configuration, or generated build outputs destructively.

Findings:

- The configured tree is a release macOS build with app signing enabled: `config_host.mk` exports `ENABLE_RELEASE_BUILD=TRUE`, `MACOSX_CODESIGNING_IDENTITY=0CD938B3F72F1B00C73F30E5F27FA2C6358588CD`, and an empty `MACOSX_PACKAGE_SIGNING_IDENTITY`.
- The active keychain cannot satisfy that configured app-signing identity: `security find-identity -p codesigning -v` reported `0 valid identities found`.
- The real signed `make -C /Users/lu/可点office test-install` reached installer/DMG packaging but failed at `macosx-codesign-app-bundle` with repeated `The specified item could not be found in the keychain`; the following `hdiutil create ... .dmg` command succeeded, but the installer still failed because the signing error was recorded in the packaging log.
- Source inspection confirms the blocker is expected for this environment: `solenv/bin/modules/installer/simplepackage.pm` runs `macosx-codesign-app-bundle` for the main app when `MACOSX_CODESIGNING_IDENTITY` is set, while the top-level `test-install` target also signs the test app when that variable is non-empty.
- A dry-run of the local unsigned override (`PKGFORMAT= MACOSX_CODESIGNING_IDENTITY= test-install`) showed the safe verification path: no DMG package format and no app-bundle signing invocation remained in the final install steps.

Verification:

- `env -u MAKEFLAGS -u MFLAGS -u MAKELEVEL MAKE="/opt/homebrew/bin/gmake" /opt/homebrew/bin/gmake -C /Users/lu/可点office PKGFORMAT= MACOSX_CODESIGNING_IDENTITY= test-install` passed as a local unsigned verification path.
- The unsigned run reported blank `Package format:`, `Successful packaging process!`, `Installer finished`, and `Test Installation finished`; it produced `/Users/lu/可点office/test-install/可圈office.app`.
- `/Users/lu/可点office/test-install/可圈office.app/Contents/MacOS/soffice --headless --version` ran successfully and reported `可圈office 26.8.0.0.alpha0 75333b0de5e041261c9cd3468bcb677af01d37a0`.
- `codesign --verify --deep --strict /Users/lu/可点office/test-install/可圈office.app` failed, as expected for this unsigned local path; this confirms the path is useful for local runtime/build verification only and is not a release-signing substitute.

What Round 47 Does Not Solve:

- Release-grade signed DMG packaging remains blocked until the configured Developer ID/Application signing identity is available in the active keychain or the build is reconfigured intentionally.
- This round did not import certificates, modify keychains, delete generated outputs, or bypass signing in a release artifact; the unsigned override was used only to prove a local install/runtime verification path.
- Full `make check` remains unresolved: a `gmake -n check` probe reached the generated gbuild check path and stopped at a missing `workdir/LinkTarget/CppunitTest/libtest_chart2_common_functors.dylib.objectlist` evaluation dependency, so broader unit/subsequent checks still need a separate cleanup-free investigation.

## Round 48

Goal: answer whether 可圈office can be built on GitHub, and define a safe first CI path for a Windows MSI without pretending a release artifact already exists.

Findings:

- GitHub Actions is feasible in principle for Windows builds, but there is no existing build workflow baseline to extend: `/Users/lu/可点office` has no local `.github/workflows`, while `/Users/lu/kdoffice-src/.github/workflows` contains only upstream LibreOffice's `lockdown.yml` mirror-management workflow.
- The wrapper build tree at `/Users/lu/可点office` has no configured git remote in the local checkout, while the source tree at `/Users/lu/kdoffice-src` tracks upstream `https://github.com/LibreOffice/core.git` on `master`; neither is clearly the private 可圈office GitHub repository target.
- The local build tree is macOS-configured and cannot directly produce a Windows MSI; Windows needs a separate Cygwin/Visual Studio configuration, not a mutation of the current macOS `autogen.lastrun`.
- Existing upstream Windows config points are available: `distro-configs/LibreOfficeWin64.conf` sets `--host=x86_64-pc-cygwin` and `--with-package-format=msi`, while `distro-configs/Jenkins/windows_wsl_common.conf` documents Visual Studio 2022 plus external dependency paths used by Windows automation.

Recommended first GitHub path:

- Add a manual-only `workflow_dispatch` Windows MSI workflow in the actual private 可圈office source repository, not in the local macOS wrapper tree unless that wrapper is the repository pushed to GitHub.
- Start unsigned: disable release signing and upload the resulting MSI/logs as artifacts only. Add Windows code signing later when a certificate, password, and `signtool` path are explicitly available as GitHub secrets.
- Prefer a self-hosted Windows runner for reliable full builds. A hosted `windows-latest` runner can be tried for a smoke/build probe, but LibreOffice-scale disk/time/cache pressure makes it a risk for release builds.

What Round 48 Does Not Solve:

- No workflow file was written because the GitHub target repository is ambiguous: wrapper `/Users/lu/可点office` has no remote, and source `/Users/lu/kdoffice-src` points at upstream LibreOffice rather than the private 可圈office remote; its only current workflow is the upstream read-only mirror lockdown workflow, not a build workflow.
- No Windows MSI was produced or verified in this environment.
- No signing secrets, certificates, or release publishing steps were added.

## Round 49

Goal: turn the confirmed GitHub target `https://github.com/miounet11/-office` into a concrete manual installer-build CI entry for both macOS and Windows.

Changes:

- Set the wrapper repository remote to `origin https://github.com/miounet11/-office`.
- Added `.github/workflows/build-installers.yml` as a manual-only GitHub Actions workflow with `workflow_dispatch` input for `both`, `macos`, or `windows`.
- Added a macOS job on `macos-14` that configures an unsigned 可圈office build, runs `make build`, then runs `make PKGFORMAT=dmg MACOSX_CODESIGNING_IDENTITY= MACOSX_PACKAGE_SIGNING_IDENTITY= test-install` and uploads DMG/PKG/log artifacts.
- Added a Windows job on `windows-2022` that installs Cygwin packages, configures a Visual Studio 2022 x86_64 Cygwin MSI build with `--with-package-format=msi`, runs `make build` and `make test-install`, then uploads MSI/CAB/EXE/log artifacts.
- The workflow uses `downstream-branding` only if that directory is present in the pushed repository, so the CI file can run before the branding asset layout is finalized in Git.

Verification:

- Confirmed `origin` now points to `https://github.com/miounet11/-office` for `/Users/lu/可点office`.
- Static workflow checks passed locally for the required installer jobs, manual trigger, artifact upload, unsigned macOS override, and Windows MSI configure flag.

What Round 49 Does Not Solve:

- The workflow has not yet run on GitHub, so hosted-runner dependency completeness, disk pressure, timeout behavior, and installer artifact paths still need real CI validation.
- The workflow intentionally builds unsigned artifacts only; release signing still needs explicit macOS Developer ID / Windows code-signing secret handling.
- No push was performed in this round. The new workflow must be committed and pushed to `miounet11/-office` before GitHub can run it.
