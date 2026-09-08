#!/usr/bin/env bash
# check-basecamp-contract.sh — the module still satisfies what Basecamp requires of it.
#
# Logos Basecamp 0.2.3 loads a `ui_qml` module in two processes: the QML named by the manifest's
# `view` runs in the main application, the plugin dylib runs in a `ui-host` child, and the two are
# joined over QtRemoteObjects. A module that ignores this still installs, still opens, and still
# renders every panel — it just does nothing, because its QML's `backend` was a context property
# only its own engine ever had. That is precisely how this module shipped for a day.
#
# app/tests/module_contract_test.cpp asserts the two halves of the contract. This builds and runs it.
#
#   PMSIG_CONTRACT_LIVE=1  also fetches a real account through the plugin's slots. Needs a reachable
#                          sequencer and the deployment values (see docs/DEPLOYMENT.md).
#
# Missing tools fail this script (gate H2).

set -euo pipefail
cd "$(dirname "$0")/.." || { echo "cannot cd to repo root" >&2; exit 1; }

QT_DIR="${PMSIG_QT_DIR:-$HOME/qt-basecamp/6.9.2/macos}"
[[ -d "$QT_DIR" ]] || { echo "FATAL: Qt not found at $QT_DIR. Set PMSIG_QT_DIR." >&2; exit 1; }
command -v cmake >/dev/null 2>&1 || { echo "FATAL: cmake not found." >&2; exit 1; }

case "$(uname)" in
  Darwin) LIBEXT=dylib ;;
  Linux)  LIBEXT=so ;;
  *)      echo "FATAL: unsupported platform $(uname)" >&2; exit 1 ;;
esac

echo "==> building the contract test"
cmake -S app -B app/build -DCMAKE_PREFIX_PATH="$QT_DIR" >/dev/null
cmake --build app/build --target PrivateMultisigContractTest PrivateMultisigPlugin >/dev/null

# The plugin is tested where it will actually live: beside the FFI library it loads by
# @loader_path. app/lib holds that pair after build-basecamp.sh has run.
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
cp "app/build/libprivate_multisig_plugin.$LIBEXT" "$STAGE/private_multisig_plugin.$LIBEXT"
# The plugin resolves the FFI library by @loader_path/$ORIGIN, so it has to sit beside it. Build it
# here when build-basecamp.sh has not already staged one, so this check stands on its own in CI.
if [[ -f "app/lib/libpmsig_ffi.$LIBEXT" ]]; then
  cp "app/lib/libpmsig_ffi.$LIBEXT" "$STAGE/"
else
  echo "==> building the FFI library the plugin loads"
  command -v cargo >/dev/null 2>&1 || { echo "FATAL: cargo not found. Install Rust: https://rustup.rs" >&2; exit 1; }
  cargo build --release -p pmsig-basecamp-ffi >/dev/null
  cp "target/release/libpmsig_ffi.$LIBEXT" "$STAGE/"
fi

echo "==> checking the module contract"
QT_QPA_PLATFORM=offscreen ./app/build/PrivateMultisigContractTest \
  "$STAGE/private_multisig_plugin.$LIBEXT" app/qml/Main.qml
