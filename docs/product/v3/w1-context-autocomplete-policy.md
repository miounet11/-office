# V3-W1 Context Autocomplete Policy

Status: **context autocomplete contract active** (2026-06-10: design/fixture only; runtime implementation not started)
Owner spec: docs/product/v3/w1-in-app-chat-spec.md

## 1. Decision

W1 Chat may offer @ suggestions only inside the chat input. The mention UI is a scoped helper for the explicit context syntax policy, not a replacement for existing Office autocomplete, formula, field, style, or accessibility flows.

Allowed suggestions:

- @selection
- @doc
- @connector:<id>

The UI contract is scope=chat-input-only and officeAutocompletePolicy=delegate-existing-controls. W1 must not hijack global Office autocomplete handlers, must require an explicit keyboard or pointer commit before adding a mention, and must not preview or persist raw document, selection, connector, or prompt content in fixtures.

## 2. Connector Suggestions

Connector suggestions are placeholders until W2 manifests are available. A connector entry may be suggested only when a W2 connector manifest is present and the connector is allowed for read-only context fetch. Unknown connector ids are not suggested, even if the typed text resembles a connector name.

@connector:<id> remains read-only in W1 v0. The autocomplete contract does not authorize connector fetch runtime, connector write-back, or connector registry implementation.

## 3. Fixture Envelope

Every valid docs/qa/fixtures/v3/in-app-chat/ fixture must declare:

- mentionsUi.trigger = @
- mentionsUi.scope = chat-input-only
- mentionsUi.suggestions = @selection, @doc, @connector:<id>
- mentionsUi.officeAutocompletePolicy = delegate-existing-controls
- mentionsUi.hijacksGlobalAutocomplete = false
- mentionsUi.requiresExplicitCommit = true
- mentionsUi.connectorSuggestionsRequireW2Manifest = true
- mentionsUi.unknownConnectorSuggestions = false
- mentionsUi.rawPreviewContent = false
- mentionsUi.rawContentInFixture = false
- mentionsUi.runtimeParserImplementation = not-started

## 4. Guards

tests/v3-in-app-chat-test.sh rejects:

- global-autocomplete-hijack.json: W1 tries to intercept global Office autocomplete instead of staying inside the chat input.
- unknown-connector-suggestion.json: W1 suggests an unknown connector without a W2 manifest.
- raw-context-preview.json: W1 previews or stores raw context content in the mention dropdown/fixture.
- autocomplete-runtime-parser-started.json: the fixture claims parser/autocomplete runtime implementation has started before the gate opens.

Existing W1 guards still apply: explicit context only, per-doc-local history, native Markdown subset rendering, V2 chunk streaming states, no direct accelerator registration, no new chat schema, no stored prompt content in evidence, and no runtime/source implementation before V2 GA or explicit user authorization.
