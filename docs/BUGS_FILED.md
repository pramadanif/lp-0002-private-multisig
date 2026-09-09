# Bugs and papercuts found upstream

Plan gate **P15 / SC-H.10** asks for this file to list issues filed upstream, or to say explicitly
that there are none. There are several, all found by building against the real thing rather than by
reading docs.

Nothing here is a complaint. Each entry says what happened, what it cost, and what the fix or
workaround is — the same information a maintainer would need.

**Status:** written up here first. Filing upstream is pending; each entry below is drafted so it can
be pasted into an issue with no rework.

---

## 1. `wallet auth-transfer init` hangs on an already-initialised account

**Repo:** `logos-blockchain/logos-execution-zone` (wallet) · **Severity:** medium · **Reproduced:** yes

Running `wallet auth-transfer init --account-id <acct>` against an account that is *already*
initialised does not return. It sits at 0% CPU indefinitely; we watched one for over two minutes
before killing it. Initialising a fresh account works and returns promptly.

**Why it matters:** this is the natural shape of an idempotent setup script — "init, then claim". The
hang looks exactly like a network problem, so the first instinct is to blame connectivity or the
testnet, not the command.

**Workaround:** query the account's nonce over RPC first and skip `init` when it is non-zero
(`scripts/fund-testnet.sh`).

**Suggested fix:** return an error such as "account already initialised" instead of blocking.

## 2. The faucet's prerequisite is only discoverable by failing

**Repo:** `logos-blockchain/logos-execution-zone` (wallet / pinata) · **Severity:** low

`wallet pinata claim --to <acct>` on an uninitialised account fails with a *good* message that names
the fix. But nothing before that point says the account must be initialised first — the testnet
tutorial (`docs/LEZ testnet v0.1 tutorials/wallet-setup.md`) lists `wallet pinata` as "Piñata faucet
(claim)" with no mention of `auth-transfer init`.

**Suggested fix:** one line in the tutorial, or have `claim` initialise on demand.

## 3. `sequencer_service` takes a config *file*, but the README shows a directory

**Repo:** `logos-blockchain/logos-execution-zone` · **Severity:** low · **Reproduced:** yes

The README's standalone-mode instructions pass a directory:

```
cargo run --features standalone -p sequencer_service lez/sequencer/service/configs/debug
```

That fails immediately with `Error: Is a directory (os error 21)`. Elsewhere the same README passes
the file (`…/configs/debug/sequencer_config.json`), which works.

**Suggested fix:** make the two examples consistent, or accept a directory and look for
`sequencer_config.json` inside it.

## 4. The released SPEL pins a LEZ version the live testnet does not accept

**Repo:** `logos-co/spel` · **Severity:** high for new users · **Reproduced:** yes

SPEL **v0.6.0** (the latest release) pins LEZ `v0.2.0`. Between v0.2.0 and v0.2.4,
`AccountId::for_regular_private_account` gained a `vpk` parameter — v0.2.0 hashes
`prefix ‖ npk ‖ identifier`, v0.2.4 hashes `prefix ‖ npk ‖ vpk ‖ identifier`. **Private account ids
therefore differ**, so a project built on the released SPEL derives addresses the live testnet does
not recognise.

SPEL `main` already pins `v0.2.4`, so anyone following `main` is fine and anyone following the
release is not.

**How we found it:** by fingerprinting the deployed testnet rather than trusting a tag — a LEZ
`ProgramId` is the risc0 ImageID of the program ELF, and LEZ commits prebuilt `artifacts/`. The
testnet's `token` and `privacy_preserving_circuit` ImageIDs match v0.2.4's artifacts exactly and do
not match v0.2.0's.

**Suggested fix:** cut a release from `main`, or note the incompatibility in the v0.6.0 release notes.

## 5. `getProgramIds` returns only built-in programs

**Repo:** `logos-blockchain/logos-execution-zone` · **Severity:** low (documentation)

`getProgramIds` returns a fixed map of LEZ's own programs (`amm`, `authenticated_transfer`, `pinata`,
`privacy_preserving_circuit`, `token`). A freshly deployed user program does **not** appear, which
reads as a failed deployment — we briefly thought ours had failed, though the deployment transactions
were on chain and carried the ELF.

**Suggested fix:** name it in the RPC docs as a built-in registry, or add a method that resolves a
deployed `ProgramId`.

## 6. risc0's `prove` feature requires full Xcode on macOS

**Repo:** `risc0/risc0` · **Severity:** low (papercut) · **Reproduced:** yes

Enabling `risc0-zkvm`'s `prove` feature on macOS builds Metal kernels, which needs `xcrun metal` from
full Xcode. With only Command Line Tools installed the build fails with
`unable to find utility "metal"`.

**Workaround:** use risc0's default (client) features and let the external `r0vm` from `rzup` do the
proving — no Metal compilation, and it is what an evaluator will have anyway.

**Suggested fix:** mention the Xcode requirement where the `prove` feature is documented.

## 7. Unexplained: a second in-process proof does not complete

**Repo:** unclear — possibly `risc0/risc0` · **Severity:** unknown · **Not diagnosed**

Running two proofs sequentially in one process, the first completed in 53 s and the second had not
finished after 25 minutes, twice. Observed **before** we understood our memory situation, and most
likely the same cause — the machine was already loaded and the second proof swapped. Not re-tested
under clean conditions.

Recorded here rather than filed, because filing an unreproduced report with a likely mundane
explanation wastes a maintainer's time. It will be filed only if it reproduces on an unloaded machine.

---

## 8. Basecamp's QML sandbox JIT-compiles a regex it is not entitled to

**Logos Basecamp 0.2.3, macOS 26.0.1, Apple Silicon.** Opening a `ui_qml` module whose C++ is
reached through a replica factory kills the application:

```
Thread 14 Crashed:: QQmlThread
0  libsystem_pthread.dylib  pthread_jit_write_protect_np + 520
1  libpcre2-16.0.dylib      sljit_malloc_exec + 144
2  libpcre2-16.0.dylib      pcre2_jit_compile_16 + 128
3  QtCore                   QRegularExpressionPrivate::compilePattern()
4  QtCore                   QRegularExpression::match(...)
5  main_ui.dylib            RestrictedUrlInterceptor::qmldirDeclaresNativePlugin(QString) const
6  main_ui.dylib            RestrictedUrlInterceptor::intercept(QUrl, QQmlAbstractUrlInterceptor::DataType)
```

`EXC_BREAKPOINT (SIGTRAP)`. The sandbox's url interceptor runs a `QRegularExpression` over each
`qmldir` it intercepts; Qt JIT-compiles a pattern once it has been used enough times, and
`pthread_jit_write_protect_np` traps because the process may not JIT:

```
$ codesign -d --entitlements - /Applications/LogosBasecamp.app/Contents/MacOS/LogosBasecamp.bin
    com.apple.security.cs.disable-library-validation = true
$ codesign -dvvv /Applications/LogosBasecamp.app
    CodeDirectory ... flags=0x10000(runtime)
```

Hardened runtime, and the only entitlement is the one that lets third-party modules load. There is
no `com.apple.security.cs.allow-jit` — so the JIT the application's own QML sandbox reaches for is
not available to it.

**Workaround** (needed to open this module at all): start Basecamp with Qt's regex JIT off.

```bash
launchctl setenv QT_ENABLE_REGEXP_JIT 0    # inherited by apps launched from Finder or the Dock
```

**Suggested fix:** add `com.apple.security.cs.allow-jit` to the app's entitlements, or set
`QT_ENABLE_REGEXP_JIT=0` in the bundle's own launch environment.

**Why it is easy to miss.** It needs a module whose QML tree causes enough interceptor calls to pass
Qt's JIT threshold; Basecamp's bundled `logos_delivery_demo` is small enough to stay under it. And
the crash names neither Basecamp's own code nor the module's — every frame is Qt or PCRE2.

---

## 9. Nothing documents the replica factory a `ui_qml` module must ship

**Logos Basecamp 0.2.3.** A `ui_qml` module's QML runs in the main process while its plugin runs in
a `ui-host` child. The QML reaches the plugin as `logos.module("<name>")`, and that call returns null
unless a *second* plugin — `<name>_replica_factory.<ext>`, beside the first, declaring IID
`logos.view.replica_factory/1.0` — is present to build the replica:

```
LogosQmlBridge: no replica factory plugin registered for "private_multisig"
```

Nothing in the manifest mentions it, no header for the interface ships with the application, and the
generator (`spel-client-gen --target logos-module`) does not emit one. A module without it installs,
opens, and renders every panel — and does nothing, because each binding raises
`ReferenceError: backend is not defined` while the window draws perfectly.

The other route is closed explicitly: `logos.callModule()` answers
`{"error":"view modules must be called via logos.module()"}` for view modules.

The interface had to be reconstructed from `package_manager_ui_replica_factory.dylib`'s vtable:

```
[offset-to-top][typeinfo][~dtor D1][~dtor D0][acquire(QRemoteObjectNode*)][replicaMetaObject() const]
```

Getting the destructor wrong is not a compile error — the host calls `acquire` at a fixed slot and
lands on whatever is there, which for us was libc++abi's RTTI data, in Basecamp's own process.

**Suggested fix:** ship the interface header, and have `spel-client-gen --target logos-module`
generate the factory alongside the plugin. Both would have made this a non-event.

---

## Not bugs — our own mistakes, kept for honesty

These cost real time and were **ours**, not upstream's. They are in `docs/tried-failed.md` in full:

- Putting the membership witness in `instruction_data`, which a LEZ program echoes into its
  committed `ProgramOutput` — the member's spending key was recoverable from the guest journal.
- "Fixing" that with a fifth private input, which LEZ's `write_inputs` cannot deliver. The tests
  passed only because our own harness was more permissive than the runtime.
- A false-negative privacy test: scanning the journal for raw secret bytes, when risc0's serde
  word-encodes each byte, so a 32-byte secret never appears as a contiguous run.
