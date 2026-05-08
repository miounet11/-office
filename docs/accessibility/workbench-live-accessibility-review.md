# BETA-01 Workbench Live Accessibility Review

Date: 2026-04-28
Owner: Clavue
Reviewer: Codex
Round: BETA-01 Workbench Live Accessibility Evidence
Decision: **defer**

## Objective

Reduce the Workbench live accessibility beta blocker by separating verified static/UITest evidence from checks that still require a live macOS GUI and assistive-technology operator.

## Scope

Covered surface:

- `/Users/lu/kdoffice-src/sfx2/uiconfig/ui/startcenter.ui`
- `/Users/lu/kdoffice-src/uitest/workbench_tests/start_center_scenarios.py`
- `/Users/lu/可点office/docs/accessibility/workbench-accessibility-evidence-m2-06.md`
- `/Users/lu/可点office/docs/accessibility/workbench-accessibility-checklist.md`
- `/Users/lu/可点office/tmp/workbench-accessibility-check.md`
- `/Users/lu/kdoffice-src/workdir/UITest/workbench_smoke/done.log`

Non-goals:

- No Workbench source edits.
- No UI command, sidebar, provider, plugin runtime, import/export, PPTX export, or Writer analyzer changes.
- No broad suite accessibility certification for Writer, Calc, Impress canvases, menus, dialogs, help, or extensions.

## Evidence collected

| Evidence | Result | What it proves | What it does not prove |
| --- | --- | --- | --- |
| Static accessibility check | **pass** | Scenario controls exist, have Chinese labels, are keyboard-focusable, and expose task-intent tooltips. | Live Tab order, Shift+Tab reverse order, focus-ring rendering, VoiceOver output, contrast, resize, and missing-template runtime behavior. |
| Source/UI inspection | **pass with limitations** | Start Center XML exposes focusable blank/open routes, scenario buttons, recent/local drawing areas, actions menu, and static group/fallback labels. | Runtime traversal order and actual assistive-tech announcements. |
| UITest Workbench smoke | **pass, expanded for M2-09** | Scenario/open-route smoke tests preserve click coverage and now add automated visibility/enabled reachability assertions for critical Start Center controls. | True Tab order, focused-widget state, Enter/Space activation, VoiceOver output, contrast, resize, and missing-template runtime behavior. Direct UITest `FOCUS`/`TYPE RETURN` attempts did not expose reliable keyboard activation/focus evidence and are not claimed. |
| Live manual GUI review | **blocked by environment/operator availability** | None. | Required beta checks remain blocked/deferred. |
| VoiceOver review | **blocked by environment/operator availability** | None. | Chinese accessible-name/group/intent quality remains unverified. |
| High/increased contrast review | **blocked by environment/operator availability** | None. | Focus-ring and muted-label visibility remain unverified. |

## Verification commands and results

A process check before verification found no active matching `gmake`, `make`, `UITest`, `soffice`, `LibreOffice`, `CppunitTest`, or `workbench_smoke` process, so the allowed commands were run.

| Command | Result |
| --- | --- |
| `PATH="/Users/lu/kdoffice-src/instdir/可圈office.app/Contents/Frameworks/LibreOfficePython.framework/Versions/3.13/bin:$PATH" bin/workbench-accessibility-check.sh tmp/workbench-accessibility-check-m2-09.md` | **pass**; rewrote `tmp/workbench-accessibility-check-m2-09.md` at `2026-04-29 19:13:46 +0800`, with `Status: pass`. The default macOS `/usr/bin/python3` is 3.9.6 and cannot parse the script's `ET.Element | None` annotation, so the report was refreshed with the bundled LibreOffice Python 3.13. |
| `gmake -C /Users/lu/kdoffice-src UITest_workbench_smoke` | **pass**; `workdir/UITest/workbench_smoke/done.log` records 13 tests run, 0 failed, 0 errors, 0 skipped, including the new critical-control visibility/enabled assertion. |
| Live/manual GUI, VoiceOver, contrast, resize, fallback checks | **not performed**; no manual operator session, VoiceOver transcript/audio, contrast screenshot, resize screenshot, or forced missing-template observation was available in this environment. |

## Static and automated evidence retained

- `tmp/workbench-accessibility-check.md` reports `Status: pass` for the static gate in the latest beta-gate run and explicitly says manual accessibility review remains a beta blocker.
- `tmp/workbench-accessibility-check-m2-09.md` reports `Status: pass` for the earlier static gate and explicitly says manual accessibility review remains a beta blocker.
- `workdir/UITest/workbench_smoke/done.log` is refreshed for M2-09; the UITest file now includes a critical-control visibility/enabled assertion covering scenario buttons, primary open/template routes, primary blank routes, local/recent surfaces visible in the current Start Center runtime, and help.
- `startcenter.ui` exposes Chinese labels and `can-focus=True` for scenario buttons, blank document routes, open/recent routes, `scrollrecent`, `scrolllocal`, `all_recent`, `local_view`, `mbActions`, help, and extensions.
- `startcenter.ui` exposes static accessible roles for scenario subtitle/group labels and fallback warning text.
- `start_center_scenarios.py` verifies every scenario button opens the expected document type/template title, verifies the compatibility-open cancel path leaves Start Center usable, and asserts that the critical Start Center controls are present, visible, and enabled in the UITest runtime.

## M2-12 live accessibility blocker decision

M2-12 did not close the live accessibility blocker. The latest static gate remains passing, but no live macOS operator notes, VoiceOver transcript/audio, high/increased-contrast screenshots, resize screenshots, or forced missing-template fallback observation are available in this session.

Decision: **blocked** for beta readiness until the manual operator procedure below is completed and the observed pass/fail evidence is appended here. Do not infer live Tab/Shift+Tab order, Enter/Space activation, VoiceOver output, contrast, resize, or missing-template fallback behavior from static XML or UITest click coverage.

## Live checks passed

No live/manual beta checks passed in this round. The only refreshed passes are supporting static/source/UITest evidence.

## Live checks blocked

| Area | Required live check | Current decision | Evidence / blocker |
| --- | --- | --- | --- |
| Tab traversal | Fresh profile: Tab moves through scenario buttons, blank document routes, recent/local views, filter/actions, help, and extensions without traps. | **defer** | Static XML proves focusability and M2-09 UITest proves controls are runtime-visible/enabled; no reliable live focus traversal was captured. |
| Shift+Tab traversal | Reverse traversal reaches the same controls and does not trap or skip critical controls. | **defer** | No live reverse traversal was captured; UITest does not provide trustworthy traversal-order evidence for this surface. |
| Scenario button activation | Enter and Space activate `scenario_report`, `scenario_minutes`, `scenario_notice`, `scenario_plan`, `scenario_outline`, `scenario_budget`, `scenario_sales`, `scenario_schedule`, `scenario_pitch`, `scenario_project_report`, `scenario_courseware`, and `scenario_compat_open`. | **defer** | M2-09 attempted direct UITest `FOCUS` + `TYPE RETURN` activation and it did not reliably open the scenario; click activation remains automated, keyboard activation remains manual. |
| Blank/open route activation | Enter and Space activate `open_all`, `open_remote`, `open_recent`, `templates_all`, `writer_all`, `calc_all`, `impress_all`, `draw_all`, `math_all`, `database_all`, `help`, `extensions`, and `mbActions` where applicable. | **defer** | Static focusability exists for the buttons/menu button; live keyboard activation was not captured. |
| VoiceOver labels | VoiceOver reads Chinese button labels, group context, fallback warning text, and enough task intent for a Chinese user to choose correctly. | **defer** | No VoiceOver session transcript/audio/manual observation is available. |
| VoiceOver order | VoiceOver navigation order matches visual/task grouping and does not announce confusing hidden/empty surfaces first. | **defer** | Static source cannot prove runtime announcement order. |
| High/increased contrast | Focus rings, group labels, muted subtitle/body labels, warning hint, button boundaries, and empty/recent states remain visible. | **defer** | XML uses foreground alpha for muted labels; contrast must be reviewed live in macOS/VCL rendering. |
| Narrow resize | Narrow Start Center keeps task controls reachable and avoids critical label clipping/overlap. | **defer** | Scenario grid is four columns in XML; live resize behavior was not captured. |
| Short resize | Short Start Center keeps scenario controls, actions, and recent/local panes reachable. | **defer** | Static layout cannot prove scroll/reachability at constrained height. |
| Missing-template fallback | Missing scenario template shows warning text and moves focus to a useful fallback: template list or blank document route. | **defer** | Fallback label exists and wraps, but hidden-to-visible runtime behavior and focus movement were not exercised. |

## Live blocker evidence matrix

This matrix turns the deferred live blockers into operator-capturable evidence. A beta pass needs the pass evidence recorded for each row; any blocker signal should remain a live-review blocker until corrected or explicitly waived.

| Area | Controls to exercise | Operator steps | Pass evidence to capture | Blocker signals |
| --- | --- | --- | --- | --- |
| Tab and Shift+Tab traversal | Scenario buttons, blank document routes, open/recent/template routes, recent/local views, filter/actions, help, extensions | Start from a fresh profile on the Start Center; press Tab until focus cycles once; repeat with Shift+Tab; record every focused control in order. | Forward and reverse order list with no traps, skipped visible critical controls, or dead-end panes. | Focus disappears, loops before all critical controls, lands on unlabeled surfaces first, or cannot leave recent/local/filter/action areas. |
| Enter and Space activation | All scenario buttons plus `open_all`, `open_remote`, `open_recent`, `templates_all`, `writer_all`, `calc_all`, `impress_all`, `draw_all`, `math_all`, `database_all`, `help`, `extensions`, `mbActions` | Keyboard-focus each control; activate with Enter and Space where applicable; cancel/close opened dialogs or documents and return to Start Center. | Activation result per control, including safe return path after dialogs/documents and no lost focus. | Enter or Space does nothing on a button, opens the wrong route, traps focus in a dialog, or loses Start Center focus after cancel/close. |
| VoiceOver labels and order | Scenario group labels/buttons, compatibility-open task, blank/open routes, recent/local items, filter/actions, fallback warning | Enable VoiceOver; navigate by keyboard/VoiceOver commands; transcribe the spoken Chinese name, group/context, state, and intent for each control group. | Transcript confirms clear Chinese names, useful group context, actionable task intent, and navigation order matching the visual task grouping. | Unlabeled/generic announcements, missing group context, hidden/empty surfaces announced before useful tasks, or tooltip-only intent not spoken. |
| High/increased contrast visibility | Focus rings, muted subtitle/body labels, group labels, button boundaries, warning hint, empty/recent states | Enable macOS Increase Contrast or a high-contrast appearance; traverse focus and capture screenshots at normal, narrow, and warning states if available. | Screenshots/notes show visible focus indication, readable muted text, visible button boundaries, and perceivable warning/empty states. | Focus ring blends into background, muted labels become too faint, button boundaries disappear, or warning/empty-state text is not readable. |
| Narrow and short resize reachability | Scenario grid, open/recent/template controls, recent/local panes, action menu, help/extensions | Resize Start Center to narrow and short sizes; use keyboard only to reach all critical controls; capture dimensions and screenshots for failures. | All critical controls remain reachable with no critical label clipping, overlap, or inaccessible off-screen content. | Four-column scenario grid clips labels/buttons, panes hide keyboard focus, controls overlap, or scrolling cannot reach critical routes. |
| Missing-template fallback | `scenario_fallback_hint`, failed scenario button, `templates_all`, blank document routes | Force or simulate one missing scenario template; activate that scenario by keyboard; record warning visibility, announcement, and next focused fallback. | Warning is visible/announced promptly and focus moves to a useful fallback such as `templates_all` or an appropriate blank document route. | Failure is silent, warning appears off-screen/unannounced, focus stays on a broken task, or no usable fallback receives focus. |

## Control-by-control live review matrix

| Control group | Controls | Static/UITest status | Live review still required |
| --- | --- | --- | --- |
| Writer scenarios | `scenario_report`, `scenario_minutes`, `scenario_notice`, `scenario_plan` | Focusable, labeled, tooltipped; UITest opens expected Writer templates. | Tab/Shift+Tab position, Enter/Space activation, VoiceOver group/name/intent, focus-ring visibility. |
| Calc scenarios | `scenario_budget`, `scenario_sales`, `scenario_schedule` | Focusable, labeled, tooltipped; UITest opens expected Calc templates. | Tab/Shift+Tab position, Enter/Space activation, VoiceOver group/name/intent, focus-ring visibility. |
| Impress scenarios | `scenario_outline`, `scenario_pitch`, `scenario_project_report`, `scenario_courseware` | Focusable, labeled, tooltipped; UITest opens expected Writer/Impress templates. | Tab/Shift+Tab position, Enter/Space activation, VoiceOver group/name/intent, focus-ring visibility. |
| Office open scenario | `scenario_compat_open` | Focusable, labeled, tooltipped; UITest verifies file-picker cancel returns to usable Start Center. | Enter/Space activation, dialog handoff/cancel keyboard path, VoiceOver intent quality. |
| Blank document routes | `writer_all`, `calc_all`, `impress_all`, `draw_all`, `math_all`, `database_all` | Focusable and Chinese-labeled in XML. | Tab order, Enter/Space activation, VoiceOver names, focus-ring visibility. |
| File/navigation routes | `open_all`, `open_remote`, `open_recent`, `templates_all` | Focusable and Chinese-labeled in XML. | Tab order, Enter/Space activation, VoiceOver state/expanded semantics. |
| Recent/local views | `scrollrecent`, `scrolllocal`, `all_recent`, `local_view` | Focusable/reachable surfaces in XML. | Item-level traversal, VoiceOver item names, empty-state behavior, resize reachability. |
| Filter/actions | `lbFilter`, `cbFilter`, `mbActions`, `clear_all`, `clear_unavailable` | Label relationship and actions tooltip exist; `mbActions` focusable. | Combo/menu keyboard operation, VoiceOver state, action menu traversal. |
| Help/extensions | `help`, `extensions` | Focusable and Chinese-labeled in XML. | Tab order, activation, VoiceOver names, focus-ring visibility. |
| Fallback warning | `scenario_fallback_hint` | Chinese visible text, wrap enabled, static accessible role. | Runtime visibility, announcement timing, and focus movement when a template is missing. |

## Remaining beta blockers

- Live Tab and Shift+Tab traversal across scenario buttons, blank document routes, recent/local views, filter/actions, help, and extensions. M2-09 reduced this only by proving the currently visible/enabled critical Start Center controls are reachable by UITest, not by proving traversal order.
- Enter and Space activation for task and open routes. M2-09 click smoke remains automated; direct UITest keyboard activation was not reliable enough to claim.
- VoiceOver Chinese label, group, intent, order, and fallback-warning quality.
- High-contrast/increased-contrast visibility for focus rings, muted labels, group labels, button boundaries, empty/recent states, and warning text.
- Narrow/short resize reachability and clipping behavior.
- Missing-template fallback warning visibility and focus movement to a useful fallback.

## Keep/revise/defer decision

**defer**: keep the refreshed static/source/UITest evidence as supporting evidence, but do not claim beta accessibility. The live Workbench accessibility beta blocker remains open because the required manual GUI, VoiceOver, contrast, resize, and missing-template observations were not performed.

## Manual operator procedure needed to close BETA-01

Run from a fresh profile on macOS with the built app:

1. Launch Start Center and record app/build/profile details.
2. Traverse forward with Tab from the first focusable Workbench control through all scenario, open, recent/local, filter/action, help, and extension controls; record observed order and any traps/skips.
3. Traverse backward with Shift+Tab across the same controls; record observed order and any traps/skips.
4. Activate each task scenario and open/blank route with Enter and Space where feasible; record success/failure and whether focus returns safely after cancel/close paths.
5. Enable VoiceOver and record Chinese label/group/intent quality for scenario groups, task buttons, open/blank routes, recent/local surfaces, actions, and fallback warning.
6. Enable high contrast or increased contrast and record focus-ring visibility, muted-label readability, warning readability, and button-boundary visibility.
7. Resize the Start Center to narrow and short sizes and record whether all critical controls remain reachable without critical clipping or overlap.
8. Force or simulate a missing-template scenario and record warning visibility plus focus movement to a useful fallback.

## Files changed

- `/Users/lu/可点office/docs/accessibility/workbench-live-accessibility-review.md`
- `/Users/lu/可点office/bin/workbench-accessibility-check.sh`

## Next recommended bottleneck

Assign a manual macOS operator to perform the live review procedure above and append observed pass/fail evidence. Until then, beta gates should continue to treat Workbench live accessibility as a manual blocker.
