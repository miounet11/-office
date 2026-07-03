#!/usr/bin/env bash
# V2 H9 worker/UI lifecycle gate.
#
# Locks the dynamic W5 lifecycle proof after L128/L144:
#   - TaskQueue emits W5 scheduling-contract evidence reasons.
#   - TaskScheduler runs the first synchronous worker lifecycle primitive.
#   - TaskRunner starts a real worker thread and emits in-process
#     notification events for UI/system-notification bridges.
#   - TaskReviewBridge converts awaiting-review notifications into
#     deterministic review-open requests for future OS toast clicks.
#   - TaskReviewBridge resolves review-open requests against TaskStore
#     and rejects stale task state / plan mismatches before UI handoff.
#   - AutoOpenReviewNotificationSink connects TaskRunner awaiting-review
#     notifications to stored-task diff-review-opened results.
#   - CoworkUiBridge connects the CoworkDialog new-task action to
#     TaskQueue -> TaskRunner -> AutoOpenReviewNotificationSink.
#   - Review accept bridge moves opened awaiting-review tasks to applied.
#   - CoworkDialog opens a visible DiffReview surface and accepts selected
#     awaiting-review tasks back to applied.
#   - OS-notification gateway payloads and click-through to stored review are
#     locked before platform-specific toast backends land.
#   - Cowork UI runner path can forward awaiting-review notifications into the
#     OS-notification sink seam while still auto-opening visible review.
#   - Native OS notification backend abstraction, macOS NSUserNotification
#     submitter, and non-macOS fallback are build/test locked without claiming
#     system click callbacks are complete.
#   - Native click callback payloads can be converted back into stored-review
#     open requests through the same validation path used by OS click core.
#   - macOS NSUserNotificationCenterDelegate dispatches native click payloads
#     into a registered CoworkDialog sink that opens stored review.
#   - Windows Shell notification-area backend posts balloon notifications and
#     dispatches click callbacks into the same native click sink path.
#   - kqoffice_cowork cppunit runs the lifecycle evidence contracts.
#   - Cowork UI entry can list TaskStore states and is shipped as a dialog
#     surface. This is not a full GUI click-through; that remains a separate
#     UITest/manual smoke item while svp is unstable.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if [[ -n "${KDOFFICE_SRC_ROOT:-}" ]]; then
    src_root="$(cd -P "$KDOFFICE_SRC_ROOT" && pwd)"
elif [[ -d "$repo_root/libreoffice-core" ]]; then
    src_root="$(cd -P "$repo_root/libreoffice-core" && pwd)"
elif [[ -d /Users/lu/kdoffice-src ]]; then
    src_root=/Users/lu/kdoffice-src
else
    src_root="$repo_root"
fi

if [[ -n "${PKG_CONFIG:-}" && -x "${PKG_CONFIG:-}" ]]; then
    :
elif [[ -x /tmp/kqoffice-pkgconf-utf8 ]]; then
    export PKG_CONFIG=/tmp/kqoffice-pkgconf-utf8
elif [[ -f "$repo_root/bin/kqoffice-pkgconf-utf8.sh" ]]; then
    export PKG_CONFIG="$repo_root/bin/kqoffice-pkgconf-utf8.sh"
fi

checks=0

require_file() {
    local path="$1"
    local label="$2"
    if [[ ! -f "$path" ]]; then
        echo "FAIL: missing $label at $path" >&2
        exit 1
    fi
    checks=$((checks + 1))
}

require_token() {
    local token="$1"
    local path="$2"
    local label="$3"
    if ! grep -Fq "$token" "$path"; then
        echo "FAIL: missing $label token '$token' in $path" >&2
        exit 1
    fi
    checks=$((checks + 1))
}

queue_cxx="$src_root/kqoffice/source/ai/cowork/TaskQueue.cxx"
queue_hxx="$src_root/kqoffice/source/ai/cowork/TaskQueue.hxx"
scheduler_cxx="$src_root/kqoffice/source/ai/cowork/TaskScheduler.cxx"
scheduler_hxx="$src_root/kqoffice/source/ai/cowork/TaskScheduler.hxx"
runner_cxx="$src_root/kqoffice/source/ai/cowork/TaskRunner.cxx"
runner_hxx="$src_root/kqoffice/source/ai/cowork/TaskRunner.hxx"
review_bridge_cxx="$src_root/kqoffice/source/ai/cowork/TaskReviewBridge.cxx"
review_bridge_hxx="$src_root/kqoffice/source/ai/cowork/TaskReviewBridge.hxx"
os_notification_cxx="$src_root/kqoffice/source/ai/cowork/TaskOsNotificationBridge.cxx"
os_notification_hxx="$src_root/kqoffice/source/ai/cowork/TaskOsNotificationBridge.hxx"
native_notification_cxx="$src_root/kqoffice/source/ai/cowork/TaskNativeOsNotificationBackend.cxx"
native_notification_hxx="$src_root/kqoffice/source/ai/cowork/TaskNativeOsNotificationBackend.hxx"
macos_native_notification_mm="$src_root/kqoffice/source/ai/cowork/MacTaskNativeOsNotificationBackend.mm"
windows_native_notification_cxx="$src_root/kqoffice/source/ai/cowork/WindowsTaskNativeOsNotificationBackend.cxx"
ui_bridge_cxx="$src_root/kqoffice/source/ai/cowork/CoworkUiBridge.cxx"
ui_bridge_hxx="$src_root/kqoffice/source/ai/cowork/CoworkUiBridge.hxx"
library_mk="$src_root/kqoffice/Library_kqoffice_ai.mk"
cowork_test="$src_root/kqoffice/qa/cppunit/test_cowork.cxx"
cowork_dialog="$src_root/cui/source/dialogs/cowork/CoworkDialog.cxx"
cowork_ui="$src_root/cui/uiconfig/ui/cowork-dialog.ui"
diff_review_panel="$src_root/svx/source/sidebar/diff-review/DiffReviewPanel.cxx"
diff_review_dialog_ui="$src_root/svx/uiconfig/ui/diff-review-dialog.ui"
svx_ui_config="$src_root/svx/UIConfig_svx.mk"
test_log="$repo_root/workdir/CppunitTest/kqoffice_cowork.test.log"

echo "=== V2 H9 worker/UI lifecycle gate ==="
echo "SRCDIR=$src_root"

require_file "$queue_cxx" "TaskQueue implementation"
require_file "$queue_hxx" "TaskQueue header"
require_file "$scheduler_cxx" "TaskScheduler implementation"
require_file "$scheduler_hxx" "TaskScheduler header"
require_file "$runner_cxx" "TaskRunner implementation"
require_file "$runner_hxx" "TaskRunner header"
require_file "$review_bridge_cxx" "TaskReviewBridge implementation"
require_file "$review_bridge_hxx" "TaskReviewBridge header"
require_file "$os_notification_cxx" "TaskOsNotificationBridge implementation"
require_file "$os_notification_hxx" "TaskOsNotificationBridge header"
require_file "$native_notification_cxx" "TaskNativeOsNotificationBackend implementation"
require_file "$native_notification_hxx" "TaskNativeOsNotificationBackend header"
require_file "$windows_native_notification_cxx" "WindowsTaskNativeOsNotificationBackend implementation"
require_file "$ui_bridge_cxx" "CoworkUiBridge implementation"
require_file "$ui_bridge_hxx" "CoworkUiBridge header"
require_file "$library_mk" "kqoffice_ai library makefile"
require_file "$cowork_test" "cowork cppunit"
require_file "$cowork_dialog" "CoworkDialog implementation"
require_file "$cowork_ui" "CoworkDialog UI"
require_file "$diff_review_panel" "DiffReview visible dialog implementation"
require_file "$diff_review_dialog_ui" "DiffReview visible dialog UI"
require_file "$svx_ui_config" "svx UIConfig"

tmp_log="$(mktemp -t v2-h9-cowork-cppunit.XXXXXX.log)"
trap 'rm -f "$tmp_log"' EXIT
V2_H9_PARALLELISM="${V2_H9_PARALLELISM:-2}"
if ! make PARALLELISM="$V2_H9_PARALLELISM" PKG_CONFIG="${PKG_CONFIG:-}" CppunitTest_kqoffice_cowork >"$tmp_log" 2>&1; then
    cat "$tmp_log"
    echo "FAIL: CppunitTest_kqoffice_cowork failed" >&2
    exit 1
fi
checks=$((checks + 1))

require_file "$test_log" "latest kqoffice_cowork cppunit log"

require_token "bool TaskQueue::cancel(const OUString& monthDir," "$queue_cxx" "reason-aware cancel implementation"
require_token "const OUString& reason," "$queue_hxx" "reason-aware cancel API"
require_token 'u"enqueued"_ustr' "$queue_cxx" "enqueue evidence"
require_token 'u"dispatched"_ustr' "$queue_cxx" "dispatch evidence"
require_token 'u"user-accepted"_ustr' "$queue_cxx" "accept/apply evidence"
require_token 'u"user-cancelled-before-dispatch"_ustr' "$queue_cxx" "pending cancel evidence"
require_token 'u"user-cancelled-mid-run"_ustr' "$queue_cxx" "running cancel evidence"
require_token 'u"refined-resubmit"_ustr' "$queue_cxx" "refine resubmit evidence"
require_token "kqoffice/source/ai/cowork/TaskScheduler" "$library_mk" "TaskScheduler build wiring"
require_token "kqoffice/source/ai/cowork/TaskRunner" "$library_mk" "TaskRunner build wiring"
require_token "kqoffice/source/ai/cowork/TaskOsNotificationBridge" "$library_mk" "TaskOsNotificationBridge build wiring"
require_token "kqoffice/source/ai/cowork/TaskNativeOsNotificationBackend" "$library_mk" "TaskNativeOsNotificationBackend build wiring"
require_token "MacTaskNativeOsNotificationBackend" "$library_mk" "macOS native notification build wiring"
require_token "WindowsTaskNativeOsNotificationBackend" "$library_mk" "Windows native notification build wiring"
require_token "gb_Library_use_system_win32_libs" "$library_mk" "Windows native notification system library wiring"
require_token "shell32" "$library_mk" "Windows shell notification library wiring"
require_token "gb_Library_add_objcxxobjects" "$library_mk" "macOS Objective-C++ build wiring"
require_token "Foundation" "$library_mk" "macOS Foundation framework wiring"
require_token "kqoffice/source/ai/cowork/TaskReviewBridge" "$library_mk" "TaskReviewBridge build wiring"
require_token "kqoffice/source/ai/cowork/CoworkUiBridge" "$library_mk" "CoworkUiBridge build wiring"
require_token "class SAL_DLLPUBLIC_EXPORT TaskWorker" "$scheduler_hxx" "worker interface"
require_token "class SAL_DLLPUBLIC_EXPORT TaskScheduler" "$scheduler_hxx" "scheduler interface"
require_token "bool TaskScheduler::runOne" "$scheduler_cxx" "scheduler runOne implementation"
require_token "recoverInterruptedRunning" "$scheduler_cxx" "restart recovery implementation"
require_token 'u"worker-apply-plan-ready"_ustr' "$scheduler_cxx" "worker success evidence"
require_token 'u"process-restart-during-run"_ustr' "$scheduler_cxx" "restart recovery evidence"
require_token "class SAL_DLLPUBLIC_EXPORT TaskNotificationSink" "$runner_hxx" "notification sink interface"
require_token "class SAL_DLLPUBLIC_EXPORT TaskRunner" "$runner_hxx" "runner interface"
require_token "startOneAndJoinForTest" "$runner_cxx" "real worker thread runner"
require_token "osl_setThreadName(\"KQOfficeTaskRunner\")" "$runner_cxx" "worker thread name"
require_token 'u"worker-started"_ustr' "$runner_cxx" "worker started notification"
require_token 'u"task-running"_ustr' "$runner_cxx" "task running notification"
require_token 'u"awaiting-review-notification"_ustr' "$runner_cxx" "awaiting-review notification"
require_token 'u"task-failed-notification"_ustr' "$runner_cxx" "failed notification"
require_token 'u"worker-idle"_ustr' "$runner_cxx" "worker idle notification"
require_token 'u"worker-empty"_ustr' "$runner_cxx" "empty queue notification"
require_token "OUString monthDir" "$runner_hxx" "notification month directory"
require_token "struct SAL_DLLPUBLIC_EXPORT TaskReviewRequest" "$review_bridge_hxx" "review request envelope"
require_token "class SAL_DLLPUBLIC_EXPORT TaskReviewRequestSink" "$review_bridge_hxx" "review request sink interface"
require_token "struct SAL_DLLPUBLIC_EXPORT TaskReviewOpenResult" "$review_bridge_hxx" "review open result envelope"
require_token "struct SAL_DLLPUBLIC_EXPORT TaskReviewAcceptResult" "$review_bridge_hxx" "review accept result envelope"
require_token "class SAL_DLLPUBLIC_EXPORT TaskReviewOpenSink" "$review_bridge_hxx" "review open sink interface"
require_token "class SAL_DLLPUBLIC_EXPORT AutoOpenReviewNotificationSink" "$review_bridge_hxx" "auto-open notification sink interface"
require_token "openReviewFromNotification" "$review_bridge_hxx" "notification click bridge API"
require_token "openReviewRequest" "$review_bridge_hxx" "review request open API"
require_token "acceptReviewResult" "$review_bridge_hxx" "review accept apply API"
require_token "buildReviewRequestFromNotification" "$review_bridge_cxx" "review request builder"
require_token 'u"open-review-request"_ustr' "$review_bridge_cxx" "review-open request token"
require_token 'u"diff-review-opened"_ustr' "$review_bridge_cxx" "diff review opened token"
require_token 'u"diff-review-accepted"_ustr' "$review_bridge_cxx" "diff review accepted token"
require_token 'u"notification-click-review-opened"_ustr' "$review_bridge_cxx" "notification click open source token"
require_token 'u"invalid-review-accept-request"_ustr' "$review_bridge_cxx" "invalid accept guard"
require_token 'u"review-accept-transition-failed"_ustr' "$review_bridge_cxx" "accept transition guard"
require_token "AutoOpenReviewNotificationSink::notify" "$review_bridge_cxx" "auto-open notification handler"
require_token "m_notificationSink.notify(notification)" "$review_bridge_cxx" "notification forwarding"
require_token "openReviewFromNotification(notification, m_store, m_openSink" "$review_bridge_cxx" "auto-open bridge dispatch"
require_token "autoOpenAttemptCount" "$review_bridge_hxx" "auto-open attempt counter"
require_token "autoOpenSuccessCount" "$review_bridge_hxx" "auto-open success counter"
require_token "TaskNotificationKind::AwaitingReview" "$review_bridge_cxx" "review event filter"
require_token "notification.monthDir.isEmpty()" "$review_bridge_cxx" "review request month guard"
require_token "TaskState::AwaitingReview" "$review_bridge_cxx" "stored task awaiting-review guard"
require_token "review-task-not-awaiting-review" "$review_bridge_cxx" "stale task state guard"
require_token "review-plan-mismatch" "$review_bridge_cxx" "plan mismatch guard"
require_token "queue.markApplied" "$review_bridge_cxx" "review accept marks applied"
require_token "struct SAL_DLLPUBLIC_EXPORT TaskOsNotificationRequest" "$os_notification_hxx" "OS notification request envelope"
require_token "class SAL_DLLPUBLIC_EXPORT TaskOsNotificationSink" "$os_notification_hxx" "OS notification sink interface"
require_token "class SAL_DLLPUBLIC_EXPORT OsNotificationTaskNotificationSink" "$os_notification_hxx" "OS notification runner sink"
require_token "buildOsNotificationFromTaskNotification" "$os_notification_hxx" "OS notification payload builder API"
require_token "openReviewFromOsNotificationClick" "$os_notification_hxx" "OS notification click open API"
require_token 'u"os-notification-posted"_ustr' "$os_notification_cxx" "OS notification posted token"
require_token 'u"os-notification-click-review"_ustr' "$os_notification_cxx" "OS notification click token"
require_token 'u"invalid-os-notification-click"_ustr' "$os_notification_cxx" "invalid OS click guard"
require_token 'u"任务已完成，等待审批"_ustr' "$os_notification_cxx" "OS notification visible title"
require_token "m_notificationSink.notify(notification)" "$os_notification_cxx" "OS notification forwarding"
require_token "m_osSink.postNotification(request)" "$os_notification_cxx" "OS notification dispatch"
require_token "openReviewRequest(request.reviewRequest, store" "$os_notification_cxx" "OS click stored review dispatch"
require_token "class SAL_DLLPUBLIC_EXPORT TaskNativeOsNotificationBackend" "$native_notification_hxx" "native OS notification backend interface"
require_token "struct SAL_DLLPUBLIC_EXPORT TaskNativeOsNotificationClickPayload" "$native_notification_hxx" "native OS notification click payload"
require_token "class SAL_DLLPUBLIC_EXPORT NativeTaskOsNotificationSink" "$native_notification_hxx" "native OS notification sink"
require_token "createPlatformTaskNativeOsNotificationBackend" "$native_notification_hxx" "platform native notification backend factory"
require_token "createWindowsTaskNativeOsNotificationBackend" "$native_notification_hxx" "Windows native notification backend factory"
require_token "buildOsNotificationRequestFromNativeClickPayload" "$native_notification_hxx" "native click payload builder API"
require_token "openReviewFromNativeOsNotificationClick" "$native_notification_hxx" "native click open API"
require_token "class SAL_DLLPUBLIC_EXPORT TaskNativeOsNotificationClickSink" "$native_notification_hxx" "native click sink interface"
require_token "setTaskNativeOsNotificationClickSink" "$native_notification_hxx" "native click sink registration API"
require_token "clearTaskNativeOsNotificationClickSink" "$native_notification_hxx" "native click sink clear API"
require_token "dispatchNativeOsNotificationClickPayload" "$native_notification_hxx" "native click dispatch API"
require_token "recordNativeOsNotificationSubmitEvidence" "$native_notification_hxx" "native notification submit evidence API"
require_token "recordNativeOsNotificationClickDispatchEvidence" "$native_notification_hxx" "native notification click dispatch evidence API"
require_token "recordNativeOsNotificationReviewOpenEvidence" "$native_notification_hxx" "native notification review-open evidence API"
require_token "taskNativeOsNotificationSmokeClickEnabled" "$native_notification_hxx" "native notification smoke click gate API"
require_token "FallbackTaskNativeOsNotificationBackend" "$native_notification_hxx" "fallback native notification backend"
require_token 'u"native-os-notification-unavailable"_ustr' "$native_notification_cxx" "native notification unavailable token"
require_token 'u"native-os-notification-submitted"_ustr' "$native_notification_cxx" "native notification submitted token"
require_token "postNativeNotification" "$native_notification_cxx" "native notification post API"
require_token "NativeTaskOsNotificationSink::postNotification" "$native_notification_cxx" "native notification sink dispatch"
require_token "createMacosTaskNativeOsNotificationBackend" "$native_notification_cxx" "macOS backend factory dispatch"
require_token "createWindowsTaskNativeOsNotificationBackend" "$native_notification_cxx" "Windows backend factory dispatch"
require_token "buildOsNotificationRequestFromNativeClickPayload" "$native_notification_cxx" "native click payload builder implementation"
require_token "openReviewFromNativeOsNotificationClick" "$native_notification_cxx" "native click review-open implementation"
require_token "openReviewFromOsNotificationClick(request, store" "$native_notification_cxx" "native click delegates to OS click core"
require_token "TaskNativeOsNotificationClickSink::~TaskNativeOsNotificationClickSink" "$native_notification_cxx" "native click sink virtual destructor"
require_token "setTaskNativeOsNotificationClickSink" "$native_notification_cxx" "native click sink registration implementation"
require_token "clearTaskNativeOsNotificationClickSink" "$native_notification_cxx" "native click sink clear implementation"
require_token "dispatchNativeOsNotificationClickPayload" "$native_notification_cxx" "native click payload dispatch implementation"
require_token "sink->handleNativeNotificationClick(payload)" "$native_notification_cxx" "native click sink invocation"
require_token "KQOFFICE_AI_NATIVE_NOTIFICATION_EVIDENCE_LOG" "$native_notification_cxx" "native notification evidence log env"
require_token "KQOFFICE_AI_NATIVE_NOTIFICATION_SMOKE_CLICK" "$native_notification_cxx" "native notification smoke click env"
require_token "recordNativeOsNotificationSubmitEvidence" "$native_notification_cxx" "native notification submit evidence implementation"
require_token 'u"native-os-notification-submit"_ustr' "$native_notification_cxx" "native notification submit evidence token"
require_token 'u"native-os-notification-click-dispatch"_ustr' "$native_notification_cxx" "native notification click-dispatch evidence token"
require_token 'u"native-os-notification-review-open"_ustr' "$native_notification_cxx" "native notification review-open evidence token"
require_token "createMacosTaskNativeOsNotificationBackend" "$macos_native_notification_mm" "macOS native backend factory implementation"
require_token "NSUserNotification" "$macos_native_notification_mm" "macOS native notification object"
require_token "KQOfficeTaskNotificationDelegate" "$macos_native_notification_mm" "macOS notification delegate"
require_token "NSUserNotificationCenterDelegate" "$macos_native_notification_mm" "macOS delegate protocol"
require_token "setDelegate:delegate" "$macos_native_notification_mm" "macOS notification delegate registration"
require_token "didActivateNotification" "$macos_native_notification_mm" "macOS notification click callback"
require_token "payloadFromUserInfo" "$macos_native_notification_mm" "macOS notification userInfo payload extractor"
require_token "dispatchNativeOsNotificationClickPayload" "$macos_native_notification_mm" "macOS notification click dispatch"
require_token "deliverNotification" "$macos_native_notification_mm" "macOS native notification delivery"
require_token "recordNativeOsNotificationSubmitEvidence(result)" "$macos_native_notification_mm" "macOS native notification submit evidence"
require_token "taskNativeOsNotificationSmokeClickEnabled()" "$macos_native_notification_mm" "macOS native notification smoke click gate"
require_token "recordNativeOsNotificationClickDispatchEvidence" "$macos_native_notification_mm" "macOS native notification click-dispatch evidence"
require_token "userInfo" "$macos_native_notification_mm" "macOS notification click payload metadata"
require_token "@\"monthDir\"" "$macos_native_notification_mm" "macOS notification month metadata"
require_token "@\"evidenceId\"" "$macos_native_notification_mm" "macOS notification evidence metadata"
require_token "WindowsTaskNativeOsNotificationBackend" "$windows_native_notification_cxx" "Windows native backend class"
require_token "Shell_NotifyIconW" "$windows_native_notification_cxx" "Windows Shell_NotifyIcon backend"
require_token "NIN_BALLOONUSERCLICK" "$windows_native_notification_cxx" "Windows balloon click callback"
require_token "NIN_BALLOONTIMEOUT" "$windows_native_notification_cxx" "Windows balloon cleanup callback"
require_token "dispatchNativeOsNotificationClickPayload(self->m_payload)" "$windows_native_notification_cxx" "Windows click dispatch"
require_token "clickPayloadFromRequest" "$windows_native_notification_cxx" "Windows notification click payload builder"
require_token "windows-shell-notifyicon" "$windows_native_notification_cxx" "Windows backend token"
require_token "createWindowsTaskNativeOsNotificationBackend" "$windows_native_notification_cxx" "Windows native backend factory implementation"
require_token "struct SAL_DLLPUBLIC_EXPORT CoworkUiBridgeResult" "$ui_bridge_hxx" "Cowork UI bridge result"
require_token "runCoworkUiTaskBridge" "$ui_bridge_hxx" "Cowork UI bridge API"
require_token "TaskOsNotificationSink& osNotificationSink" "$ui_bridge_hxx" "Cowork UI OS notification sink overload"
require_token "osNotificationPostedCount" "$ui_bridge_hxx" "Cowork UI OS notification result counter"
require_token "class SAL_DLLPUBLIC_EXPORT CoworkUiTaskBridgeJob" "$ui_bridge_hxx" "Cowork async UI bridge job"
require_token "bool prepare()" "$ui_bridge_hxx" "Cowork async job prepare API"
require_token "bool start()" "$ui_bridge_hxx" "Cowork async job start API"
require_token "bool isDone() const" "$ui_bridge_hxx" "Cowork async job completion API"
require_token "CoworkUiBridgeWorker" "$ui_bridge_cxx" "Cowork UI bridge worker"
require_token "CoworkUiBridgeWorker aWorker(600)" "$ui_bridge_cxx" "Cowork async running-state visibility window"
require_token "TaskQueue aQueue(m_aStore)" "$ui_bridge_cxx" "Cowork async job queue ownership"
require_token "aQueue.enqueue(m_aTask)" "$ui_bridge_cxx" "Cowork async job pending prepare"
require_token "TaskRunner runner(scheduler, runnerSink)" "$ui_bridge_cxx" "Cowork UI bridge runner sink seam"
require_token "OsNotificationTaskNotificationSink osSink(autoSink, osNotificationSink)" "$ui_bridge_cxx" "Cowork UI OS notification runner sink"
require_token "m_xTaskJob = std::make_unique<CoworkUiTaskBridgeJob>" "$cowork_dialog" "CoworkDialog starts async UI bridge job"
require_token "m_aTaskPollTimer.SetInvokeHandler" "$cowork_dialog" "CoworkDialog task poll timer"
require_token "OnTaskPoll" "$cowork_dialog" "CoworkDialog nonblocking task poll handler"
require_token "m_xTaskJob->prepare()" "$cowork_dialog" "CoworkDialog prepares pending task before worker start"
require_token "m_xTaskJob->start()" "$cowork_dialog" "CoworkDialog starts worker from timer"
require_token "m_xTaskJob->join()" "$cowork_dialog" "CoworkDialog joins async job before cleanup"
require_token "CoworkDialogNativeClickSink" "$cowork_dialog" "CoworkDialog native click sink"
require_token "setTaskNativeOsNotificationClickSink(m_xNativeClickSink)" "$cowork_dialog" "CoworkDialog native click sink registration"
require_token "clearTaskNativeOsNotificationClickSink(m_xNativeClickSink.get())" "$cowork_dialog" "CoworkDialog native click sink cleanup"
require_token "handleNativeNotificationClick" "$cowork_dialog" "CoworkDialog native click callback handler"
require_token "openReviewFromNativeOsNotificationClick(payload, store, openSink" "$cowork_dialog" "CoworkDialog native click opens stored review"
require_token "recordNativeOsNotificationReviewOpenEvidence" "$cowork_dialog" "CoworkDialog native notification review-open evidence"
require_token "os_notifications=" "$cowork_dialog" "CoworkDialog OS notification evidence log"
require_token "OnNewTask prepared pending" "$cowork_dialog" "CoworkDialog pending state log"
require_token "OnTaskPoll completed" "$cowork_dialog" "CoworkDialog async completion log"
require_token "CoworkDialogReviewOpenSink" "$cowork_dialog" "CoworkDialog visible review sink"
require_token "ShowDiffReviewPanel" "$cowork_dialog" "CoworkDialog opens visible DiffReview"
require_token "buildCoworkReviewEntries" "$cowork_dialog" "CoworkDialog review entry builder"
require_token "btn_accept_task" "$cowork_dialog" "CoworkDialog accept button wiring"
require_token "OnAcceptTask applied" "$cowork_dialog" "CoworkDialog accept applied log"
require_token "acceptReviewResult(openResult, store" "$cowork_dialog" "CoworkDialog accept bridge dispatch"
require_token "cowork-dialog-selected-review" "$cowork_dialog" "CoworkDialog selected-review source token"
require_token "refreshTaskList(m_aActiveTaskId)" "$cowork_dialog" "CoworkDialog preserves active task selection"
require_token "m_aSelectedTaskId" "$cowork_dialog" "CoworkDialog selected task fallback"
require_token "m_xTaskList->n_children() == 0" "$cowork_dialog" "CoworkDialog ignores transient empty selection"
require_token "class DiffReviewDialog final" "$diff_review_panel" "DiffReview visible dialog controller"
require_token "diff-review-dialog.ui" "$diff_review_panel" "DiffReview dialog resource binding"
require_token "Application::IsMainThread()" "$diff_review_panel" "DiffReview main-thread guard"
require_token "Application::PostUserEvent" "$diff_review_panel" "DiffReview worker-to-UI dispatch"
require_token "weld::DialogController::runAsync" "$diff_review_panel" "DiffReview non-modal presentation"
require_token "panel_host" "$diff_review_dialog_ui" "DiffReview panel host"
require_token "svx/uiconfig/ui/diff-review-dialog" "$svx_ui_config" "DiffReview dialog UI packaging"
require_token "testQueueLifecycleEvidenceContract" "$cowork_test" "H9 lifecycle evidence cppunit"
require_token "testSchedulerRunOneSuccessReleasesWorker" "$cowork_test" "scheduler success cppunit"
require_token "testSchedulerRunOneFailureReleasesWorker" "$cowork_test" "scheduler failure cppunit"
require_token "testSchedulerRecoverInterruptedRunningTasks" "$cowork_test" "scheduler recovery cppunit"
require_token "testRunnerThreadSuccessNotifiesAwaitingReview" "$cowork_test" "runner success cppunit"
require_token "testRunnerThreadFailureNotifiesFailed" "$cowork_test" "runner failure cppunit"
require_token "testRunnerThreadEmptyQueueNotifiesIdle" "$cowork_test" "runner empty queue cppunit"
require_token "testNotificationClickBuildsReviewRequest" "$cowork_test" "review click request cppunit"
require_token "testNotificationClickRejectsNonReviewEvents" "$cowork_test" "review click rejection cppunit"
require_token "testOsNotificationBuildsClickPayload" "$cowork_test" "OS notification payload cppunit"
require_token "testOsNotificationClickOpensStoredReview" "$cowork_test" "OS notification click open cppunit"
require_token "testOsNotificationSinkIgnoresNonReviewEvents" "$cowork_test" "OS notification non-review cppunit"
require_token "testOsNotificationClickRejectsStaleTaskState" "$cowork_test" "OS notification stale click cppunit"
require_token "testNativeOsNotificationFallbackRecordsUnavailable" "$cowork_test" "native OS notification fallback cppunit"
require_token "testPlatformNativeOsNotificationFactoryFallsBackWhenUnavailable" "$cowork_test" "platform native factory cppunit"
require_token "testNativeOsNotificationSinkCountsSubmittedBackend" "$cowork_test" "native OS notification sink cppunit"
require_token "testNativeOsNotificationClickPayloadBuildsRequest" "$cowork_test" "native OS notification click payload cppunit"
require_token "testNativeOsNotificationClickOpensStoredReview" "$cowork_test" "native OS notification click open cppunit"
require_token "testNativeOsNotificationClickDispatchesRegisteredSink" "$cowork_test" "native OS notification click dispatch cppunit"
require_token "testRunnerAwaitingReviewNotificationCanOpenReview" "$cowork_test" "runner-to-review bridge cppunit"
require_token "testReviewRequestOpensStoredAwaitingReviewTask" "$cowork_test" "stored review request cppunit"
require_token "testReviewRequestRejectsStaleTaskState" "$cowork_test" "stale review request cppunit"
require_token "testReviewRequestRejectsPlanMismatch" "$cowork_test" "plan mismatch review request cppunit"
require_token "testReviewAcceptResultMarksTaskApplied" "$cowork_test" "review accept applied cppunit"
require_token "testReviewAcceptRejectsStaleTaskState" "$cowork_test" "review accept stale cppunit"
require_token "testReviewAcceptRejectsPlanMismatch" "$cowork_test" "review accept plan mismatch cppunit"
require_token "testRunnerNotificationAutoOpensStoredReview" "$cowork_test" "runner notification auto-open cppunit"
require_token "testRunnerFailureNotificationDoesNotAutoOpenReview" "$cowork_test" "failure notification no auto-open cppunit"
require_token "testAutoOpenReviewNotificationRecordsPlanMismatch" "$cowork_test" "auto-open plan mismatch cppunit"
require_token "testCoworkUiBridgeRunsNewTaskToOpenedReview" "$cowork_test" "Cowork UI bridge cppunit"
require_token "testCoworkUiBridgePostsOsNotificationRequest" "$cowork_test" "Cowork UI OS notification cppunit"
require_token "testCoworkUiAsyncBridgeExposesPendingRunningAndCompletes" "$cowork_test" "Cowork async UI bridge cppunit"
require_token "sawRunning" "$cowork_test" "Cowork async running-state assertion"
require_token "provider-timeout" "$cowork_test" "failed worker evidence test"
require_token "collectTaskIdsForMonth" "$cowork_dialog" "task list state collector"
require_token "TaskStore store" "$cowork_dialog" "TaskStore-backed UI list"
require_token "task_list_view" "$cowork_ui" "task list widget"
require_token "btn_new_task" "$cowork_ui" "new task UI action"
require_token "btn_accept_task" "$cowork_ui" "accept task UI action"
require_token "接受任务" "$cowork_ui" "accept task label"
require_token "testQueueLifecycleEvidenceContract" "$test_log" "latest H9 cppunit run"
require_token "testSchedulerRunOneSuccessReleasesWorker" "$test_log" "latest scheduler success cppunit run"
require_token "testSchedulerRunOneFailureReleasesWorker" "$test_log" "latest scheduler failure cppunit run"
require_token "testSchedulerRecoverInterruptedRunningTasks" "$test_log" "latest scheduler recovery cppunit run"
require_token "testRunnerThreadSuccessNotifiesAwaitingReview" "$test_log" "latest runner success cppunit run"
require_token "testRunnerThreadFailureNotifiesFailed" "$test_log" "latest runner failure cppunit run"
require_token "testRunnerThreadEmptyQueueNotifiesIdle" "$test_log" "latest runner empty queue cppunit run"
require_token "testNotificationClickBuildsReviewRequest" "$test_log" "latest review click request cppunit run"
require_token "testNotificationClickRejectsNonReviewEvents" "$test_log" "latest review click rejection cppunit run"
require_token "testOsNotificationBuildsClickPayload" "$test_log" "latest OS notification payload cppunit run"
require_token "testOsNotificationClickOpensStoredReview" "$test_log" "latest OS notification click open cppunit run"
require_token "testOsNotificationSinkIgnoresNonReviewEvents" "$test_log" "latest OS notification non-review cppunit run"
require_token "testOsNotificationClickRejectsStaleTaskState" "$test_log" "latest OS notification stale click cppunit run"
require_token "testNativeOsNotificationFallbackRecordsUnavailable" "$test_log" "latest native OS notification fallback cppunit run"
require_token "testPlatformNativeOsNotificationFactoryFallsBackWhenUnavailable" "$test_log" "latest platform native factory cppunit run"
require_token "testNativeOsNotificationSinkCountsSubmittedBackend" "$test_log" "latest native OS notification sink cppunit run"
require_token "testNativeOsNotificationClickPayloadBuildsRequest" "$test_log" "latest native OS notification click payload cppunit run"
require_token "testNativeOsNotificationClickOpensStoredReview" "$test_log" "latest native OS notification click open cppunit run"
require_token "testNativeOsNotificationClickDispatchesRegisteredSink" "$test_log" "latest native OS notification click dispatch cppunit run"
require_token "testRunnerAwaitingReviewNotificationCanOpenReview" "$test_log" "latest runner-to-review bridge cppunit run"
require_token "testReviewRequestOpensStoredAwaitingReviewTask" "$test_log" "latest stored review request cppunit run"
require_token "testReviewRequestRejectsStaleTaskState" "$test_log" "latest stale review request cppunit run"
require_token "testReviewRequestRejectsPlanMismatch" "$test_log" "latest plan mismatch review request cppunit run"
require_token "testReviewAcceptResultMarksTaskApplied" "$test_log" "latest review accept applied cppunit run"
require_token "testReviewAcceptRejectsStaleTaskState" "$test_log" "latest review accept stale cppunit run"
require_token "testReviewAcceptRejectsPlanMismatch" "$test_log" "latest review accept plan mismatch cppunit run"
require_token "testRunnerNotificationAutoOpensStoredReview" "$test_log" "latest runner notification auto-open cppunit run"
require_token "testRunnerFailureNotificationDoesNotAutoOpenReview" "$test_log" "latest failure notification no auto-open cppunit run"
require_token "testCoworkUiAsyncBridgeExposesPendingRunningAndCompletes" "$test_log" "latest Cowork async UI bridge cppunit run"
require_token "testAutoOpenReviewNotificationRecordsPlanMismatch" "$test_log" "latest auto-open plan mismatch cppunit run"
require_token "testCoworkUiBridgeRunsNewTaskToOpenedReview" "$test_log" "latest Cowork UI bridge cppunit run"
require_token "testCoworkUiBridgePostsOsNotificationRequest" "$test_log" "latest Cowork UI OS notification cppunit run"
require_token "OK (56)" "$test_log" "kqoffice_cowork OK(56)"

echo "Status: passed"
echo "Checks: $checks"
