# `docs/_archive/` — not a status surface

Everything here is **superseded**. It is agent working notes and per-phase build logs, kept because
deleting them would erase the record of how the work actually went, and moved out of `docs/` because
a reviewer opening this repository should find one answer to "where does this stand", not eleven
dated ones that disagree.

**The canonical surface is three files:**

| | |
|-|-|
| [`README.md`](../../README.md) | what this is, and how to run it |
| [`docs/SOLUTION_DRAFT.md`](../SOLUTION_DRAFT.md) | the submission packet — the shape a judge reads |
| [`docs/criteria-checklist.md`](../criteria-checklist.md) | every success criterion, with evidence |

Nothing in this folder should be cited as current. Where a file here held a fact that was still
true and lived nowhere else, that fact was moved into the canonical set before archiving — the
rescues are listed at the bottom.

## What moved, and why

| Was | Now | Why |
|-----|-----|-----|
| `docs/agent-gap-brief.md` | `_archive/` | Agent scratch — a gap analysis pinned to commit `534b571` |
| `docs/agent-lock-brief.md` | `_archive/` | Agent scratch — a lock table pinned to `0321d01f`; `TRACKING.md` pointed at it for "everything else is locked", which is what `criteria-checklist.md` is for |
| `docs/agent-now-brief.md` | `_archive/` | Agent scratch — a status snapshot at pin `24c6ac4` |
| `docs/agent-packet-brief.md` | `_archive/` | Agent scratch — the plan for rewriting `SOLUTION_DRAFT.md`; the rewrite is done, so the plan is history |
| `docs/agent-read-receipt.md` | `_archive/` | Agent scratch — a 2026-09-04 receipt for reading the plan |
| `docs/agent-rename-audit.md` | `_archive/` | Agent scratch — the `lp0002` → `lp-0002-private-multisig` audit. Its lesson is now a gate, preflight **PF-18** |
| `docs/session-state.md` | `_archive/` | A dated snapshot (2026-09-07) whose "still open" list is now almost entirely closed |
| `docs/reviewer-gaps.md` | `_archive/` | A reading of all nine closed LP-0002 submissions. Its findings were folded into `criteria-checklist.md`; its §5 answer on `execute` carrying no proof was already in `SOLUTION_DRAFT.md` |
| `docs/phase-{-1,0,A,B,C,D,E,F}-status.md` | `_archive/` | Per-phase build logs. Three still read "in progress" for work that had finished |
| `PRIZE_CHECKLIST.md` (repo root) | `_archive/` | A mirror of the criteria that said, in its own second heading, "Status lives in one place, and it is not this file" |
| `docs/plan/PROMPT_CLAUDE_CODE_LP0002.md` | `_archive/` | The build prompt — agent input, not prize text |
| `evidence/testnet-run-2026-09-07-inflight.md` | `_archive/` | The only orphan in `evidence/` — nothing cited it, and its half-finished lifecycle hashes are superseded by the 2026-09-08 redeploy. Left in `evidence/` they would sit beside the real ones with nothing saying which is which |

`git mv` throughout, so `git log --follow` still works on every one of them.

## Facts rescued before archiving

Each of these was true, lived only in a file being archived, and was moved into the canonical set.

1. **Reproducibility is demonstrated, not asserted** — from `session-state.md` into
   [`limitations.md`](../limitations.md) §11. Rebuilding `membership` on a different day in a fresh
   container returned a byte-identical ImageID. That section had also gone stale in the opposite
   direction: it claimed `artifacts/IMAGE_IDS.md` recorded a *local* build, while the file itself
   said `reproducible` for both guests — two documents a judge reads, disagreeing.

2. **Why submissions actually get rejected** — from `reviewer-gaps.md` into
   [`criteria-checklist.md`](../criteria-checklist.md). The three causes with their PR numbers, the
   long tail, and the lesson from the accepted ones: #64 was awarded after two mechanical fixes, one
   of them because its explorer links had expired between submission and review. That section had
   also gone stale, still describing "our two ⛔ rows on CI and testnet" when both are green and the
   only ⛔ left is the video.

3. **The phase ledger** — `TRACKING.md` now marks E and F complete and G/H/I truthfully, instead of
   pointing at archived logs as if they were current.

4. **An approval that never confirmed on the public testnet** — from
   `evidence/testnet-run-2026-09-07-inflight.md` into [`tried-failed.md`](../tried-failed.md): the
   four causes ruled out without spending another twenty-minute proof, and what was left.

## Two corrections this cleanup forced

Neither was a link. Both were a judge-facing file asserting something that had stopped being true.

- **`limitations.md` §11** said `artifacts/IMAGE_IDS.md` recorded a *local* build. The file said
  `reproducible` for both guests. Verified against `git show 566286f:artifacts/IMAGE_IDS.md` before
  rewriting, rather than trusting the note that reported it.
- **`tried-failed.md`** ended with "the cause is still unknown, and the factory stays out of the
  package until it is known". Both causes were found days ago and the factory ships — measured:
  `variants/darwin-arm64/private_multisig_replica_factory.dylib` is inside the packaged `.lgx`. That
  section now records both real causes, and that neither was among the five theories tested.

## Result

Measured against `b062d71` (2026-09-09), working tree uncommitted so the operator can review the
moves before they land.

| | |
|-|-|
| Files moved | **19** — 18 into `docs/_archive/`, plus one orphan out of `evidence/` |
| Facts rescued into the canonical set | **4** (listed above) |
| Judge-facing files corrected | **2** — `limitations.md` §11, `tried-failed.md` |
| `check-links.sh` | **exit 0** — 94 relative links across 46 files, all resolve |
| `preflight-submission.sh` | `pass=20 fail=0 pending=2`, exit 1 — unchanged by this cleanup. The two PENDING are PF-09 (explorer index, external) and PF-12 (the video, human); PENDING exits 1 by design so a submission can never read ready while work is outstanding |
| Markdown under `docs/`, excluding `_archive/` and `plan/` | **20** |
| Markdown at the repository root | **1** — `README.md` |

Nothing under `.refs/` was touched, no history was rewritten, and no `.lgx` was rebuilt.
