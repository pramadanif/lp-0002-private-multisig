# Demo video — shot list and narration

**Status: NOT RECORDED.** This is the script, written so the session is reading and running rather
than improvising. Replace the "Say" lines with the real transcript once the video exists, and put the
URL in `solutions/LP-0002.md` — not only in the PR description.

**Three things closed a rival submission for this exact prize on 2026-09-07, in the reviewer's own
words. They are requirements, not preferences:**

1. *"demo video doesn't cover Basecamp app but only CLI"* — the Basecamp module must be on camera,
   doing something.
2. *"demo video is narrated using AI which is not fair comparing to other submitters"* — **narrate it
   yourself.** No text-to-speech, no synthetic voice, no cloned voice. This one is disqualifying and
   cannot be fixed in the edit.
3. *"main point of submission is the solution file … transaction hashes are trimmed and do not have
   links, video link is missing"* — full hashes, real links, and the video URL, in the solution file.

The prize also requires terminal output showing proof generation and confirming `RISC0_DEV_MODE=0`,
and says a silent screencast is not sufficient: narrate the architecture, and demonstrate M-of-N
approval and execution with shielded accounts.

**Target length: 8–10 minutes.** The sections below are timed to that.

---

## Before recording

1. **Set the pin.** Film after the commit is settled. `git log -1` on camera must match the commit
   the submission names.
2. **Re-verify the chain.** `./scripts/verify-onchain.sh` must exit 0 *today* — testnets get wiped,
   and a dead link fails the plan gate. If it fails, redeploy before filming.
3. **Basecamp needs the JIT workaround.** Without it the app dies when the module opens — Basecamp's
   bug, written up in [BUGS_FILED.md](BUGS_FILED.md) §8:
   ```bash
   launchctl setenv QT_ENABLE_REGEXP_JIT 0   # then restart Basecamp so it inherits this
   ```
   Check it took:
   ```bash
   ps eww -p "$(pgrep -x LogosBasecamp.bin)" | tr ' ' '\n' | grep QT_ENABLE_REGEXP_JIT
   ```
4. **Install the current package** through Package Manager → Install Local Package, from
   `app/private_multisig.lgx`. Confirm the row reads Type `ui_qml`.
5. **Fill Settings once, before recording** (see §6) so the demo is not four minutes of typing — then
   clear the Config and Proposal fields so the fetches happen live on camera.
6. **Close Chrome and one editor.** The composed proof needs ~9 GB free; on a loaded machine it swaps
   and looks hung. This is the most likely way for a recording to go wrong.
7. **Terminal at a legible font size.** A reviewer has to read `RISC0_DEV_MODE=0`.
8. Run `./demo.sh` once beforehand to warm every build, and **record the second run**. Same evidence,
   far shorter, and nothing about it is less true.

---

## 1. Identity and pin (~30 s)

Show `git log -1` and `git status`.

> "This is a private M-of-N multisig for the Logos Execution Zone, at commit `<sha>`, clean tree.
> Everything you're about to see runs from this commit."

**On camera:** the commit hash, matching the one the submission names.

## 2. The problem (~60 s)

> "A public multisig on LEZ can't work with shielded accounts. Its members would have to be fresh
> zero-nonce keypairs that the program claims. A shielded account is owned by the privacy protocol,
> and its nonce isn't a counter you can hold at zero — LEZ derives it from the account id, then
> re-derives it from the member's secret on every use. So membership can't be an ownership relation.
> It has to be proven in zero knowledge."

## 3. Architecture (~2 min) — ADR-001, on the `config_hash` line

> "Everything hangs off this hash. The member root, the threshold M, and the membership verifier's
> ImageID are all hashed into the seed of the multisig's address. So an attacker who lowers M, or
> swaps in a permissive verifier, doesn't get a weaker multisig — they get a different address, where
> nothing exists and nobody has funded anything."

> "An approval proves two things at once. LEZ's privacy-preserving circuit proves you control a live
> shielded account. Our membership guest proves that same account is in the member set, and emits a
> nullifier. The nullifier is keyed to your secret, not your address, so you can't vote twice from
> another of your own addresses."

**Answer the obvious question before a reviewer asks it:**

> "Execute carries no proof, and that's deliberate. By the time it runs, the threshold is already a
> fact on chain — a set of distinct, proof-backed nullifiers. Anyone may execute, including a
> non-member, and that is what keeps execution unlinkable to any approver. What stops a stranger
> redirecting the money is that execute pins both ends: the funds leave the multisig's own account,
> and the recipient must be the one the proposal named, or the call is refused."

## 4. The demo (~3 min edited) — `./demo.sh`

**On camera, in order:**

- the `RISC0_DEV_MODE=0` banner
- `sequencer is live — getLastBlockId = N` — a real node, not an in-process executor
- both program deployments
- proof generation starting, then confirming

> "This is a real proof — dev mode is off, you can see it in the banner. About twenty minutes and
> roughly nine gigabytes, and it happens twice, because two approvals is what a full two-of-three
> means. I'm speeding up the wait, not cutting it: the clock stays on screen and the raw log is in
> the repository."

**Compress the wait as a labelled time-lapse. Do not cut the start or the finish.**

Nothing in the prize text says whether editing is allowed, so do not rely on it being allowed. What
LP-0002 *does* require is that the recording shows proof generation and confirms `RISC0_DEV_MODE=0`.
A time-lapse satisfies that only if nothing is hidden:

- keep a running wall clock visible **through** the sped-up section;
- label it on screen, e.g. `time-lapse ×60, no cuts`;
- show the banner and the start at real speed, and the receipt and confirmation at real speed;
- publish the top-level run log beside the video so the timestamps can be checked against it.

**Not the per-approval logs.** `.e2e/run/approve*.log` records the CLI's arguments, and one of them is
the member's `ApprovalWitness` — first field `nsk`, their nullifier secret key. The scripts redact it
and preflight **PF-16** fails the submission if any tracked file carries one, but do not go looking
for a way around that. See [tried-failed.md](tried-failed.md).

## 5. What the chain records (~90 s) — `./scripts/verify-onchain.sh`

> "This reads only public chain data. No secrets, no local state. It confirms the config account
> rehashes to its own address, that it names the deployed verifier, that the threshold was met at
> full M — not a lowered tier — that every nullifier is distinct, and that the proposal executed."

Point at the INV-7 line as it prints:

> "And this one matters. The account holding the sixty is the recipient *the proposal named*. The
> verifier reads it out of the proposal account, never from an argument I passed in."

## 6. The Basecamp module (~2 min) — REQUIRED

A CLI-only video was rejected for this prize. This section is not optional.

1. **Package Manager → local.** The `private_multisig` row, Type `ui_qml`.
   > "Two point six megabytes. The sha256 is published in `docs/basecamp-load.md`, so anyone can
   > check what they downloaded."
2. **Applications → Blockchain → open it.** It appears with its own icon, like a catalog app.
3. **Settings** — show the four fields already filled, and say what they are:
   ```
   Sequencer URL          https://testnet.lez.logos.co
   Program ID (hex)       79cf1dbaffe6295ce97af319e139220380d3da8ed4a877a12fd35cedc4a60468
   Wallet path            <your wallet directory>
   Wallet CLI directory   <lez checkout>/target/release
   ```
4. **Config** — paste this and press ↻:
   ```
   99cff7fa1f0c4fa267f29d34baafd720906a0e4259e013bc2ca42ac53498fbe4
   ```
   > "Two of three required. The member root, and the membership verifier — that ImageID is the same
   > one in DEPLOYMENT.md, character for character. This is the same account the verifier just
   > checked, read by the module itself."
5. **Proposal** — paste this and press ↻:
   ```
   f47f48e87e171ea02816f28fe542e50677a36f23f948e7956db994a9aefba255
   ```
   > "Two approvals, executed, sixty to that recipient. And here is the whole record of *who*
   > approved: a count, and two nullifiers. No account ids, no member list, nothing that identifies
   > anyone. That's the point of the prize, and it's on screen rather than in a test."
6. **Accounts** — press Check, then Reload.
   > "The same wallet the CLI used, read through the module."
7. **Approve** — open it and let the page speak for itself.
   > "This panel deliberately can't submit. An approval's witness is your nullifier secret key, and
   > this module builds public transactions — so it doesn't offer to. There's a CI check that fails
   > the build if anyone reconnects it."

**Say plainly, on camera:**

> "Two honest caveats. The package carries the darwin-arm64 variant only — that's the machine I built
> it on. And Basecamp has to be started with `QT_ENABLE_REGEXP_JIT=0`, because its QML sandbox
> JIT-compiles a regex under a hardened runtime that isn't entitled to do it. That's the host's bug,
> not this module's — reproduced and written up in `BUGS_FILED.md`, together with the replica factory
> plugin a module has to ship that nothing in Basecamp documents."

## 7. Honesty (~60 s) — `limitations.md`, then `tried-failed.md`

> "What this doesn't do. It's unaudited. The member set is fixed at creation. It doesn't defend
> against timing or network correlation. Proving needs about nine gigabytes free — the first time I
> ran it with a browser open it swapped for hours and looked broken."

> "And here's what I got wrong. I shipped a version where the member's spending key was recoverable
> from the guest journal. My first test scanned for the raw bytes and said it was clean — a false
> negative, because risc0 word-encodes each byte. Decoding the journal showed the key sitting there.
> That's fixed, and the test decodes now instead of scanning."

> "The same class of mistake came back later. The CLI echoes its arguments, so the approval witness —
> a member's secret key — was sitting in a run log. The scripts redact it now, and a preflight check
> fails the submission if any tracked file carries one. It caught its own author writing that up."

**Do not skip this section.** A submission that only shows what works invites the reviewer to go
looking for what does not.

## 8. Close (~20 s)

> "Everything you've seen is in the repository at the commit I opened with: the reproducible guest
> builds, the deployment with full transaction hashes and links, the CI run that does this whole
> lifecycle against a real sequencer, and the limitations. Thanks for watching."

---

## Checklist before publishing

- [ ] Narrated by a human, start to finish — **not** text-to-speech
- [ ] Commit hash legible, and the one the submission names
- [ ] `RISC0_DEV_MODE=0` legible
- [ ] Proof generation visibly starts and finishes; time-lapse labelled, clock visible, nothing cut
- [ ] Full lifecycle at **full M** (2-of-3), not a lowered threshold
- [ ] The Basecamp module on camera **reading chain state**, not merely installed
- [ ] Both caveats said out loud: the single variant, and the `QT_ENABLE_REGEXP_JIT=0` host bug
- [ ] `verify-onchain.sh` exits 0 on the day of filming
- [ ] Video URL added to `solutions/LP-0002.md` (preflight PF-12 checks for it)
- [ ] This file replaced with the actual transcript
