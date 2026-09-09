# Where LP-0002 actually stands

Measured 2026-09-09, pin `24c6ac4`. Nothing here is carried over from an earlier note; every line
was re-run.

## One paragraph

The design is finished and proven: 128 tests, reproducible guests, and a full lifecycle that has run
end to end against a standalone sequencer **and** against the public testnet, redeployed after the
reset and re-verified from public data on 2026-09-09 (`verify-onchain.sh`, exit 0). The Basecamp
module now works rather than merely installing: for a day it rendered every panel and did nothing,
because Basecamp loads a `ui_qml` module's QML in its main process while the plugin runs in a
`ui-host` child, so the context property the scaffold set was never in scope. The plugin now
publishes its API the way Basecamp's own modules do, `Main.qml` resolves it through
`logos.module()`, and the IDL carries the account layouts a fetch needs to decode. Two things are
left: **the video**, which needs a human, and the **public explorer**, which has indexed the two
program deployments but not yet the five lifecycle transactions.

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
| Basecamp module loads | **PASS** | host log: `ui-host: loaded plugin "private_multisig"`, `Successfully loaded UI module`; appears under Applications → Blockchain |
| Basecamp module *works* | **PASS** | `check-basecamp-contract.sh`: the plugin publishes the API Basecamp replicates, `Main.qml` resolves it via `logos.module()`, and with `PMSIG_CONTRACT_LIVE=1` it fetched the deployed 2-of-3 and listed 5 wallet accounts through the plugin's own slots |
| Basecamp variants | **PARTIAL** | `darwin-arm64` only — stated scope, not a defect |
| Testnet evidence | **PASS** | redeployed 2026-09-08T15:25Z; `verify-onchain.sh` exit 0 on 2026-09-09 |
| `check-explorer-links.sh` | **PENDING (external)** | exit 75 — 22 of 27 evidence URLs resolve. Of the seven lifecycle transactions the explorer has now indexed two; the other five it has not. It is working through them, not dropping them |
| CI fast jobs | **PASS** | all green on the pin |
| CI e2e standalone | **PASS (twice)** | run [34302452494](https://github.com/pramadanif/lp-0002-private-multisig/actions/runs/34302452494) on pin `a8755b4`, all eleven jobs green, e2e 3 h 40 m, two 96-min proofs, `VERIFIED from public chain data alone`. Before it, run 34275830322 on pin `c530fc8`, 2 h 54 m: real sequencer, both approvals proved at 75 min each with `RISC0_DEV_MODE=0`, execute at full M, verified from chain data. A local run of the same script passed too ([evidence](../evidence/e2e-local-2026-09-09.md)) |
| Docs vs reality | **PASS** | README, criteria-checklist, SOLUTION_DRAFT, basecamp-load, evidence and phase-E/F all re-run today |
| Video | **HUMAN** | not recorded; must show the Basecamp module fetching real state, and use a human voice |

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

1. **Record the video.** Human-voiced, showing the Basecamp module fetch the deployed config and
   proposal, the CLI lifecycle with `RISC0_DEV_MODE=0` legible, and the pin commit. Shot list:
   [video-transcript.md](video-transcript.md).
2. Confirm the e2e job is green on the final pin.
3. Re-run `verify-onchain.sh` and `check-explorer-links.sh` **on the day the PR is opened** — the
   testnet wipes, and a dead link fails the plan gate.
4. Write `solutions/LP-0002.md` from `SOLUTION_DRAFT.md` with full untrimmed hashes and links.
5. Stop. The operator opens the PR; the agent never does.
