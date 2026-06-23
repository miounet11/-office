# V3-W1 Keyboard Shortcut Survey

Status: **in-app-chat entry-route contract active** (2026-06-10: design-only; no runtime registration)
Owner spec: `docs/product/v3/w1-in-app-chat-spec.md`

## 1. Decision

W1 must not register a new global accelerator for Chat during the contract phase. The accepted route is:

```
Cmd+Shift+K -> V2 CommandPalette -> chat fallback intent -> W1 sfx2 sidebar
```

The fixture contract names this route `command-palette-chat-fallback` and requires `directAcceleratorRegistration=false`.

## 2. Current Constraints

| Constraint | Locked decision |
|---|---|
| `Cmd+K` | Reserved by the existing office accelerator surface and must not be claimed for W1 Chat. |
| `Cmd+Shift+K` | Already proven as the V2 CommandPalette entry path; W1 reuses it as the command surface, not as a second direct binding. |
| `sfx2-sidebar` | W1 Chat may render there after chat fallback is selected, but registration/runtime wiring remains gated. |
| `officecfg` | No new W1 accelerator or Sidebar.xcu registration before explicit implementation authorization. |
| V2 command behavior | CommandPalette remains the first visible keyboard target; W1 is a fallback/intent path inside that surface. |

## 3. Contract Impact

`tests/v3-in-app-chat-test.sh` locks the shortcut route by requiring every valid W1 fixture to declare:

```json
{
  "entry": {
    "shortcut": "Cmd+Shift+K",
    "route": "command-palette-chat-fallback",
    "container": "sfx2-sidebar",
    "directAcceleratorRegistration": false
  }
}
```

The guard fixture `direct-accelerator-registration.json` is invalid because it attempts to bind Chat directly to `Cmd+Shift+K` and would collide with the V2 CommandPalette proof ladder.

## 4. Exit Criteria

- W1 runtime may open the Chat sidebar only through CommandPalette chat fallback until a later approved UX change explicitly revises this survey.
- Any direct W1 accelerator registration must update this survey, W1 fixtures, W1 self-test, V3 sweep docs, and V2 mirrors in the same ledger row.
- No source/runtime path is authorized by this document.
