#!/usr/bin/env bash
# generate-basecamp-ffi.sh — regenerate the C ABI the Basecamp module calls, from the IDL.
#
# The two files under crates/basecamp-ffi/src/generated/ are committed so the library builds
# without the generator present. They are machine output: regenerate rather than edit. This script
# rewrites them in place, so `git diff` after running it is how you tell whether the committed
# copies still match the IDL.
set -euo pipefail
cd "$(dirname "$0")/.." || { echo "cannot cd to repo root" >&2; exit 1; }

CG="${PMSIG_CLIENT_GEN:-.refs/spel-main/target/release/spel-client-gen}"
[[ -x "$CG" ]] || { echo "FATAL: spel-client-gen not at $CG. Set PMSIG_CLIENT_GEN." >&2; exit 1; }
[[ -s artifacts/multisig.idl.json ]] || { echo "FATAL: artifacts/multisig.idl.json missing. Run ./scripts/generate-idl.sh" >&2; exit 1; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
"$CG" --idl artifacts/multisig.idl.json --out-dir "$TMP" --target rust+ffi

for f in private_multisig_client.rs private_multisig_ffi.rs; do
  [[ -s "$TMP/$f" ]] || { echo "FATAL: the generator did not produce $f" >&2; exit 1; }
  cp "$TMP/$f" "crates/basecamp-ffi/src/generated/$f"
done
cp "$TMP/private_multisig.h" crates/basecamp-ffi/private_multisig.h

# The generator does not emit rustfmt-formatted code, and CI runs `cargo fmt --check` over the
# workspace. Formatting here keeps the committed files a deterministic function of the IDL — running
# this script twice still produces identical files — without turning the check off for the crate.
cargo fmt -p pmsig-basecamp-ffi || { echo "FATAL: rustfmt failed on the generated files" >&2; exit 1; }

echo "==> regenerated crates/basecamp-ffi/src/generated/ from artifacts/multisig.idl.json"
