# Criteria checklist

Every official Success Criterion from [`prizes/LP-0002.md`](plan/LP-0002.md), mapped to the evidence
that supports it — or marked plainly as unmet.

**Rule:** a row is ✅ only when a command was run and its output recorded. "The code does it" is not
evidence. Rows that are not there yet say so, and say what is missing.

Status: ✅ evidence exists · ◐ partial · ⛔ not met

---

## Functionality

| ID | Criterion | Status | Evidence |
|----|-----------|--------|----------|
| **P-F1** | Shielded member approves without revealing identity to on-chain observers **or other members** | ✅ | On chain: tx `f2458791…198fbcb5` from `Private/Dm4TU2ht…`; the proposal account holds a count and nullifiers only (`artifacts/phase-E-ppe-approve-SUCCESS.txt`). Against co-members: `crates/sdk/tests/peer_privacy.rs` — `prepare_approval` takes a public `MultisigView` plus the member's own secrets, and has **no parameter** for another member's identity |
| **P-F2** | On-chain verifier confirms M approvals **without recording which** members | ✅ | Decoded from chain: `approvals=1, nullifier[0]=c67cce32…, executed=false`, no identity field. `Proposal` has six fields and none can hold a roster (`crates/multisig-core/src/lib.rs`) |
| **P-F3** | A member cannot approve twice (nullifiers) | ✅ | `a_member_cannot_approve_the_same_proposal_twice` → error **1002** (`7002` on chain); `a_member_cannot_double_vote_from_another_of_their_addresses` (nullifier keyed to `nsk`, not account id) |
| **P-F4** | Completed execution unlinkable to any individual member | ✅ | Shown for a **completed execute** on the public testnet. The proposal account after execution holds `approvals=2` and two nullifiers and no identity field; `execute` (`c226f747…`, block 43065) is a public transaction submitted by the payer, and nothing in it or in the account names an approver. The two approvals are separate privacy-preserving transactions whose only on-chain trace is a nullifier. `the_on_chain_record_does_not_distinguish_which_members_approved` |
| **P-F5** | Proof generation runs client-side on a standard laptop | ✅ | Standalone membership proof **115.97 s**; composed approval **≈19 min 26 s**, peak **8.74 GB**, on an 8-core 16 GB laptop with no GPU. Both in `docs/cu-costs.md`. Caveat stated: needs ~7 GB *free* (`docs/limitations.md` §10a) |
| **P-F6** | Reference integration: threshold-gated action on LEZ **testnet** with shielded members | ✅ | LEZ public testnet: multisig `n3HuidKX…` created (`d64d3566…`, block 43002), treasury funded 100, proposal (`1102908e…`), two anonymous approvals (`b84980b3…` block 43040, `5234e72b…` block 43061), `execute` (`c226f747…`, block 43065). Treasury 100 → 40, payee 0 → 60. [`docs/DEPLOYMENT.md`](DEPLOYMENT.md) |
| **P-F7** | ≥1 multisig on testnet: create + propose + approve-to-threshold + execute, reproducible with evidence | ✅ | All four steps on the public testnet, evidence in [`docs/DEPLOYMENT.md`](DEPLOYMENT.md) and [`evidence/testnet-lifecycle-verified.md`](../evidence/testnet-lifecycle-verified.md). Reproducible: `./scripts/deploy-testnet.sh` from the committed reproducible binaries, and `./scripts/verify-onchain.sh` re-checks it from public data alone — it passed, including INV-7 (the payee named *by the proposal* holds the 60 approved) and the exact treasury remainder |
| **P-F8** | Full documentation and a clean public repository | ✅ | Public repo, 128 tests, ADRs, security model, error codes, limitations, `SOLUTION_DRAFT.md`, `BUGS_FILED.md`, `DEPLOYMENT.md`, and a documentation index in the README |

## Usability

| ID | Criterion | Status | Evidence |
|----|-----------|--------|----------|
| **P-U1** | Module/SDK for building Logos modules | ✅ | `pmsig-sdk` (prove + member API), `pmsig-core`, `pmsig-store`, `pmsig-cli`. Guide: `docs/integration.md`, whose code is the **compiled** example `crates/sdk/examples/integrate.rs` |
| **P-U2** | Basecamp GUI: local build, downloadable assets, loadable | ◐ | **Built and committed:** `app/private_multisig.lgx`, 2,605,557 bytes, sha256 `785eb121…40746ad`, `lgx verify` reports the structure valid. It contains the plugin, `qml/Main.qml`, and `libpmsig_ffi.dylib` — the C ABI the UI's thirteen `extern "C"` functions call, generated from the same IDL and checked symbol by symbol before packaging. Build instructions: `./scripts/build-basecamp.sh`. **Two gaps remain:** the package carries only the `darwin-arm64` variant, and it has not been shown loading in Basecamp |
| **P-U3** | IDL for the LEZ program, using SPEL | ✅ | `artifacts/multisig-idl.json`, generated from `#[lez_program]` at compile time by `scripts/generate-idl.sh`. Independently confirmed usable: the SPEL CLI built working commands from it and submitted real transactions |

## Reliability

| ID | Criterion | Status | Evidence |
|----|-----------|--------|----------|
| **P-R1** | Proof failures handled gracefully, clear error to the member | ✅ | `prove_failures` tests: truncated/empty binary → **2001**; the guest's own reason is passed through; dev mode → **2003** explaining *why*. `2002 ProverNotFound` names the install command |
| **P-R2** | Partial approvals (< M) preserved and resumable across client restarts | ✅ | `crates/store/tests/resume.rs` (9 tests) and `a_partial_approval_set_survives_between_processes` — each CLI command is its **own process**, so the restart is real. Atomic writes; a corrupt store is reported, never discarded |
| **P-R3** | Deterministic, documented error codes for all invalid-proof and double-vote cases | ✅ | 13 on-chain codes + 11 client codes in `docs/error-codes.md`. A test asserts **every** enum code appears in that document with the same number |

## Performance

| ID | Criterion | Status | Evidence |
|----|-----------|--------|----------|
| **P-P1** | CU cost of each on-chain operation documented (numeric) | ✅ | All four instructions measured against the **reproducible binaries the chain is given**: `create_multisig` 155,809 · `create_proposal` 257,625 · `execute` 315,293 · `verify_approval` 602,662 cycles. [`docs/cu-costs.md`](cu-costs.md) §2, regenerate with `./scripts/measure-cu.sh`. Each figure comes from a run that succeeded — a program error would burn cycles and be published as the happy path otherwise |

## Supportability

| ID | Criterion | Status | Evidence |
|----|-----------|--------|----------|
| **P-S1** | Deployed and tested on LEZ devnet/testnet | ✅ | Deployed to the LEZ public testnet and exercised end to end there — see P-F6/P-F7. Both programs deployed from the reproducible build; `membership` at block 38661, `multisig` at 40565 |
| **P-S2** | E2E tests against a LEZ sequencer (**standalone**) in CI | ✅ | Run [34052567273](https://github.com/pramadanif/lp0002/actions/runs/34052567273), job "e2e against a real standalone LEZ sequencer": **success, 3 h 41 m**. Not a skipped pass — the log carries `DEMO COMPLETE`, both approvals at `RISC0_DEV_MODE=0`, `executed and confirmed`, and the INV-7 check reporting the payee holding 60 of 60 approved with 40 left in the treasury |
| **P-S3** | CI green on the default branch | ✅ | GitHub Actions green on `main`: `fmt + clippy + tests`, `shellcheck`, `RISC0_DEV_MODE clobber check` |
| **P-S4** | README documents E2E usage: deploy steps, addresses, CLI **and** Basecamp | ✅ | README §"End-to-end usage" covers prerequisites, guest build, demo, testnet deploy, public verification, the CLI and the Basecamp app step by step. **Program addresses are now in it** — the deployed ImageIDs, the config and proposal PDAs, the payee, and the block of every lifecycle transaction; the full list with explorer links is [`docs/DEPLOYMENT.md`](DEPLOYMENT.md) |
| **P-S5** | Reproducible `demo.sh` against a **real local sequencer** with `RISC0_DEV_MODE=0` | ✅ | `./demo.sh` completed unattended against a genuine standalone sequencer with `RISC0_DEV_MODE=0`: deploy → create 2-of-3 → fund → propose → two composed approvals → `execute` → on-chain verification, ending at `DEMO COMPLETE`. An abort can no longer exit 0 — completion additionally requires the script to reach its own end and say so |
| **P-S6** | Narrated video showing terminal output incl. proof generation, confirming `RISC0_DEV_MODE=0` | ⛔ | Not recorded. **Human gate** — see `docs/limitations.md` |

---

## Cross-check against actual rejections

[`reviewer-gaps.md`](reviewer-gaps.md) reads all nine closed LP-0002 submissions and the three
accepted ones. Three causes account for nearly every rejection: **CI not running a real LEZ sequencer
(6×)**, **missing or dead testnet evidence (5×)**, and **missing CU cost (5×)**. Our two ⛔ rows on
CI and testnet are exactly those, and are the right place to spend remaining effort.

Causes that killed others and are already closed here: derivation-only binding (#91), dev-mode
clobber in a child script (#97), and no partial-approval resume (#91) — all three mutation-tested
rather than merely implemented.

## Summary

| | Count |
|---|---|
| ✅ evidence exists | **19** |
| ◐ partial | **1** |
| ⛔ not met | **1** |

These counts are checked against the rows above by `scripts/check-criteria-summary.py`, which CI
runs. They drifted badly once — the summary read 10/5/6 while the rows read 19/1/1 — and a
checklist that disagrees with itself is worse than none, because it is read as the submission's own
account of what it has done.

**What is outstanding:** P-U2, the Basecamp module — the package is built, committed and verified
structurally, but it has not been shown loading in Basecamp and carries only the `darwin-arm64`
variant. And P-S6, the narrated video, which is not recorded.


This file is regenerated by hand as phases land. Preflight check **PF-07** fails the submission if
any criterion id is missing from it.
