# Loading the module in Logos Basecamp

`app/private_multisig.lgx` — 2632654 bytes, sha256 `2da8a47af92fe43ac2bde9825ad3c482e36f463472b4918bc53a63b466fdec36`, variant **darwin-arm64**.

Verify what you downloaded before installing it:

```bash
shasum -a 256 app/private_multisig.lgx     # must print the hash above
lgx verify app/private_multisig.lgx        # "Package structure is valid"
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

## Why the panels rendered and did nothing

The module shipped for a day looking complete and doing nothing: every panel drew, and no button
had any effect. The cause is the part of Basecamp's module contract that is not written down.

A `ui_qml` module is loaded **twice over**. The plugin dylib goes into a `ui-host` child process,
which calls `initLogos` and then publishes the plugin object over QtRemoteObjects under the module's
name. The QML named by the manifest's `view` is loaded by the **main** Basecamp process, in an
engine the plugin never touches. So the `backend` context property the scaffold set on its own
`QQuickWidget` engine was never in scope where the QML actually ran:

```
file:///…/plugins/private_multisig/qml/Main.qml:297: ReferenceError: backend is not defined
```

Line 297 is the fetch button. Basecamp logs this as a *warning* and carries on rendering, so the
window looks finished. Nothing in the build catches it, because everything builds and the standalone
preview app — which does set that context property — works perfectly.

Basecamp's own `package_manager_ui` shows the contract: its QML reaches C++ as
`logos.module("package_manager_ui")`, and the properties and slots it reads live on the **plugin**
class. So:

- `PrivateMultisigPlugin` now carries the whole API and forwards to the backend. The methods are
  public **slots**, because QtRemoteObjects replicates properties, signals and public slots — a
  `Q_INVOKABLE` that is not a slot would not be callable from the replica.
- `Main.qml` resolves its backend from either host: the `ctxBackend` context property when it is
  loaded in-process, otherwise `logos.module("private_multisig")`. One file, both hosts.

`./scripts/check-basecamp-contract.sh` asserts both halves, and CI runs it. Reverting `Main.qml` to
the context-property form makes it fail with 47 unresolved bindings — the same count the Basecamp
log showed.

## Why `lgx` cannot build this package

`lgx` 0.1.0 — the current release — writes **manifestVersion 0.5.0** packages, with the icon in a
top-level `assets/` directory. **Logos Basecamp 0.2.3 reads the 0.3.0 layout**, where the icon and
`metadata.json` live inside the variant. A 0.5.0 package installs with no error and no effect:
Basecamp logs `installPlugin` and then nothing at all, and the module never appears. The tool is
ahead of the application that has to load its output.

`scripts/pack_lgx.py` therefore writes the archive directly. Its hash scheme is documented nowhere;
it was derived by testing candidates against a package that does install — `logos_delivery_demo`
0.2.1 from the official repository — until all three of its recorded hashes reproduced exactly:

```
hashes["variants/<v>"] = sha256( Σ "<path in variant>\0<sha256 of contents>\n" , sorted )
hashes["variants"]     = sha256( Σ "<variant>\0<that variant's hash>\n" , sorted )
hashes["root"]         = sha256( "variants\0<the variants hash>\n" )
```

`build-basecamp.sh` reads those hashes back out of the finished archive and recomputes them, so a
packaging bug cannot ship a package that merely claims to be consistent.

## Two other things that had to match

**Qt version.** The plugin must be built against the Qt the host ships, not the newest one
installed. Qt embeds a version tag symbol, so a plugin built against 6.11 cannot be loaded by an
application carrying 6.9: `dlopen` fails with `Symbol not found: _qt_version_tag_6_11`, and
Basecamp does not log `dlopen` failures. Basecamp 0.2.3 carries **Qt 6.9.2**:

```bash
python3 -m aqt install-qt mac desktop 6.9.2 clang_64 -O ~/qt-basecamp
```

**Library paths.** As linked, the plugin named absolute paths on the build machine — Qt under
`/opt/homebrew/...` and the FFI library under this checkout's `target/`. Neither exists inside
Basecamp. `build-basecamp.sh` repoints them at `@rpath` and `@loader_path` and refuses to package
while any build-machine path remains.

## Why an earlier package installed but never appeared

The metadata has to be written into the manifest **before** `lgx add`, not after. `lgx create`
leaves a skeleton with no hashes; `lgx add` computes `hashes.root` over whatever the manifest says
at that moment. An earlier build edited the manifest afterwards, so the recorded root hash described
a file that no longer existed.

Basecamp only checks it on the `ui_qml` install path — which is why the very first package, whose
`type` was empty, installed happily and then sat there with Type "-": Basecamp never took that path.
Setting the type correctly took the path, the hash did not match, and the install failed with no
message at all. The log shows `installPlugin` being called and then nothing — no error, no
"UI plugin file installed".

`scripts/build-basecamp.sh` now patches the manifest between `create` and `add`.

## If Type shows "-"

That is the manifest, not the package. Read the installed copy:

```bash
cat ~/Library/Application\ Support/Logos/LogosBasecamp/plugins/private_multisig/manifest.json
```

`type` must be `ui_qml` and `icon` must name a file that exists in the package. An earlier build
declared `"type": "ui"`, which Basecamp stored as `""`, and pointed `icon` at an `icon.svg`
that was never packaged — so the row had no type, no icon, and the module never reached
Applications. Both are fixed; `scripts/build-basecamp.sh` now refuses to package without a
256×256 PNG icon, and `scripts/patch_lgx_manifest.py` carries `type` and `icon` into the
package manifest because `lgx` itself leaves them empty.

## Building it yourself

```bash
./scripts/build-basecamp.sh          # needs Qt6, cmake, ninja and the lgx tool
```

It builds the C ABI library the UI calls, checks that **every** `extern "C"` symbol
`app/src/PrivateMultisigBackend.cpp` declares is actually exported, builds the Qt plugin, and only
then packages. A missing symbol fails the build rather than producing a package that installs and
then cannot call the program.

## What is and is not claimed

The package is built, verified structurally, installs, and its panels are wired to the chain: the
contract check fetches the deployed config through the plugin's own slots and decodes it to the
2-of-3 in [DEPLOYMENT.md](DEPLOYMENT.md), which is the whole path a press of ↻ takes.

```
  ok     fetchConfig filled the config property
         decoded: {"m":2,…,"n":3,…,"version":1}
  ok     the fetched multisig is the deployed 2-of-3
```

It carries only the `darwin-arm64` variant — the platform it was built on — and the click-through in
Basecamp itself is shown in the demo video rather than asserted by a script, since no automation
hook is exposed for it. Both are recorded in [limitations.md](limitations.md) and against P-U2 in
[criteria-checklist.md](criteria-checklist.md).
