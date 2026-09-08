# Loading the module in Logos Basecamp

`app/private_multisig.lgx` — 2637016 bytes, sha256 `c5cb15eb38190bcedfe657b3b6bc6dd339adce2dc44e7afa9bc0d58c8c06c217`, variant **darwin-arm64**.

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

## What is not claimed

The package is built, verified structurally, and installs. **It has not been shown running its UI
against a chain**, and it carries only the `darwin-arm64` variant — the platform it was built on.
Both are recorded in [limitations.md](limitations.md) and against P-U2 in
[criteria-checklist.md](criteria-checklist.md).
