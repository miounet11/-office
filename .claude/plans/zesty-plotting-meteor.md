# Context
The LibreOffice downstream workspace already exists at `/Users/lu/可点office/libreoffice-core`, and the first visible **可圈offie** branding pass has landed in packaging/product-name and Linux launcher metadata.

Current implemented surface:
- `instsetoo_native/util/openoffice.lst.in`
- `sysui/productlist.mk`
- `sysui/desktop/menus/startcenter.desktop`
- `sysui/desktop/menus/writer.desktop`
- `sysui/desktop/menus/calc.desktop`

The next milestone is not “finish all branding.” It is to move from string-only edits toward a **buildable, runnable downstream desktop MVP** while keeping scope tight around Docs + Sheets.

# Recommended approach
Proceed in three controlled steps:
1. verify the repo can be configured for a local downstream build
2. extend branding only through existing safe metadata/custom-brand hooks
3. produce the first concrete build/configuration proof before attempting deeper product surgery

This keeps work aligned with the desktop-first MVP goal and avoids risky global renames or module removal.

## Step 1: build bootstrap for the downstream tree
Inspect and use LibreOffice’s normal build entrypoints instead of inventing a custom flow:
- `autogen.sh`
- `README.md`
- distro configs under `distro-configs/` as needed

Important implementation note already confirmed:
- `autogen.sh` rejects source paths containing spaces, but `/Users/lu/可点office` has no spaces, so this workspace layout is acceptable.

Execution target:
- run configure/bootstrap commands only to the point needed to prove the tree can be configured locally for downstream work
- do **not** claim success until `autogen.sh` / configure actually completes

## Step 2: continue branding through existing supported hooks
Prefer existing branding mechanisms over ad hoc file-by-file replacement.

Existing reusable hook found:
- `configure.ac:15461-15490` supports `--with-branding=<dir>`
- `desktop/Package_branding.mk`
- `desktop/Package_branding_custom.mk`
- `Repository.mk:1116-1125`

Recommended use:
- keep the current text/launcher changes
- add a dedicated downstream branding asset directory for logo/splash/about images through `--with-branding`, instead of patching core image packaging logic

## Step 3: finish the next visible metadata layer
After build bootstrap is proven, update the next safest user-visible metadata surfaces:
- `sysui/desktop/appstream-appdata/libreoffice-writer.appdata.xml`
- `sysui/desktop/appstream-appdata/libreoffice-calc.appdata.xml`
- optionally `sysui/desktop/appstream-appdata/libreoffice-base.appdata.xml` and other module metadata only if needed for consistency

For this phase:
- prioritize Writer and Calc naming/summary/description text
- avoid deep changes to module registration, executable names, or file associations unless build verification shows they are required

# Critical files to modify next
Primary build/bootstrap files:
- `/Users/lu/可点office/libreoffice-core/autogen.sh`
- `/Users/lu/可点office/libreoffice-core/README.md`
- `/Users/lu/可点office/libreoffice-core/configure.ac`
- `/Users/lu/可点office/libreoffice-core/desktop/Package_branding.mk`
- `/Users/lu/可点office/libreoffice-core/desktop/Package_branding_custom.mk`
- `/Users/lu/可点office/libreoffice-core/Repository.mk`

Primary next branding files:
- `/Users/lu/可点office/libreoffice-core/sysui/desktop/appstream-appdata/libreoffice-writer.appdata.xml`
- `/Users/lu/可点office/libreoffice-core/sysui/desktop/appstream-appdata/libreoffice-calc.appdata.xml`

Already modified files to preserve and validate:
- `/Users/lu/可点office/libreoffice-core/instsetoo_native/util/openoffice.lst.in`
- `/Users/lu/可点office/libreoffice-core/sysui/productlist.mk`
- `/Users/lu/可点office/libreoffice-core/sysui/desktop/menus/startcenter.desktop`
- `/Users/lu/可点office/libreoffice-core/sysui/desktop/menus/writer.desktop`
- `/Users/lu/可点office/libreoffice-core/sysui/desktop/menus/calc.desktop`

# Scope rules
Keep doing:
- desktop-first MVP work
- Docs + Sheets emphasis
- minimal downstream branding that is easy to validate
- use of LibreOffice’s built-in branding/configure hooks where available

Do not do yet:
- deep module removal
- global replacement of every `LibreOffice` string
- AI integration
- OFD / e-sign / compliance extras
- broad executable or package-identity surgery beyond what build verification requires

# Verification
Verification must be concrete before implementation is considered complete:
1. confirm current branding edits are still present in git diff/status
2. run the downstream bootstrap/configure step successfully
3. confirm the branding hook path (`--with-branding`) is the path used for image assets
4. update Writer/Calc appstream metadata and verify diffs
5. if feasible, produce at least one build/configuration artifact or successful configure result

Only after that should the next phase begin: additional visible branding surfaces such as splash/about/assets or broader desktop metadata consistency.
