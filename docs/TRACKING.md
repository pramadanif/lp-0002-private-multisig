# Tracking

- Plan source: ../lambda-prize/planlp0002.md (v5.1)
- Prize source: ../lambda-prize/prizes/LP-0002.md
- Sibling layout: intentional — easy human eval side-by-side
- Solution repo absolute path: /Users/muhammadbaguspramadani/Documents/myproject/lp-0002-private-multisig
- Current phase: **H (submission packet)**. Phase E closed 2026-09-09: the unattended run it was
  waiting on completed twice on the same day — CI run 34275830322 (2 h 54 m, two 75-minute proofs at
  `RISC0_DEV_MODE=0`) and a laptop run (`evidence/e2e-local-2026-09-09.md`).
- Last green SC: Phase E and F complete; Phase H complete — the video is recorded and every
  criterion is met. The only thing still outstanding is not a criterion: the public explorer has
  not finished indexing five of the lifecycle transactions.
- Blockers: the testnet reset on 2026-09-08 is **handled** — redeployed the same day, and
  `verify-onchain.sh` re-read the whole lifecycle from public data on 2026-09-09 (exit 0).
  Outstanding: the public explorer has indexed the two program deployments but not yet the five
  lifecycle transactions (`check-explorer-links.sh` exits 75). **The Basecamp module** is
  built, packaged, installed in Basecamp 0.2.3 and wired to the chain (see `scripts/check-basecamp-contract.sh`); only the `darwin-arm64` variant ships. **The video** is recorded and published — <https://youtu.be/7gRweVxWEL4>, at commit `138c683`.
  Everything else is locked with command evidence — see
  [criteria-checklist.md](criteria-checklist.md), which carries the evidence per criterion.
  (Historic: the `e2e-sequencer` job was wired and had not completed; it went green on
  2026-09-06, run 34052567273, and again on 2026-09-09 on the current pin — run 34275830322,
  2 h 54 m, two proofs of 75 min each.) Each run has failed further along than the last: missing guest toolchain → missing `libpcsclite` → a SIGPIPE panic in our own script (`docs/tried-failed.md`). Every failure so far has been a real defect, and the job fails rather than faking a pass. The build itself is large: a full blockchain node plus a C++ groth16 stack, ~12 min before anything else starts. (#105 eligibility: operator decided 2026-09-04 to proceed through Phase I — `docs/_archive/phase-N1-status.md` §3.)

- Remote: https://github.com/pramadanif/lp-0002-private-multisig (public)

## Pins (settled in Phase −1, evidence-backed)

| What | Pin | Why |
|------|-----|-----|
| LEZ | **v0.2.4** | Live testnet ImageIDs match v0.2.4 artifacts exactly; v0.2.0 does not (`artifacts/phase-N1-testnet-version-fingerprint.txt`) |
| SPEL | **`main` @ `5126b7ed8a9b`** | Released v0.6.0 pins LEZ v0.2.0 → wrong private account ids on this testnet. `main` pins v0.2.4. Unreleased → disclose in `docs/limitations.md` |
| Rust (host) | 1.94.0 | LEZ v0.2.4 `rust-toolchain.toml` |
| risc0 | 3.0.5 (`r0vm`, `cargo-risczero`); guest rust 1.97.0 | LEZ v0.2.4 `Cargo.toml` |
| Testnet RPC / explorer | `https://testnet.lez.logos.co` / `https://explorer.testnet.lez.logos.co` | Cited in merged upstream `solutions/LP-0005.md`; both probed live |

## Abort watch

| Date (UTC) | Competing LP-0002 PR | Merged LP-0002 PR? | Action |
|------------|----------------------|--------------------|--------|
| 2026-09-04 | #125 *(empty — not APPROVED)* | none | continue |
| 2026-09-07 | #125 **CLOSED, not merged** | none | continue |
| 2026-09-09 | **#143 OPEN** — "LP-0002 — Private M-of-N Multisig (resubmission of #133)", `jeefxM`, opened 2026-09-08 20:53 UTC | none | continue — the prize is unclaimed while nothing is merged, but this is now a race, and the video is the only thing between this work and a submission |

## Human gates outstanding

| Gate | Needed by | State |
|------|-----------|-------|
| ~~Funded LEZ testnet keys~~ | — | **NOT A HUMAN GATE.** LEZ ships a proof-of-work faucet (Piñata). `./scripts/fund-testnet.sh` obtains funds unattended — verified: balance 150 → 300 on the public testnet |
| Narrated video URL + transcript | Phase H (W5/H11) | **requested** — shot list and narration ready in `docs/video-transcript.md`; this is the last blocking deliverable |
| Basecamp click-QA (if automation fails) | Phase F | **done** — the module was opened in Basecamp 0.2.3 and its panels read the deployed multisig |

## Carried forward

| Item | Needed by | Note |
|------|-----------|------|
| ~~Reproducible guest build~~ | — | **DONE 2026-09-05.** `build-guests.sh --docker` now works and `artifacts/IMAGE_IDS.md` records `reproducible (cargo risczero build, container r0.1.91.1)`. It had never run: the docker branch passed `--bin`, which `cargo risczero build` does not accept. Two further defects behind it — the pinned container's guest rustc is 1.91 against a workspace MSRV of 1.94, and the ELF was picked with `head -1` from a directory holding the raw ELF, an already-wrapped `.bin` and a copy under `deps/` |
| Second-proof slowdown undiagnosed | Phase H (BUGS_FILED) | `docs/tried-failed.md`; does not affect the recorded 53.26 s |
| ~~PPE composition not demonstrated~~ | — | **DONE.** tx `f2458791…198fbcb5` confirmed; ≈19 min, peak 8.74 GB (`artifacts/phase-E-ppe-approve-SUCCESS.txt`) |
| ~~U-6~~ | — | **RESOLVED.** It can; `--bin-<NAME>` resolves the ChainedCall dependency |
| ~~Recursive composition cost unmeasured~~ | — | **MEASURED.** ≈19 min 26 s, peak 8.74 GB, needs ~9 GB free RAM |
| Verifier change rotates every `config_hash` | Phase H (limitations) | Consequence of ADR-002 |
| ~~Funded testnet wallet lost~~ | — | **WRONG — retracted 2026-09-05.** I claimed the wallet was gone after searching `find ~ -maxdepth 3 -name wallet_config.json`, which cannot reach `.e2e/wallet-testnet/wallet_config.json` at depth 6. The wallet was there the whole time and is funded (450). Only `.e2e/lez` and `.e2e/spel` — build outputs — were missing |
| **Both** programs must be redeployed before any evidence is pinned | Phase G | `artifacts/phase-E-*.txt` records ImageIDs `821c23d9…` (membership) and `cee07cd3…` (multisig). Neither matches `artifacts/IMAGE_IDS.md` today (`f5cc9f37…`, `94bc1426…`). On LEZ the ImageID *is* the ProgramId, so **every** recorded on-chain result is for a superseded binary, and `config_hash` — which commits to the membership program id (ADR-002) — changes with it, moving every multisig address. An earlier version of this row said the membership ImageID was unchanged; that was true only of the INV-7 rebuild on 2026-09-05, not of the Phase E evidence, and reading it as "the membership evidence still stands" would have been wrong |

## Phase ledger

Commit column: the commit that **added** each status document. Two entries here named commits that
do not exist (`8e2f0b1`, `4c1a8f2`) — history was rewritten by a `git filter-branch` that purged a
leaked key, and the recorded hashes were never updated. A reviewer checking them would have found
nothing. Corrected 2026-09-05; every hash below now resolves.

The per-phase status documents were build logs, not part of the submission packet, and three of
them still read "in progress" for work that had finished. They are kept for history under
`docs/_archive/` and are **not** a current status surface: the one place status lives is
[criteria-checklist.md](criteria-checklist.md).

| Phase | Status | Archived status doc | Commit |
|-------|--------|--------------------|--------|
| −1 | ✅ complete | `docs/_archive/phase-N1-status.md` | `f6a1a15` |
| 0  | ✅ complete | `docs/_archive/phase-0-status.md` | `5ef6b93` / `b14f49e` |
| A  | ✅ complete | `docs/_archive/phase-A-status.md` | `ec9534a` |
| B  | ✅ complete | `docs/_archive/phase-B-status.md` | `f8b6e5f` |
| C  | ✅ complete | `docs/_archive/phase-C-status.md` | `aebb278` |
| D  | ✅ complete | `docs/_archive/phase-D-status.md` | `10276c1` |
| E  | ✅ complete — closed 2026-09-09 when the unattended run completed twice in one day | `docs/_archive/phase-E-status.md` | `7026ecf` |
| F  | ✅ complete — the Basecamp module installs, opens and reads the chain | `docs/_archive/phase-F-status.md` | `de77b2e` |
| G  | ✅ complete — deployed to the public testnet, `verify-onchain.sh` exit 0 | `docs/DEPLOYMENT.md` | — |
| H  | ✅ complete — packet written, video recorded and linked, all 21 criteria met | `docs/SOLUTION_DRAFT.md` | — |
| I  | not started — the operator opens the prize PR, never the agent | — | — |
