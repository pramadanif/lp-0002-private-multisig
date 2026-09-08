# Where LP-0002 actually stands

Measured 2026-09-08, pin `7f16b1b`. Nothing here is carried over from an earlier note; every line
was re-run.

## One paragraph

The design is finished and proven: 128 tests, reproducible guests, a full lifecycle that has run
end to end against a standalone sequencer in CI (3 h 41 m, green) **and** against the public testnet
with two anonymous approvals and an executed transfer. Two things stand between that and a
submission. **The testnet was reset** — chain height is back to 19, our deployment at blocks
43002–43065 is gone, and the payer holds 0; it must be redeployed, and because resets recur it has
to be done close to the day the PR is opened. And **the Basecamp package installs but is not
recognised as an application**: our manifest says `type: "ui"`, which Basecamp stores as empty, so
the package shows Type "-" and never appears alongside catalog apps.

## Race

| | |
|-|-|
| #125 (edenbd1) | **CLOSED 2026-09-07, not merged** |
| Open LP-0002 PRs | none |
| Merged LP-0002 | none — the prize is unclaimed |

Why #125 was rejected, in the reviewer's words — these are the bar:

1. "demo video doesn't cover Basecamp app but only CLI"
2. "demo video is narrated using AI which is not fair comparing to other submitters"
3. "main point of submission is the **solution file** … transaction hashes are trimmed and do not
   have links, video link is missing"

Point 3 decides the shape of the work: what is judged is `solutions/LP-0002.md`, not the PR
description and not the repository.

## Gaps

| Gap | State | Evidence |
|-----|-------|----------|
| Basecamp `type` | **FAIL** | source `type: "ui"`; installed manifest `type: ""`, icon `""`, Type column "-" |
| Basecamp recognised as app | **FAIL** | does not appear in Applications; catalog apps use `ui_qml` |
| Basecamp variants | **PARTIAL** | `darwin-arm64` only |
| Testnet evidence | **FAIL** | chain reset to height 19; deployment and balances gone |
| `verify-onchain.sh` | **FAIL** | passes only against a live deployment; there is none right now |
| `check-explorer-links.sh` | **FAIL** | transactions genuinely absent after the reset |
| CI `fmt + clippy + tests` | **FAIL** | rzup hit `api.github.com` rate limit — fixed, unverified |
| CI `evidence URLs` | **FAIL** | followed the reset; will pass once redeployed |
| CI e2e standalone | **PASS** | run 34052567273, 3 h 41 m |
| Docs vs reality | **PASS** | README, criteria-checklist, SOLUTION_DRAFT, phase-E/F rewritten today |
| Video | **HUMAN** | not recorded; must show Basecamp and use a human voice |

## What the reset costs, and what it does not

Lost: the on-chain transactions, the funded payer, and the claimed approver accounts — those claims
lived on the old chain.

Kept: everything that made the deployment possible. The reproducible binaries, the scripts, and —
most of all — the knowledge of the ordering that took three failed runs to find: **a shielded
account must be claimed with `auth-transfer init` while it is still wholly default; once
`sync-private` gives it a nonce it can never be claimed or used as an approver again**
([lez-admission-rules.md](lez-admission-rules.md)). On a chain at height 19 there is nothing to sync,
so the redeploy should be markedly faster than the first one.

## Plan, in order

1. Basecamp manifest → `type: "ui_qml"`, a sidebar category, a real icon; rebuild; document the
   reinstall steps. This unblocks the operator's UI check and the video.
2. CI green on the pin — rzup token fix is in, needs a run to confirm.
3. Redeploy to the testnet: faucet, fresh shielded accounts, claim before sync, full M, execute.
4. Refresh `DEPLOYMENT.md` with full untrimmed hashes **and links**, and the solution file with them.
5. Video shot list; then `HUMAN_BLOCKED: video`.
6. Day-of re-verification, then stop for the operator's decision on opening the PR.
