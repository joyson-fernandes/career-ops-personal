#!/usr/bin/env bash
# Run career-ops batch-runner.sh, then sync results to career-ops-data so the
# in-cluster dashboard picks them up via its git-sync sidecar.
#
# Pass through every flag exactly as batch-runner.sh accepts them.
#
# Usage:
#   co-batch                                 # run with defaults
#   co-batch --parallel 4 --min-score 3.0    # parallel, min-score gate
#   co-batch --model claude-sonnet-4-6 --retry-failed
#   co-batch --dry-run                       # no batch run, no sync
#   co-batch --no-sync ...                   # batch runs, sync skipped

set -euo pipefail

PROJECT_DIR="${CAREER_OPS_DIR:-${HOME}/career-ops}"
RUNNER="$PROJECT_DIR/batch/batch-runner.sh"
HOOK="$PROJECT_DIR/hooks/post-batch.sh"

if [[ ! -x "$RUNNER" ]]; then
  echo "ERROR: $RUNNER not found or not executable." >&2
  exit 1
fi

SYNC=true
DRY_RUN=false
RUNNER_ARGS=()
for arg in "$@"; do
  case "$arg" in
    --no-sync) SYNC=false ;;            # absorbed; not forwarded to runner
    --dry-run) DRY_RUN=true; RUNNER_ARGS+=("$arg") ;;
    *)         RUNNER_ARGS+=("$arg") ;;
  esac
done

bash "$RUNNER" "${RUNNER_ARGS[@]}"

if [[ "$DRY_RUN" == "true" ]]; then
  exit 0
fi

if [[ "$SYNC" == "true" && -x "$HOOK" ]]; then
  echo
  echo "=== Syncing to career-ops-data ==="
  bash "$HOOK"
fi
