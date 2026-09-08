# Solution: LP-0002 — Private M-of-N Multisig for LEZ

**Status: the full lifecycle runs on the LEZ public testnet, and the Basecamp module reads it.**
What is outstanding is listed below rather than glossed — read "What is not done" before taking
anything here as a claim.

**Submitted by:** pramadanif
**Repository:** https://github.com/pramadanif/lp0002
**Commit:** _pinned at submission time; not yet fixed_

---

## Summary

A private M-of-N multisig for the Logos Execution Zone. Members hold shielded LEZ accounts and
approve proposals **anonymously**: the chain records that a threshold was reached and never which
members reached it.

The precise on-chain claim, stated so a reviewer can check it rather than take it on trust:

- An approval is a **privacy-preserving transaction**. LEZ's privacy-preserving circuit runs
  `env::verify` over the multisig program **and** a chained membership program. There is no public
  approve path — not one that is discouraged, one that does not exist.
- The proof is bound to a **live** shielded account, not merely to a derived key. LEZ's circuit
  proves the approver controls an account whose commitment is in the current commitment set; our
  membership guest re-derives that same account id from its own witnesses and refuses if it differs.
  Dropping that assertion is the derivation-only pattern rejected in prize PR #91, and a test fails
  if it is removed.
- The proposal account holds an **approval count and a set of nullifiers**. It has no roster, no
  bitmap, and no field that could hold one.
- The member set, the threshold **and the membership verifier's ImageID** are all committed in the
  PDA seed. Lowering M, substituting the member set, or naming a permissive verifier does not weaken
  the multisig — it names one that does not exist.

## Why `execute` carries no proof

Answering this up front, because a previous submission to this prize was closed partly for *"the
execute transaction contains no proof"*.

The proof is at **approve** time. Each approval is a privacy-preserving transaction whose validity
depends on LEZ's circuit verifying the multisig program **and** the chained membership program. By
the time `execute` runs, the threshold is already a fact on chain: a set of distinct, proof-backed
nullifiers.

`execute` reads that verified state and moves funds if `count >= M`. It takes no secret input and
asserts nothing that was not already proven, so there is nothing left for a proof to establish.

**Keeping it public is deliberate, and better for privacy.** Anyone may execute a proposal that has
reached its threshold — including a non-member. If execution required a member, the executor *would
be* a member, and that would link a member to the proposal. A permissionless execute is what makes
criterion **P-F4** — execution unlinkable to any individual member — achievable at all.

**Which raises the obvious question: if anyone may execute, what stops them redirecting the money?**
The approvals cover the *proposal*; every other part of the transaction is chosen by whoever submits
it. So `execute` pins both ends of the transfer — the funds leave the multisig's own config PDA, and
the recipient account must be the one the proposal named, or the call is refused (**INV-7**, error
`7012` on chain).

This was a real hole, not a hypothetical one. `execute` destructured the approved action as
`{ amount, .. }`, discarding the recipient, and took a caller-supplied treasury account that nothing
tied to the multisig — so a submitter could have redirected an approved payment to themselves while
every approval still verified. It was found by running the program through the risc0 executor rather
than by reading it, and neither script would have caught it: both proposed a transfer to one address
and then executed with `--treasury $CREATOR --recipient $CREATOR`, moving money from an account to
itself. `execute_refuses_a_recipient_the_proposal_did_not_name` is the regression test; with the
binding removed it fails, showing the multisig paying an account the proposal never named.

## Architecture

```
config_hash = SHA256( DS_CONFIG ‖ member_root[32] ‖ M[1] ‖ N[1] ‖ multisig_id[32] ‖ membership_program_id[32] )
```

That single line is the anchor. The config account lives at
`for_public_pda(program_id, PdaSeed(config_hash))`, so its address attests to its own configuration,
and the program re-hashes the stored fields and rejects a mismatch.

**Nullifier:** `nf = SHA256(DS_NF ‖ nsk ‖ multisig_id ‖ proposal_id)` — deterministic per
(member, multisig, proposal), preimage-hiding, and keyed to `nsk` rather than an account id so a
member cannot vote twice from another of their 2^128 addresses.

Full reasoning: [ADR-001](adr/ADR-001-architecture.md) and
[ADR-002](adr/ADR-002-bind-verifier-to-config-hash.md).

## Evidence

| Claim | Where |
|-------|-------|
| Full lifecycle on the public testnet, create → propose → approve ×2 → execute | [DEPLOYMENT.md](DEPLOYMENT.md) |
| The money moved: treasury 100 → 40, payee 0 → 60 | [evidence/testnet-lifecycle-verified.md](../evidence/testnet-lifecycle-verified.md) |
| Both approvals are `PrivacyPreserving` transactions, not public ones | `./scripts/verify-onchain.sh` — checks the variant byte of each published transaction |
| The payee holding the funds is the one *the proposal named* (INV-7) | `verify_onchain` reads the recipient out of the proposal account, never from an argument |
| Same lifecycle against a standalone sequencer, in CI, `RISC0_DEV_MODE=0` | [run 34052567273](https://github.com/pramadanif/lp0002/actions/runs/34052567273) — 3 h 41 m, green |
| Reproducible guest binaries | `./scripts/build-guests.sh --docker`; the membership ImageID reproduces byte-identically across days and rebuilds |
| Byte-compatibility with LEZ's own vectors | `crates/membership-core/tests/lez_compat.rs` |
| Derivation cross-checked against a real wallet account | `crates/sdk/examples/wallet_member.rs` |
| CU per instruction, measured on the deployed binaries | [cu-costs.md](cu-costs.md) |
| Criteria → evidence map | [criteria-checklist.md](criteria-checklist.md) |

**The prize demo is `./demo.sh`.** It drives a real standalone LEZ sequencer with
`RISC0_DEV_MODE=0`. `demo-fast.sh` is a development tour, generates no proof, and is **not** cited
as evidence anywhere.

## Downloads, and how to check them yourself

| | |
|-|-|
| Basecamp module | [`app/private_multisig.lgx`](../app/private_multisig.lgx) |
| Size | 2,631,462 bytes |
| sha256 | `4d6a68a60466ef52adc4d74584cf37e161cfc2cb97fed39788e282bc90edfa84` |
| Variant | `darwin-arm64` (built on the machine that produced it — [limitations](limitations.md)) |
| Install steps | [basecamp-load.md](basecamp-load.md) |

```bash
shasum -a 256 app/private_multisig.lgx     # must match the hash above
lgx verify app/private_multisig.lgx        # "Package structure is valid"
```

Verify the deployment from public data, needing no secrets and no local state:

```bash
./scripts/verify-onchain.sh                # reads docs/DEPLOYMENT.md
./scripts/check-explorer-links.sh          # every evidence URL must resolve
```

`verify-onchain.sh` checks the config account is owned by the program and rehashes to its own
address, that it names the deployed verifier, that the threshold was met at **full M** with distinct
nullifiers, that the proposal executed, that the payee named *by the proposal* holds the amount that
was approved (INV-7), that the treasury holds exactly the remainder, and that the approvals were
`PrivacyPreserving` transactions rather than public ones.

## Measurements

| | |
|---|---|
| Membership proof (standalone) | 115.97 s, 602,662 cycles |
| Composed approval (what a member actually pays) | ≈19 min 26 s, peak 8.74 GB |
| Free RAM required | ≈9 GB |
| Host | 8-core laptop, 16 GB, no GPU prover |

## What is not done

Listed first-class, because the difference between built and demonstrated is what this prize's gates
test:

- **The Basecamp module loads, and its panels read the chain — but no UI has been driven on
  camera yet.** `app/private_multisig.lgx` — 2,631,462 bytes, sha256 `4d6a68a6…90edfa84` — installs
  through Basecamp's own "Install Local Package", is listed as `ui_qml`, and opens from
  Applications → Blockchain.

  Four undocumented facts stood in the way, each of which fails silently:

  1. `lgx` 0.1.0 writes a package format Basecamp 0.2.3 cannot read — the install logs
     `installPlugin` and then nothing at all.
  2. The plugin must be built against the Qt the host ships (6.9.2, not the newest installed): Qt's
     version tag symbol makes a 6.11 build unloadable, and Basecamp does not log `dlopen` failures.
  3. The linker's absolute paths to the build machine have to be rewritten.
  4. A `ui_qml` module's QML runs in Basecamp's **main** process while its plugin runs in a
     `ui-host` child. The generated scaffold set `backend` as a context property on the engine it
     built itself — an engine Basecamp never renders — so every binding raised
     `ReferenceError: backend is not defined` behind a window that drew perfectly, and no button did
     anything.

  The plugin now publishes its API the way Basecamp's own modules do, and the QML resolves it
  through `logos.module()`. `./scripts/check-basecamp-contract.sh` asserts both halves of that
  contract and, with `PMSIG_CONTRACT_LIVE=1`, fetches the deployed config through the plugin's own
  slots — the path a press of ↻ takes — decoding the same 2-of-3 `verify-onchain.sh` reads. CI runs
  it. What is not yet shown is the window open and doing that on camera. The package also carries
  only the `darwin-arm64` variant. See [basecamp-load.md](basecamp-load.md).

- **No narrated video.** P-S6 unmet.

- **The public explorer has not indexed all of the evidence.** Every transaction answers over
  JSON-RPC and `verify-onchain.sh` reads them all; the explorer renders the two program deployments
  but not yet the five lifecycle transactions. `./scripts/check-explorer-links.sh` says which, and
  exits 75 rather than passing quietly.

Full list: [limitations.md](limitations.md).

## Why Logos

[why-logos.md](why-logos.md). Briefly: this scheme needs shielded accounts whose repeated use is
unlinkable, and execution that can depend on secrets the chain never sees. LEZ provides both in the
base layer; on a chain where validators must see the inputs, it is not possible at all.

## Honest notes

- SPEL is pinned to `main`, not the v0.6.0 release, because the release pins LEZ v0.2.0 and derives
  private account ids the live testnet does not recognise. An unreleased dependency is a real cost;
  it is taken deliberately and recorded.
- Things we got wrong and fixed are in [tried-failed.md](tried-failed.md), including a leak of the
  member's spending key into the guest journal that we shipped, then caught by decoding the journal
  rather than trusting a byte scan.
- Upstream papercuts found along the way: [BUGS_FILED.md](BUGS_FILED.md).
