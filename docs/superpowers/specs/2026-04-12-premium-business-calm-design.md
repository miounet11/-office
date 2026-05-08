# 可圈office Premium Business Calm Design Spec

## Objective

Elevate 可圈office from a functional rebrand into a visually cohesive desktop productivity product that feels calm, premium, modern, and business-appropriate.

The redesign should improve elegance and polish without making the application feel flashy, experimental, or unfamiliar for serious document work.

## Design Intent

The target impression is:

- professional enough for business environments
- calm enough for long-duration daily use
- modern enough to feel intentionally designed
- branded enough to feel like 可圈office rather than only a renamed LibreOffice build

This direction should favor restraint over decoration.

## Core Diagnosis

Based on the current screenshots, the main visual issues are:

### 1. Heavy chrome
The interface shows too many borders, separators, boxed regions, and competing panel boundaries.

**Result:** the UI feels busy and dated.

### 2. Weak hierarchy
Toolbars, sidebars, utility controls, and content-adjacent surfaces compete at similar visual weight.

**Result:** the user’s eye is not guided clearly toward the main working area.

### 3. Inconsistent density and spacing
Padding, grouping, and control density feel inherited rather than intentionally designed.

**Result:** the interface feels mechanically assembled instead of polished.

### 4. Mixed visual language
Branding, controls, icons, and panels do not yet read as one coherent design family.

**Result:** the product feels customized but not fully unified.

### 5. Shallow brand presence
The visible branding is concentrated mainly in naming rather than in a complete visual system.

**Result:** first impression does not yet feel premium or distinctive.

## Recommended Direction

Use a hybrid of two visual directions:

### A. Executive Calm for the working UI
Apply this to the main editing environment:

- main window chrome
- toolbar region
- sidebars and inspectors
- status and secondary utility surfaces
- document frame surroundings

Traits:

- reduced border noise
- softer contrast between surfaces
- flatter, quieter chrome
- more intentional spacing and grouping
- minimal accent usage

### B. Branded Business Identity for entry surfaces
Apply this to high-identity surfaces:

- splash screen
- start center
- about screen
- app icon/logo presentation
- document type entry cards and empty states

Traits:

- more deliberate logo composition
- cleaner typography hierarchy
- refined use of one brand accent family
- premium first impression without visual excess

## Primary Design Principles

### Content first
The document canvas and primary working area should visually dominate.

### Quiet chrome
Reduce visible lines, boxes, and hard separators whenever possible.

### Controlled density
Aim for a balanced, business-grade density: not cramped, not airy to the point of feeling consumer-oriented.

### One accent strategy
Use one restrained accent family for active state, selection, and priority actions.

### Premium through restraint
The UI should feel better because unnecessary visual weight is removed and proportions are improved, not because decoration is added.

## Visual System

### Color
Recommended palette behavior:

- base background: soft off-white or light warm neutral
- secondary surface: slightly darker neutral panel tone
- primary text: deep charcoal or dark neutral
- secondary text: muted gray
- accent: one business-grade blue, indigo, or teal family
- destructive/warning states: conventional and functional, not stylized

Avoid:

- multiple accent families competing in the same view
- strong saturated fills in standard chrome
- harsh black/white contrast as a default UI treatment

### Contrast
Contrast should stay strong enough for serious productivity use while feeling calmer than the current interface.

This is not a low-contrast aesthetic exercise.

### Typography
Typography should communicate confidence and clarity.

Guidelines:

- keep control typography platform-safe and readable
- improve hierarchy on splash/start/about surfaces through size, weight, and spacing
- avoid decorative typography choices
- make product identity areas feel intentional rather than default

### Iconography
The app should move toward a quieter, more consistent icon presentation.

Guidelines:

- reduce visual noise around icons through calmer surrounding chrome
- prioritize icon consistency over novelty
- improve high-visibility icon surfaces first rather than attempting a full icon redesign immediately

Priority order:

1. start center / document entry surfaces
2. splash / about / app identity surfaces
3. toolbar presentation and high-frequency controls

## Surface-by-Surface Goals

### Splash screen
Current role: first impression and identity anchor.

Target changes:

- cleaner composition
- stronger whitespace discipline
- more premium logo scale and placement
- restrained accent use
- better alignment between background, logo, and product name presentation

Success condition:
The splash should immediately look intentional and premium, not only customized.

### Start center
This is one of the highest-value surfaces for perceived polish.

Target changes:

- simplify layout hierarchy
- give the logo/identity zone more authority
- refine spacing around recent files, templates, and creation actions
- reduce clutter and visual competition
- make document-type actions feel more coherent and premium

Success condition:
The start center should feel modern, branded, and calmer than the current screenshots.

### Main window chrome
Target changes:

- soften chrome contrast relative to content
- reduce dependence on heavy borders and visible panel boxing
- let the editing canvas dominate
- normalize spacing rhythm across top-level surfaces

Success condition:
The work area should feel quieter and more focused.

### Toolbars
Target changes:

- reduce visual segmentation
- group controls with spacing before relying on lines or boxes
- lower nonessential contrast
- keep frequently used actions discoverable but not visually loud

Success condition:
The toolbar should feel organized and efficient without dominating the window.

### Sidebars and panels
Target changes:

- lower panel contrast
- reduce border heaviness
- simplify headings and section framing
- make selected states clear but restrained

Success condition:
Panels should support content, not compete with it.

### About screen and product identity surfaces
Target changes:

- stronger brand cohesion with splash/start center
- cleaner typography and spacing
- premium composition instead of utility-first presentation

Success condition:
All brand surfaces should clearly belong to one deliberate product identity.

## What to Avoid

Do not move toward:

- highly colorful creative-suite aesthetics
- oversized consumer-app softness
- heavy translucency or glassmorphism as a primary style
- gradient-heavy decorative treatment
- ultra-minimal low-contrast styling
- disruptive layout changes that reduce office-suite familiarity

The result should still feel like serious productivity software.

## Implementation Priorities

### Tier 1 — highest visual ROI
1. splash screen
2. start center
3. about/product identity surfaces
4. top-level chrome tone and spacing

### Tier 2
5. sidebars and panel styling
6. toolbar visual quieting
7. spacing normalization across controls and major surfaces

### Tier 3
8. selective icon polish
9. empty states and secondary branded surfaces
10. consistency pass across modules

## Implementation Boundaries

This spec is intentionally visual and product-facing.

It should not assume large interaction model changes, major workflow redesign, or deep feature restructuring.

The preferred implementation path should focus on:

- theme and branding surfaces
- window/chrome styling opportunities already available in the LibreOffice-style stack
- start center and branded resource refinement
- selective UI surface polish rather than broad risky rearchitecture

## Review Criteria

A redesigned surface should be accepted only if it is visibly:

- calmer
- more coherent
- less cluttered
- more premium
- more recognizably part of a single 可圈office design language

Across screenshots, the redesign should make it obvious that:

- the product is custom, not merely renamed
- entry surfaces carry premium brand identity
- working surfaces prioritize clarity and focus
- the document canvas is visually dominant

## Deliverable Outcome

The intended result is a desktop UI that feels:

- polished enough for executive or enterprise use
- pleasant enough for daily document work
- branded enough to stand on its own identity
- restrained enough to remain trustworthy and productive
