# Solution packet — gap analysis and fix plan

What a judge opens is `solutions/LP-0002.md` in the prize repository, not this one. This note records
what that file needed, what the judge-facing Markdown in *this* repository disagreed about, and what
was done. Measured 2026-09-09.

## Measured, not assumed

| | |
|-|-|
| Pin at time of writing | `d8a801bd125112dee452ad2b9cf4210088be8626` (moves until the freeze) |
| `.lgx` | 2,653,306 bytes, sha256 `1d8b806dfabdc369d8c1546e42ff933a96194eb74f7d78fdb58260768597204d` |
| `verify-onchain.sh` | **exit 0** — 2-of-3, full M, INV-7 satisfied, `VERIFIED from public chain data alone` |
| `check-explorer-links.sh` | **exit 75** — 22 of 27 evidence URLs resolve; five lifecycle transactions are on chain and not yet indexed (two of the seven have since appeared, so the indexer is progressing) |
| `preflight-submission.sh` | `pass=18 fail=0 pending=2` (PF-09 explorer index, PF-12 video) |
| CI e2e green | **twice.** Run [34302452494](https://github.com/pramadanif/lp-0002-private-multisig/actions/runs/34302452494) on pin `a8755b4` — all eleven jobs green, e2e 3 h 40 m, two 96-minute proofs at `RISC0_DEV_MODE=0`. Before it, run [34275830322](https://github.com/pramadanif/lp-0002-private-multisig/actions/runs/34275830322) on pin `c530fc8`, 2 h 54 m |
| Upstream race | **PR #143 is OPEN** — "LP-0002 — Private M-of-N Multisig (resubmission of #133)", opened 2026-09-08 20:53 UTC |

## Gap table — `SOLUTION_DRAFT.md` against the LP-0000 template

The template's order is Summary → Repository → Approach → Success Criteria Checklist → FURPS →
Supporting Materials → Terms. LP-0005 adds a **Public-testnet deployment** table; LP-0013 puts a
**Demo Video** section near the top.

| Section | Before | Action |
|---------|--------|--------|
| Summary | present, strong | kept, tightened |
| Demo Video | **missing** | added, explicit `TBD` |
| Repository | **missing as a section** — repo and licence were scattered | added as the template's bullet list |
| Public-testnet deployment | linked out only | **full table inlined**, complete hashes with explorer links |
| Approach | present, strong (execute-carries-no-proof, INV-7, binding vs #91) | kept, folded together |
| Success Criteria Checklist | **missing** — lived only in `criteria-checklist.md` | all 21 inlined as `- [x]`/`- [ ]` with one-line evidence |
| FURPS | **missing entirely** | added, five dimensions |
| Supporting Materials | partial | completed |
| What is not done | present | kept, first-class |
| Terms & Conditions | **missing** | added |

**Why the missing ones mattered.** The reviewer who closed the previous LP-0002 attempt wrote that
*"main point of submission is the solution file … transaction hashes are trimmed and do not have
links, video link is missing"*. A packet that links out to a repository for its evidence is asking
the judge to do the assembling.

## Inconsistencies found across judge-facing files

Each was a real contradiction between two files a judge reads, quoted from both sides.

1. **Package hash.** `SOLUTION_DRAFT.md` and `basecamp-load.md` carried
   `c8056283…f436fd06` / 2,632,590 bytes while the file on disk was `3fabf039…97eefe0b` /
   2,664,654 bytes. A published hash that does not match the artefact is worse than no hash.
   *(Fixed — and fixed again after the icon rebuild. Chasing it twice showed the real fault: the
   packaging step stamped the build time into the gzip header, so the hash moved on every rebuild
   whether or not anything changed. `pack_lgx.py` now writes deterministically and two builds are
   byte-identical, which is what makes a published hash worth publishing. Current value in the
   measured table above.)*

2. **Whether the Basecamp panels work.** `criteria-checklist.md` P-U2 said the module "reads the
   deployed multisig", while `basecamp-load.md` still carried "**inside Basecamp these panels are
   currently inert**" and a section headed "The piece still missing: a replica factory". Both were
   true at different hours of the same day; only one is true now. *(Fixed — the factory ships.)*

3. **The host caveat.** The `QT_ENABLE_REGEXP_JIT=0` requirement appeared in the README and
   `BUGS_FILED.md` but not in `SOLUTION_DRAFT.md`, so the packet would have promised a working module
   without saying what it takes to open one. *(Fixed.)*

4. **Preflight count.** `agent-lock-brief.md` quoted `pass=17` after PF-16 raised it to 18.
   *(Fixed.)*

5. **Video status.** Consistently "not recorded" everywhere — no drift found. The new
   `solutions/LP-0002.md` keeps one `TBD` slot in two places (Repository bullet and Demo Video), and
   `P-S6` stays unchecked until a URL exists.

## What remains, and who owns it

| Item | Owner | Note |
|------|-------|------|
| Narrated video | **human** | Script ready in [video-transcript.md](../video-transcript.md); URL then replaces both `TBD` slots and checks P-S6 |
| Explorer index | **external** | Five transactions on chain, not yet rendered. Re-run `check-explorer-links.sh` on PR day |
| CI e2e on the final pin | automatic | Nothing on the path e2e exercises has changed since the green run; one run after the freeze settles it |
| Opening the PR | **operator** | Never the agent |
