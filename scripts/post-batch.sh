#!/usr/bin/env bash
# Sync career-ops data + reports to the private career-ops-data repo so the
# in-cluster dashboard pod (career-ops-dashboard) can pick them up via git-sync.
#
# Invoked at the end of batch/batch-runner.sh's merge_tracker step. Idempotent
# and safe to run by hand: `bash hooks/post-batch.sh`.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA_REPO="${CAREER_OPS_DATA_REPO:-${HOME}/career-ops-data}"

if [[ ! -d "$DATA_REPO/.git" ]]; then
  echo "post-batch: $DATA_REPO is not a git repo, skipping" >&2
  exit 0
fi

mkdir -p "$DATA_REPO/data" "$DATA_REPO/reports"

# Mirror data/ and reports/ from the working career-ops directory.
# rsync --delete prunes anything no longer present locally.
rsync -a --delete \
  --include='applications.md' \
  --include='pipeline.md' \
  --exclude='*' \
  "$PROJECT_DIR/data/" "$DATA_REPO/data/"
rsync -a --delete \
  --include='*.md' \
  --exclude='*' \
  "$PROJECT_DIR/reports/" "$DATA_REPO/reports/"

cd "$DATA_REPO"
if [[ -z "$(git status --porcelain)" ]]; then
  echo "post-batch: no data changes to push"
  exit 0
fi

git add data reports
git -c user.name='career-ops sync' -c user.email='career-ops@joysontech' \
  commit -m "Sync from career-ops $(date -u +%Y-%m-%dT%H:%M:%SZ)" --quiet

if git push --quiet origin main 2>/dev/null; then
  echo "post-batch: pushed to career-ops-data"
else
  echo "post-batch: push failed (check network/credentials)" >&2
  exit 1
fi
