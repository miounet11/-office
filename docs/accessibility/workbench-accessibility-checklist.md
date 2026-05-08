# Workbench Accessibility Checklist

This checklist defines the P1-03 accessibility review gate for the task-first Start Center workbench.

## Static Gate

Run:

```sh
bin/workbench-accessibility-check.sh tmp/workbench-accessibility-check.md
```

The static gate verifies:

- Scenario buttons exist for the Writer, Calc, Impress, and Office-file-open workflows.
- Scenario buttons have Chinese labels.
- Scenario buttons are keyboard-focusable.
- Scenario buttons have task-intent tooltips.
- The scenario section mnemonic points to the first task button.
- Scenario group labels and fallback warning text expose static accessible roles.

## Manual Beta Gate

The static gate is not enough for beta. A live review must verify:

- Keyboard traversal: `Tab` and `Shift+Tab` move through task buttons, file-open controls, recent files, filter controls, help, and extensions without focus traps.
- Keyboard activation: `Enter` and `Space` activate each task button and the compatibility-open button.
- VoiceOver: Chinese group labels, button labels, warning text, and task intent are read clearly.
- High contrast: focus rings, group labels, warning state, and button boundaries remain visible.
- Resize behavior: narrow and short windows do not clip critical task controls or make them unreachable.
- Fallback behavior: when a template is missing, warning text is perceivable and focus reaches a useful fallback.

## Current Scope

This gate covers custom Workbench surfaces only:

- `sfx2/uiconfig/ui/startcenter.ui`
- `sfx2/source/dialog/backingwindow.cxx`
- `uitest/workbench_tests/start_center_scenarios.py`

It does not prove broad application accessibility across Writer, Calc, Impress, dialogs, help, or advanced menus.
