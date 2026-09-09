#!/usr/bin/env bash
# generate-idl.sh — emit the SPEL IDL for the multisig program (criterion P-U3).
#
# The IDL is generated from the #[lez_program] annotations at compile time, so it cannot drift from
# the program's actual instruction set. Committed to artifacts/ so reviewers and the CLI can use it
# without a build.
#
# Missing tools fail this script (gate H2).

set -euo pipefail
cd "$(dirname "$0")/.." || { echo "cannot cd to repo root" >&2; exit 1; }

command -v cargo >/dev/null 2>&1 || { echo "FATAL: cargo not found. Install Rust: https://rustup.rs" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "FATAL: jq not found (needed to format the IDL)." >&2; exit 1; }

mkdir -p artifacts
OUT=artifacts/multisig.idl.json

echo "==> generating IDL from #[lez_program] annotations"
( cd programs/multisig-spel && cargo run --quiet --bin idl ) | jq . > "$OUT.instructions"

# SPEL's IDL carries instructions; account *layouts* come from its separate #[account_type]
# attribute, whose collector reads field types as written and so cannot see through the aliases our
# state structs use (Digest32, Threshold, MemberCount, ProgramIdWords). Annotating the structs and
# spelling the aliases out would edit crates that compile into the guest, changing the ELF whose
# hash is the deployed ProgramId. This derives the same layouts on the host, from those structs'
# own source. crates/idl-accounts/tests/roundtrip.rs decodes real Borsh bytes through the result,
# so the layouts cannot drift from the structs without a test failing.
echo "==> deriving account layouts from the state structs"
cargo run --quiet -p pmsig-idl-accounts -- \
  MultisigConfig,Proposal crates/multisig-core/src/lib.rs crates/core/src/lib.rs > "$OUT.accounts"

jq -s '.[0] + {accounts: .[1].accounts, types: .[1].types}' "$OUT.instructions" "$OUT.accounts" > "$OUT"
rm -f "$OUT.instructions" "$OUT.accounts"

for acc in MultisigConfig Proposal; do
  jq -e --arg a "$acc" '.accounts[] | select(.name == $a)' "$OUT" >/dev/null || {
    echo "FATAL: account layout '$acc' missing from the generated IDL — Basecamp cannot decode" >&2
    exit 1
  }
done
echo "==> account layouts present: $(jq -r '[.accounts[].name] | join(", ")' "$OUT")"

INSTRUCTIONS=$(jq -r '.instructions | length' "$OUT")
NAME=$(jq -r '.name' "$OUT")
echo "==> wrote $OUT — program '$NAME', $INSTRUCTIONS instructions:"
jq -r '.instructions[] | "      - \(.name)"' "$OUT"

# The lifecycle the prize asks for must all be present; a truncated IDL is a silent failure.
for ix in create_multisig create_proposal approve execute; do
  jq -e --arg ix "$ix" '.instructions[] | select(.name == $ix)' "$OUT" >/dev/null || {
    echo "FATAL: instruction '$ix' missing from the generated IDL" >&2
    exit 1
  }
done
echo "==> all four lifecycle instructions present"
