# Tried and failed

A running, honest log of approaches attempted and abandoned, and of things that surprised us. Kept
because the reasoning behind a rejected path is worth as much to a reviewer as the path taken — and
because a repo where nothing ever went wrong is not a believable repo.

Entries are appended as work happens. Design-time rejections that were never coded live in
ADR-001 §7; this file is for things actually attempted or discovered by measurement.

---

## Phase −1

### Pinning LEZ by "latest tag" would have been wrong — and quietly so

**Tried.** The obvious pin is the newest tag, or else the one a competitor used (#123 pinned v0.2.2).
The SPEL framework's released version, v0.6.0, pins LEZ **v0.2.0**, so "use released SPEL" looked like
the safe, conservative choice.

**Failed, because.** Address derivation is not stable across those versions. At v0.2.0,
`AccountId::for_regular_private_account` hashes `prefix ‖ npk ‖ identifier` (80 bytes). At v0.2.4 it
hashes `prefix ‖ npk ‖ vpk ‖ identifier`, where `ViewingPublicKey::LEN = 1184`. Building against
v0.2.0 derives shielded account addresses **the live testnet does not recognise** — and the failure
would surface late, as unexplained rejections during testnet deployment in Phase G.

**What we did instead.** Fingerprinted the deployed version rather than guessing. A LEZ `ProgramId`
is the risc0 ImageID of the program ELF, and LEZ commits prebuilt binaries under `artifacts/` at every
tag. Computing those ImageIDs and comparing with the live `getProgramIds`:

| Program | Live testnet | v0.2.0 | v0.2.4 |
|---------|--------------|--------|--------|
| `token` | `ccc4713e…` | `c5d50f88…` ✗ | `ccc4713e…` ✓ exact |
| `privacy_preserving_circuit` | `383e884f…` | `ab86d257…` ✗ | `383e884f…` ✓ exact |

So: pin LEZ **v0.2.4**, and pin SPEL to **`main`** (which tracks v0.2.4) rather than its released
v0.6.0. Depending on an unreleased SPEL commit is a real cost, and it is disclosed in
`docs/limitations.md` rather than hidden.

Evidence: `artifacts/phase-N1-testnet-version-fingerprint.txt`.

### `getBlockHeight` is not a LEZ RPC method

**Tried.** Probing the testnet with `getBlockHeight`, by analogy with other chains.

**Failed.** `{"error":{"code":-32601,"message":"Method not found"}}`. Reading
`sequencer/service/rpc/src/lib.rs` gives the actual set: `sendTransaction`, `checkHealth`, `getBlock`,
`getBlockRange`, `getLastBlockId`, `getAccountBalance`, `getTransaction`, `getAccountsNonces`,
`getProofForCommitment`, `getAccount`, `getProgramIds`. The height method is `getLastBlockId`.

Minor, but it is the whole reason this repo reads LEZ's source for every interface instead of
assuming shapes from other ecosystems.

## Phase 0

### `mapfile` is not available to macOS evaluators

**Tried.** `mapfile -t targets < <(…)` in `scripts/check-dev-mode-clobber.sh`.

**Failed.** macOS ships bash **3.2.57** as `/bin/bash`, and `mapfile` arrived in bash 4. The script
died with `mapfile: command not found` — and, worse, `set -u` then made it exit non-zero for the
*wrong reason*, which would have looked like a real H3 violation.

**What we did instead.** A `while IFS= read -r` loop. Every script in this repo is written for bash
3.2, because the prize says evaluators clone the repo and run the demo from a clean environment, and
some of those environments are Macs.

## Phase A

### The membership guest cannot take `nsk` on trust

**Nearly shipped.** The first sketch had the membership guest verify `npk ∈ member_root` and compute
the approval nullifier from the witness `nsk` — and stop there. Membership proven, nullifier bound to
a secret; it reads as complete.

**Why that is not enough.** Nothing tied the witness to the transaction. The guest would prove only
*"someone knows an `nsk` whose `npk` is in the member set"* — a statement about key material, not
about chain state. It is true of a member who never created a shielded account, true of one whose
account has been fully spent, and it remains true forever once the key exists. That is exactly the
derivation-only property reviewers rejected in prize PR #91, and gate H8 exists to catch it.

**Fix.** The guest re-derives `AccountId::for_regular_private_account(npk, vpk, identifier)` from its
own witnesses and asserts it equals the approver's `pre_state.account_id` — the account LEZ's PPE
circuit independently proved is live, unspent and being spent in *this* transaction (ADR-001 D4).

### A wrong reason for the right fix — corrected

**Claimed, in the first draft of ADR-001 D4 and of this file:** that without the account-binding
assertion a member could double-vote, by handing their real `nsk` to LEZ's PPE circuit and a
*different* `nsk` to the membership guest, minting a fresh nullifier on each attempt.

**That reasoning is wrong**, and it is recorded here rather than quietly deleted. The substituted
`nsk` would have to derive an `npk` that is itself a leaf under `member_root` — i.e. the attacker
would need a *second* key that is already a member. A member holds one. So the substitution fails at
the membership check, before the nullifier is ever computed.

**What is actually true.** Double-voting is prevented by INV-4 alone: `nf_approve` is a deterministic
function of `(nsk, multisig_id, proposal_id)`, and a member has only one `nsk`. The account-binding
assertion buys something different and still necessary — **liveness**. Without it, an approval's
on-chain footprint could be an account with no relationship to the member: the transaction spends some
account, the witness names a member key, and nothing connects them.

The fix did not change; the justification did. `SC-B.5` now tests the property that is actually at
stake — a witness that does not control the presented account is accepted by a derivation-only variant
and rejected by the real one.

## Phase B

### The guest journal was leaking the member's spending key

**Shipped, briefly.** The first working membership guest took the whole witness — `nsk`, `vpk`,
`identifier`, Merkle path — as its instruction argument, the obvious shape for a program that has to
verify all of it.

**Why that is bad.** A LEZ program echoes its `instruction_data` into the `ProgramOutput` it writes,
and `ProgramOutput::write()` **commits to the guest's journal**. So the journal contained the
member's `nsk` verbatim.

On-chain privacy would have survived: the inner `ProgramOutput` never reaches the chain, because
LEZ's privacy-preserving circuit consumes it via `env::verify` and commits only
`PrivacyPreservingCircuitOutput`. But the inner receipt would have been a **spending key sitting in a
file** — a worse failure than the identity leak the prize is about, and one that any SDK caching or
debug dump would have turned into key loss.

**How it was nearly missed.** The first version of the SC-B.4 test scanned the journal for the raw
32 bytes of `nsk` and reported it clean. That scan is a **false negative**: risc0's serde writes each
`u8` as its own 32-bit word, so a 32-byte secret occupies 128 journal bytes and never appears as a
contiguous run. Decoding the journal properly showed the witness could be read straight back out:

```
raw_nsk=false            <- what the naive scan saw
word_nsk=true            <- the same secret, word-encoded
witness_recoverable_from_journal=true
```

**Fix.** The instruction was split. `ApprovalClaim` — `multisig_id`, `proposal_id`, `member_root`,
`claimed_nullifier`, all already public on chain — stays in `instruction_data`. `ApprovalWitness`
moved to a **separate private input**, read with `env::read()` after the standard LEZ inputs and
never echoed into `ProgramOutput`. The chained-call check that the caller's `instruction_data`
matches the callee's still holds, because both sides carry the claim.

`the_journal_carries_no_member_secret` now decodes the journal instead of scanning it, and asserts
the recovered instruction is exactly the public claim.

**What remains in the journal, by necessity:** the approver's `account_id`, in `pre_states`. Every
LEZ program commits its pre/post states — that is how the runtime validates execution — so this is
not removable and is not specific to this design. It is why `docs/security.md` records that **inner
receipts are prover-local secret material** that the SDK never persists or transmits.

### A second proof in the same process does not finish in reasonable time

**Observed, not explained.** `scripts/prove-bench.sh` runs two proving tests sequentially with
`--test-threads=1`. The first completes reliably — 123.9 s before the witness split, 53.3 s after.
The **second** proof in the same process ran for over 25 minutes on two separate occasions without
completing, at ~740% CPU in `r0vm` throughout, for a guest of only 598 k cycles.

**What is known:** the guest is small; the first proof of an identical workload takes under a minute;
`ProverOpts::default()` is `ReceiptKind::Composite`, so this is not recursion. Version skew was ruled
out — r0vm was aligned to 3.0.6 and the behaviour persisted.

**Not diagnosed.** Plausible candidates are r0vm session/process reuse across successive
`prove_with_opts` calls, or host memory pressure on an 8-core laptop. Recorded here rather than
guessed at, and it will be filed upstream if it reproduces on a clean machine
(`docs/BUGS_FILED.md`).

**Why it does not block Phase B.** The property the second test asserts — that the journal carries no
member secret — does not depend on proving. A journal is determined by what the guest commits, and is
byte-identical whether the session is executed or proved. `the_journal_carries_no_member_secret`
asserts it by execution, decoding the journal, and runs in CI in under a second. The proved variant is
kept, `#[ignore]`d, as a belt-and-braces check for when the slowdown is understood.

## Phase E

### A guest cannot take a private input on LEZ — the Phase B "fix" was unimplementable

**Shipped in Phase B, and wrong.** Phase B found the member's `nsk` in the membership guest's
journal, because the witness was in `instruction_data` and LEZ echoes that into the committed
`ProgramOutput`. The fix was to move the witness to a *separate private input*, read with
`env::read()` after the standard LEZ inputs. Tests passed. The journal was clean.

**It fails on a real chain.** The first genuine transaction to reach the guest died with:

```
panicked at risc0-zkvm/src/guest/env/read.rs:78:
  called `Result::unwrap()` on an `Err` value: DeserializeUnexpectedEnd
❌ Failed to submit privacy-preserving transaction:
   ProgramProveFailed("Guest panicked: ... DeserializeUnexpectedEnd")
```

The cause is not the tooling. `lee/state_machine/src/program/mod.rs::write_inputs` writes **exactly
four** values to every program — `program_id`, `caller_program_id`, `pre_states`,
`instruction_data` — and there is no fifth and no extension point. Nothing in LEZ will ever write a
private input, so a guest that reads one can never run.

**Why the tests did not catch it.** They drove the guest through a harness we control
(`ExecutorEnv` built by our own SDK), which happily wrote a fifth input. The harness was more
permissive than the runtime. A test that only ever exercises your own harness proves your harness
works.

**The correction.** The witness travels in `instruction_data`, as it originally did, and the honest
consequence is stated rather than engineered away: **the inner guest journal contains the member's
`nsk`**. That is safe only because the inner journal never reaches the chain — LEZ's
privacy-preserving circuit consumes it via `env::verify` and commits only
`PrivacyPreservingCircuitOutput` (nullifiers, commitments, ciphertext). An inner receipt is
prover-local secret material and must be treated like a private key at rest
(`docs/security.md` §3b, `docs/limitations.md` §7).

**SC-B.4 was therefore unachievable as literally worded** ("journal has no npk / member id
plaintext") for a guest's own journal on LEZ. The test now asserts what is true and load-bearing —
the witness *is* in the inner journal, and the chain-facing output is what carries no identity —
rather than asserting a property the platform cannot provide.

## Piping a Rust program's stdout into `awk ... exit`

**Symptom.** `e2e-local-sequencer.sh` died with exit 101 immediately after reporting
`wallet has 2 shielded accounts`, with no message — 44 minutes into a CI run.

**Cause.** The line was

```bash
CREATOR=$("$WALLET" account list 2>/dev/null | awk '/Public\//{print $2; exit}')
```

`awk` exits at the first match and closes the pipe. Rust ignores `SIGPIPE`, so instead of dying
quietly the wallet panics on its next write to stdout — hence 101, not 141 — and `set -o pipefail`
turns that into a failed pipeline. The command had in fact done its job. `2>/dev/null` then threw
away the panic message, which is why the failure said nothing at all.

**Fix.** Capture the output whole, then parse it:

```bash
wallet_accounts=$("$WALLET" account list 2>&1) || die "...: $wallet_accounts"
CREATOR=$(printf '%s\n' "$wallet_accounts" | awk '/Public\//{print $2; exit}')
```

`awk` closing a pipe from a shell builtin is harmless.

**Why it is written down.** This is the *second and third* time this pattern was fixed here. The
first fix was never recorded, so it came back — twice. The third instance was the worst of them:

```bash
tx=$("$SPEL" ... 2>&1 | tee "$OUT/approve$i.log" | awk '/tx_hash/{print $2; exit}')
```

That is the **approval step of `deploy-testnet.sh`**, the path that produces the submission's
on-chain evidence, and it is worse than the others in two ways. It is nondeterministic — whether
`awk` closes the pipe before the prover's last write depends on how much output follows the
`tx_hash` line — and the failure it produces is a *successful twenty-minute approval reported as a
failure*.

**The rule.** Never pipe a Rust process into a reader that can stop early — `awk ... exit`,
`head -n`, `grep -q`, `grep -m1`. Write to a file and parse the file. And do not send stderr to
`/dev/null` on any path whose failures have to be diagnosable.

## A member's spending key, sitting in a log file

Found on 2026-09-09 while deciding which run log to publish beside the demo video.

The SPEL CLI prints every argument it was handed, and then the serialised instruction data. For
`approve`, one of those arguments is the `ApprovalWitness`, whose first field is `nsk` — the
member's nullifier secret key. Both approve scripts redirect that output to a per-run log, so the
key sat in plaintext in `.e2e/run/approve*.log` and `.e2e/testnet/approve*.log`:

```
  witness = 0x<64 hex characters, the first 32 bytes of which are the member's nsk>…
```

The real line is not reproduced here, and that is not squeamishness: writing this entry is how
**PF-16 caught its author**. The first draft quoted the actual value from the run, the check failed
the submission, and the key came back out. A rule that only catches other people is not a rule.

Two things made it worse than a stray file. `docs/video-transcript.md` asks for the unedited run
log to be published next to the recording, so the path from "good evidence practice" to "a spending
key committed to the submission repository" was one `git add -f` long. And the progress line the
demo prints every minute is a `tail -n 1` of that same log — on screen, in a recording, truncated
to eighty characters, which is longer than the key.

This project already runs a CI check asserting the Basecamp UI cannot persist the witness. The leak
arrived from the other side, in our own scripts, and `limitations.md` §10b positively asserted the
opposite: *"the key never reaches the chain, the store or a log"*.

Fixed in three places, because one would have been the same mistake again: the scripts redact the
witness from the log the moment the approval finishes and before anything tails it; the heartbeat
refuses to echo a line containing one; and preflight **PF-16** fails the submission if any tracked
file carries a witness. The existing logs on disk were redacted too. The check was mutation-tested
by planting a real key in a tracked file and confirming it failed.

**The rest of the sweep, so the scope is checked rather than assumed.** The CLI's `LocalState`
persists `member_npks` — public keys — and never an `nsk`; the key is read per command from
`--member-file` and stays in memory. Nothing in the SDK, the CLI or the store prints or writes a
witness. The deliberate `witness` files the scripts pass with `--witness-file` live under `.e2e/`,
which `.gitignore` covers, and none exists anywhere else in the tree. The committed artifact
`artifacts/phase-E-ppe-approve-SUCCESS.txt` describes the witness's layout — "1312 byte Borsh —
nsk, vpk, identifier, Merkle path" — without containing it.

**And the fix had a bug of its own, found ten minutes later.** The first redaction used
`sed -i ''`, which is the macOS spelling. GNU sed wants the suffix attached, so `-i ''` makes it
open a file named `""`, fail, and — because the helper then checks its own work — abort the run.
The e2e job runs on Linux. That would have failed CI at the first approval, about two hours in,
with an error about a missing file rather than about sed. Rewritten to a temp file and a `mv`,
which behaves the same on both, and a failure now aborts loudly instead of being shrugged off.

**What it cost to find:** nothing but reading a file before publishing it. **What it would have cost
not to:** the one secret this entire prize is about, in public, in the repository submitted to win it.

## Verifying a Basecamp module against a stub I wrote myself

2026-09-09. For most of a night this repository claimed the Basecamp module "reads the chain". It
does not — not inside Basecamp.

`check-basecamp-contract.sh` loads the real plugin, loads the real `Main.qml`, and gives the QML a
`logos` object with one method: `module(name)`, returning the plugin. Every assertion passed, live
against the testnet. The trouble is that the stub was written from a reading of Basecamp's own
`package_manager_ui`, and it modelled a host that hands the QML the object directly. The real host
does not:

```
LogosQmlBridge: no replica factory plugin registered for "private_multisig"
```

Basecamp loads a **second** plugin — beside the first, named for the module, IID
`logos.view.replica_factory/1.0` — and asks *it* to construct the replica. `package_manager_ui` ships
one; we did not. Without it `logos.module()` returns null, and the module's own footer said so in red
the whole time: **backend unavailable**. The evidence was on screen in the first screenshot and I
read past it, because my own check was green.

**The lesson is about the shape of the test, not the bug.** A stub written by the same person who
wrote the code, from the same reading of the same reference, tests that reading — not the world. It
passed for the same reason the module failed.

### And the first fix crashed the application

The interface is undocumented and Basecamp ships no headers, so it was reconstructed from the
reference plugin's vtable: the secondary sub-vtable begins directly with `acquire`, so there is no
virtual destructor, and `replicaMetaObject()` comes second. That much was read out of the binary
rather than guessed. The plugin built, loaded, and returned a replica in a test harness.

In Basecamp it crashed the application on startup — three times, in Basecamp's own QML url
interceptor, compiling a regex through PCRE2's JIT, with no frame of ours in the backtrace. Three
explanations were formed and all three were **tested and disproved**:

| Theory | Test | Result |
|--------|------|--------|
| An `LC_RPATH` to this machine's Qt pulled a second QtCore into the process | Load it under a host running Basecamp's own Qt and count mapped QtCore images | One before, one after — dyld reuses the already-loaded framework |
| Two Qt copies regardless of rpath | Same measurement with the rpath stripped | Identical |
| Ad-hoc signature costs the process its JIT entitlement | Sign a test host `-o runtime` with `com.apple.security.cs.allow-jit`, load the dylib, force a PCRE2 JIT compile | Compiles and matches happily |

Two more theories followed, and both were disproved the same way: that any third-party dylib would
crash it, and that the `callModule` route was at fault. Five stated theories, five refutations.

**Both real causes were found, and neither was any of the five.**

The first is the host's. Basecamp runs under a hardened runtime whose entitlements do not include
`com.apple.security.cs.allow-jit`, so PCRE2's JIT traps the moment Qt decides a pattern has been
used often enough to compile — reproduced and written up in [BUGS_FILED.md](BUGS_FILED.md) §8. The
workaround is `launchctl setenv QT_ENABLE_REGEXP_JIT 0` before starting Basecamp, and it has to be
`launchctl` rather than a shell `export`, because the app is launched from the Dock and never sees
a terminal's environment. Checking that took its own mistake: an early check read the variable in
the shell that set it, not in the process that mattered.

The second was mine. The reconstructed factory interface had no virtual destructor, so every entry
in the vtable was off by two slots and the host called `acquire` at the address of a destructor. The
reason it took so long to see is worth recording: **my own load test kept a private copy of the
interface declaration**, so the test and the plugin were wrong in exactly the same way and agreed
with each other perfectly. Once both were made to include one shared header —
`app/src/LogosViewReplicaFactory.h` — the test reproduced the crash immediately. A test that carries
its own copy of the thing under test is not a test.

The factory now ships: `variants/darwin-arm64/private_multisig_replica_factory.dylib` inside
`app/private_multisig.lgx`, and the module opens and reads chain state in Basecamp.

What is worth keeping from the five dead ends is the discipline, not the theories: each was stated,
given a measurement that could refute it, and dropped when it was refuted — rather than shipped as a
plausible story. What is worth keeping from the two real causes is that neither was reachable by
reasoning. One needed the host's entitlements read, the other needed a test that did not share the
defect it was looking for.

## An approval that never confirmed on the public testnet

2026-09-07. A full lifecycle run against the public testnet got as far as the first approval and
stopped: the wallet gave up waiting after 30 blocks. That does not mean rejected — the proof was
already at the sequencer and could land later — so the run was recorded before rerunning anything,
because rerunning the script would have been wrong twice over: the deterministic parameters would
collide with accounts just created, and a fresh namespace would abandon a treasury already funded
with 100 while the payer had only 100 left.

Four causes were ruled out without spending another twenty-minute proof:

| Suspected | Ruled out by |
|-----------|--------------|
| Circuit version mismatch | Testnet fingerprint matched v0.2.4, checked the same day |
| PDA collision | Both PDAs were empty before the run |
| Transaction too large | The local sequencer uses the same 1 MiB `max_block_size` and accepted this shape without delay |
| A malformed transaction | CI passed the full cycle with the same reproducible binaries against a standalone sequencer |

What remained was contention for block space on a public testnet, where LEZ defers a transaction
that does not fit to the next block, repeatedly — and the actual rejection reason, if there was one,
only exists in a node log that is not ours.

The deployments from that day survived and are still the two the submission cites
(`fe3a65ee…`, `ef9029b2…`). The lifecycle was redone on 2026-09-08 after a testnet reset, and those
later transactions are the ones in [DEPLOYMENT.md](DEPLOYMENT.md). The in-flight note itself is in
`docs/_archive/` rather than `evidence/`, because its half-finished hashes would otherwise sit
beside the real ones with nothing saying which is which.
