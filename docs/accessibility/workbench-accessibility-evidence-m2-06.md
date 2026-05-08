# M2-06 Workbench Accessibility Evidence Packet

Date: 2026-04-28
Owner: Clavue
Reviewer: Codex read-only closeout accepted for alpha; live accessibility review remains beta-blocking.
Scope: task-first Start Center Workbench accessibility evidence for M2-06.

## Scope boundaries

This packet covers the custom Workbench Start Center surfaces only:

- `/Users/lu/kdoffice-src/sfx2/uiconfig/ui/startcenter.ui`
- `/Users/lu/kdoffice-src/uitest/workbench_tests/start_center_scenarios.py`
- `/Users/lu/可点office/bin/workbench-accessibility-check.sh`
- `/Users/lu/可点office/docs/accessibility/workbench-accessibility-checklist.md`

This is not a full-suite accessibility certification for Writer, Calc, Impress, dialogs, menus, help, extensions, or document canvases.

## Evidence sources

| Evidence | Result | Notes |
| --- | --- | --- |
| Static Workbench accessibility gate | Pass in latest available report | `tmp/workbench-accessibility-check.md` records all scenario controls present, labeled, focusable, and tooled. |
| Scenario UITest coverage | Pass; refreshed for M2-09 | `uitest/workbench_tests/start_center_scenarios.py` exercises every scenario button, compatibility-open cancel path, and runtime visibility/enabled reachability for currently visible critical Start Center controls. `workdir/UITest/workbench_smoke/done.log` records 13 tests run, 0 failed, 0 errors, 0 skipped. |
| Source/UI inspection | Pass with limitations | UI exposes focusable task/open/blank routes; manual VoiceOver, resize, contrast, and focus-order checks remain live-review items. |

## Static accessibility findings

| Area | Finding | Evidence |
| --- | --- | --- |
| Scenario buttons | Pass | Writer, Calc, Impress, and Office-file-open scenario buttons exist with Chinese labels, `can-focus=True`, and task-intent tooltips. |
| Group labels | Pass | Scenario subtitle/group/fallback labels expose static accessible roles. |
| Scenario mnemonic | Pass | `scenario_label` targets `scenario_report`, giving a keyboard entry point into task buttons. |
| Filter label relationship | Pass | `lbFilter` and `cbFilter` declare reciprocal accessibility relations. |
| Recent/local views | Pass with limitation | `scrollrecent`, `scrolllocal`, `all_recent`, and `local_view` are focusable/reachable surfaces, but live item traversal is not proven by static XML. |
| Actions menu | Pass with limitation | `mbActions` is focusable and has tooltip text; live menu traversal is not proven by static XML. |

## Keyboard traversal and activation

| Check | Status | Evidence / limitation |
| --- | --- | --- |
| Scenario button focusability | Pass | All task-first scenario buttons have `can-focus=True`. |
| Blank document routes | Pass | Left rail blank Writer, Calc, Impress, Draw, Math, and Database buttons have `can-focus=True`. |
| Open/recent/template routes | Pass | Open local, open remote, recent toggle, templates toggle, recent/local scrolled views, and actions menu are focusable or mnemonic-addressable. |
| Scenario activation | Pass by automated route smoke | UITest clicks every scenario button and verifies the resulting document type/template title. |
| Critical control runtime reachability | Pass by automated UITest assertion | M2-09 asserts scenario buttons, primary open/template routes, primary blank routes, local/recent surfaces visible in the current Start Center runtime, and help are present, visible, and enabled. Controls hidden in this runtime state (`open_remote`, `draw_all`, `math_all`, `database_all`, `extensions`, and actions-menu internals) remain live-review/manual coverage items. |
| Compatibility-open cancel path | Pass by automated route smoke | UITest opens the compatibility file picker and verifies no route-smoke failure on cancel and the Start Center remains usable; this is not broad process-survival coverage. |
| Tab/Shift+Tab order | Manual beta blocker | Static evidence proves focusability and M2-09 proves runtime visibility/enabled state, not actual traversal order or focus-trap absence. |
| Enter/Space activation | Manual beta blocker | UITest uses click activation; an M2-09 direct `FOCUS` + `TYPE RETURN` attempt did not reliably activate scenario buttons, so keyboard activation still needs live review. |

## VoiceOver and accessible naming

| Check | Status | Evidence / limitation |
| --- | --- | --- |
| Visible Chinese labels | Pass | Scenario buttons, group labels, blank document routes, open/recent routes, and help/extensions controls use Chinese visible labels. |
| Task intent | Pass with limitation | Scenario buttons expose tooltip text describing task intent. Live VoiceOver reading of tooltip-equivalent intent is not proven. |
| Group context | Pass with limitation | Group labels have static accessible roles, but live VoiceOver grouping/order needs manual confirmation. |
| Warning/fallback text | Pass with limitation | Fallback warning has Chinese text and static accessible role, but the missing-template path and focus movement are not automated. |

## Resize, contrast, and visual accessibility

| Area | Status | Evidence / limitation |
| --- | --- | --- |
| High contrast / increased contrast | Manual beta blocker | Muted labels use foreground alpha and require live contrast review. |
| Focus rings | Manual beta blocker | Focusability is present, but actual macOS/VCL focus-ring visibility must be checked live. |
| Narrow window resize | Risk to review | The scenario grid is fixed at four columns; narrow widths may compress or clip task controls. |
| Short window resize | Risk to review | Scenario area does not expand; short windows may push task controls against recent/local panes. |
| Fallback warning visibility | Pass static, manual live blocker | Text wraps and exposes a static role, but hidden-to-visible behavior requires live missing-template review. |

## Scenario button coverage

| Button | Intended route | Evidence |
| --- | --- | --- |
| `scenario_report` | Writer report template | UITest expects Writer document title `工作汇报`. |
| `scenario_minutes` | Writer minutes template | UITest expects Writer document title `会议纪要`. |
| `scenario_notice` | Writer notice template | UITest expects Writer document title `通知`. |
| `scenario_plan` | Writer project plan template | UITest expects Writer document title `项目方案`. |
| `scenario_outline` | Writer PPT outline draft template | UITest expects Writer document title `PPT 提纲初稿`. |
| `scenario_budget` | Calc budget template | UITest expects Calc document title `预算总览`. |
| `scenario_sales` | Calc sales follow-up template | UITest expects Calc document title `销售跟进`. |
| `scenario_schedule` | Calc schedule template | UITest expects Calc document title `项目排期`. |
| `scenario_pitch` | Impress pitch template | UITest expects Impress document title `商务路演`. |
| `scenario_project_report` | Impress project report template | UITest expects Impress document title `项目汇报`. |
| `scenario_courseware` | Impress courseware template | UITest expects Impress document title `教学课件`. |
| `scenario_compat_open` | Open local Office file | UITest verifies cancel returns to usable Start Center. |

## Beta accessibility blockers retained

M2-06 evidence is scoped and durable once paired with refreshed command output, but beta accessibility must still block on live review for:

- Tab and Shift+Tab traversal order across scenario buttons, blank document routes, recent/local views, filter/actions, help, and extensions.
- Enter and Space activation for every task and open route.
- VoiceOver reading quality for Chinese group labels, task buttons, intent text, fallback warning, and recent/template controls.
- High-contrast and increased-contrast visibility for focus rings, muted labels, group labels, button boundaries, and warning text.
- Narrow/short resize behavior with all task controls reachable and no critical clipping.
- Missing-template fallback behavior, including visible warning text and focus movement to a useful fallback.

## Round acceptance

M2-06 evidence acceptance is satisfied when this packet is paired with refreshed command output:

```sh
PATH="/Users/lu/kdoffice-src/instdir/可圈office.app/Contents/Frameworks/LibreOfficePython.framework/Versions/3.13/bin:$PATH" bin/workbench-accessibility-check.sh tmp/workbench-accessibility-check-m2-09.md
gmake -C /Users/lu/kdoffice-src UITest_workbench_smoke
```

The packet intentionally does not claim beta-ready accessibility until the retained live-review blockers are closed.
