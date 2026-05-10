# V2 Day-0 Skeleton Landed (W1 + W2)

Date: 2026-05-08
Wave: V2 W1 (Provider Runtime) + V2 W2 (Cmd+K Command Palette)
Spec: `docs/product/v2-master-plan.md`, `docs/product/v2/w1-provider-runtime-spec.md`, `docs/product/v2/w2-cmd-palette-spec.md`

## What landed

This is the **Day-0 skeleton** — the minimum code that lets V2 W1 and W2
build, link, and pass a contract test. No backend, no UI, no dispatcher
integration yet. Day-1 work for each wave is captured in the spec docs.

### W1 Provider Runtime (offline-only, stub)

- New UNO IDL surface in `offapi/com/sun/star/ai/`:
  - `XProvider` — synchronous `call(ProviderRequest)` + `listCapabilities()` + `getServiceMode()`
  - `ProviderRequest` — { capability, prompt, context, timeoutMs }
  - `ProviderResponse` — { status, content, evidenceId, durationMs }
- New module `kqoffice/` with `Library_kqoffice_ai`:
  - `Provider` — Day-0 stub: returns `policy-denied` for blocked capabilities,
    `provider-error` for allowed ones (no backend yet).
  - `ServiceModePolicy` — three-tier mode (`offline` / `private` / `cloud`),
    Day-0 only `offline` is wired with allow-list `{rewrite, summarize, format-fix, intent-to-uno}`.
- `CppunitTest_kqoffice_provider` — 7 cases covering policy gating,
  empty-input rejection, mode accessor, and stub error contract.

Out of scope for Day-0 (W1 Day-1+):
- Ollama HTTP probe + `OllamaAdapter`
- `private` / `cloud` mode allow-lists
- Async / streaming
- Integration smoke `bin/v2-w1-smoke.sh`

Landed in W1 Day-1b (2026-05-08, after Day-0):
- `EvidenceRecorder` writes per-request JSON to
  `${UserInstallation}/ai-evidence/YYYY-MM/<evidence_id>.json`,
  evidence id format `ev-<YYYYMMDDHHMMSS>-<seq>`.
  Provider now mints an evidence id on the `provider-error` path
  (capability allowed but no backend yet) and persists the request
  envelope. `policy-denied` still returns empty evidenceId by design.
- `CppunitTest_kqoffice_provider` grew from 7 to **10 cases** (10/10 green):
  `testEvidenceIdMintedOnProviderError`,
  `testEvidenceFileWrittenWithCapability`,
  `testEvidenceIdsAreUniqueAcrossCalls`.
  Log: `workdir/CppunitTest/kqoffice_provider.test.log` — `OK (10)`.

### W2 Cmd+K Command Palette (fuzzy match + popover)

- New `cui/source/inc/commandpalette/FuzzyMatcher.hxx` —
  **header-only** pure scoring logic (avoids fdo#47246 double-link with
  cui library + cppunit binary). Algorithm exactly per W2 spec:
  exact (+100), pinyin-first prefix (+80), labelZh substring (+60),
  labelEn substring (+40), recency boost (+freq/10).
- `cui/source/dialogs/commandpalette/CommandPalette.cxx` — Day-0
  controller skeleton wired to FuzzyMatcher.
- `cui/uiconfig/ui/commandpalette.ui` — GTK4 popover with search
  entry + results listbox + hint label, all i18n-ready (zh-CN strings).
- `CppunitTest_cui_commandpalette_fuzzy` — 8 cases covering
  empty-query, exact match (zh + en), pinyin prefix, substring (zh + en),
  frequency tie-break, top-N cap.

Out of scope for Day-0 (W2 Day-1+):
- `Cmd+K` accelerator binding in `GenericCommands.xcu`
- `CommandIndex` scanning of `*Commands.xcu`
- `SfxDispatcher::Execute` integration
- v1 LLM intent-to-uno fallback (depends on W1 Day-1)
- `CppunitTest_cui_dialogs` UI test
- Pinyin generator integration (uses `i18npool`, deferred to Day-1)

## File map (this commit)

```
new   offapi/com/sun/star/ai/XProvider.idl
new   offapi/com/sun/star/ai/ProviderRequest.idl
new   offapi/com/sun/star/ai/ProviderResponse.idl
new   kqoffice/Module_kqoffice.mk
new   kqoffice/Library_kqoffice_ai.mk
new   kqoffice/CppunitTest_kqoffice_provider.mk
new   kqoffice/Makefile
new   kqoffice/source/ai/provider/Provider.{cxx,hxx}
new   kqoffice/source/ai/provider/ServiceModePolicy.{cxx,hxx}
new   kqoffice/qa/cppunit/test_provider.cxx
new   cui/source/inc/commandpalette/FuzzyMatcher.hxx     (header-only)
new   cui/source/inc/commandpalette/CommandPalette.hxx
new   cui/source/dialogs/commandpalette/CommandPalette.cxx
new   cui/uiconfig/ui/commandpalette.ui
new   cui/qa/unit/CommandPaletteFuzzyTest.cxx
new   cui/CppunitTest_cui_commandpalette_fuzzy.mk
edit  Repository.mk                  (+ kqoffice_ai library group)
edit  RepositoryModule_host.mk       (+ kqoffice module)
edit  offapi/UnoApi_offapi.mk        (+ com/sun/star/ai idl files)
edit  cui/Library_cui.mk             (+ commandpalette/CommandPalette object)
edit  cui/Module_cui.mk              (+ commandpalette fuzzy check target)
edit  cui/UIConfig_cui.mk            (+ commandpalette.ui)
```

19 new files, 6 modified.

## Verification

- `make -n CppunitTest_cui_commandpalette_fuzzy` — gbuild parses, full
  link command emitted.
- `make -n CppunitTest_kqoffice_provider` — gbuild parses.
- Real compile + run pending (separate Day-0 CI step).

## Naming notes

- IDL namespace is `com.sun.star.ai` rather than the spec's tentative
  `com.kqoffice.ai`. Reason: spec §"Stop Conditions" #2 flags potential
  upstream namespace collision; using the existing `com.sun.star`
  hierarchy as an extension is safer and matches LO precedent (e.g.
  `com.sun.star.auth` is a downstream-friendly extension surface).
- Implementation namespace is `com.kqoffice.ai.Provider` to keep brand
  separation at the impl level without forking the IDL surface.

## Day-1 next picks

Recommended order, in dependency-topology order
(W1 Day-1b `EvidenceRecorder` already landed — see "Landed in W1 Day-1b" above):

1. **W1 Day-1a** — `OllamaAdapter`: probe `localhost:11434/api/tags`,
   minimal `POST /api/generate` blocking call, 30s timeout.
2. **W2 Day-1a** — `CommandIndex`: scan `officecfg/.../UI/*Commands.xcu`,
   build `std::vector<CommandEntry>`, persist frequency in
   `${UserInstallation}/cmdpalette/recent.json`.
3. **W2 Day-1b** — `Cmd+K` accelerator + dispatcher integration:
   register `.uno:CommandPalette` in `GenericCommands.xcu`, hook
   `SfxDispatcher::Execute` from popover Enter handler.
4. **W2 Day-1c** — i18npool pinyin generator integration for `pinyinFirst`.
