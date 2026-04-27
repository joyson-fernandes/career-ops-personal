# career-ops-personal

Personal scripts that wire [career-ops](https://github.com/santifer/career-ops) into the [career-ops-dashboard](https://github.com/joyson-fernandes/career-ops-dashboard) running on the Joysontech Kubernetes cluster.

These are intentionally kept out of the main career-ops fork so the OSS upstream stays clean, the `update-system.mjs` auto-updater can't clobber them, and they have their own release/version history.

## What's here

| Script | Purpose |
|--------|---------|
| `scripts/process-url.sh` | One-shot CLI wrapper. Runs `claude -p` with the career-ops batch prompt for a single URL: A–G eval → report → PDF → tracker → push to dashboard. Symlinked into `~/bin/co-process`. |
| `scripts/post-batch.sh` | rsync `data/` and `reports/` into `~/career-ops-data` and `git push`. The in-cluster dashboard's `git-sync` sidecar pulls the change within ~30 s. Hooked from career-ops `batch/batch-runner.sh::merge_tracker`. |
| `scripts/install.sh` | Symlinks both scripts into `~/career-ops/{scripts,hooks}` and `~/bin`. Idempotent — re-run after `git pull`. |

## Install

```bash
git clone https://github.com/joyson-fernandes/career-ops-personal.git ~/career-ops-personal
~/career-ops-personal/scripts/install.sh
```

The installer expects `~/career-ops` to exist (override with `CAREER_OPS_DIR=...`). Make sure `~/bin` is on your `$PATH`.

## Usage

### Single URL — full pipeline end-to-end

```bash
co-process https://job-boards.greenhouse.io/anthropic/jobs/12345
```

Default model is `claude-sonnet-4-6`. Override with `--model claude-opus-4-7` or the `MODEL` env var. Pass `--no-sync` to skip the post-batch push.

### Batch processing

`career-ops/batch/batch-runner.sh` calls `hooks/post-batch.sh` automatically at the end of `merge_tracker`. Nothing extra to do.

### Manual sync

```bash
~/career-ops/hooks/post-batch.sh   # ad-hoc rsync + push
```

## Companion projects

| Repo | Role |
|------|------|
| [`santifer/career-ops`](https://github.com/santifer/career-ops) | OSS upstream. Treated as read-only — no personal commits. |
| [`joyson-fernandes/career-ops-dashboard`](https://github.com/joyson-fernandes/career-ops-dashboard) | Web dashboard (Go + chi + templ + htmx). Reads from the data repo via a `git-sync` sidecar. |
| [`joyson-fernandes/career-ops-data`](https://github.com/joyson-fernandes/career-ops-data) | Private data repo. `applications.md`, `pipeline.md`, `reports/*.md`. Pushed to by `post-batch.sh`, pulled from by the dashboard. |
| [`joyson-fernandes/career-ops-personal`](https://github.com/joyson-fernandes/career-ops-personal) | This repo. CLI helpers + integration scripts. |

## License

MIT.
