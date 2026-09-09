# LP-0002 lock brief

Pin `0321d01ff4944474aab81cf7aca3896f0d2bbc2a`. Every line below was measured, not recalled.

**SUBMISSION_STATUS = NOT READY** — L2 (the public explorer has not indexed five transactions) and L11 (the video, human) open; L1 and L7 locked, with L3, L4, L5, L6, L8, L9, L10.

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
| **L1** Basecamp package | **LOCKED** | `.lgx` 2653306 bytes, sha256 `1d8b806dfabdc369d8c1546e42ff933a96194eb74f7d78fdb58260768597204d`. Installs in Basecamp 0.2.3, opens from Applications → Blockchain, and its panels read the deployed multisig — Config shows the 2-of-3 and the membership ImageID, Proposal two nullifiers and `executed`, Accounts the wallet. Needed a replica factory plugin (`logos.view.replica_factory/1.0`) whose interface was reconstructed from the host binary; `check-basecamp-contract.sh` asserts the contract and the factory test publishes the plugin and acquires a replica through the shipped factory. Caveats, both stated: `darwin-arm64` only, and Basecamp must start with `QT_ENABLE_REGEXP_JIT=0` — [BUGS_FILED.md](BUGS_FILED.md) §8, the host's bug |
| **L2** Explorer live | **NOT LOCKED** | Redeployed 2026-09-08. `check-explorer-links.sh` → exit 75: all seven transactions are on the chain and the sequencer returns each one; the explorer has indexed two of them so far and not the other five. That it has started is the point — the wait is the indexer's, not a dead deployment. Re-run before the PR |
| **L3** verify-onchain | **LOCKED** | exit 0 against the live deployment: FULL M, INV-7 (payee holds 60 of 60 approved), treasury 40 exactly, 2 privacy-preserving transactions |
| **L4** Full-M testnet lifecycle | **LOCKED** | create_multisig `007d9ff2…` · propose `aa14aa28…` · approve `a3eaeb3a…` · approve `2a283d3c…` · execute `d1a47fdd…`; treasury 100 → 40, payee 0 → 60. DEPLOYMENT.md carries all seven with full hashes and links |
| **L5** CU numeric | **LOCKED** | cu-costs.md: create_multisig 155,809 · create_proposal 257,625 · execute 315,293 · verify_approval 602,662. Zero occurrences of unavailable/TBD |
| **L6** demo + DEV_MODE=0 | **LOCKED** | No `RISC0_DEV_MODE=1` on the demo path; `E2E_COMPLETED` sentinel means an abort cannot exit 0; CI's clobber check green |
| **L7** CI tip green + real e2e | **LOCKED** | Green twice. Run [34302452494](https://github.com/pramadanif/lp-0002-private-multisig/actions/runs/34302452494) on pin `a8755b4` completed 2026-09-09 07:00 UTC with **all eleven jobs green**, its e2e job in 3 h 40 m, approvals at 03:44→05:20 and 05:20→06:56 (96 min each), `RISC0_DEV_MODE: 0` in the job environment and asserted by the job itself, ending `2 approvals of 2 required, executed, all nullifiers distinct` and `VERIFIED from public chain data alone`. `git diff a8755b4..HEAD` touches no crate, program, artifact or e2e script — only docs, the icon, the QML palette and packaging — so the current pin runs the code that run proved. Before it, run [34275830322](https://github.com/pramadanif/lp-0002-private-multisig/actions/runs/34275830322) on pin `c530fc8`: the `e2e-sequencer` job **succeeded** in 2 h 54 m against a real standalone LEZ v0.2.4 sequencer (`sequencer is live — getLastBlockId = 1`). Both approvals proved with `RISC0_DEV_MODE=0` — **75 minutes each** on a 4-core runner, against 21–22 min on the laptop — then execute at the full 2-of-3, `payment … holds 60, covering the 60 approved (INV-7)`, `treasury: 40 left, exactly funding minus the 60 paid`, `VERIFIED from public chain data alone`. Checked against a skip-to-green: the job asserts `RISC0_DEV_MODE=0`, and the two 75-minute proofs are in the log. The only commit since that pin (`2d69162`) changes `docs/cu-costs.md` and nothing else; its own e2e run is in progress |
| **L8** Doc one-truth | **LOCKED** | README, criteria-checklist, SOLUTION_DRAFT, phase-E/F, reviewer-gaps rewritten today against measured state; `check-links.sh` passes |
| **L9** Crypto / claim integrity | **LOCKED** | `cargo test --workspace` 128 passed, 0 failed. Includes INV-7 (execute refuses a recipient the proposal did not name), nullifier double-vote, restart-resume, and the admission-rule transcription |
| **L10** Solution packet | **LOCKED except the video URL** | Downloads section with the .lgx hash, size, arch and install link; verification one-liners; DEPLOYMENT.md has untrimmed hashes *with* links. Video URL fills in at L11 |
| **L11** Video | **HUMAN_BLOCKED: video** | Not recorded. Must be a human voice, must show the Basecamp UI, must show the pin and `RISC0_DEV_MODE=0` legibly |
| **L12** Preflight + day-of | **NOT LOCKED** | `pass=18 fail=0 pending=2` — PF-09 awaits the explorer index, PF-12 awaits the video. Day-of re-verification still required |

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
