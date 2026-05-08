# Engine Capability Upgrade Plan

Generated: 2026-04-28

This is the next-stage product plan for making 可圈office richer, more intelligent, and more useful across real office domains without compromising document trust.

## Executive Direction

The product direction is:

- Document trust first.
- Task acceleration second.
- AI last, optional, preview-first, and policy-controlled.

AI should not be a generic chatbot bolted onto an office suite. It should compress real office workflows: inspect a document, explain risks, propose structured changes, preview the result, apply safely, verify compatibility, and leave evidence.

## Product Pillars

| Pillar | Meaning | First Proof |
| --- | --- | --- |
| Compatibility trust layer | Every intelligent feature must prove it does not damage Office/PDF fidelity. | DOCX/XLSX/PPTX round-trip, validator readiness, visual/layout evidence. |
| Document intelligence engine | Shared contracts for diagnostics, previews, apply plans, evidence, and budgets. | Writer diagnostics plus schema-backed preview action contracts. |
| Workflow compression | Convert multi-step work into task flows, not chat sessions. | Clean formatting, prepare for sharing, check compatibility, generate deck draft. |
| Business-domain packs | Package templates, diagnostics, and evidence for concrete Chinese office domains. | Government/enterprise document pack, budget/finance pack, meeting/report pack. |
| Preview/apply safety | Nothing document-changing happens silently. | One-by-one fix with single undo group and rollback evidence. |
| Service-mode governance | Offline core remains first-class; local/private/cloud are explicit policy modes. | Plugin manifest validator and service-mode gates before runtime providers. |
| Workbench evidence console | Workbench shows task status, blockers, previews, and trust evidence. | Start Center task cards plus live accessibility evidence. |

## Priority Feature Matrix

| Priority | Workflow | Domains | Engine Work | Acceptance Evidence |
| --- | --- | --- | --- | --- |
| P0 | Chinese DOCX document trust | Government, enterprise, reports, contracts | Styles, headings, numbering, tables, headers/footers, comments, tracked changes, font fallback, PDF diagnostics. | Writer analyzer stability, DOCX round-trip, PDF export, layout evidence. |
| P0 | XLSX budget and finance trust | Finance, budgets, sales, operations | Formula compatibility, filters, charts, print areas, merged cells, dates/currency, hidden row/column diagnostics. | XLSX round-trip, formula result checks, chart/filter/print-area evidence. |
| P0 | PDF export confidence | Government, contracts, resumes, teaching | PDF/A readiness, embedded Chinese fonts, page count stability, bookmarks/TOC, visual evidence. | veraPDF readiness or explicit blocker, PDF export evidence, page/font checks. |
| P1 | Report production | Enterprise, government, meetings | TOC, captions, tables, outline diagnostics, DOCX/PDF proof. | End-to-end report workflow with compatibility evidence. |
| P1 | Meeting minutes and task follow-up | Meetings, enterprise | Minutes template, action-item tables, participant/date fields, export/share checks. | Offline template route, Writer/Calc linked evidence, PDF export. |
| P1 | Deterministic PPT draft generation | Reports, sales, teaching | Normalized outline to editable Impress slides, title/body placeholders, text fitting, notes diagnostics. | Editable slide count, PPTX export, legacy path preserved. |
| P2 | Contract review workflow | Legal/business contracts | Clause numbering, cross-reference checks, redline/comment preservation, export lock-down. | Redline/comment preservation, DOCX round-trip, PDF final export. |
| P2 | Resume and HR documents | Resumes, HR | Chinese resume templates, alignment/font diagnostics, PDF preview. | One-page stability, PDF font embedding, DOCX round-trip. |
| P2 | Teaching courseware | Education | Courseware templates, outline-to-slides, image/table placeholders, PPTX/PDF export. | Editable placeholders, PPTX/PDF export, template smoke. |
| P3 | AI writing and generation | All | Selected-context request, preview-only insertion, local/private provider boundaries. | No silent mutation, consent/policy evidence, editable output. |

## Domain Packs

| Pack | Included Artifacts | Required Diagnostics | Gate |
| --- | --- | --- | --- |
| Government/enterprise document pack | Notice, official report, policy memo, meeting minutes, table-heavy report. | Chinese font fallback, heading hierarchy, numbering, table overflow, header/footer, DOCX/PDF risk. | 30 DOCX lane samples, round-trip pass, PDF/layout evidence. |
| Business report pack | Weekly report, project review, annual summary, data appendix. | TOC, captions, tables, mixed fonts, paragraph spacing, image anchoring. | Writer analyzer stable twice, no modified-state change, DOCX/PDF comparison. |
| Budget/finance pack | Department budget, reimbursement, cashflow, sales forecast. | Formula errors, suspicious ranges, hidden rows, date/currency, print overflow. | XLSX round-trip, formula checks, chart/print evidence. |
| Meeting pack | Agenda, minutes, decision log, action tracker. | Missing owner/date/deadline, table consistency, export readiness. | Writer/Calc workflow and PDF export proof. |
| Sales pack | Proposal deck, quotation, follow-up sheet. | Filters, charts, stages, PPT theme/text fitting. | XLSX/PPTX round-trip and editable slide checks. |
| Teaching pack | Lesson plan, courseware, handout. | Slide structure, notes support, text overflow, image placeholders. | PPTX/PDF export and courseware template smoke. |
| Resume pack | Chinese resume, cover letter, portfolio PDF. | Alignment, font consistency, section completeness, PDF font embedding. | PDF visual check and one-page layout stability. |

## Interaction Model

Capabilities should be exposed as user tasks, not engine names.

Primary task entries:

- Open and inspect document.
- Prepare for sharing.
- Check compatibility.
- Make accessible.
- Clean formatting.
- Translate or rewrite with AI.
- Generate presentation draft.
- Recover or repair document.

Document-side panel groups:

- Diagnose: accessibility, compatibility, styles, fonts, layout risks.
- Fix: one-by-one repairs, grouped fixes, formatting cleanup, table/list normalization.
- AI: rewrite, summarize, translate, explain, generate outline.
- Export: PDF, DOCX, ODT, print readiness, sharing checks.

Every document-changing workflow follows:

```text
Task selected
-> capability check
-> policy and engine gate
-> analyze
-> preview
-> user review
-> apply one / apply and next / fix all preview / reject
-> verify result
-> evidence record
```

`Fix all` is allowed only when the engine separates safe, medium-risk, and high-risk fixes. High-risk fixes remain one-by-one.

## Engine Roadmap

### M3-01: Engine Contract Spine

Define or extend data contracts for:

- capability manifest
- diagnostic
- preview action
- apply plan
- document snapshot
- provider request
- evidence record
- performance budget

Exit gate:

- JSON fixtures pass for valid and invalid contracts.
- Dashboard and readiness reports list the contracts.
- No runtime provider or document mutation is introduced.

### M3-02: Capability Registry Stub

Add a built-in capability registry design and, later, a local-only stub.

Registry answers:

- Which module is active?
- Which capabilities are available?
- Is the capability preview-only, apply-capable, blocked, or disabled by policy?
- What service mode is required?
- What evidence and budget gates apply?

Exit gate:

- Built-in capabilities are discoverable without runtime plugin loading.
- Private/cloud capabilities remain blocked by service policy.
- UI can show blocked/preview-only/available state.

### M3-03: Writer One-By-One Fix Path

Build the first deterministic local apply path after preview.

First candidate:

- a single low-risk Writer formatting fix such as long-paragraph spacing or heading normalization.

Exit gate:

- Preview shows exactly what changes.
- Apply creates one undo unit.
- Undo restores prior document state.
- Failure leaves document unchanged.
- Repeated diagnostics update after apply.

### M3-04: Calc Diagnostic Seed

Add read-only Calc diagnostics for high-risk business documents.

First rules:

- formula error cells
- suspicious blank ranges
- hidden rows/columns
- print-area overflow
- date/currency inconsistency

Exit gate:

- Diagnostics are stable across repeated runs.
- No modified-state or undo-stack mutation.
- XLSX smoke evidence remains green.

### M3-05: Impress Draft Workflow Expansion

Expand the deterministic presentation builder without UI/provider scope creep.

First rules:

- title/body placeholder editability
- text fitting diagnostics
- bullet-depth limits
- speaker notes materialization or stable unsupported diagnostic

Exit gate:

- PPTX export succeeds.
- Legacy Writer-to-Impress path remains untouched.
- Generated deck opens and remains editable.

### M3-06: Workbench Evidence Console

Workbench should surface task availability and trust state.

Card states:

- Available
- Preview only
- Blocked by policy
- Needs document
- Beta disabled
- Requires compatibility proof

Exit gate:

- Keyboard and screen-reader path works.
- Live accessibility blocker is closed.
- No color-only status.

### M3-07: Local/Offline Plugin Runtime Design

Design only, no runtime execution until blockers close.

Prerequisites:

- signing/trust design
- allowlist and disable-all switch
- quarantine
- crash isolation
- service-mode enforcement
- no-document-mutation-on-failure tests

Exit gate:

- Runtime remains blocked until all prerequisites are proven.

### M3-08: AI Provider Preview Path Design

Design selected-context AI requests after local deterministic flows.

Rules:

- explicit user action
- visible context summary
- no live document handle
- scoped payload
- timeout and cancellation
- output as preview/editable insertion only
- no silent replacement

Exit gate:

- Provider failure leaves document state, selection, undo stack, and modified state unchanged.

## Quality Gates

| Gate | Requirement |
| --- | --- |
| Preview gate | Every document-changing command has preview, undo, or checkpoint behavior. |
| Accessibility gate | Task flows work with keyboard and screen reader. |
| Compatibility gate | Fixes are verified against target formats where relevant. |
| Policy gate | Cloud/private/local modes obey visible policy controls. |
| Trust gate | Users can see why an issue exists, what will change, and how it was verified. |
| Failure gate | Blocked, partial, failed, and unavailable states are explicit and recoverable. |
| Batch safety gate | Fix all cannot silently apply high-risk transformations. |
| Audit/evidence gate | AI insertions, compatibility repairs, and accessibility fixes leave inspectable local evidence. |

## Current Non-Negotiable Blockers

These remain blockers before any beta-quality claim:

- Trusted exact Officeotron and veraPDF validator assets.
- Strict source hygiene.
- Live Workbench accessibility evidence.

These remain blockers before runtime AI/provider/plugin claims:

- plugin signing/trust
- allowlist and disable-all
- quarantine
- crash isolation
- service-mode enforcement
- consent and selected-context summary
- failure isolation proving no document mutation

## Ownership

| Lane | Codex | Clavue |
| --- | --- | --- |
| Product/control plan | Own roadmap, gates, schemas, dashboard wording. | Review source feasibility and scope risk. |
| Engine contracts | Define schema and fixture gates. | Audit source entry points and dependency boundaries. |
| Writer intelligence | Review and gate. | Own source implementation once round packet is approved. |
| Calc diagnostics | Define initial contracts and evidence. | Audit Calc read-only extraction points before code. |
| Impress/PPT | Gate deterministic model and evidence. | Own builder source work within explicit scope. |
| Workbench UX | Define task state and accessibility gates. | Verify live behavior and source-entry risk. |
| AI/provider | Keep blocked until policy prerequisites. | Review runtime risk before implementation. |

## Immediate Next Round

Round: `M3-04 Writer One-By-One Apply Guardrail Acceptance + Beta Hardening`

Owner: Single owner per accepted round packet

Current resume point:

- M3-01 source-entry audit is accepted, M3-02 contract fixtures are accepted, and M3-03 built-in local/offline registry stub design is accepted as documentation/control-plane work;
- accept the M3-04 Writer one-by-one apply guardrail packet before any Writer apply implementation;
- keep beta promotion blocked by exactly three open blockers: strict validator readiness, strict source hygiene, and live Workbench accessibility evidence.

Purpose:

- review and accept Writer apply guardrails: source surfaces, preview preconditions, one accepted user action as one undo unit, rollback/unchanged-document failure behavior, modified-state tests, and repeated diagnostics after apply;
- continue beta hardening by acquiring trusted exact Officeotron and veraPDF assets, executing the source-hygiene release packet until strict mode passes, and completing live Workbench accessibility review;
- do not implement runtime registry code, UI commands, provider/plugin runtime, import/export changes, Writer apply code, Calc diagnostics, Workbench UI, undo wiring, or document mutation in this round.
