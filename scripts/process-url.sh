#!/usr/bin/env bash
# Process a single job URL through the full career-ops pipeline:
#   evaluate (A-G) → report .md → PDF → tracker entry → push to dashboard
#
# Uses claude -p with Sonnet by default (cheaper than Opus, all tools work).
# Designed for ad-hoc one-shot runs from any terminal.
#
# Usage:
#   process-url.sh <url>
#   process-url.sh --model claude-opus-4-7 <url>
#   MODEL=claude-opus-4-7 process-url.sh <url>
#   process-url.sh --no-sync <url>      # skip the post-batch dashboard sync

set -euo pipefail

PROJECT_DIR="${CAREER_OPS_DIR:-${HOME}/career-ops}"
BATCH_DIR="$PROJECT_DIR/batch"
REPORTS_DIR="$PROJECT_DIR/reports"
PROMPT_FILE="$BATCH_DIR/batch-prompt.md"
MODEL="${MODEL:-claude-sonnet-4-6}"
SYNC=true

usage() {
  cat <<USAGE
Usage: $(basename "$0") [OPTIONS] <url>

Run the full career-ops pipeline for a single job URL: evaluate → report → PDF
→ tracker → push to dashboard.

Options:
  --model NAME    Claude model to use (default: claude-sonnet-4-6)
  --no-sync       Skip post-batch sync to career-ops-data
  -h, --help      Show this help

Examples:
  $(basename "$0") https://job-boards.greenhouse.io/anthropic/jobs/12345
  $(basename "$0") --model claude-opus-4-7 https://...
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model)    MODEL="$2"; shift 2 ;;
    --no-sync)  SYNC=false; shift ;;
    -h|--help)  usage; exit 0 ;;
    --)         shift; break ;;
    -*)         echo "unknown flag: $1" >&2; usage >&2; exit 2 ;;
    *)          break ;;
  esac
done

URL="${1:-}"
if [[ -z "$URL" ]]; then
  usage >&2
  exit 2
fi

if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "ERROR: $PROMPT_FILE not found." >&2
  exit 1
fi

if ! command -v claude &>/dev/null; then
  echo "ERROR: 'claude' CLI not found in PATH." >&2
  exit 1
fi

cd "$PROJECT_DIR"

# Compute next report number: max(reports/NNN-*.md) + 1.
next_report_num() {
  local max=0
  if [[ -d "$REPORTS_DIR" ]]; then
    for f in "$REPORTS_DIR"/*.md; do
      [[ -f "$f" ]] || continue
      local n="${f##*/}"
      n="${n%%-*}"
      n=$((10#$n))
      (( n > max )) && max=$n
    done
  fi
  printf '%03d' $((max + 1))
}

REPORT_NUM=$(next_report_num)
DATE=$(date +%Y-%m-%d)
ID="adhoc-$(date +%s)"
JD_FILE="/tmp/co-jd-${ID}.txt"
RESOLVED_PROMPT=$(mktemp -t co-prompt-XXXXXX)
trap 'rm -f "$RESOLVED_PROMPT" "$JD_FILE"' EXIT

# Render the system prompt with this run's placeholders.
sed \
  -e "s|{{URL}}|${URL//|/\\|}|g" \
  -e "s|{{JD_FILE}}|${JD_FILE//|/\\|}|g" \
  -e "s|{{REPORT_NUM}}|${REPORT_NUM}|g" \
  -e "s|{{DATE}}|${DATE}|g" \
  -e "s|{{ID}}|${ID}|g" \
  "$PROMPT_FILE" > "$RESOLVED_PROMPT"

PROMPT="Process this job offer end-to-end. Run the full pipeline: A-G evaluation + report .md + PDF (if score >= 3.0) + tracker line. URL: $URL  JD file: $JD_FILE  Report number: $REPORT_NUM  Date: $DATE  Batch ID: $ID"

echo "→ URL:    $URL"
echo "→ Report: $REPORT_NUM ($DATE)"
echo "→ Model:  $MODEL"
echo

claude -p \
  --dangerously-skip-permissions \
  --model "$MODEL" \
  --append-system-prompt-file "$RESOLVED_PROMPT" \
  "$PROMPT"

# Merge any TSV the worker dropped in batch/tracker-additions/.
if compgen -G "$BATCH_DIR/tracker-additions/*.tsv" > /dev/null; then
  echo
  echo "=== Merging tracker additions ==="
  node "$PROJECT_DIR/merge-tracker.mjs"
  node "$PROJECT_DIR/verify-pipeline.mjs" || true
fi

# Push to career-ops-data so the dashboard picks it up within ~30s.
if [[ "$SYNC" == "true" && -x "$PROJECT_DIR/hooks/post-batch.sh" ]]; then
  echo
  echo "=== Syncing to career-ops-data ==="
  bash "$PROJECT_DIR/hooks/post-batch.sh"
fi

echo
echo "✅ Done. Report: reports/${REPORT_NUM}-*.md"
