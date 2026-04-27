# career-ops — Daily Usage Guide

How Joyson uses career-ops day-to-day. Covers the OSS engine (`santifer/career-ops`), the personal CLI wrappers (`co-process`, `co-batch`), and the K8s-hosted web dashboard.

---

## The four repos

```
~/career-ops              santifer/career-ops              OSS engine. Read-only.
~/career-ops-personal     joyson-fernandes/career-ops-personal   CLI wrappers + sync hooks.
~/career-ops-data         joyson-fernandes/career-ops-data       Private data store (applications.md, reports/).
~/career-ops-dashboard    joyson-fernandes/career-ops-dashboard  Web UI source.
```

The dashboard pod runs in K8s, pulls from `career-ops-data` via a `git-sync` sidecar, and serves https://careerops.joysontech.com (LAN-only, basic-auth).

---

## What goes where

| File | Purpose | Source |
|------|---------|--------|
| `~/career-ops/cv.md` | Your canonical CV. Drives every PDF. | You edit. Gitignored. |
| `~/career-ops/article-digest.md` | Compact proof points (metrics, case study URLs). Wins over `cv.md` when both have a metric. | You edit. Optional. |
| `~/career-ops/config/profile.yml` | Identity, comp targets, location, archetypes. | You edit. |
| `~/career-ops/modes/_profile.md` | User-specific archetypes, narrative, negotiation scripts. | You edit. Auto-update never touches it. |
| `~/career-ops/portals.yml` | Tracked companies + title/location filters for scan. | You edit. |
| `~/career-ops/data/applications.md` | Application tracker (markdown table). | Updated by batch / co-process. **Don't add rows by hand** — write a TSV in `batch/tracker-additions/` and run `merge-tracker.mjs`. |
| `~/career-ops/data/pipeline.md` | Inbox of pending URLs. | Appended by `scan.mjs`, you can also paste URLs here. |
| `~/career-ops/reports/{NNN}-{slug}-{date}.md` | Per-application evaluation report. | Auto-generated. |
| `~/career-ops/output/cv-{slug}.pdf` | Generated CVs. Gitignored. | `generate-pdf.mjs`. |

---

## Daily workflows

### "I saw a posting on LinkedIn"

```bash
co-process 'https://job-boards.greenhouse.io/anthropic/jobs/12345'
```

Quote the URL if it has `?` or `&`. Sonnet 4.6 by default. Adds the report, pushes to `career-ops-data`, dashboard refreshes within ~30 s.

If the page is behind login or Playwright stalls, copy the JD text and paste it into Claude Code as `/career-ops <JD text>`. Same pipeline, no fetch step. Then run `bash ~/career-ops/hooks/post-batch.sh` to push.

### "I want to scan for new postings"

```bash
node ~/career-ops/scan.mjs              # appends new URLs to data/pipeline.md
node ~/career-ops/scan.mjs --dry-run    # preview only
```

Scheduled scan runs every 3 days at 09:00 UK via launchd (`~/Library/LaunchAgents/com.joysontech.career-ops-scan.plist`). Results posted to Discord webhook.

### "I want to process the inbox in bulk"

```bash
co-batch --parallel 4 --min-score 3.0 --model claude-sonnet-4-6
```

After it finishes the post-batch hook pushes to `career-ops-data`. Useful flags:

| Flag | Effect |
|------|--------|
| `--parallel N` | N workers in parallel. 4 is sane on Sonnet. |
| `--min-score N` | Skip PDF + tracker when score < N. Saves time on weak fits. |
| `--model NAME` | Pick model. Default is Claude Max default; Sonnet for cheap batches. |
| `--retry-failed` | Only retry rows marked `failed` in `batch-state.tsv`. |
| `--dry-run` | List pending without running. |
| `--no-sync` | Run batch but skip the dashboard push. |

### "I want to update my CV"

```bash
$EDITOR ~/career-ops/cv.md
node ~/career-ops/cv-sync-check.mjs       # warn if structure breaks anything
node ~/career-ops/generate-pdf.mjs        # regenerate output/cv-*.pdf
```

`co-process` and `co-batch` always read the latest `cv.md` at evaluation time, so nothing else to rebuild — only manual PDF generation needs the script.

### "I want to view my pipeline"

- **Web** — https://careerops.joysontech.com (basic-auth `joyson` + password from `vault kv get secret/career-ops/basic-auth`). LAN-only.
- **TUI** — `cd ~/career-ops/dashboard && go run .` for the terminal UI.
- **Raw markdown** — `~/career-ops/data/applications.md` is the source of truth.

### "I want to apply to a posting"

```
/career-ops apply <url>
```

In Claude Code. Reads the application form via Playwright, generates draft answers using your CV. **You always review and click Submit yourself** — never auto-submitted.

### "I want to compare two offers"

```
/career-ops ofertas
```

Picks the highest-scored Evaluated rows and produces a head-to-head ranking. Use after a few apply-and-respond rounds.

### "I want to research a company before interviewing"

```
/career-ops deep Cohere
/career-ops interview-prep cohere-forward-deployed-engineer
```

`deep` produces long-form company research. `interview-prep` builds a STAR+R bank tied to the role and writes `~/career-ops/interview-prep/{company-role}.md`.

### "I want LinkedIn referrers for a role"

```
/career-ops contacto <url>
```

Finds 2–3 LinkedIn contacts at the company and drafts an outreach message. Doesn't send anything — you copy/paste.

### "I want to follow up on stale applications"

```
/career-ops followup
```

Reads `data/applications.md` + `data/follow-ups.md`, flags applications past their cadence, drafts follow-up messages.

### "I keep getting rejected — what am I doing wrong?"

```
/career-ops patterns
```

Aggregates `Status=Rejected` rows, groups by archetype/company-stage, surfaces what's repeatedly missing from your CV.

---

## Slash command reference

All commands run inside Claude Code (or OpenCode / Gemini CLI — same modes). Type `/` and the menu autocompletes.

| Command | Mode | Purpose |
|---------|------|---------|
| `/career-ops` (no args) | discovery | Show the menu. |
| `/career-ops <URL or JD>` | auto-pipeline | Full pipeline (eval + report + PDF + tracker). |
| `/career-ops oferta` | oferta | Evaluation only — no PDF, no tracker. |
| `/career-ops ofertas` | ofertas | Compare and rank multiple offers. |
| `/career-ops contacto` | contacto | LinkedIn outreach. |
| `/career-ops deep` | deep | Company research. |
| `/career-ops interview-prep` | interview-prep | STAR+R prep file. |
| `/career-ops pdf` | pdf | Regenerate CV only. |
| `/career-ops latex` | latex | Export CV as Overleaf `.tex`. |
| `/career-ops training` | training | Score a course/cert against North Star. |
| `/career-ops project` | project | Score a portfolio project idea. |
| `/career-ops tracker` | tracker | Application status overview. |
| `/career-ops apply` | apply | Live form-fill assistant. |
| `/career-ops scan` | scan | Run portal scan (same as `node scan.mjs`). |
| `/career-ops pipeline` | pipeline | Process all pending URLs in `data/pipeline.md`. |
| `/career-ops batch` | batch | Mass processing instructions. |
| `/career-ops patterns` | patterns | Rejection-pattern analysis. |
| `/career-ops followup` | followup | Follow-up cadence + drafts. |

---

## Routine maintenance

| Cadence | Task |
|---------|------|
| Daily | Glance at https://careerops.joysontech.com |
| Weekly | `/career-ops followup` — flag overdue applications |
| Bi-weekly | `/career-ops tracker` — full status read |
| Monthly | `/career-ops patterns` — review rejection signals |
| When CV changes | `node generate-pdf.mjs` |
| Quarterly | `node update-system.mjs check` to see if upstream has new modes/scripts |

---

## When things go wrong

| Symptom | Fix |
|---------|-----|
| `co-process` hangs on a URL | Ctrl-C. Copy the JD text. Use `/career-ops <JD text>` in Claude Code instead. |
| `zsh: no matches found: https://...` | Quote the URL: `co-process 'https://...'` |
| Dashboard shows stale data | `bash ~/career-ops/hooks/post-batch.sh` (or wait 30 s after the last batch) |
| `command not found: co-process` | `~/career-ops-personal/scripts/install.sh` |
| Auto-update broke a personal addition | `node ~/career-ops/update-system.mjs rollback` |
| Forgot dashboard password | `vault kv get -field=password secret/career-ops/basic-auth` |
| `verify-pipeline.mjs` complains about applications.md | `node normalize-statuses.mjs && node dedup-tracker.mjs` |
| Two scans collided / dupe URLs in pipeline.md | `node verify-pipeline.mjs` flags them; remove by hand |
| Pod stuck `Init:0/1` | Check `kubectl logs -n career-ops -l app=career-ops-dashboard -c git-sync-init` — usually a GitHub auth issue |

---

## Cost knobs

`co-process` and `co-batch` default to **Sonnet 4.6** under your Claude Max subscription. Per-job cost is roughly 5× cheaper than Opus. Use `--model claude-opus-4-7` only when you genuinely need the deeper reasoning (e.g. principal-level roles or unusual JDs).

`--min-score 3.0` on `co-batch` skips PDF generation for weak fits, which is most of the cost in a batch. Keep it set.

---

## Ethical defaults

- **Never auto-submitted.** Every application gets reviewed by you before sending.
- **Sub-3.0 scores recommend against applying.** Override only with a specific reason.
- **Quality over speed.** A 5-application week with strong fits beats a 50-application blast.
- **CV is read-only at eval time.** No mode mutates `cv.md`.
