#!/usr/bin/env bash
# V3 W6/M5.1 - Plan-Act-Observe planner metadata runtime smoke.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
src_root="$repo_root/libreoffice-core"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

[[ -d "$src_root" ]] || fail "missing source root $src_root"

python3 - "$repo_root" "$src_root" <<'PY'
from __future__ import annotations

import sys
from pathlib import Path

repo = Path(sys.argv[1])
src = Path(sys.argv[2])

runtime_hxx = src / "sfx2/source/sidebar/AIChatAgentPlannerRuntime.hxx"
runtime_cxx = src / "sfx2/source/sidebar/AIChatAgentPlannerRuntime.cxx"
library_mk = src / "sfx2/Library_sfx.mk"
plan_schema = repo / "docs/schemas/agent-step-plan.schema.json"
result_schema = repo / "docs/schemas/agent-step-result.schema.json"
task_state_schema = repo / "docs/schemas/agent-task-state.schema.json"
w6_spec = repo / "docs/product/v3/w6-agent-multistep-spec.md"
dependency_policy = repo / "docs/product/v3/w6-dependency-policy.md"
plan_validation_policy = repo / "docs/product/v3/w6-plan-validation-policy.md"
approval_policy = repo / "docs/product/v3/w6-approval-policy.md"
resume_policy = repo / "docs/product/v3/w6-resume-policy.md"
shadow_doc_policy = repo / "docs/product/v3/w6-shadow-doc-policy.md"
prompt_policy = repo / "docs/product/v3/w6-prompt-library.md"
agent_plan_test = repo / "tests/v3-agent-step-plan-test.sh"
agent_result_test = repo / "tests/v3-agent-step-result-state-test.sh"
todo = repo / "docs/product/v3/v3-upgrade-development-todolist-2026-06-13.md"
in_app = repo / "tests/v3-in-app-chat-test.sh"

for path in [
    runtime_hxx,
    runtime_cxx,
    library_mk,
    plan_schema,
    result_schema,
    task_state_schema,
    w6_spec,
    dependency_policy,
    plan_validation_policy,
    approval_policy,
    resume_policy,
    shadow_doc_policy,
    prompt_policy,
    agent_plan_test,
    agent_result_test,
    todo,
    in_app,
]:
    if not path.exists():
        raise SystemExit(f"FAIL: missing {path}")

hxx = runtime_hxx.read_text()
cxx = runtime_cxx.read_text()
mk = library_mk.read_text()
schema = plan_schema.read_text()
result_schema_text = result_schema.read_text()
task_state_schema_text = task_state_schema.read_text()
w6_text = w6_spec.read_text()
dependency_text = dependency_policy.read_text()
plan_validation_text = plan_validation_policy.read_text()
approval_text = approval_policy.read_text()
resume_text = resume_policy.read_text()
shadow_doc_text = shadow_doc_policy.read_text()
prompt_text = prompt_policy.read_text()
agent_plan_test_text = agent_plan_test.read_text()
agent_result_test_text = agent_result_test.read_text()
todo_text = todo.read_text()
in_app_text = in_app.read_text()
combined = hxx + cxx


def strip_leading_block_comments(text: str) -> str:
    body = text.lstrip()
    while body.startswith("/*") and "*/" in body:
        body = body.split("*/", 1)[1].lstrip()
    return body


cxx_body = strip_leading_block_comments(cxx)

request_fields = [
    "TaskId",
    "SchemaVersion",
    "GoalHash",
    "GoalLength",
    "CreatedAt",
    "OwnerSurface",
    "MaxSteps",
    "Policy",
    "Steps",
    "RootEvidenceRequiresPolicyDecision",
    "RootEvidenceRequiresEvidenceRecord",
    "RootAuditLogRequired",
    "BlocksMergeOnMissingEvidence",
]

policy_fields = [
    "ApprovalMode",
    "SelectedModeSource",
    "PromptStrategy",
    "PerStepRequiresExplicitUserChoice",
    "ImplicitPerStepPromptsAllowed",
    "ReviewStepRequired",
    "CrossSessionResumeAllowed",
    "ResumePoint",
    "RequiresUserConfirmation",
    "RequiresDocumentHashMatch",
    "RequiresShadowSnapshot",
    "RequiresAuditReplay",
    "AutoResumeAllowed",
    "StaleCheckpointBehavior",
    "DefaultServiceMode",
    "AllowPublicEgress",
    "RequiresPolicyPreflight",
    "SandboxMode",
    "ShadowDocMode",
    "WriterCompatibilityTarget",
    "CreatesNewDocShellType",
    "MainDocMutationBeforeApprovalAllowed",
    "MergeRequiresApproval",
    "GraphType",
    "ExecutionOrder",
    "AllowsCycles",
    "AllowsFutureDependencies",
    "AllowsParallelRuntime",
    "RuntimeSchedulerImplementation",
    "ValidationPhase",
    "OnInvalidPlan",
    "BlocksExecution",
    "AutoRetryAllowed",
    "AutoSimplificationAllowed",
    "RuntimePlannerImplementation",
    "PromptSetId",
    "PromptSetVersion",
    "PlannerPromptId",
    "ActorPromptId",
    "ObserverPromptId",
    "Temperature",
    "TopP",
    "SeedRequired",
    "PublicEgressAllowed",
    "RuntimePromptExecution",
    "PatchStepMustUseApplyPlanRuntime",
    "ParagraphAction",
    "CellAction",
    "SlideElementAction",
]

checks = {
    "schema active": "v3-agent-step-plan/0.1" in schema and '"maxItems": 25' in schema and '"forward-only-dag"' in schema,
    "result state contracts present": "v3-agent-step-result/0.1" in result_schema_text and "agent-task-state" in task_state_schema_text,
    "policies active": "runtime scheduler not started" in dependency_text and "planner runtime not started" in plan_validation_text and "approval UI runtime not started" in approval_text and "resume runtime not started" in resume_text and "shadow doc runtime not started" in shadow_doc_text and "prompt runtime not started" in prompt_text,
    "w6 spec self-test": "agent-step-plan self-test" in w6_text and "Checks: 13" in w6_text and "Plan-Act-Observe" in w6_text,
    "contract tests still present": "forward-only-dag" in agent_plan_test_text and "fail-closed-user-visible" in agent_plan_test_text and "usesV2AsyncCowork" in agent_result_test_text,
    "runtime class": "class AIChatAgentPlannerRuntime final" in hxx,
    "step struct": "struct AIChatAgentPlanStep" in hxx,
    "policy struct": "struct AIChatAgentPlannerPolicy" in hxx,
    "request struct": "struct AIChatAgentPlannerRequest" in hxx,
    "result struct": "struct AIChatAgentPlannerResult" in hxx,
    "request fields": all(field in hxx for field in request_fields),
    "policy fields": all(field in hxx for field in policy_fields),
    "compiled": "sfx2/source/sidebar/AIChatAgentPlannerRuntime" in mk,
    "validate api": "ValidatePlan(const AIChatAgentPlannerRequest& rRequest) const" in hxx + cxx,
    "default policy": "MakeDefaultPolicy" in hxx + cxx and "w6-plan-act-observe-v1" in cxx,
    "task id guard": "IsTaskIdAllowed" in hxx + cxx and 'rTaskId.startsWith(u"agt-"_ustr)' in cxx,
    "owner surface guard": "IsOwnerSurfaceAllowed" in hxx + cxx and 'rOwnerSurface == u"writer"_ustr' in cxx and 'rOwnerSurface == u"calc"_ustr' in cxx and 'rOwnerSurface == u"impress"_ustr' in cxx,
    "schema shape guard": "IsPlanShapeAllowed" in hxx + cxx and "v3-agent-step-plan/0.1" in cxx and "GoalLength < 8" in cxx and "rRequest.MaxSteps > 25" in cxx,
    "hash only goal": "GoalHash" in hxx + cxx and "goal-hash-only=true" in cxx and "raw-goal=false" in cxx,
    "hash only step text": "TitleHash" in hxx + cxx and "DescriptionHash" in hxx + cxx and "raw-step-text=false" in cxx,
    "approval policy guard": "IsApprovalPolicyAllowed" in hxx + cxx and "default-whole-task" in cxx and "explicit-user-choice" in cxx and "ImplicitPerStepPromptsAllowed = false" in cxx,
    "resume policy guard": "ResumePoint = u\"evidence-complete-checkpoint\"_ustr" in cxx and "AutoResumeAllowed = false" in cxx and "fail-closed-user-visible" in cxx,
    "data boundary guard": "IsDataBoundaryAllowed" in hxx + cxx and "offline" in cxx and "private" in cxx and "AllowPublicEgress = false" in cxx,
    "sandbox guard": "IsSandboxAllowed" in hxx + cxx and "shadow-doc" in cxx and "discard-step-branch" in cxx,
    "shadow doc guard": "IsShadowDocPolicyAllowed" in hxx + cxx and "per-step-compatible-branch" in cxx and "v2-w3-swdocshell" in cxx and "CreatesNewDocShellType = false" in cxx and "main-document-mutation=false" in cxx,
    "dependency policy guard": "IsDependencyPolicyAllowed" in hxx + cxx and "forward-only-dag" in cxx and "topological-index" in cxx and "AllowsParallelRuntime = false" in cxx,
    "forward dag guard": "HasForwardOnlyDag" in hxx + cxx and "nDependency >= rStep.Index" in cxx and "ContainsDuplicateDependency" in cxx,
    "planner validation guard": "IsPlannerValidationAllowed" in hxx + cxx and "before-execution" in cxx and "AutoRetryAllowed = false" in cxx and "AutoSimplificationAllowed = false" in cxx,
    "prompt policy guard": "IsPromptPolicyAllowed" in hxx + cxx and "planner-v1" in cxx and "actor-v1" in cxx and "observer-v1" in cxx and "Temperature = 0" in cxx and "TopP = 1" in cxx,
    "token lock guard": "IsTokenLockAllowed" in hxx + cxx and "ParagraphAction = 7" in cxx and "CellAction = 5" in cxx and "SlideElementAction = 4" in cxx,
    "step kind guard": "IsStepKindAllowed" in hxx + cxx and "fetch" in cxx and "query" in cxx and "transform" in cxx and "patch" in cxx and "review" in cxx,
    "expected output guard": "IsExpectedOutputAllowed" in hxx + cxx and "connector-manifest" in cxx and "knowledge-index-result" in cxx and "agent-step-result" in cxx and "apply-plan-runtime" in cxx and "user-approval" in cxx,
    "step evidence guard": "IsStepEvidenceAllowed" in hxx + cxx and "policy-decision" in cxx and "connector-fetch" in cxx and "kb-query" in cxx and "shadow-doc-diff" in cxx and "apply-plan-runtime-validated" in cxx,
    "review step guard": "HasReviewStep" in hxx + cxx and "review-step-required" in cxx,
    "apply plan guard": "PatchStepsUseApplyPlanEvidence" in hxx + cxx and "apply-plan-token-lock-invalid" in cxx,
    "root evidence guard": "RootEvidenceRequiresPolicyDecision" in hxx + cxx and "RootEvidenceRequiresEvidenceRecord" in hxx + cxx and "RootAuditLogRequired" in hxx + cxx and "BlocksMergeOnMissingEvidence" in hxx + cxx,
    "plan id": "MakePlanId" in hxx + cxx and "agp-" in cxx,
    "planner evidence": "MakePlannerEvidenceId" in hxx + cxx and "evidence:agent-plan:" in cxx,
    "hash reference": "MakePlannerHashReference" in hxx + cxx and "sha256:" in cxx,
    "fail closed message": "MakeFailureMessage" in cxx and "agent-plan-invalid reason=" in cxx and "schema-validated=false" in cxx and "fail-closed-user-visible=true" in cxx,
    "success message": "agent-plan-validated task-id=" in cxx and "state=schema-validated" in cxx and "plan-act-observe=true" in cxx,
    "runtime not started posture": "runtimePlannerImplementation=not-started" in cxx and "runtimeSchedulerImplementation=not-started" in cxx and "runtimePromptExecution=not-started" in cxx and "runtimeShadowDocImplementation=not-started" in cxx,
    "no step execution": "step-execution=false" in cxx and "actor-runtime=false" in cxx and "observer-runtime=false" in cxx,
    "no public egress": "public-egress=false" in cxx and "allowPublicEgress=false" in cxx,
    "in app runs planner smoke": "v3-agent-planner-runtime-test.sh" in in_app_text,
    "todo records m5.1 complete": "- [x] M5.1 Implement Plan-Act-Observe task planner runtime" in todo_text and "Follow-up task id: M5.2" in todo_text,
    "no raw goal field": "GoalText" not in combined and "RawGoal" not in combined and "PromptText" not in combined,
    "no raw step text field": "OUString Title;" not in hxx and "OUString Description;" not in hxx and "RawStep" not in combined,
    "no raw prompt": "RawPrompt" not in combined and "PromptBody" not in combined,
    "no document content": "DocumentText" not in combined and "storesDocumentContent=true" not in combined,
    "no main doc mutation api": "ScDoc" not in combined and "SdDrawDocument" not in combined and "GetDoc()" not in combined and "SetModified" not in combined,
    "no shadow doc runtime": "ShadowDocRuntime" not in combined and "SwDocShell*" not in combined and "SwDocShell&" not in combined,
    "no apply execution": "ExecuteList" not in combined and "ApplyPlan(" not in combined,
    "no llm/model runtime": "LLM" not in combined and "ModelDownloader" not in combined and "EmbeddingPipeline" not in combined,
    "no network api": "INetURLObject" not in combined and "curl" not in combined.lower() and "http://" not in cxx_body.lower() and "https://" not in cxx_body.lower(),
    "no webview": "WebView" not in combined,
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: " + ", ".join(failed))

print(f"V3 agent planner runtime self-test passed. Checks: {len(checks)}")
PY
