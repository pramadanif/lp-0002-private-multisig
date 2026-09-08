# What LEZ checks before a transaction reaches a block

`execute` was submitted and never confirmed four times — twice on the public testnet, once in CI,
once locally — while the program's own tests passed. This document is the result of reading the
layer that was actually rejecting it, and it maps every rule to how this program satisfies it.

## The layer nobody was testing

There are two distinct layers, and only one of them was covered:

| | |
|---|---|
| `validate_execution` (`lee/state_machine/core/src/program/mod.rs`) | eight rules about a program's own input/output. `crates/sdk/tests/multisig_program.rs` exercised this and passed throughout |
| `ValidatedStateDiff::from_public_transaction` (`lee/state_machine/src/validated_state_diff/mod.rs`) | admission. Eighteen rules, and it *calls* `validate_execution` as one step. **Every rejection came from here** |

That is why the executor tests were green while the chain refused the transaction: they tested the
inner layer. It is also why the public testnet was useless for diagnosis — it reports only
`Transaction not found in preconfigured amount of blocks`. The actual reason exists only in a
sequencer's log, which is available when you run one locally.

## Every rule, and how `execute` satisfies it

`execute` submits four accounts: `config` (PDA), `proposal` (PDA), `recipient`, `submitter` (signer).

| Rule | How this transaction satisfies it |
|------|-----------------------------------|
| Public transaction must have at least one account | four |
| No duplicate `account_ids` | the payee is a separate account from the submitter. **Violated once**: setting the payee to `$CREATOR`, which is also the submitter |
| Nonce count matches signature count | one signer, one nonce; the CLI fetches nonces and exits non-zero if it cannot |
| Valid signature | the submitter signs. **Violated once**: before `execute` took a signer at all, the witness set was empty. `approve` gets away without one only because it is privacy-preserving — the proof stands in for the signature |
| Unknown program | both programs are deployed before this runs |
| `InconsistentAccountPreState` | the state machine builds the pre-states from chain state itself; the program echoes them unchanged |
| `InvalidAccountAuthorization` / `AuthorizedAccountMarkedAsNotAuthorized` | checked **in both directions**, and satisfied by construction: the state machine sets `is_authorized = signer_account_ids.contains(id)` when it builds the pre-states, and the program passes them through. For a top-level call `authorized_pdas` is empty — LEZ's own test `compute_public_authorized_pdas_no_caller_returns_empty` pins that — so the two PDAs must not carry the flag, and do not |
| `MismatchedProgramId` / `MismatchedCallerProgramId` | emitted by the SPEL dispatcher from the call it was actually given |
| `ExecutionValidationFailed` | the inner eight rules. **Violated once**: the treasury held nothing, so `checked_sub` failed |
| `DefaultAccountModifiedWithoutClaim` | the payee is an existing account owned by auth-transfer. **Violated once**: paying `0xc3c3…c3`, an address nobody had ever used. Claiming it is not an option — a multisig must not take ownership of the account it pays |
| `ClaimedNonDefaultAccount`, `ClaimedUnauthorizedAccount`, `MismatchedPdaClaim` | `execute` requests no claims |
| `DeclaredAccountMissingFromOutput` | all four accounts are returned |
| `MaxChainedCallsDepthExceeded` | `execute` makes no chained call; only `approve` does |

## Why the payee cannot be anything simpler

Three rules together leave exactly one shape. The payee must **already exist** (a never-used account
cannot be credited), must be **owned by a program** (`validate_execution` rule 7 refuses a default
owner with non-default state), and must be **distinct from the submitter** (ids in a message are
unique). Hence: a second public account, created and initialised under auth-transfer.

## What this cost, and what it should have cost

Four rejections, each found by running the full demo — two proofs and a sequencer build, roughly
fifty minutes — to learn one rule. Reading this module takes minutes.

`every_instruction_satisfies_lez_admission_rules` in `crates/sdk/tests/multisig_program.rs` now
transcribes the rules that can be checked without the `lee` crate, which lives in an uncommitted
local checkout and so cannot be a dependency. It catches two of the four in 0.1 seconds; it is
mutation-tested against both.

## The rule that only exists on a public chain

Everything above is checked by the sequencer against the transaction. This one is not a rule about
the transaction at all — it is about the wallet that built it.

A privacy-preserving transaction is proved against the **current root of the shielded pool**. The
wallet holds `last_synced_block` in its `storage.json`, and `wallet account sync-private` is what
advances it. Nothing calls that command for you.

On a standalone sequencer this can never be wrong: `scripts/e2e-local-sequencer.sh` wipes the chain
before every run, so an unsynced wallet at block 0 is looking at the head. On a public testnet with
41,833 blocks behind it, a wallet at block 0 proves against a root the chain abandoned long ago.

**What that looks like from outside**, which is why it took a run to find:

- every *public* transaction succeeds — deploying programs, `create_multisig`, funding the treasury,
  creating and initialising the payee. None of them touch shielded state.
- the *one* privacy-preserving transaction is accepted by the RPC and given a `tx_hash`. Nothing
  reports an error.
- it is never included in a block. Thirty blocks later the wallet says **"Transaction not found in
  preconfigured amount of blocks"**, which reads like a network fault.
- twenty minutes of real proving is gone, and the failure names nothing that is actually wrong.

The shape of it is the diagnosis: *all public steps pass and only the private one fails.* Nothing
else on this list produces that pattern.

Ruled out along the way, none of them the cause: the testnet's `privacy_preserving_circuit`
ProgramId (identical to v0.2.4, checked the same day), an address collision (both PDAs were empty
before the run), the 1 MiB block limit (the transaction is ~364 KB over JSON-RPC, and the local
sequencer enforces the same limit and had accepted the same shape without one deferral), unfunded
shielded accounts (the successful local wallet's are 0 too), and a malformed transaction (CI runs
the whole lifecycle on the same reproducible binaries).

`scripts/deploy-testnet.sh` now syncs before the approvals and checks the sync worked — calling
`sync-private` is not the same as having synced, and a wallet still far behind fails identically
twenty minutes later. An unreadable chain head fails too, rather than passing as zero: the first
version of that gate would have waved through exactly the state it exists to catch.

## The nonce that locks an account out of every program

Rules 3, 4 and 7 close on each other, and a shielded account walks into the gap on its own.

- **3.** the nonce may not change
- **4.** `program_owner` may not change
- **7.** a post-state with the default `program_owner` requires the pre-state to have been *wholly*
  default

A shielded account is created with `nonce: 0` — wholly default, so rule 7 is satisfied and any
program may echo it back. `wallet account sync-private` then gives it a random nonce. From that
moment the account is no longer default, its owner is still nobody, and neither can be changed. **No
program can return it at all**, and `auth-transfer init` refuses it too:

```
Guest panicked: Account must be uninitialized
```

That is `initialize_account` in LEZ's own `authenticated_transfer`, which asserts
`account == Account::default()` before claiming. An account is claimable only while it is untouched.

### Why this never appeared locally

`scripts/e2e-local-sequencer.sh` wipes the chain before every run and never syncs — nothing needs
it, because block 0 *is* the head. The approvers therefore keep `nonce: 0` forever, stay wholly
default, and rule 7 cannot fire. Every local run and every CI run has been passing under that
condition. It is not a weaker version of the public testnet; it is a different case.

### The two faces of the same trap

Both testnet attempts failed, differently, for this one reason:

| wallet | nonce | rule 7 | shielded root | outcome |
|--------|-------|--------|---------------|---------|
| unsynced | 0 | passes | stale by 41,833 blocks | accepted by the RPC, never included; "Transaction not found in preconfigured amount of blocks" after 30 blocks |
| synced | random | **fails** | current | `NonDefaultAccountWithDefaultOwner`, four minutes into proving |

Syncing was the right fix for the first failure and it exposed the second. Neither error names the
nonce.

### What actually works

Claim the account **before it is ever synced**, while it is still wholly default:

```bash
wallet account new private                       # nonce 0
wallet auth-transfer init --account-id Private/<id>   # ~5 min: claiming a shielded account is
                                                      # itself a privacy-preserving transaction
```

After that its `program_owner` is not default, so rule 7 can never fire for it again, whatever the
nonce becomes. Confirmed on the testnet: `F3eR1g8x…` went from `owner_default=true` to
`owner_default=false`, block 42984, while the two accounts that had already been synced stayed
locked out — bearing a nonce, owned by nobody, refused by `init`.

**So the order is load-bearing: create, claim, then sync.** Sync first and the account is finished.
