# Loading the module in Logos Basecamp

`app/private_multisig.lgx` — 2653306 bytes, sha256 `1d8b806dfabdc369d8c1546e42ff933a96194eb74f7d78fdb58260768597204d`, variant **darwin-arm64**.
The package is built deterministically, so that hash is a fact about the *inputs*, not about the
minute it was built: rebuilding from the same tree reproduces it byte for byte. (It did not always.
Two builds used to differ in four bytes of gzip header — a timestamp — which would have made the
published hash go stale on every rebuild and made an honest reviewer's mismatch look like tampering.
`pack_lgx.py` now writes mtime 0 and no stored filename.) Change the icon, the QML or a dylib and
the hash moves, as it should.

Verify what you downloaded before installing it:

```bash
shasum -a 256 app/private_multisig.lgx     # must print the hash above
lgx verify app/private_multisig.lgx        # "Package structure is valid"

./scripts/build-basecamp.sh                # optional: rebuild and get the same hash back
```

## Install

1. **Package Manager → local**. If an older `private_multisig` is listed, delete it first —
   installing over it leaves the previous manifest in place, which is how a package with the wrong
   `type` kept showing after it had been rebuilt.
2. **Install Local Package** → choose `app/private_multisig.lgx`.
3. The row should read **Type `ui_qml`**, with a size and a date. A Type of "-" means Basecamp did
   not recognise the manifest — see below.
4. The module then appears under **Applications**, in the **Blockchain** category, with the icon,
   the same way a catalog app such as LEZ Wallet does. Open it from there.

Installed files land in:

```
~/Library/Application Support/Logos/LogosBasecamp/plugins/private_multisig/
```

## Before the first fetch: Settings

A freshly installed module points at nothing. Open **Settings** and fill in all three, then use the
panels:

| Field | Value for the deployment in [DEPLOYMENT.md](DEPLOYMENT.md) |
|-------|------------------------------------------------------------|
| Sequencer URL | `https://testnet.lez.logos.co` |
| Program ID (hex) | `79cf1dbaffe6295ce97af319e139220380d3da8ed4a877a12fd35cedc4a60468` |
| Wallet Path | a wallet directory you control, e.g. `.e2e/wallet-testnet` |
| Wallet CLI directory | the directory holding LEZ's `wallet` binary, e.g. `<lez checkout>/target/release` |

The last one is only needed for the **Wallet** pages. They do not talk to the chain through the C
ABI's client — they run LEZ's `wallet` binary, which is resolved through `PATH`, and Basecamp starts
its module hosts with the desktop session's `PATH`, which has no LEZ build tree in it. Without the
setting those pages failed with a bare `No such file or directory (os error 2)`; they now say which
binary is missing and which setting fixes it.

Until the first three are set the module points at `http://127.0.0.1:3040` with no program id, and a
fetch finds nothing. It now says so — the panel names the sequencer and program id it used — rather than
leaving the "No data" placeholder up, which is indistinguishable from an account that is genuinely
empty.

Then, on **Config**, paste the `config_hash` and press ↻; on **Proposal**, the `proposal_seed`.

## What each panel does, and how that was checked

These panels work inside Logos Basecamp. Each row below was also measured directly, by driving the
plugin's own slots from `scripts/check-basecamp-contract.sh` against the live deployment in
[DEPLOYMENT.md](DEPLOYMENT.md) — the same code the buttons call, so a failure is caught by a script
rather than by a person clicking.

Getting there needed the replica factory described below, and Basecamp itself has to be started with
`QT_ENABLE_REGEXP_JIT=0` — see [BUGS_FILED.md](BUGS_FILED.md) §8.

| Panel | State | How |
|-------|-------|-----|
| Config | reads the chain | `fetchConfig` returns the deployed 2-of-3: `m 2`, `n 3`, member root, membership program id. Asserted by `check-basecamp-contract.sh` with `PMSIG_CONTRACT_LIVE=1` |
| Proposal | reads the chain | `fetchProposal` returns `executed true`, two distinct nullifiers, and the `TreasuryTransfer` of 60 to the payee `verify-onchain.sh` checks |
| Wallet → connection | works | `checkConnection` → `{"status":"ok","sequencer_url":"https://testnet.lez.logos.co"}` |
| Wallet → accounts | works | `listAccounts` reads 5 accounts from the same wallet the CLI uses, once **Wallet CLI directory** is set |
| Wallet → inspect | works | `inspectAccount` on the payee returns its owner program and status |
| Wallet → decode | works | `decodeAccount` on the config PDA returns `type: MultisigConfig` with the fields above — this is what the IDL's account layouts bought |
| Create Multisig · Create Proposal · Approve · Execute | wired | These submit transactions, so they are not fired at the public chain by a check. What is asserted is that the slot reaches the FFI and reports: `execute` with a seed that cannot be hex returns an error rather than doing nothing. The lifecycle evidence comes from the CLI |

## The piece nothing documents: a replica factory

A `ui_qml` module is loaded in two processes, and the QML side does not build the connection itself.
Basecamp's bridge loads a **second** plugin, beside the first and named for the module, and asks it
for the replica:

```
LogosQmlBridge: no replica factory plugin registered for "private_multisig"
qml: private_multisig: no backend — … logos.module("private_multisig") resolved. Every panel is inert.
```

Basecamp's own `package_manager_ui` ships exactly this, as `package_manager_ui_replica_factory.dylib`.
The interface is undocumented and no headers ship with the application; its IID is
`logos.view.replica_factory/1.0`, and its shape can be read out of that reference plugin's vtable —
its secondary sub-vtable is

```
[offset-to-top][typeinfo][~dtor D1][~dtor D0][acquire(QRemoteObjectNode*)][replicaMetaObject() const]
```

so the destructor is virtual and comes **first**. That detail is not cosmetic: a wrong layout is not
a compile error, and the host calls what it believes is `acquire` at a fixed slot and lands on
whatever is there.

**Two crashes came out of getting this wrong, and both are worth knowing about.**

The first attempt handed back a *dynamic* replica and omitted that virtual destructor. Basecamp died
on opening the module, in its own QML url interceptor, with no frame of ours in the backtrace.
Several plausible causes were proposed and each was **disproved by measurement** rather than argued
away: a build-machine `LC_RPATH` (dyld reuses the host's already-loaded Qt, so no second copy is
created — measured, one before and one after), an ad-hoc code signature (a hardened, JIT-entitled
test host loads the same dylib and JIT-compiles regexes happily), and loading any third-party dylib
at all (Basecamp's own bundled `logos_delivery_demo` ships a factory and opens fine).

What actually lay underneath was two separate bugs stacked on each other:

1. **Basecamp's**, described in [BUGS_FILED.md](BUGS_FILED.md) §8 — its QML sandbox JIT-compiles a
   regex under a hardened runtime with no `allow-jit` entitlement. `QT_ENABLE_REGEXP_JIT=0` removes
   it.
2. **Ours**, which the first bug had been masking: the missing destructor slot. With the JIT crash
   gone, the real one surfaced as an instruction fetch into libc++abi's RTTI data, two slots off.

The interface now lives in one header shared by the factory and its test — because the test kept its
own copy, drifted from the factory, and reproduced Basecamp's crash in our own process, which is how
the layout was finally pinned down. `scripts/check-basecamp-contract.sh` publishes the plugin,
acquires a replica through the shipped factory, and asserts the two pair and that a slot call
travels: source and replica signatures match, and a value set through the replica comes back.

## What is and is not claimed

The package is built, verified structurally, installs in Basecamp 0.2.3 and opens from
Applications → Blockchain, and every panel renders. The code behind those panels is proven against
the live chain — the contract check fetches the deployed config through the plugin's own slots and
decodes it to the 2-of-3 in [DEPLOYMENT.md](DEPLOYMENT.md):

```
  ok     fetchConfig filled the config property
         decoded: {"m":2,…,"n":3,…,"version":1}
  ok     the fetched multisig is the deployed 2-of-3
```

That is a harness; the same panels also read the same deployment inside Basecamp itself, which is
what the module is for. Two limits stand: the package carries only the `darwin-arm64` variant — the
platform it was built on — and Basecamp must be started with `QT_ENABLE_REGEXP_JIT=0`, which is the
host's bug rather than this module's. Both are recorded in [limitations.md](limitations.md) and
against P-U2 in [criteria-checklist.md](criteria-checklist.md).
