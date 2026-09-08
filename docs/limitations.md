# Known limitations

Written to be useful to someone deciding whether to rely on this, which means it is specific rather
than reassuring. Everything here is a real constraint of the current build, not a hypothetical.

Plan gate **H12/W16** requires this file to exist and resolve at the pinned commit — one prior
submission to this prize linked a `limitations.md` that 404'd. It is also the file preflight check
PF-06 refuses to submit without.

---

## 1. Not audited, not production

No third-party security review. The cryptographic construction is standard in shape — Merkle
membership plus a domain-separated nullifier, composed under LEZ's privacy-preserving circuit — but
"standard in shape" is not "audited". Do not hold real value with this.

## 2. The member set is fixed at creation

`member_root` is inside `config_hash`, which seeds the multisig's PDA. Changing the member set
therefore changes the address: it does not modify a multisig, it names a different one. There is no
add-member or remove-member instruction, and adding one would require a design that lets the address
survive a membership change.

**Consequence:** a compromised member cannot be evicted. The remedy is to create a new multisig and
move the funds — which is a governance action the old multisig can itself approve.

## 3. Changing the verifier rotates every address

[ADR-002](adr/ADR-002-bind-verifier-to-config-hash.md) binds the membership program's id into
`config_hash`, so that an attacker cannot name a permissive verifier. The cost is that a new build of
the membership program has a new ImageID, and therefore changes the `config_hash` — and the
address — of every multisig.

Existing multisigs keep working against the verifier they were created with. New ones must be created
to adopt a new verifier. This was a deliberate trade: the alternative, storing the verifier id in the
account, is trust-on-first-use.

## 4. Anonymity is bounded by the member set

The scheme hides *which* member approved, within the member set. It cannot make that set larger. At
the default 2-of-3, an observer who knows the membership knows that two of three approved. That is
inherent to threshold visibility, not a defect — but it means the privacy claim is "unlinkable within
N", not "anonymous".

If the operator publishes the member list, the anonymity set is whatever remains.

## 5. No defence against timing or network correlation

Each approval is a transaction at a point in time. An adversary watching the chain learns how many
approvals landed and when; one watching the network learns which IP submitted them. With a small `N`
and members in known time zones, timing is a real correlation channel.

Nothing in this design addresses either. Use an anonymising transport if it matters.

## 6. Proposal content is public

By design and by scope: the prize hides member identity and vote, not the proposed action. Anyone can
read what a proposal would do.

## 7. Inner receipts are secret material

An approval is proved in two layers. Only the outer `PrivacyPreservingCircuitOutput` reaches the
chain, and it carries just nullifiers, commitments and ciphertext. The **inner** `ProgramOutput`
contains the approver's `account_id`, because every LEZ program commits its pre-states — that is how
the runtime validates execution, and it is not removable.

The SDK therefore never persists or transmits inner receipts, and the member's key material is kept
out of them entirely (a separate private input, not `instruction_data`). We shipped that bug once and
caught it by decoding a journal — see [tried-failed.md](tried-failed.md). **Treat an inner receipt
like a private key at rest**: anyone holding one learns which account approved.

## 8. An approval spends the member's shielded account

LEZ private accounts advance their nonce on every use, so approving consumes and recreates the
member's account state. A member therefore needs a live shielded account, and cannot produce two
approvals from the same account state. The SDK sequences this; it is a real constraint on a member
who wants to approve several proposals at once.

## 8b. A member's account must be claimed before it is ever synced

A shielded account is created wholly default, with `nonce: 0`. In that state any program may return
it, and `auth-transfer init` may claim it. `wallet account sync-private` gives it a random nonce,
and from that moment three of LEZ's execution rules close on it: the nonce may not change (3), the
program owner may not change (4), and a post-state with the default owner requires the pre-state to
have been wholly default (7). An account that is unowned *and* non-default satisfies none of them.

Such an account can no longer approve — the privacy circuit rejects the whole execution with
`NonDefaultAccountWithDefaultOwner` — and it can no longer be claimed either, because
`initialize_account` asserts the account is untouched. It is finished, permanently.

**So the order matters, and it is not recoverable:**

```bash
wallet account new private                            # nonce 0
wallet auth-transfer init --account-id Private/<id>   # claim it FIRST (~5 min: this is itself a
                                                      # privacy-preserving transaction)
wallet account sync-private                           # only then
```

Once claimed, the owner is not default and rule 7 can never apply to it again, whatever the nonce
becomes.

This does not arise on a standalone sequencer, because the demo wipes the chain before every run and
never syncs — an approver there keeps `nonce: 0` and stays claimable forever. It was found on the
public testnet, where two accounts were synced before being claimed and are now permanently unusable
as members. `docs/lez-admission-rules.md` carries the diagnosis.

## 9. Dependency pins that are not releases

- **SPEL** is pinned to `main` at commit `5126b7ed8a9b`, **not** the v0.6.0 release. The release pins
  LEZ v0.2.0, whose `AccountId::for_regular_private_account` omits the viewing key and therefore
  derives addresses the live testnet does not recognise. `main` pins v0.2.4. Depending on an
  unreleased commit is a real cost, taken deliberately; see [VERSIONS.md](VERSIONS.md).
- **LEZ** is pinned to `v0.2.4`, established by fingerprinting the testnet's deployed ImageIDs rather
  than by assumption.

## 10a. The composed approval proof is expensive, and needs free RAM

The **standalone** membership proof takes 115.97 s. The **composed** approval — LEZ's
privacy-preserving circuit running `env::verify` over two chained programs — takes **≈19 minutes**
and peaks at **8.74 GB** on an 8-core laptop with no GPU prover. It completes; it is simply a
different order of cost, because composition needs *succinct* receipts, i.e. a lift+join for every
segment of every inner program.

**The practical requirement is roughly 7 GB of free RAM**, and that is the part likely to bite an
evaluator. Our first attempt failed for exactly this reason and it was **not** a hardware limit:
Chrome (5.8 GB), Cursor (1.7 GB) and VS Code (1.4 GB) were already holding ~9 GB of the 16 GB, so
the prover was forced into swap and thrashed for hours without finishing. With Chrome and Cursor
closed, the same proof completed in 19 minutes and swap never moved.

So for **P-F5** ("proof generation runs client-side on a standard laptop"): it holds, on a 16 GB
laptop, *provided ~7 GB is actually free*. A machine that is otherwise loaded will appear to hang.
The README states this up front so nobody concludes the demo is broken.

Evidence: `artifacts/phase-E-ppe-approve-SUCCESS.txt`.

## 10. Measurement caveats

- **Proving time (115.97 s)** is a single sample, on one 8-core laptop with no GPU. It is not a
  distribution and not a benchmark suite.
- **A second proof in the same process** did not complete within 25 minutes on two occasions, while
  the first took 53 s. Undiagnosed. It does not affect the recorded figure, which is the first proof
  of a fresh process — what a member actually experiences — but it is unexplained and is recorded
  rather than smoothed over.

## 10a-bis. The memory requirement is now checked, not just stated

Both scripts that generate a composed approval refuse to start one when less than ~7 GB is free
(`PMSIG_MIN_FREE_GB` overrides; `0` disables). They used to print "expect ~9 GB of free RAM" and
proceed regardless, which is how the first attempt at this ran for hours: below that threshold the
prover does not fail, it swaps, and hours of thrashing are indistinguishable from slow proving.

The check is a resource precondition, not a correctness one — nothing about the proof changes if you
clear it — so it is overridable, and says so in the message.

## 10b. A spending key on the command line

`pmsig approve --member <hex>` puts a member's nullifier secret key in the process's argument list,
where `ps` shows it to every other process on the machine, and where the shell records it in
history. The machine running the client is not a private place, and for a tool about not revealing
which member acted that is worth stating rather than assuming.

This section used to add "the key never reaches the chain, the store or a log". **The last of those
was false.** The SPEL CLI echoes the arguments it is given, and dumps the serialised instruction
data — and both approve scripts redirected that into a run log, so `nsk` sat in plaintext in
`.e2e/run/approve*.log` and `.e2e/testnet/approve*.log`. Those directories are ignored by git, but
[video-transcript.md](video-transcript.md) asks for a run log to be published beside the recording,
which put one `git add -f` between a helpful habit and a spending key in the submission repository.
The heartbeat line that goes on screen during a recording also tailed that same log.

Fixed in three places rather than one: both scripts redact the witness from the log as soon as the
approval finishes and before anything reads it back, the heartbeat refuses to echo a line
containing one, and preflight check **PF-16** fails the submission if any *tracked* file carries an
approval witness — mutation-tested by planting one and watching it fail. The key still reaches the
argument list, which is what this section is about.

`--member-file` reads the key from a file instead and is the better default; `--member` still works
and warns. Neither is a substitute for a real key store, which this client does not have: it is a
local demo tool, marked `[local]` on every command, not a wallet.

## 11. Build reproducibility

`artifacts/IMAGE_IDS.md` currently records a **local** build and says so in the file. A deployed or
quoted binary must come from `./scripts/build-guests.sh --docker`, which builds inside the pinned
container LEZ itself uses. Until that has been run, the recorded ImageID is a development value.

## 12. The CLI does not yet reach a sequencer

`pmsig` runs against a local state file and prints `[local]` on every such command. It applies the
real transition rules, but it is not a chain and no CLI output is testnet evidence.

Its `create` also takes every member's secret key, so that one machine can act as several members in
a demo. A real deployment never does this: each member derives their own npk, shares only that, and
keeps their own authentication path. The on-chain state has no member list at all.

## 13. What is not yet demonstrated

Stated plainly, because the difference between "designed" and "demonstrated" is the whole point of
this prize's evidence gates. Everything struck through here was undemonstrated when it was written
and is not any more; the entries are kept rather than deleted so the record shows what changed.

- ~~A completed privacy-preserving approval.~~ **Demonstrated.** Real anonymous approvals proved
  with `RISC0_DEV_MODE=0`, with no member identity on chain — only a count and nullifiers.
- ~~`execute` at full M.~~ **Demonstrated at the full 2-of-3**, not a lowered threshold:
  `verify-onchain.sh` checks that specifically (H13/W15) and re-read it from public data on
  2026-09-09.
- ~~The multisig on the public testnet.~~ **Deployed and live.** Both programs, a 2-of-3 config, a
  proposal, two anonymous approvals and an executed transfer — treasury 100 → 40, payee 0 → 60.
  Every transaction is linked in [DEPLOYMENT.md](DEPLOYMENT.md).
- ~~The Basecamp module doing anything.~~ **It reads the chain**, through the same plugin slots the
  UI calls — see [basecamp-load.md](basecamp-load.md).

What is genuinely still open:

- **The narrated video.** Not recorded. It needs a human voice — an AI narration is one of the
  stated reasons the previous submission for this prize was rejected.
- **The public explorer's index.** All eleven evidence URLs answer over JSON-RPC, and the explorer
  renders six of them; the five lifecycle transactions are on chain but not yet indexed.
  `./scripts/check-explorer-links.sh` reports which, and exits 75 rather than passing quietly.
- **One platform variant.** The Basecamp package carries `darwin-arm64` only — the machine it was
  built on. Nothing in the module is macOS-specific; no second machine was available to build and
  test the others, and shipping an untested variant is worse than shipping none.
- **Writes from the Basecamp UI against a public chain.** The module's instruction panels are wired
  and report failure rather than doing nothing silently, but the lifecycle evidence was produced by
  the CLI; the UI has been shown reading that state, not creating it.
