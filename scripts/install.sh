#!/usr/bin/env bash
# Wire career-ops-personal into the local career-ops install.
#
# - Symlinks scripts/* into ~/career-ops/scripts and ~/career-ops/hooks
#   so /career-ops batch and the slash commands pick them up.
# - Symlinks scripts/process-url.sh into ~/bin as co-process.
#
# Idempotent — re-run after pulling new versions of this repo.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CAREER_OPS_DIR="${CAREER_OPS_DIR:-${HOME}/career-ops}"
BIN_DIR="${HOME}/bin"

if [[ ! -d "$CAREER_OPS_DIR" ]]; then
  echo "ERROR: $CAREER_OPS_DIR does not exist." >&2
  echo "       Set CAREER_OPS_DIR to your career-ops checkout, or clone it first." >&2
  exit 1
fi

mkdir -p "$BIN_DIR" "$CAREER_OPS_DIR/scripts" "$CAREER_OPS_DIR/hooks"

link() {
  local src="$1" dst="$2"
  if [[ -L "$dst" || -e "$dst" ]]; then
    rm -f "$dst"
  fi
  ln -s "$src" "$dst"
  echo "  $dst → $src"
}

echo "Installing from $REPO_DIR"
link "$REPO_DIR/scripts/process-url.sh" "$CAREER_OPS_DIR/scripts/process-url.sh"
link "$REPO_DIR/scripts/post-batch.sh"  "$CAREER_OPS_DIR/hooks/post-batch.sh"
link "$REPO_DIR/scripts/process-url.sh" "$BIN_DIR/co-process"
link "$REPO_DIR/scripts/co-batch.sh"    "$BIN_DIR/co-batch"

echo
echo "Done. Try: co-process --help, co-batch --help"
