#!/usr/bin/env bash
# V3 W9/M7.4 - i18n locale and manual docs runtime smoke.

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

import json
import sys
from pathlib import Path

repo = Path(sys.argv[1])
src = Path(sys.argv[2])

runtime_hxx = src / "sfx2/source/sidebar/AIChatI18nManualRuntime.hxx"
runtime_cxx = src / "sfx2/source/sidebar/AIChatI18nManualRuntime.cxx"
edition_hxx = src / "sfx2/source/sidebar/AIChatEditionPolicyRuntime.hxx"
edition_cxx = src / "sfx2/source/sidebar/AIChatEditionPolicyRuntime.cxx"
tenant_hxx = src / "sfx2/source/sidebar/AIChatTenantContextRuntime.hxx"
tenant_cxx = src / "sfx2/source/sidebar/AIChatTenantContextRuntime.cxx"
policy_cxx = src / "sfx2/source/sidebar/AIChatPolicyEngineRuntime.cxx"
audit_cxx = src / "sfx2/source/sidebar/AIChatAuditLogRuntime.cxx"
library_mk = src / "sfx2/Library_sfx.mk"
i18n_schema = repo / "docs/schemas/i18n-locale-policy.schema.json"
manual_schema = repo / "docs/schemas/manual-docs-manifest.schema.json"
policy_schema = repo / "docs/schemas/policy-rule.schema.json"
i18n_fixture = repo / "docs/qa/fixtures/v3/i18n-locale/valid/zh-cn.json"
manual_fixture = repo / "docs/qa/fixtures/v3/manual-docs/valid/manual-docs-manifest.json"
w9_spec = repo / "docs/product/v3/w9-market-readiness-spec.md"
todo = repo / "docs/product/v3/v3-upgrade-development-todolist-2026-06-13.md"
i18n_contract = repo / "tests/v3-i18n-locale-test.sh"
manual_contract = repo / "tests/v3-manual-docs-test.sh"
edition_runtime = repo / "tests/v3-edition-policy-runtime-test.sh"
tenant_test = repo / "tests/v3-tenant-context-runtime-test.sh"
policy_test = repo / "tests/v3-policy-engine-runtime-test.sh"
no_egress_test = repo / "tests/v3-local-cloud-no-egress-test.sh"
in_app = repo / "tests/v3-in-app-chat-test.sh"

for path in [
    runtime_hxx,
    runtime_cxx,
    edition_hxx,
    edition_cxx,
    tenant_hxx,
    tenant_cxx,
    policy_cxx,
    audit_cxx,
    library_mk,
    i18n_schema,
    manual_schema,
    policy_schema,
    i18n_fixture,
    manual_fixture,
    w9_spec,
    todo,
    i18n_contract,
    manual_contract,
    edition_runtime,
    tenant_test,
    policy_test,
    no_egress_test,
    in_app,
]:
    if not path.exists():
        raise SystemExit(f"FAIL: missing {path}")

hxx = runtime_hxx.read_text()
cxx = runtime_cxx.read_text()
combined = hxx + cxx
edition = edition_hxx.read_text() + edition_cxx.read_text()
tenant = tenant_hxx.read_text() + tenant_cxx.read_text()
policy = policy_cxx.read_text()
audit = audit_cxx.read_text()
mk = library_mk.read_text()
i18n_schema_text = i18n_schema.read_text()
manual_schema_text = manual_schema.read_text()
policy_schema_text = policy_schema.read_text()
i18n_value = json.loads(i18n_fixture.read_text())
manual_value = json.loads(manual_fixture.read_text())
w9_text = w9_spec.read_text()
todo_text = todo.read_text()
i18n_contract_text = i18n_contract.read_text()
manual_contract_text = manual_contract.read_text()
edition_runtime_text = edition_runtime.read_text()
tenant_test_text = tenant_test.read_text()
policy_test_text = policy_test.read_text()
no_egress_text = no_egress_test.read_text()
in_app_text = in_app.read_text()


def strip_leading_block_comments(text: str) -> str:
    body = text.lstrip()
    while body.startswith("/*") and "*/" in body:
        body = body.split("*/", 1)[1].lstrip()
    return body


cxx_body = strip_leading_block_comments(cxx)

locale_state_fields = ["OsLocale", "UiLocale", "SupportedLaunchLocales", "FallbackLocale"]
ui_fields = ["FollowsSystemLocale", "UsesExistingI18nPool", "SilentSwitchAllowed"]
override_fields = ["Enabled", "CommandPattern", "ExplicitOnly", "PersistsWithoutUserAction"]
ai_output_fields = ["DefaultLocale", "MatchesUiLocale", "InlineOverride", "OutputLanguage", "EvidenceRequired"]
manual_baseline_fields = ["Embedded", "OnlineMirror", "RequiredLocales"]
i18n_gate_fields = ["BlocksGA", "RequiresV2RegressionGreen", "RuntimeImplementation", "I18nPoolRuntimeActive", "PromptLanguageRuntimeActive", "CloudTranslationActive"]
locale_policy_fields = ["PolicyId", "SchemaVersion", "CreatedAt", "Locale", "Ui", "AiOutput", "Manual", "RequiredEvidence", "EvidenceIds", "Gates", "TenantContextRef", "PolicyContextRef", "AuditChainRef", "EditionPolicyRef", "NoEgressRef", "HashReference"]
topic_fields = ["TopicId", "TitleToken", "Required", "Embedded", "OnlineMirror", "Locales", "PathByLocale", "EvidenceId"]
manual_policy_fields = ["RootPath", "Embedded", "OnlineMirror", "HelpKey", "HelpMenuEntry", "SearchEnabled", "NoExternalDependency"]
manual_locales_fields = ["RequiredLocales", "LaunchLocales", "FallbackLocale", "FallbackForUntranslated"]
delivery_fields = ["EmbeddedBundle", "OnlineMirrorSource", "OfflineReadable", "RequiresPublicInternet", "UpdateChannel"]
manual_gate_fields = ["BlocksGA", "RequiresV2RegressionGreen", "RuntimeImplementation", "HelpViewerRuntimeActive", "OnlineMirrorSyncRuntimeActive", "RemoteDocsServiceActive"]
manifest_fields = ["ManifestId", "SchemaVersion", "CreatedAt", "Manual", "Locales", "Topics", "Delivery", "RequiredEvidence", "EvidenceIds", "Gates", "TenantContextRef", "PolicyContextRef", "AuditChainRef", "LocalePolicyRef", "EditionPolicyRef", "NoEgressRef", "HashReference"]
open_fields = ["OpenId", "ManifestId", "TopicId", "Locale", "PathRef", "OfflineOpenSucceeded", "RequiresPublicInternet", "EvidenceRequired", "EvidenceId", "AuditLogRef"]
apis = [
    "SaveLocalePolicy",
    "SaveManualManifest",
    "RecordManualOpen",
    "IsLocalePolicyIdAllowed",
    "IsManualManifestIdAllowed",
    "IsTimestampAllowed",
    "IsLocaleAllowed",
    "IsLaunchLocaleOrderAllowed",
    "IsRequiredManualLocalesAllowed",
    "IsAiOutputLanguageAllowed",
    "IsI18nRequiredEvidenceAllowed",
    "IsManualRequiredEvidenceAllowed",
    "IsManualTopicIdAllowed",
    "IsManualTopicOrderAllowed",
    "IsManualPathAllowed",
    "IsLocalePolicyShapeAllowed",
    "IsManualManifestShapeAllowed",
    "IsManualOpenRecordShapeAllowed",
    "MakeLocalePolicyId",
    "MakeManualManifestId",
    "MakeLocalePolicyHashReference",
    "MakeManualManifestHashReference",
    "MakeManualOpenId",
]

manual_topics = [topic["id"] for topic in manual_value["topics"]]
manual_paths = [path for topic in manual_value["topics"] for path in topic["pathByLocale"].values()]

checks = {
    "runtime class": "class AIChatI18nManualRuntime final" in hxx,
    "locale state struct": "struct AIChatI18nLocaleState" in hxx and all(field in hxx for field in locale_state_fields),
    "ui policy struct": "struct AIChatI18nUiPolicy" in hxx and all(field in hxx for field in ui_fields),
    "override struct": "struct AIChatI18nInlineOverride" in hxx and all(field in hxx for field in override_fields),
    "ai output struct": "struct AIChatI18nAiOutputPolicy" in hxx and all(field in hxx for field in ai_output_fields),
    "manual baseline struct": "struct AIChatI18nManualBaseline" in hxx and all(field in hxx for field in manual_baseline_fields),
    "i18n gate struct": "struct AIChatI18nGateState" in hxx and all(field in hxx for field in i18n_gate_fields),
    "locale policy struct": "struct AIChatI18nLocalePolicy" in hxx and all(field in hxx for field in locale_policy_fields),
    "topic struct": "struct AIChatManualTopic" in hxx and all(field in hxx for field in topic_fields),
    "manual policy struct": "struct AIChatManualPolicy" in hxx and all(field in hxx for field in manual_policy_fields),
    "manual locales struct": "struct AIChatManualLocales" in hxx and all(field in hxx for field in manual_locales_fields),
    "delivery struct": "struct AIChatManualDelivery" in hxx and all(field in hxx for field in delivery_fields),
    "manual gate struct": "struct AIChatManualGateState" in hxx and all(field in hxx for field in manual_gate_fields),
    "manifest struct": "struct AIChatManualDocsManifest" in hxx and all(field in hxx for field in manifest_fields),
    "open record struct": "struct AIChatI18nManualOpenRecord" in hxx and all(field in hxx for field in open_fields),
    "result struct": "struct AIChatI18nManualResult" in hxx and "Success" in hxx and "Message" in hxx,
    "public api": all(api in hxx + cxx for api in apis),
    "compiled": "sfx2/source/sidebar/AIChatI18nManualRuntime" in mk,
    "uses edition": '#include "AIChatEditionPolicyRuntime.hxx"' in hxx and "edition-policy:" in cxx,
    "uses tenant": "AIChatTenantContextRuntime" in cxx and "ValidateActionScope" in cxx,
    "uses audit timestamp": "AIChatAuditLogRuntime::IsTimestampAllowed" in cxx,
    "uses metadata hash": "AIChatKnowledgeIndexStore::MakeMetadataHash" in cxx,
    "storage sidecar": "kqoffice-v3-ai-i18n-manual" in cxx and "i18n-manual.tsv" in cxx,
    "append only": "AppendUtf8Line" in cxx and "setPos(osl_Pos_Absolut, nSize)" in cxx,
    "store records": "i18n-locale-policy" in cxx and "manual-docs-manifest" in cxx and "manual-open" in cxx,
    "i18n schema version": "v3-i18n-locale-policy/0.1" in cxx,
    "manual schema version": "v3-manual-docs/0.1" in cxx,
    "ids": 'rPolicyId.startsWith(u"i18n-"_ustr)' in cxx and 'rManifestId.startsWith(u"manual-"_ustr)' in cxx and 'rOpenRecord.OpenId.startsWith(u"mop-"_ustr)' in cxx,
    "launch locales": "LaunchLocales" in cxx and "zh-CN" in cxx and "en-US" in cxx and "ja-JP" in cxx and "zh-TW" in cxx,
    "required manual locales": "RequiredManualLocales" in cxx and "manualRequiredLocales=zh-CN,en-US" in cxx,
    "fallback locales": "fallbackLocale=en-US" in cxx and "fallbackForUntranslated=ja-JP,zh-TW" in cxx,
    "ui follows os": "OsLocale != rPolicy.Locale.UiLocale" in cxx and "uiFollowsSystemLocale=true" in cxx,
    "existing i18npool": "UsesExistingI18nPool" in hxx and "usesExistingI18nPool=true" in cxx,
    "silent switch forbidden": "SilentSwitchAllowed" in hxx and "silentSwitchAllowed=false" in cxx,
    "ai output matches": "MatchesUiLocale" in hxx and "aiOutputMatchesUiLocale=true" in cxx and "IsAiOutputLanguageAllowed" in cxx,
    "lang command": "^/lang (zh-CN|en-US|ja-JP|zh-TW|zh|en|ja)$" in cxx and "langOverrideExplicitOnly=true" in cxx,
    "no silent persist": "PersistsWithoutUserAction" in hxx and "persistsWithoutUserAction=false" in cxx,
    "manual root": "docs/manual/" in cxx and "RootPath" in hxx,
    "help key": "HelpKey" in hxx and "helpKey=?" in cxx and "HelpMenuEntry" in hxx,
    "manual search": "SearchEnabled" in hxx and "searchEnabled=true" in cxx,
    "offline readable": "OfflineReadable" in hxx and "offlineReadable=true" in cxx,
    "no external dependency": "NoExternalDependency" in hxx and "noExternalDependency=true" in cxx,
    "manual topics": all(x in cxx for x in ["index", "quickstart", "ai-features", "connectors", "tenant-admin", "companion", "localcloud", "troubleshooting"]) and "topics=8" in cxx,
    "manual paths": "docs/manual/" in cxx and 'u"/"_ustr + rTopicId + u".md"_ustr' in cxx,
    "manual open": "manual-open-recorded" in cxx and "offlineOpenSucceeded=true" in cxx and "requiresPublicInternet=false" in cxx,
    "i18n evidence": all(x in cxx for x in ["i18n-locale-policy", "locale-selection", "language-override", "ai-output-language", "evidence-record"]),
    "manual evidence": all(x in cxx for x in ["manual-docs-manifest", "embedded-help-open", "online-mirror-sync", "locale-coverage", "v2-regression-green"]),
    "shared evidence refs": "policy-decision" in cxx and "audit-log-entry" in cxx and "edition-policy" in cxx and "localcloud-no-egress" in cxx,
    "refs": "tenant-context:" in cxx and "policy-context:" in cxx and "audit-chain:" in cxx and "edition-policy:" in cxx and "localcloud-no-egress:" in cxx,
    "runtime gates": "metadata-runtime-active" in cxx and "I18nPoolRuntimeActive" in hxx and "PromptLanguageRuntimeActive" in hxx and "CloudTranslationActive" in hxx and "HelpViewerRuntimeActive" in hxx and "OnlineMirrorSyncRuntimeActive" in hxx and "RemoteDocsServiceActive" in hxx,
    "no service messages": "i18npool-runtime=not-started" in cxx and "prompt-language-runtime=not-started" in cxx and "cloud-translation=not-started" in cxx and "help-viewer-runtime=not-started" in cxx and "online-mirror-sync-runtime=not-started" in cxx and "remote-docs-service=not-started" in cxx,
    "tenant target": 'rTargetType == u"i18n-manual"_ustr' in tenant and 'rSurface == u"i18n-manual"_ustr' in tenant,
    "policy target": 'rTargetType == u"i18n-manual"_ustr' in policy and '"i18n-manual"' in policy_schema_text,
    "audit link": "AIChatAuditLogRuntime" in audit and "audit-log-entry-appended" in audit,
    "edition link": "AIChatEditionPolicyRuntime" in edition and "edition-policy-saved" in edition,
    "i18n schema": '"v3-i18n-locale-policy/0.1"' in i18n_schema_text and '"matchesUiLocale"' in i18n_schema_text and '"silentSwitchAllowed"' in i18n_schema_text,
    "manual schema": '"v3-manual-docs/0.1"' in manual_schema_text and '"requiresPublicInternet"' in manual_schema_text and '"const": false' in manual_schema_text,
    "fixture i18n": i18n_value["locale"]["osLocale"] == i18n_value["locale"]["uiLocale"] == "zh-CN" and i18n_value["aiOutput"]["outputLanguage"] == "Chinese",
    "fixture manual topics": manual_topics == ["index", "quickstart", "ai-features", "connectors", "tenant-admin", "companion", "localcloud", "troubleshooting"],
    "fixture manual paths": len(manual_paths) == 16 and len(set(manual_paths)) == 16,
    "fixture offline": manual_value["delivery"]["offlineReadable"] is True and manual_value["delivery"]["requiresPublicInternet"] is False,
    "contract i18n": "Checks: 8" in i18n_contract_text and "AI output default locale must match UI locale" in i18n_contract_text,
    "contract manual": "Checks: 8" in manual_contract_text and "Manual docs contract" in manual_contract_text,
    "w9 spec": "i18n-locale self-test" in w9_text and "manual-docs self-test" in w9_text and "zh-CN / en-US" in w9_text,
    "edition runtime regression": "AIChatEditionPolicyRuntime" in edition_runtime_text,
    "tenant runtime regression": "i18n-manual" in tenant_test_text,
    "policy runtime regression": "i18n-manual" in policy_test_text,
    "no egress regression": "public egress requires explicit opt-in" in no_egress_text,
    "in app umbrella": "v3-agent-failure-recovery-runtime-test.sh" in in_app_text,
    "todo m7.4 pending or complete": (
        "- [ ] M7.4 Finalize manual docs and i18n." in todo_text
        or "- [x] M7.4 Finalize manual docs and i18n." in todo_text
    ),
    "todo m7.4 recorded": (
        ("Start M7.4" in todo_text and "tests/v3-i18n-manual-runtime-test.sh" in todo_text)
        or ("- [x] M7.4 Finalize manual docs and i18n." in todo_text and "Follow-up task id: M7.5." in todo_text)
    ),
    "no raw manual body": "RawManual" not in combined and "ManualBody" not in combined and "ManualPayload" not in combined,
    "no raw document": "DocumentText" not in combined and "RawDocumentContent" not in combined and "storesDocumentContent=true" not in combined,
    "no raw prompt": "RawPrompt" not in combined and "PromptText" not in combined,
    "no public internet true": "requiresPublicInternet=true" not in combined and "publicEgress=true" not in combined,
    "no webview": "WebView" not in combined and "webview=true" not in combined,
    "no online fetch": "HttpClient" not in combined and "FetchDocs" not in combined and "DownloadManual" not in combined,
    "no network api": "INetURLObject" not in combined and "curl" not in combined.lower() and "http://" not in cxx_body.lower() and "https://" not in cxx_body.lower(),
    "no cloud translation": "CloudTranslationClient" not in combined and "TranslateApi" not in combined,
    "no telemetry": "Telemetry" not in combined and "Analytics" not in combined,
    "no sqlite/vector/model": "sqlite" not in combined.lower() and "lancedb" not in combined.lower() and "VectorStore" not in combined and "ModelRuntime" not in combined,
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: " + ", ".join(failed))

print(f"V3 i18n/manual runtime self-test passed. Checks: {len(checks)}")
PY
