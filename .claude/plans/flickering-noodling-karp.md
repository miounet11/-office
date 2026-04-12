## Context
The requested goal is still a full China-oriented localization pass, but the first feasible packaging/branding slice in this checkout is already complete: visible brand strings were normalized to `可圈Office`, Finder-facing macOS metadata was localized, Quick Look extension names were localized, packaged language default was switched to `zh-CN`, and remaining typo-brand references in editable/generated repo files were cleaned up. The limiting factor is now the repository state itself: the generated top-level `Makefile` still points `SRCDIR` at `/Users/lu/可点office/libreoffice-core`, that directory is missing, and there are still no editable in-app localization assets such as `.ui`, `.po`, `.xcu`, `.xcs`, `.src`, or `.ulf` anywhere in this checkout. Because of that, the user’s requested menu/button/function Han化 cannot be implemented from the currently available files.

## Recommended approach
Do not spend more implementation effort on packaging metadata in this checkout. The next meaningful development slice is to restore the real LibreOffice source/resource tree and then localize the actual in-app UI surfaces.

1. **Treat the current checkout as packaging/config complete for this phase**
   - Keep the completed branding/localization changes already made in the current tree.
   - Do not keep editing generated/config-only artifacts unless they are regenerated from a restored source tree and need to be synchronized.

2. **Unblock the missing source tree first**
   - Restore or provide `/Users/lu/可点office/libreoffice-core` so the repo again contains the real UI/resource sources.
   - After the tree is present, confirm where Writer/Calc/Impress shared UI resources actually live before editing anything.

3. **Second-wave localization once source files exist**
   - Target real user-facing resources under the restored source tree: dialog definitions, command/menu labels, string tables, and localization catalogs.
   - Prioritize visible Chinese-office UX surfaces first: application name, start surfaces, top-level menus, common toolbar labels, Writer and Calc high-frequency commands, template/start-center copy, and document-type labels.
   - Reuse the existing brand spelling `可圈Office` and keep technical IDs, MIME types, bundle IDs, and security/signing metadata stable.

4. **Regenerate configured artifacts only after source edits**
   - If the restored source tree changes configure or packaging outputs, regenerate and then update derived files in this checkout only as needed.
   - Avoid hand-editing generated outputs as the primary localization path.

## Critical files to modify
- First prerequisite: restore `/Users/lu/可点office/libreoffice-core`
- Then modify the actual UI/localization resources discovered under that source tree (`.ui`, `.po`, `.xcu`, `.xcs`, `.src`, `.ulf`, or equivalent real resource files)
- Only update derived/configured files in `/Users/lu/可点office` after regeneration if they still need brand/language synchronization

## Existing sources to reuse
- `/Users/lu/可点office/instsetoo_native/util/openoffice.lst` — completed packaging/product branding reference
- `/Users/lu/可点office/sysui/desktop/macosx/Info.plist` — completed Finder-visible document-type localization reference
- `/Users/lu/可点office/extensions/source/macosx/quicklookpreview/appex/Info.plist` — completed Quick Look preview naming reference
- `/Users/lu/可点office/extensions/source/macosx/quicklookthumbnail/appex/Info.plist` — completed Quick Look thumbnail naming reference
- `/Users/lu/可点office/autogen.lastrun` and `/Users/lu/可点office/config_host_lang.mk` — current product-name and language-default configuration references

## Verification
- Before any further implementation, verify that `/Users/lu/可点office/libreoffice-core` exists and that real UI/localization resource files are present.
- After source-level localization edits, read back the changed resource files and verify the edits are limited to user-visible strings.
- Run syntax/format validation appropriate to the touched files, then run targeted module builds/tests using the existing top-level make targets once the source tree is complete.
- For macOS metadata or packaging files regenerated later, re-run the already used checks (`plutil -lint`, `git diff --check`, and shell syntax validation where applicable).
- In the final implementation report, explicitly state that the current checkout’s packaging/metadata phase is complete and that in-app Han化 depended on restoring the missing source/resource tree.
