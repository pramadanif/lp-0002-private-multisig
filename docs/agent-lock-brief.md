# LP-0002 lock brief

Pin `0321d01ff4944474aab81cf7aca3896f0d2bbc2a`. Every line below was measured, not recalled.

**SUBMISSION_STATUS = NOT READY**

## One paragraph

The design and the code are done and proven — 128 tests green, reproducible guests, numeric CU for
all four instructions, and a full lifecycle that ran end to end both in CI against a standalone
sequencer and on the public testnet with two anonymous approvals and an executed transfer. Since
then **the testnet was reset**: chain height is 19, our deployment at blocks 43002–43065 is gone,
the payer holds 0, and `verify-onchain.sh` now reports "config account is not owned by the multisig
program" because the account no longer exists. That takes L2, L3 and L4 from locked to lost and they
must be redone. **CI is red on the tip** and has been for every commit today. And the **Basecamp
package was rebuilt correctly but the machine still has the old install**, so its recognition is
unconfirmed. Nothing here is "almost": four gates are open.

## Race

| | |
|-|-|
| #125 (edenbd1) | CLOSED 2026-09-07, not merged |
| Open LP-0002 PRs | none |
| Merged / approved LP-0002 | none — no abort condition |

## Lock table

| Gate | State | Proof |
|------|-------|-------|
| **L1** Basecamp package | **HUMAN_BLOCKED: basecamp-confirm** | `app/manifest.json` type `ui_qml`, category `Blockchain`, icon `assets/icon.png`; `.lgx` 2622557 bytes, sha256 `1ad7018313cc7702d197c074276cfba2d78c1c5a5741c87a850e6dec2b4b943e`, `lgx verify` valid; packaged manifest carries type/category/icon. **Installed copy on this machine is still the old one** (`type=''`, `icon=''`, `category='tools'`) — the operator must reinstall. Steps: [basecamp-load.md](basecamp-load.md) |
| **L2** Explorer live | **NOT LOCKED** | `check-explorer-links.sh` → exit 1. Transactions absent: the chain was reset |
| **L3** verify-onchain | **NOT LOCKED** | exit 1, "config account is not owned by the multisig program" |
| **L4** Full-M testnet lifecycle | **NOT LOCKED** | DEPLOYMENT.md describes blocks 43002–43065; chain height is now 19. Must redeploy and strike the superseded rows |
| **L5** CU numeric | **LOCKED** | cu-costs.md: create_multisig 155,809 · create_proposal 257,625 · execute 315,293 · verify_approval 602,662. Zero occurrences of unavailable/TBD |
| **L6** demo + DEV_MODE=0 | **LOCKED** | No `RISC0_DEV_MODE=1` on the demo path; `E2E_COMPLETED` sentinel means an abort cannot exit 0; CI's clobber check green |
| **L7** CI tip green + real e2e | **NOT LOCKED** | Every completed run on main today: failure. rzup hit the api.github.com rate limit; fix committed, unverified. Tip `0fb19dc` still running |
| **L8** Doc one-truth | **LOCKED** | README, criteria-checklist, SOLUTION_DRAFT, phase-E/F, reviewer-gaps rewritten today against measured state; `check-links.sh` passes |
| **L9** Crypto / claim integrity | **LOCKED** | `cargo test --workspace` 128 passed, 0 failed. Includes INV-7 (execute refuses a recipient the proposal did not name), nullifier double-vote, restart-resume, and the admission-rule transcription |
| **L10** Solution packet | **NOT LOCKED** | SOLUTION_DRAFT needs the new deployment's untrimmed hashes with links, the pin CI URL, and the .lgx hash; video URL pending L11 |
| **L11** Video | **HUMAN_BLOCKED: video** | Not recorded. Must be a human voice, must show the Basecamp UI, must show the pin and `RISC0_DEV_MODE=0` legibly |
| **L12** Preflight + day-of | **NOT LOCKED** | `pass=15 fail=2 pending=1` — PF-09 and PF-10 fail on the reset |

## What the reset cost, and what it did not

Lost: the transactions, the funded payer, and the approver accounts claimed on the old chain.

Kept: the recipe. Reproducible binaries, working scripts, and the ordering that took three failed
runs to find — **a shielded account must be claimed with `auth-transfer init` while it is still
wholly default; once `sync-private` gives it a nonce it can never be claimed or used as an approver
again** ([lez-admission-rules.md](lez-admission-rules.md)). At height 19 there is nothing to sync, so
the redeploy should be far quicker than the first.

This also settles a question of sequencing: **the deployment has to be done close to the day the PR
is opened.** A reviewer on an earlier prize asked exactly this — "re-submit transactions as they are
not available anymore".

## Next commands

1. `./scripts/fund-testnet.sh` — payer is at 0
2. `wallet account new private` ×2, then `auth-transfer init` on each **before** any sync
3. `PMSIG_MEMBER_IDS=… ./scripts/deploy-testnet.sh` — full M, then refresh DEPLOYMENT.md
4. Confirm CI green on the pin
5. Operator reinstalls the .lgx and confirms Type `ui_qml`
