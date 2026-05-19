#!/usr/bin/env bash
set -u

RSS_SAMPLE_COUNT="${RSS_SAMPLE_COUNT:-3}"
RSS_SAMPLE_INTERVAL_SECONDS="${RSS_SAMPLE_INTERVAL_SECONDS:-30}"
EXCLUDE_FIRST_SAMPLES="${EXCLUDE_FIRST_SAMPLES:-0}"
OUTPUT_DIR="/tmp/algo_memory_evidence"
PROCESS_NAME="AlgoTradingMac"
TARGET_PID=""
DURATION_MINUTES=""
APP_SUPPORT_ROOT="${TRADINGKIT_APP_SUPPORT_ROOT:-}"
SCENARIO_LABEL=""

POSITIONAL=()
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --duration-minutes)
      DURATION_MINUTES="${2:-}"
      shift 2
      ;;
    --interval-seconds)
      RSS_SAMPLE_INTERVAL_SECONDS="${2:-}"
      shift 2
      ;;
    --samples)
      RSS_SAMPLE_COUNT="${2:-}"
      shift 2
      ;;
    --exclude-first-samples)
      EXCLUDE_FIRST_SAMPLES="${2:-}"
      shift 2
      ;;
    --process-name)
      PROCESS_NAME="${2:-}"
      shift 2
      ;;
    --pid)
      TARGET_PID="${2:-}"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="${2:-}"
      shift 2
      ;;
    --app-support-root)
      APP_SUPPORT_ROOT="${2:-}"
      shift 2
      ;;
    --scenario-label)
      SCENARIO_LABEL="${2:-}"
      shift 2
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

if [[ "${#POSITIONAL[@]}" -ge 1 ]]; then
  OUTPUT_DIR="${POSITIONAL[0]}"
fi
if [[ "${#POSITIONAL[@]}" -ge 2 ]]; then
  PROCESS_NAME="${POSITIONAL[1]}"
fi

if [[ -n "$DURATION_MINUTES" ]]; then
  duration_seconds=$((DURATION_MINUTES * 60))
  if [[ "$RSS_SAMPLE_INTERVAL_SECONDS" -le 0 ]]; then
    RSS_SAMPLE_INTERVAL_SECONDS=60
  fi
  RSS_SAMPLE_COUNT=$((duration_seconds / RSS_SAMPLE_INTERVAL_SECONDS + 1))
fi

mkdir -p "$OUTPUT_DIR"

{
  echo "diagnosticStartedAt=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "processName=$PROCESS_NAME"
  if [[ -n "$TARGET_PID" ]]; then
    echo "pid=$TARGET_PID"
  fi
  echo "outputDir=$OUTPUT_DIR"
  echo "sampleCount=$RSS_SAMPLE_COUNT"
  echo "sampleIntervalSeconds=$RSS_SAMPLE_INTERVAL_SECONDS"
  echo "excludeFirstSamples=$EXCLUDE_FIRST_SAMPLES"
  echo "scenarioLabel=${SCENARIO_LABEL:-unspecified}"
  if [[ -n "$APP_SUPPORT_ROOT" ]]; then
    echo "appSupportRoot=$APP_SUPPORT_ROOT"
  else
    echo "appSupportRoot=default"
  fi
} > "$OUTPUT_DIR/diagnostic_context.txt"

cat > "$OUTPUT_DIR/allocation_attribution_next_steps.txt" <<'EOF'
Optional allocation attribution commands for a local diagnostic run:

1. Instruments Allocations, attach to an existing app:
   PID=$(pgrep -x AlgoTradingMac | head -n 1)
   xcrun xctrace record --template "Allocations" --attach "$PID" --time-limit 600s --output /tmp/algo_memory_evidence/allocations.trace
   xcrun xctrace export --input /tmp/algo_memory_evidence/allocations.trace --toc --output /tmp/algo_memory_evidence/allocations_toc.xml

2. Isolated development launch with Malloc Stack Logging:
   TRADINGKIT_APP_SUPPORT_ROOT=/tmp/algo_memory_evidence/appsupport MallocStackLogging=1 /path/to/AlgoTradingMac.app/Contents/MacOS/AlgoTradingMac
   PID=$(pgrep -x AlgoTradingMac | head -n 1)
   scripts/collect_algo_memory_diagnostics.sh --pid "$PID" --output-dir /tmp/algo_memory_evidence/direct_pid_check --scenario-label direct_launch_pid_check
   heap "$PID" > /tmp/algo_memory_evidence/heap.txt
   leaks "$PID" > /tmp/algo_memory_evidence/leaks.txt
   malloc_history "$PID" <address-from-leaks-or-heap>

Keep traces and heap/leaks output under /tmp. Do not commit trace bundles, raw heap logs, app-support records, account identifiers, raw PM messages, raw job payloads, raw article bodies, Telegram routes, or secrets.
EOF

if [[ -n "$TARGET_PID" ]]; then
  PID="$TARGET_PID"
  : > "$OUTPUT_DIR/pgrep_error.txt"
else
  PID="$(pgrep -x "$PROCESS_NAME" 2>"$OUTPUT_DIR/pgrep_error.txt" | head -n 1 || true)"
fi
date > "$OUTPUT_DIR/process_summary.txt"

if [[ -z "$PID" ]] || ! ps -p "$PID" >/dev/null 2>&1; then
  {
    echo "process=$PROCESS_NAME"
    if [[ -n "$TARGET_PID" ]]; then
      echo "pid=$TARGET_PID"
    fi
    echo "status=not_running"
  } >> "$OUTPUT_DIR/process_summary.txt"
  exit 0
fi

{
  echo "process=$PROCESS_NAME"
  echo "pid=$PID"
  ps -p "$PID" -o pid,etime,rss,vsz,command
} >> "$OUTPUT_DIR/process_summary.txt"

vmmap -summary "$PID" > "$OUTPUT_DIR/vmmap_start_summary.txt" 2>&1 || true

{
  echo "timestamp,pid,rss_kb,vsz_kb"
  sample_index=0
  while [[ "$sample_index" -lt "$RSS_SAMPLE_COUNT" ]]; do
    ps -p "$PID" -o pid=,rss=,vsz= | awk -v ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{print ts "," $1 "," $2 "," $3}'
    sample_index=$((sample_index + 1))
    if [[ "$sample_index" -lt "$RSS_SAMPLE_COUNT" ]]; then
      sleep "$RSS_SAMPLE_INTERVAL_SECONDS"
    fi
  done
} > "$OUTPUT_DIR/rss_samples.csv"

python3 - "$OUTPUT_DIR/rss_samples.csv" "$EXCLUDE_FIRST_SAMPLES" > "$OUTPUT_DIR/rss_slope.txt" <<'PY' || true
import csv
import datetime as dt
import sys

path = sys.argv[1]
exclude_first_samples = max(0, int(sys.argv[2] or "0"))
with open(path, "r", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))
if len(rows) < 2:
    print("rss_slope_unavailable=not_enough_samples")
    raise SystemExit(0)
if exclude_first_samples > 0 and len(rows) - exclude_first_samples >= 2:
    rows = rows[exclude_first_samples:]
elif exclude_first_samples > 0:
    print("rss_slope_exclusion_ignored=not_enough_remaining_samples")

def parse_time(value):
    return dt.datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=dt.timezone.utc)

first = rows[0]
last = rows[-1]
elapsed = (parse_time(last["timestamp"]) - parse_time(first["timestamp"])).total_seconds()
if elapsed <= 0:
    print("rss_slope_unavailable=non_positive_elapsed")
    raise SystemExit(0)
rss_delta_kb = int(last["rss_kb"]) - int(first["rss_kb"])
rss_delta_mb = rss_delta_kb / 1024
slope_mb_per_min = rss_delta_mb / (elapsed / 60)
print(f"sampleCount={len(rows)}")
print(f"excludedInitialSamples={exclude_first_samples}")
print(f"elapsedSeconds={elapsed:.0f}")
print(f"rssDeltaKB={rss_delta_kb}")
print(f"rssDeltaMB={rss_delta_mb:.3f}")
print(f"rssSlopeMBPerMinute={slope_mb_per_min:.3f}")
if slope_mb_per_min >= 1:
    print("rssSlopeWarning=multi_mb_per_min")
else:
    print("rssSlopeWarning=none")
PY

vmmap -summary "$PID" > "$OUTPUT_DIR/vmmap_summary.txt" 2>&1 || true

python3 - \
  "$OUTPUT_DIR/rss_slope.txt" \
  "$OUTPUT_DIR/vmmap_start_summary.txt" \
  "$OUTPUT_DIR/vmmap_summary.txt" \
  > "$OUTPUT_DIR/memory_classification.txt" <<'PY' || true
import re
import sys

rss_path, start_path, end_path = sys.argv[1:4]

def parse_key_values(path):
    values = {}
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as handle:
            for line in handle:
                if "=" in line:
                    key, value = line.strip().split("=", 1)
                    values[key] = value
    except FileNotFoundError:
        pass
    return values

def unit_to_mb(value, unit):
    number = float(value)
    unit = unit.upper()
    if unit == "K":
        return number / 1024
    if unit == "G":
        return number * 1024
    return number

def vmmap_region_sizes(path, label):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as handle:
            for line in handle:
                stripped = line.lstrip()
                if not stripped.startswith(label + " "):
                    continue
                if stripped.startswith(label + " ("):
                    continue
                return [
                    unit_to_mb(match.group(1), match.group(2))
                    for match in re.finditer(r"([0-9]+(?:\.[0-9]+)?)([KMG])", line)
                ]
    except FileNotFoundError:
        return None
    return None

def physical_footprint(path):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as handle:
            for line in handle:
                match = re.search(r"Physical footprint:\s+([0-9]+(?:\.[0-9]+)?)([KMG])", line)
                if match:
                    return unit_to_mb(match.group(1), match.group(2))
    except FileNotFoundError:
        return None
    return None

def vmmap_region_size(path, label, column_index=0):
    sizes = vmmap_region_sizes(path, label)
    if not sizes or column_index >= len(sizes):
        return None
    return sizes[column_index]

rss_values = parse_key_values(rss_path)
duration_minutes = None
try:
    duration_minutes = float(rss_values.get("elapsedSeconds", "0")) / 60
except ValueError:
    duration_minutes = None
rss_slope = None
try:
    rss_slope = float(rss_values.get("rssSlopeMBPerMinute", "nan"))
except ValueError:
    rss_slope = None

start_physical = physical_footprint(start_path)
end_physical = physical_footprint(end_path)
start_vm_allocate = vmmap_region_size(start_path, "VM_ALLOCATE")
end_vm_allocate = vmmap_region_size(end_path, "VM_ALLOCATE")
start_malloc_small = vmmap_region_size(start_path, "MALLOC_SMALL")
end_malloc_small = vmmap_region_size(end_path, "MALLOC_SMALL")
start_malloc_small_resident = vmmap_region_size(start_path, "MALLOC_SMALL", column_index=1)
end_malloc_small_resident = vmmap_region_size(end_path, "MALLOC_SMALL", column_index=1)
start_malloc_small_dirty = vmmap_region_size(start_path, "MALLOC_SMALL", column_index=2)
end_malloc_small_dirty = vmmap_region_size(end_path, "MALLOC_SMALL", column_index=2)

def delta(start, end):
    if start is None or end is None:
        return None
    return end - start

physical_delta = delta(start_physical, end_physical)
vm_allocate_delta = delta(start_vm_allocate, end_vm_allocate)
malloc_small_delta = delta(start_malloc_small, end_malloc_small)
malloc_small_resident_delta = delta(start_malloc_small_resident, end_malloc_small_resident)
malloc_small_dirty_delta = delta(start_malloc_small_dirty, end_malloc_small_dirty)

def slope(delta_value):
    if delta_value is None or not duration_minutes or duration_minutes <= 0:
        return None
    return delta_value / duration_minutes

physical_slope = slope(physical_delta)
vm_allocate_slope = slope(vm_allocate_delta)
malloc_small_slope = slope(malloc_small_delta)
malloc_small_resident_slope = slope(malloc_small_resident_delta)
malloc_small_dirty_slope = slope(malloc_small_dirty_delta)

print(f"rssSlopeMBPerMinute={rss_slope if rss_slope is not None else 'unknown'}")
print(f"physicalFootprintStartMB={start_physical if start_physical is not None else 'unknown'}")
print(f"physicalFootprintEndMB={end_physical if end_physical is not None else 'unknown'}")
print(f"physicalFootprintDeltaMB={physical_delta if physical_delta is not None else 'unknown'}")
print(f"physicalFootprintSlopeMBPerMinute={physical_slope if physical_slope is not None else 'unknown'}")
print(f"vmAllocateStartMB={start_vm_allocate if start_vm_allocate is not None else 'unknown'}")
print(f"vmAllocateEndMB={end_vm_allocate if end_vm_allocate is not None else 'unknown'}")
print(f"vmAllocateDeltaMB={vm_allocate_delta if vm_allocate_delta is not None else 'unknown'}")
print(f"vmAllocateSlopeMBPerMinute={vm_allocate_slope if vm_allocate_slope is not None else 'unknown'}")
print(f"mallocSmallStartMB={start_malloc_small if start_malloc_small is not None else 'unknown'}")
print(f"mallocSmallEndMB={end_malloc_small if end_malloc_small is not None else 'unknown'}")
print(f"mallocSmallDeltaMB={malloc_small_delta if malloc_small_delta is not None else 'unknown'}")
print(f"mallocSmallSlopeMBPerMinute={malloc_small_slope if malloc_small_slope is not None else 'unknown'}")
print(f"mallocSmallResidentDeltaMB={malloc_small_resident_delta if malloc_small_resident_delta is not None else 'unknown'}")
print(f"mallocSmallResidentSlopeMBPerMinute={malloc_small_resident_slope if malloc_small_resident_slope is not None else 'unknown'}")
print(f"mallocSmallDirtyDeltaMB={malloc_small_dirty_delta if malloc_small_dirty_delta is not None else 'unknown'}")
print(f"mallocSmallDirtySlopeMBPerMinute={malloc_small_dirty_slope if malloc_small_dirty_slope is not None else 'unknown'}")

classification = "insufficient_vmmap_data"
if vm_allocate_slope is not None and vm_allocate_slope >= 5:
    classification = "catastrophic_vm_allocate_like"
elif physical_slope is not None and physical_slope >= 1:
    classification = "physical_footprint_growth"
elif rss_slope is not None and rss_slope >= 1 and (physical_slope is None or physical_slope < 0.5):
    classification = "rss_high_water_or_cache_dominant"
elif physical_slope is not None and abs(physical_slope) < 0.5:
    classification = "low_or_plateauing_physical_growth"
print(f"memoryShapeClassification={classification}")
PY

sample "$PID" 10 -file "$OUTPUT_DIR/sample_10s.txt" >/dev/null 2>&1 || true

if [[ -d "Packages/TradingKit" ]]; then
  (
    cd Packages/TradingKit
    if [[ -n "$APP_SUPPORT_ROOT" ]]; then
      TRADINGKIT_APP_SUPPORT_ROOT="$APP_SUPPORT_ROOT" swift run alpaca_agentctl status > "$OUTPUT_DIR/agentctl_status.json" 2>&1 || true
    else
      swift run alpaca_agentctl status > "$OUTPUT_DIR/agentctl_status.json" 2>&1 || true
    fi
  )
  python3 - "$OUTPUT_DIR/agentctl_status.json" > "$OUTPUT_DIR/status_counts.txt" 2>"$OUTPUT_DIR/status_counts_error.txt" <<'PY' || true
import json
import sys

path = sys.argv[1]
try:
    with open(path, "r", encoding="utf-8") as handle:
        raw = handle.read()
    json_start = raw.find("{")
    if json_start < 0:
        raise ValueError("no JSON object found in status output")
    payload = json.loads(raw[json_start:])
except Exception as exc:
    print(f"status_counts_unavailable: {exc}")
    raise SystemExit(0)

result = payload.get("result") or {}
watchlist = result.get("watchlist") or []
desired = result.get("marketDataDesiredSubscriptions") or {}
active = result.get("marketDataActiveSubscriptions") or {}
build_identity = result.get("buildIdentity") or {}

def compact_mapping(value):
    if not isinstance(value, dict):
        return "unknown"
    return json.dumps(value, sort_keys=True, separators=(",", ":"))

def sub_count(subscriptions):
    total = 0
    for value in subscriptions.values():
        if isinstance(value, list):
            total += len(value)
    return total

print(f"jobsCount={result.get('jobsCount', 'unknown')}")
print(f"buildTradingKitInfo={build_identity.get('tradingKitBuildInfo', 'unknown')}")
print(f"buildProcessIdentifier={build_identity.get('processIdentifier', 'unknown')}")
print(f"buildBundleIdentifier={build_identity.get('bundleIdentifier', 'unknown')}")
print(f"visibleJobsCount={result.get('visibleJobsCount', 'unknown')}")
job_projection = result.get("jobSummaryProjection") or {}
print(f"jobSummaryProjectionVisibleCap={job_projection.get('visibleCap', 'unknown')}")
print(f"jobSummaryProjectionVisibleCount={job_projection.get('visibleCount', 'unknown')}")
print(f"jobSummaryProjectionTotalJobsCount={job_projection.get('totalJobsCount', 'unknown')}")
print(f"jobSummaryProjectionListRequestCount={job_projection.get('listRequestCount', 'unknown')}")
print(f"jobSummaryProjectionCacheHitCount={job_projection.get('cacheHitCount', 'unknown')}")
print(f"jobSummaryProjectionFullScanCount={job_projection.get('fullScanCount', 'unknown')}")
print(f"jobSummaryProjectionIncrementalUpdateCount={job_projection.get('incrementalUpdateCount', 'unknown')}")
print(f"jobSummaryProjectionLastScannedCount={job_projection.get('lastScannedCount', 'unknown')}")
print(f"jobSummaryProjectionLastOutputCount={job_projection.get('lastOutputCount', 'unknown')}")
print(f"jobProgressPersistCount={job_projection.get('jobProgressPersistCount', 'unknown')}")
print(f"positionsCount={result.get('positionsCount', 'unknown')}")
print(f"openOrdersCount={result.get('openOrdersCount', 'unknown')}")
print(f"newsCount={result.get('newsCount', 'unknown')}")
news_runtime = result.get("newsRuntime") or {}
print(f"newsCleanupRequestCount={news_runtime.get('cleanupRequestCount', 'unknown')}")
print(f"newsCleanupFullScanCount={news_runtime.get('cleanupFullScanCount', 'unknown')}")
print(f"newsCleanupSkippedNoSourceChangeCount={news_runtime.get('cleanupSkippedNoSourceChangeCount', 'unknown')}")
print(f"newsCleanupRemovedEventCount={news_runtime.get('cleanupRemovedEventCount', 'unknown')}")
print(f"newsCleanupAffectedFileCount={news_runtime.get('cleanupAffectedFileCount', 'unknown')}")
print(f"newsKnownEventIDLoadCount={news_runtime.get('knownEventIDLoadCount', 'unknown')}")
print(f"newsKnownEventIDLoadDecodedLineCount={news_runtime.get('knownEventIDLoadDecodedLineCount', 'unknown')}")
print(f"newsListRecentRequestCount={news_runtime.get('listRecentRequestCount', 'unknown')}")
print(f"newsListRecentFileReadCount={news_runtime.get('listRecentFileReadCount', 'unknown')}")
print(f"newsListRecentDecodedLineCount={news_runtime.get('listRecentDecodedLineCount', 'unknown')}")
print(f"newsListRecentReturnedCount={news_runtime.get('listRecentReturnedCount', 'unknown')}")
print(f"newsListRecentByReceivedAtRequestCount={news_runtime.get('listRecentByReceivedAtRequestCount', 'unknown')}")
print(f"newsListRecentByReceivedAtFileReadCount={news_runtime.get('listRecentByReceivedAtFileReadCount', 'unknown')}")
print(f"newsListRecentByReceivedAtDecodedLineCount={news_runtime.get('listRecentByReceivedAtDecodedLineCount', 'unknown')}")
print(f"newsListRecentByReceivedAtReturnedCount={news_runtime.get('listRecentByReceivedAtReturnedCount', 'unknown')}")
print(f"newsPurgeRSSSourcesCount={news_runtime.get('purgeRSSSourcesCount', 'unknown')}")
print(f"newsPurgeRSSSourcesFileScanCount={news_runtime.get('purgeRSSSourcesFileScanCount', 'unknown')}")
print(f"newsPurgeRSSSourcesDecodedLineCount={news_runtime.get('purgeRSSSourcesDecodedLineCount', 'unknown')}")
print(f"newsPurgeRSSSourcesRemovedEventCount={news_runtime.get('purgeRSSSourcesRemovedEventCount', 'unknown')}")
print(f"newsPurgeRSSSourcesAffectedFileCount={news_runtime.get('purgeRSSSourcesAffectedFileCount', 'unknown')}")
print(f"signalsCount={result.get('signalsCount', 'unknown')}")
print(f"schedulesCount={result.get('schedulesCount', 'unknown')}")
print(f"watchlistCount={len(watchlist)}")
print(f"desiredMarketDataSubscriptionCount={sub_count(desired)}")
print(f"activeMarketDataSubscriptionCount={sub_count(active)}")
portfolio_watch_runtime = result.get("portfolioWatchRuntime") or {}
print(f"portfolioWatchSelectedCount={portfolio_watch_runtime.get('selectedCount', 'unknown')}")
print(f"portfolioWatchWatchlistCount={portfolio_watch_runtime.get('watchlistCount', 'unknown')}")
print(f"portfolioWatchRequestedSelectedCount={portfolio_watch_runtime.get('requestedSelectedCount', 'unknown')}")
print(f"portfolioWatchActiveSelectedCount={portfolio_watch_runtime.get('activeSelectedCount', 'unknown')}")
print(f"portfolioWatchPricedSelectedCount={portfolio_watch_runtime.get('pricedSelectedCount', 'unknown')}")
print(f"portfolioWatchActiveButNoUsablePriceSymbols={','.join(portfolio_watch_runtime.get('activeButNoUsablePriceSymbols') or [])}")
print(f"portfolioWatchLastMarketDataSymbol={portfolio_watch_runtime.get('lastMarketDataSymbol', 'unknown')}")
print(f"portfolioWatchLastMarketDataEventName={portfolio_watch_runtime.get('lastMarketDataEventName', 'unknown')}")
print(f"portfolioWatchLastMarketDataAt={portfolio_watch_runtime.get('lastMarketDataAt', 'unknown')}")
print(f"alwaysOnReadinessStatus={(result.get('alwaysOnReadiness') or {}).get('status', 'unknown')}")
event_stream = result.get("storeEventStream") or {}
print(f"storeEventBufferLimit={event_stream.get('bufferLimit', 'unknown')}")
print(f"storeEventYieldedCount={event_stream.get('yieldedCount', 'unknown')}")
print(f"storeEventEnqueuedCount={event_stream.get('enqueuedCount', 'unknown')}")
print(f"storeEventDroppedCount={event_stream.get('droppedCount', 'unknown')}")
print(f"storeEventLastDroppedName={event_stream.get('lastDroppedEventName', 'none')}")
print(f"storeMarketDataRawUpdateCount={event_stream.get('marketDataRawUpdateCount', 'unknown')}")
print(f"storeMarketDataUIInvalidationYieldCount={event_stream.get('marketDataUIInvalidationYieldCount', 'unknown')}")
print(f"storeMarketDataUIInvalidationCoalescedCount={event_stream.get('marketDataUIInvalidationCoalescedCount', 'unknown')}")
print(f"storeMarketDataUIInvalidationDroppedCount={event_stream.get('marketDataUIInvalidationDroppedCount', 'unknown')}")
telegram_runtime = result.get("telegramBridgeRuntime") or {}
print(f"telegramPollCount={telegram_runtime.get('pollCount', 'unknown')}")
print(f"telegramNoChangePollCount={telegram_runtime.get('noChangePollCount', 'unknown')}")
print(f"telegramMaterialChangePollCount={telegram_runtime.get('materialChangePollCount', 'unknown')}")
print(f"telegramCommunicationChangePollCount={telegram_runtime.get('communicationChangePollCount', 'unknown')}")
print(f"telegramHeartbeatRefreshPollCount={telegram_runtime.get('heartbeatRefreshPollCount', 'unknown')}")
print(f"telegramStatusRefreshRecommendedPollCount={telegram_runtime.get('statusRefreshRecommendedPollCount', 'unknown')}")
print(f"telegramDurableStateSaveCount={telegram_runtime.get('durableStateSaveCount', 'unknown')}")
print(f"telegramPollingTokenKeychainReadCount={telegram_runtime.get('pollingTokenKeychainReadCount', 'unknown')}")
print(f"telegramPollingTokenCacheHitCount={telegram_runtime.get('pollingTokenCacheHitCount', 'unknown')}")
print(f"telegramPollingTokenMissingThrottleCount={telegram_runtime.get('pollingTokenMissingThrottleCount', 'unknown')}")
print(f"telegramStatusTokenKeychainReadCount={telegram_runtime.get('statusTokenKeychainReadCount', 'unknown')}")
print(f"telegramStatusTokenCacheHitCount={telegram_runtime.get('statusTokenCacheHitCount', 'unknown')}")
print(f"telegramOutboundTokenKeychainReadCount={telegram_runtime.get('outboundTokenKeychainReadCount', 'unknown')}")
print(f"telegramOutboundTokenCacheHitCount={telegram_runtime.get('outboundTokenCacheHitCount', 'unknown')}")
owner_surface_runtime = result.get("ownerSurfaceRuntime") or {}
app_model_refresh = owner_surface_runtime.get("appModelRefresh") or {}
print(f"appModelControlEventReceivedCount={app_model_refresh.get('controlEventReceivedCount', 'unknown')}")
print(f"appModelControlEventReceivedByName={compact_mapping(app_model_refresh.get('controlEventReceivedByName'))}")
print(f"appModelSnapshotApplyCountByScope={compact_mapping(app_model_refresh.get('snapshotApplyCountByScope'))}")
print(f"appModelFullSnapshotApplyCount={app_model_refresh.get('fullSnapshotApplyCount', 'unknown')}")
print(f"appModelFullSnapshotApplyByEvent={compact_mapping(app_model_refresh.get('fullSnapshotApplyByEvent'))}")
owner_surface = owner_surface_runtime.get("ownerSurface") or {}
print(f"ownerSurfaceRebuildCount={owner_surface.get('rebuildCount', 'unknown')}")
print(f"ownerSurfaceRebuildByReason={compact_mapping(owner_surface.get('rebuildByReason'))}")
print(f"commandCenterProjectionRebuildCount={owner_surface.get('commandCenterProjectionRebuildCount', 'unknown')}")
print(f"jobScopedProjectionRefreshCount={owner_surface.get('jobScopedProjectionRefreshCount', 'unknown')}")
print(f"ownerDecisionDeskProjectionRebuildCount={owner_surface.get('ownerDecisionDeskProjectionRebuildCount', 'unknown')}")
pm_conversation_presentation = owner_surface_runtime.get("pmConversationPresentation") or {}
print(f"pmConversationPresentationRebuildCount={pm_conversation_presentation.get('rebuildCount', 'unknown')}")
print(f"pmConversationPresentationCacheHitCount={pm_conversation_presentation.get('cacheHitCount', 'unknown')}")
print(f"pmConversationRoutineFilterScannedCount={pm_conversation_presentation.get('routineFilterScannedCount', 'unknown')}")
print(f"pmConversationLastRoutineFilterScannedCount={pm_conversation_presentation.get('lastRoutineFilterScannedCount', 'unknown')}")
print(f"pmConversationLastMatchingMessageCount={pm_conversation_presentation.get('lastMatchingMessageCount', 'unknown')}")
strategy_brief_candidate = owner_surface_runtime.get("strategyBriefCandidate") or {}
volatile_cache_trim = owner_surface_runtime.get("volatileCacheTrim") or {}
print(f"volatileCacheTrimCount={volatile_cache_trim.get('trimCount', 'unknown')}")
print(f"volatileCacheLastTrimAt={volatile_cache_trim.get('lastTrimAt', 'unknown')}")
print(f"volatileCacheLastReason={volatile_cache_trim.get('lastReason', 'unknown')}")
print(f"volatileCacheMemoryPressureTrimCount={volatile_cache_trim.get('memoryPressureTrimCount', 'unknown')}")
print(f"volatileCacheCurrentCategoryCounts={compact_mapping(volatile_cache_trim.get('currentCategoryCounts'))}")
print(f"volatileCacheLastCategoryCounts={compact_mapping(volatile_cache_trim.get('lastCategoryCounts'))}")
market_data_presentation = owner_surface_runtime.get("marketDataPresentation") or {}
print(f"marketDataPresentationActiveTab={market_data_presentation.get('activeTab', 'unknown')}")
print(f"marketDataPresentationPublishedCount={market_data_presentation.get('publishedCount', 'unknown')}")
print(f"marketDataPresentationSuppressedHiddenCount={market_data_presentation.get('suppressedHiddenCount', 'unknown')}")
portfolio_watch_chart_wall = owner_surface_runtime.get("portfolioWatchChartWall") or {}
print(f"portfolioWatchChartWallActiveTab={portfolio_watch_chart_wall.get('activeTab', 'unknown')}")
print(f"portfolioWatchChartWallRebuildCount={portfolio_watch_chart_wall.get('rebuildCount', 'unknown')}")
print(f"portfolioWatchChartWallPublishedRebuildCount={portfolio_watch_chart_wall.get('publishedRebuildCount', 'unknown')}")
print(f"portfolioWatchChartWallHiddenSkipCount={portfolio_watch_chart_wall.get('hiddenSkipCount', 'unknown')}")
print(f"portfolioWatchChartWallReleaseCount={portfolio_watch_chart_wall.get('releaseCount', 'unknown')}")
print(f"portfolioWatchChartWallTrackerSymbolCount={portfolio_watch_chart_wall.get('trackerSymbolCount', 'unknown')}")
print(f"portfolioWatchChartWallTrackerPointCount={portfolio_watch_chart_wall.get('trackerPointCount', 'unknown')}")
visible_surface_allocation = owner_surface_runtime.get("visibleSurfaceAllocation") or {}
print(f"topBannerPresentationRecomputeCount={visible_surface_allocation.get('topBannerPresentationRecomputeCount', 'unknown')}")
print(f"topBannerPresentationPublishCount={visible_surface_allocation.get('topBannerPresentationPublishCount', 'unknown')}")
print(f"topBannerPresentationPublishSkipCount={visible_surface_allocation.get('topBannerPresentationPublishSkipCount', 'unknown')}")
print(f"topCardPresentationRecomputeCount={visible_surface_allocation.get('topCardPresentationRecomputeCount', 'unknown')}")
print(f"topCardPresentationPublishCount={visible_surface_allocation.get('topCardPresentationPublishCount', 'unknown')}")
print(f"topCardPresentationPublishSkipCount={visible_surface_allocation.get('topCardPresentationPublishSkipCount', 'unknown')}")
print(f"systemHealthPresentationRecomputeCount={visible_surface_allocation.get('systemHealthPresentationRecomputeCount', 'unknown')}")
print(f"systemHealthPresentationPublishCount={visible_surface_allocation.get('systemHealthPresentationPublishCount', 'unknown')}")
print(f"systemHealthPresentationPublishSkipCount={visible_surface_allocation.get('systemHealthPresentationPublishSkipCount', 'unknown')}")
print(f"statusSerializationCount={visible_surface_allocation.get('statusSerializationCount', 'unknown')}")
print(f"statusSnapshotRetainedCount={visible_surface_allocation.get('statusSnapshotRetainedCount', 'unknown')}")
portfolio_watch_visible = owner_surface_runtime.get("portfolioWatchVisible") or {}
print(f"portfolioWatchVisibleEffectiveSelectedCount={len(portfolio_watch_visible.get('effectiveSelectedSymbols') or [])}")
print(f"portfolioWatchVisibleCardCount={portfolio_watch_visible.get('cardCount', 'unknown')}")
print(f"portfolioWatchVisiblePricedCardCount={portfolio_watch_visible.get('pricedCardCount', 'unknown')}")
print(f"portfolioWatchVisibleWaitingCardCount={portfolio_watch_visible.get('waitingCardCount', 'unknown')}")
pm_conversation_visible = owner_surface_runtime.get("pmConversationVisible") or {}
print(f"pmConversationVisibleMessageCount={pm_conversation_visible.get('visibleMessageCount', 'unknown')}")
print(f"pmConversationTelegramVisibleMessageCount={pm_conversation_visible.get('telegramVisibleMessageCount', 'unknown')}")
print(f"pmConversationLastVisibleMessageAt={pm_conversation_visible.get('lastVisibleMessageAt', 'unknown')}")
print(f"strategyBriefCandidateRebuildCount={strategy_brief_candidate.get('rebuildCount', 'unknown')}")
print(f"strategyBriefCandidateCacheHitCount={strategy_brief_candidate.get('cacheHitCount', 'unknown')}")
print(f"strategyBriefCandidateScannedMessageCount={strategy_brief_candidate.get('scannedMessageCount', 'unknown')}")
print(f"strategyBriefCandidateLastScannedMessageCount={strategy_brief_candidate.get('lastScannedMessageCount', 'unknown')}")
print(f"strategyBriefCandidateLastConsideredMessageCount={strategy_brief_candidate.get('lastConsideredMessageCount', 'unknown')}")
print(f"strategyBriefCandidateLastMessageCount={strategy_brief_candidate.get('lastMessageCount', 'unknown')}")
print(f"strategyBriefCandidateMessageScanLimit={strategy_brief_candidate.get('messageScanLimit', 'unknown')}")
print(f"strategyBriefCandidateVisible={strategy_brief_candidate.get('candidateVisible', 'unknown')}")
print(f"environment={result.get('env', 'unknown')}")
print(f"liveArmed={result.get('armed', 'unknown')}")
PY
fi

echo "Wrote read-only memory diagnostics to $OUTPUT_DIR"
