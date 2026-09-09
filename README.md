# LP-0002: Private M-of-N Multisig for LEZ

A private M-of-N multisig for the Logos Execution Zone: shielded members approve without revealing
who voted. On-chain state records a threshold and nullifiers — never member identities.

Built for [λPrize LP-0002](docs/plan/LP-0002.md). Licensed **MIT OR Apache-2.0**.

Repository: <https://github.com/pramadanif/lp-0002-private-multisig>

## Narrated demo video

**<https://youtu.be/7gRweVxWEL4>** — narrated by the builder.

| | |
|-|-|
| `./demo.sh` starts, `RISC0_DEV_MODE=0` against a real sequencer | [t=100](https://youtu.be/7gRweVxWEL4?t=100) |
| lifecycle complete — two anonymous approvals, execute at full M | [t=194](https://youtu.be/7gRweVxWEL4?t=194) |
| the Basecamp module reading the deployed multisig | [t=246](https://youtu.be/7gRweVxWEL4?t=246) |

Recorded at commit `138c683`, which `demo.sh` and `verify-onchain.sh` print in their own banners.
Shot list and narration: [`docs/video-transcript.md`](docs/video-transcript.md).

## Status

| | |
|-|-|
| Public testnet lifecycle | **Done** — full 2-of-3 create → propose → 2× anonymous approve (`RISC0_DEV_MODE=0`) → execute. Verified with `./scripts/verify-onchain.sh` from public data alone (INV-7: payee holds 60). |
| Local / CI demo | **Done** — `./demo.sh` against a standalone LEZ sequencer; CI e2e with real proofs, green twice ([run 34302452494](https://github.com/pramadanif/lp-0002-private-multisig/actions/runs/34302452494), [run 34275830322](https://github.com/pramadanif/lp-0002-private-multisig/actions/runs/34275830322)). |
| Basecamp `.lgx` | **Done (darwin-arm64)** — installs as `ui_qml` under Applications → Blockchain. See [`docs/basecamp-load.md`](docs/basecamp-load.md). Approve stays in CLI/SDK (module does not submit PPE approvals). |
| Explorer index | **Pending** — txs are on the sequencer; some explorer pages still WAIT. Re-run `./scripts/check-explorer-links.sh` before opening a solution PR. |
| Narrated video | **Done** — [https://youtu.be/7gRweVxWEL4](https://youtu.be/7gRweVxWEL4), recorded at `138c683`. |

Per-criterion map: [`docs/criteria-checklist.md`](docs/criteria-checklist.md).  
Limitations: [`docs/limitations.md`](docs/limitations.md).

## Public-testnet deployment

Network: `https://testnet.lez.logos.co` · Explorer: `https://explorer.testnet.lez.logos.co`  
Redeployed **2026-09-08** after a testnet reset. Full recipe: [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md).

| # | Action | Transaction (full hash + explorer) |
|---|--------|--------------------------------------|
| 1 | Deploy `membership` | [`fe3a65ee4127a821847514d0350df479c86cb9b6d14c399c5608b36dde333fdc`](https://explorer.testnet.lez.logos.co/transaction/fe3a65ee4127a821847514d0350df479c86cb9b6d14c399c5608b36dde333fdc) |
| 2 | Deploy `multisig` | [`ef9029b2a9d4ef8c261e02af21b9a099ceba510a58a05407ff4a60714bb08d4e`](https://explorer.testnet.lez.logos.co/transaction/ef9029b2a9d4ef8c261e02af21b9a099ceba510a58a05407ff4a60714bb08d4e) |
| 3 | `create_multisig` | [`007d9ff27063b39843af29443abbcd40923de9fc4a17d9963d0521b9217e8a13`](https://explorer.testnet.lez.logos.co/transaction/007d9ff27063b39843af29443abbcd40923de9fc4a17d9963d0521b9217e8a13) |
| 4 | `create_proposal` | [`aa14aa283a0cdb5de76fee512a24aff1da30e73a6ae88cc7079a621e2a3db1d3`](https://explorer.testnet.lez.logos.co/transaction/aa14aa283a0cdb5de76fee512a24aff1da30e73a6ae88cc7079a621e2a3db1d3) |
| 5 | Approve (PPE) | [`a3eaeb3a773f35a48935944ca1b15bed683265dbded90633c094e4ef56aa4f4b`](https://explorer.testnet.lez.logos.co/transaction/a3eaeb3a773f35a48935944ca1b15bed683265dbded90633c094e4ef56aa4f4b) |
| 6 | Approve (PPE) | [`2a283d3c8887ef552bf56f415bbd6b534a4424e0765b590f3b44f6f6215a0aaa`](https://explorer.testnet.lez.logos.co/transaction/2a283d3c8887ef552bf56f415bbd6b534a4424e0765b590f3b44f6f6215a0aaa) |
| 7 | `execute` | [`d1a47fddeddbfebd1a387f52ac91ecaed43f8c20275d6fb82bf3acd2f460057e`](https://explorer.testnet.lez.logos.co/transaction/d1a47fddeddbfebd1a387f52ac91ecaed43f8c20275d6fb82bf3acd2f460057e) |

| Field | Value |
|-------|--------|
| `membership` ImageID | `960db4f24de1f1b0ebdc064a9be1246bde0e6a06f8be7f349fa562cc4207eade` |
| `multisig` ImageID | `79cf1dbaffe6295ce97af319e139220380d3da8ed4a877a12fd35cedc4a60468` |
| Config PDA | `4ZKN1S7R8F9V2fJEzDz65ogabhDi8sDS82W5i4mADZxt` |
| Proposal PDA | `32Te128ntLW4wSbT6xDb7SYha7q2g8EjFDYTUoDKHEDF` |
| Payee | `9NJmD3awoi9FT1yxZFMCvPxuHDcedZbK6LoZ9ZyhAC1J` |
| `config_hash` | `99cff7fa1f0c4fa267f29d34baafd720906a0e4259e013bc2ca42ac53498fbe4` |
| `proposal_seed` | `f47f48e87e171ea02816f28fe542e50677a36f23f948e7956db994a9aefba255` |
| Threshold | **2-of-3 (full M)** |

Re-check anytime:

```bash
./scripts/verify-onchain.sh
./scripts/check-explorer-links.sh
```

## Quickstart

```bash
# Toolchain (once): Rust 1.94+, risc0 r0vm — see docs/VERSIONS.md
# Linux: sudo apt-get install -y pkg-config libpcsclite-dev

./scripts/build-guests.sh --docker   # reproducible guests (required before deploy)
./demo.sh                            # prize demo: standalone sequencer, RISC0_DEV_MODE=0
                                     # ~40–50+ min wall-clock (two composed approvals ~20 min each)
```

`demo-fast.sh` is a development tour only — **not** the prize demo.

**RAM:** a composed approval needs ~9 GB free. Close the browser first or the prover looks hung.

## Performance

Measured figures: [`docs/cu-costs.md`](docs/cu-costs.md).

| | |
|--|--|
| On-chain CU (numeric per ix) | `create_multisig` 155,809 · `create_proposal` 257,625 · `execute` 315,293 · `verify_approval` 602,662 |
| Standalone membership prove | ~116 s |
| Composed approval (what members pay) | ~21–22 min on laptop; ~75 min on 4-core CI |
| Peak RAM | ~8.7 GB |

## Architecture

Full write-up: [`docs/adr/ADR-001-architecture.md`](docs/adr/ADR-001-architecture.md).

| Decision | Choice |
|----------|--------|
| Approve path | Privacy-preserving execution (chained `env::verify`), never public re-execution |
| Membership | LEZ-native guest; nullifier per (member, proposal) |
| Anchoring | PDA seeded by `config_hash` (member root + M + N + program ids) |
| Binding | In-circuit live shielded account, not derivation-only |
| Execute | Public, permissionless; recipient + amount frozen in the proposal (INV-7) |

```text
config_hash = SHA256( DS_CONFIG ‖ member_root[32] ‖ M[1] ‖ N[1] ‖ multisig_id[32] ‖ membership_program_id[32] )
DS_CONFIG   = "/LP0002/v1/ConfigHash/" ++ [0u8; 10]
```

Preflight **PF-13** fails if this formula drifts across README / ADR-001 / SOLUTION_DRAFT.

**Why not adapt a public multisig?** Shielded accounts are owned by the privacy protocol and do not
keep a zero nonce the program can claim. Membership must be proven in ZK. Details above and in
[`docs/why-logos.md`](docs/why-logos.md).

## End-to-end usage

### 1. Build guests

```bash
./scripts/build-guests.sh --docker
```

### 2. Local demo (`RISC0_DEV_MODE=0`)

```bash
./demo.sh
```

### 3. Public testnet

```bash
./scripts/fund-testnet.sh
LEE_WALLET_HOME_DIR=.e2e/wallet-testnet ./scripts/deploy-testnet.sh
./scripts/verify-onchain.sh
```

### 4. CLI

```bash
cargo run -p pmsig-cli --bin pmsig -- --help
# create / propose / approve / execute / status
# status prints count + nullifiers — never who approved
```

Approvals that need a real proof go through the CLI/SDK. The Basecamp Approve page is intentionally
non-submitting: the module builds public transactions and must not take a nullifier secret key.

### 5. Basecamp app

```bash
./scripts/build-basecamp.sh
# then Install Local Package → app/private_multisig.lgx
```

| | |
|--|--|
| Package | `app/private_multisig.lgx` |
| Size / hash | run `shasum -a 256 app/private_multisig.lgx` (published in [`docs/basecamp-load.md`](docs/basecamp-load.md)) |
| Type | `ui_qml` · category **Blockchain** |
| Arch | **darwin-arm64 only** (stated in limitations) |
| Host note | start Basecamp with `QT_ENABLE_REGEXP_JIT=0` — see [`docs/BUGS_FILED.md`](docs/BUGS_FILED.md) |

Step-by-step load + Settings fields for the live deployment: [`docs/basecamp-load.md`](docs/basecamp-load.md).

## Components

| Path | Role |
|------|------|
| `programs/` | Membership + multisig guests |
| `crates/sdk`, `crates/cli` | Prove + member API + `pmsig` |
| `crates/store` | Partial-approval resume across restarts |
| `app/` | Basecamp Qt/QML module + `.lgx` |
| `scripts/` | Demo, e2e sequencer, deploy, verify, preflight |
| `artifacts/` | Guest bins, ImageIDs, IDL |
| `docs/` | ADR, security, CU, deployment, criteria |

## Documentation

| Document | What it answers |
|----------|-----------------|
| [`docs/criteria-checklist.md`](docs/criteria-checklist.md) | Every prize criterion → evidence |
| [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) | Live txs + reproduce |
| [`docs/limitations.md`](docs/limitations.md) | What we do not claim |
| [`docs/cu-costs.md`](docs/cu-costs.md) | Numeric CU + prove times |
| [`docs/security.md`](docs/security.md) | Threat model |
| [`docs/basecamp-load.md`](docs/basecamp-load.md) | Install / open the GUI |
| [`docs/video-transcript.md`](docs/video-transcript.md) | Recording script |
| [`docs/tried-failed.md`](docs/tried-failed.md) | Mistakes we made and fixed |
| [`docs/BUGS_FILED.md`](docs/BUGS_FILED.md) | Upstream Basecamp/LEZ papercuts |
| [`docs/VERSIONS.md`](docs/VERSIONS.md) | Pins (LEZ **v0.2.4**, …) |

## Pinned versions

| Component | Pin |
|-----------|-----|
| LEZ | **v0.2.4** |
| SPEL | `main` @ `5126b7ed8a9b` (release v0.6.0 pins wrong LEZ for this testnet) |
| Rust (host) | 1.94.0 |
| risc0 | 3.0.6 / guest toolchain per `docs/VERSIONS.md` |

## Licence

Dual-licensed under [MIT](LICENSE-MIT) or [Apache-2.0](LICENSE-APACHE), at your option.
