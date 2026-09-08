#!/usr/bin/env bash
# build-basecamp.sh — regenerate and build the Logos Basecamp module (criterion P-U2).
#
# Stages:
#   1. regenerate the Qt/QML scaffold from the IDL   (needs spel-client-gen)
#   2. re-apply our hardening to the generated files (see below)
#   3. build the Qt plugin                            (needs Qt6 + CMake)
#   4. package a distributable .lgx                   (needs the `lgx` tool)
#
# Stage 1 and 2 work anywhere. Stages 3 and 4 need a toolchain that is not on every machine, so this
# script FAILS with instructions rather than skipping — a "successful" run that silently produced no
# package would be worse than no run (gate H2).
#
# Usage:  ./scripts/build-basecamp.sh [--regen]
#           --regen  overwrite the generated scaffold from the current IDL
#
# ─── Why stage 2 exists ─────────────────────────────────────────────────────────────────────────
#
# The generator adds a "recent values" history to input fields, stored via QSettings. That is fine
# for a config hash and catastrophic for the approval witness, which carries a member's nullifier
# secret key. It currently escapes only because the generator skips `Vec<u8>` fields — luck, not
# design. `scripts/check-basecamp-privacy.sh` turns that into an enforced property, and this script
# runs it before declaring success.

set -euo pipefail
cd "$(dirname "$0")/.." || { echo "cannot cd to repo root" >&2; exit 1; }

REGEN=0
[[ "${1:-}" == "--regen" ]] && REGEN=1

die() { echo "FATAL: $*" >&2; exit 1; }
info() { printf '    %s\n' "$*"; }
log() { printf '\n==> %s\n' "$*"; }

command -v cargo >/dev/null 2>&1 || die "cargo is required. Install Rust: https://rustup.rs"
[[ -s artifacts/multisig-idl.json ]] || die "artifacts/multisig-idl.json missing. Run ./scripts/generate-idl.sh"

# ─── 1. Regenerate from the IDL ─────────────────────────────────────────────────────────────────
if (( REGEN )); then
  CG="${PMSIG_CLIENT_GEN:-.refs/spel-main/target/release/spel-client-gen}"
  [[ -x "$CG" ]] || die "spel-client-gen not found at $CG.
       Build it with:  cd .refs/spel-main && cargo build --release -p spel-client-gen"

  log "regenerating the Basecamp scaffold from the IDL"
  # --skip-ui preserves our hardened Main.qml; drop it only for a clean regeneration.
  "$CG" --idl artifacts/multisig-idl.json --out-dir app --target logos-module \
        --module-name PrivateMultisig --ffi-lib-path lib/libpmsig_ffi.dylib \
    || die "scaffold generation failed"
  info "regenerated — re-apply the manifest and QML hardening before committing"
fi

[[ -d app ]] || die "app/ does not exist. Run with --regen first."

# ─── 2. The hardening must hold ─────────────────────────────────────────────────────────────────
log "checking the UI does not leak member secrets"
./scripts/check-basecamp-privacy.sh || die "the Basecamp UI failed its privacy checks"

# ─── 2b. The C ABI the module calls ─────────────────────────────────────────────────────────────
#
# app/src/PrivateMultisigBackend.cpp declares thirteen `extern "C"` functions and CMake is told to
# link lib/libpmsig_ffi.<ext>. Nothing built that library, so the module could be packaged and would
# then fail to load on unresolved symbols. spel-client-gen emits the whole C ABI from the same IDL
# (--target rust+ffi); crates/basecamp-ffi carries it, and this builds it.
log "building the C ABI library the module links against"
case "$(uname)" in
  Darwin) LIBEXT=dylib ;;
  Linux)  LIBEXT=so ;;
  *)      die "unsupported platform $(uname) — the module ships darwin and linux variants" ;;
esac
cargo build --release -p pmsig-basecamp-ffi || die "the FFI library failed to build"
BUILT="target/release/libpmsig_ffi.$LIBEXT"
[[ -s "$BUILT" ]] || die "cargo reported success but $BUILT is missing"
mkdir -p app/lib
cp "$BUILT" "app/lib/libpmsig_ffi.$LIBEXT"
info "app/lib/libpmsig_ffi.$LIBEXT ($(wc -c < "$BUILT" | tr -d ' ') bytes)"

# Every symbol the C++ declares must actually be in it. A missing one is a load-time failure in
# Basecamp, which is the one place it is expensive to discover.
# `nm -gU` is macOS spelling and silently lists nothing on Linux, which would turn this check into
# a check that always passes. Each platform gets its own, and an unusable nm is a failure.
case "$LIBEXT" in
  dylib) exported=$(nm -gU "$BUILT" 2>/dev/null) ;;
  so)    exported=$(nm -D --defined-only "$BUILT" 2>/dev/null) ;;
esac
[[ -n "$exported" ]] || die "could not read exported symbols from $BUILT; refusing to package blind"

wanted=$(grep -oE 'private_multisig_[a-z_]+' app/src/PrivateMultisigBackend.cpp | sort -u)
missing_syms=()
for sym in $wanted; do
  # macOS prefixes an underscore, Linux does not; accept either spelling.
  printf '%s\n' "$exported" | grep -qE "(^| )_?${sym}$" || missing_syms+=("$sym")
done
if (( ${#missing_syms[@]:-0} > 0 )); then
  die "the FFI library does not export ${#missing_syms[@]} symbol(s) the UI calls: ${missing_syms[*]}
       The module would package cleanly and then fail to load. Regenerate with
       ./scripts/generate-basecamp-ffi.sh"
fi
info "$(printf '%s\n' "$wanted" | wc -l | tr -d ' ') symbols the UI calls are all exported"

log "checking the manifest is complete"
python3 - <<'PY' || exit 1
import json, sys
m = json.load(open("app/manifest.json"))
required = ["name", "version", "type", "author", "description", "main", "manifestVersion"]
missing = [k for k in required if not m.get(k)]
if missing:
    print(f"FATAL: manifest.json has empty required fields: {missing}", file=sys.stderr)
    sys.exit(1)
print(f"    manifest ok — {m['name']} {m['version']}, {len(m['main'])} platform targets")
PY

# ─── 3. Build the Qt plugin ─────────────────────────────────────────────────────────────────────
log "building the Qt plugin"
missing=()
command -v cmake >/dev/null 2>&1 || missing+=("cmake")
command -v qmake6 >/dev/null 2>&1 || command -v qmake >/dev/null 2>&1 || missing+=("Qt6")
if (( ${#missing[@]:-0} > 0 )); then
  cat >&2 <<EOF
FATAL: cannot build the Basecamp plugin — missing: ${missing[*]}

  macOS:  brew install qt cmake ninja
  Linux:  apt install qt6-base-dev qt6-declarative-dev cmake ninja-build

This script does not skip the build and report success. Criterion P-U2 requires a loadable module
with downloadable assets, and a build that did not happen is not one.
EOF
  exit 1
fi

# Build against the Qt the *host* ships, not the newest one installed here. Qt embeds a version tag
# symbol, so a plugin built against 6.11 cannot be loaded by an application carrying 6.9: dlopen
# fails with "Symbol not found: _qt_version_tag_6_11" and Basecamp logs nothing at all — the module
# installs and never appears. Basecamp 0.2.3 carries Qt 6.9.2.
#
#   python3 -m aqt install-qt mac desktop 6.9.2 clang_64 -O ~/qt-basecamp
QT_FOR_BASECAMP="${PMSIG_QT_DIR:-$HOME/qt-basecamp/6.9.2/macos}"
if [[ -d "$QT_FOR_BASECAMP" ]]; then
  info "building against Qt at $QT_FOR_BASECAMP"
  CMAKE_QT_ARG=(-DCMAKE_PREFIX_PATH="$QT_FOR_BASECAMP")
else
  echo "WARNING: $QT_FOR_BASECAMP not found — building against whatever Qt cmake finds." >&2
  echo "         If that is newer than the host's Qt, the module will install and never load." >&2
  CMAKE_QT_ARG=()
fi
cmake -S app -B app/build -DCMAKE_BUILD_TYPE=Release "${CMAKE_QT_ARG[@]}" || die "cmake configure failed"
cmake --build app/build --parallel || die "plugin build failed"
info "plugin built"

# ─── 3b. Point the plugin at libraries that will exist where it runs ─────────────────────────────
#
# As linked, the plugin names absolute paths on the machine that built it: Qt under
# /opt/homebrew/..., and libpmsig_ffi.dylib under this checkout's target/ directory. Neither exists
# inside Basecamp, so the module installed and then never appeared — the ui_qml path loads the
# plugin, and loading failed with nothing written to the log.
#
# Basecamp ships QtCore, QtGui, QtQml, QtQuick, QtQuickWidgets, QtWidgets and the rest in its own
# Frameworks directory, so @rpath resolves them there. The FFI library travels inside the package
# next to the plugin, so @loader_path finds it.
log "rewriting the plugin's library paths for the host that will load it"
PLUGIN_BUILT="app/build/libprivate_multisig_plugin.dylib"
[[ -f "$PLUGIN_BUILT" ]] || die "$PLUGIN_BUILT not found after the build"

install_name_tool -id "@loader_path/libpmsig_ffi.$LIBEXT" "app/lib/libpmsig_ffi.$LIBEXT" 2>/dev/null \
  || die "could not set the FFI library's install name"

while read -r dep; do
  case "$dep" in
    /opt/homebrew/*Qt*.framework/*)
      fw=${dep##*/}
      install_name_tool -change "$dep" "@rpath/$fw.framework/Versions/A/$fw" "$PLUGIN_BUILT" \
        || die "could not repoint $fw"
      ;;
    */libpmsig_ffi.$LIBEXT)
      install_name_tool -change "$dep" "@loader_path/libpmsig_ffi.$LIBEXT" "$PLUGIN_BUILT" \
        || die "could not repoint the FFI library"
      ;;
  esac
done < <(otool -L "$PLUGIN_BUILT" | tail -n +2 | awk '{print $1}')

# An absolute path left behind is a plugin that cannot load on any machine but this one.
leftover=$(otool -L "$PLUGIN_BUILT" | tail -n +2 | awk '{print $1}' \
  | grep -E '^/opt/homebrew|^'"$PWD" || true)
if [[ -n "$leftover" ]]; then
  die "the plugin still names build-machine paths, so it will not load elsewhere:
$(printf '       %s\n' $leftover)"
fi
info "library paths rewritten; no build-machine paths remain"

# ─── 4. Package the .lgx ────────────────────────────────────────────────────────────────────────
log "packaging the .lgx"

# Not `lgx`. Version 0.1.0 of that tool writes manifestVersion 0.5.0 packages with the icon in a
# top-level assets/ directory; Logos Basecamp 0.2.3 reads the 0.3.0 layout, where the icon and
# metadata.json live inside the variant. A 0.5.0 package installs with no error and no effect —
# Basecamp logs `installPlugin` and then nothing at all, and the module never appears. See
# docs/basecamp-load.md. scripts/pack_lgx.py writes the layout the host actually reads.
case "$(uname -s)-$(uname -m)" in
  Darwin-arm64)  VARIANT=darwin-arm64 ;;
  Darwin-x86_64) VARIANT=darwin-amd64 ;;
  Linux-x86_64)  VARIANT=linux-amd64 ;;
  Linux-aarch64) VARIANT=linux-arm64 ;;
  *) die "unsupported platform $(uname -s)-$(uname -m) — no variant name for it" ;;
esac

PLUGIN_NAME=$(python3 -c "
import json
print(json.load(open('app/manifest.json'))['main']['$VARIANT'])" 2>/dev/null) \
  || die "app/manifest.json does not name a plugin for variant $VARIANT"

rm -rf app/.lgx-staging && mkdir -p app/.lgx-staging/qml
# Basecamp's own modules ship the plugin without a `lib` prefix, and name it that way in `main`.
cp "app/build/libprivate_multisig_plugin.$LIBEXT" "app/.lgx-staging/$PLUGIN_NAME" \
  || die "no built plugin to package"
cp app/qml/Main.qml app/.lgx-staging/qml/
# Qt cannot register a QML module without a qmldir; every ui_qml module Basecamp ships has one.
[[ -s app/qml/qmldir ]] || die "app/qml/qmldir is missing — a ui_qml module needs one"
cp app/qml/qmldir app/.lgx-staging/qml/
# Without this the package loads and then fails on the first call into the program.
cp "app/lib/libpmsig_ffi.$LIBEXT" app/.lgx-staging/ \
  || die "the FFI library is not in app/lib — the earlier stage did not run"
[[ -s app/assets/icon.png ]] || die "app/assets/icon.png is missing"
cp app/assets/icon.png app/.lgx-staging/icon.png
[[ -s app/metadata.json ]] || die "app/metadata.json is missing"

rm -f app/private_multisig.lgx
python3 scripts/pack_lgx.py app/private_multisig.lgx "$VARIANT" app/.lgx-staging \
  app/manifest.json --metadata app/metadata.json || die "packaging failed"
rm -rf app/.lgx-staging

# The package must carry the hashes it claims. pack_lgx.py computes them; this reads them back out
# of the finished archive, so a packaging bug cannot ship a package that only says it is consistent.
python3 - <<'PYCHECK' || die "the packaged hashes do not match its contents"
import gzip, hashlib, io, json, tarfile, sys
def sha(b): return hashlib.sha256(b).hexdigest()
raw = gzip.open("app/private_multisig.lgx", "rb").read()
t = tarfile.open(fileobj=io.BytesIO(raw))
files = {m.name.lstrip("./"): m for m in t.getmembers() if m.isfile()}
mf = json.loads(t.extractfile(files["manifest.json"]).read())
v = next(k.split("/", 1)[1] for k in mf["hashes"] if k.startswith("variants/"))
pre = f"variants/{v}/"
vf = {n[len(pre):]: t.extractfile(m).read() for n, m in files.items() if n.startswith(pre)}
vh = sha("".join(f"{p}\0{sha(d)}\n" for p, d in sorted(vf.items())).encode())
vsh = sha(f"{v}\0{vh}\n".encode())
rh = sha(f"variants\0{vsh}\n".encode())
bad = [n for n, (a, b) in {
    f"variants/{v}": (vh, mf["hashes"][f"variants/{v}"]),
    "variants": (vsh, mf["hashes"]["variants"]),
    "root": (rh, mf["hashes"]["root"]),
}.items() if a != b]
if bad:
    print("FAILED: hashes disagree with contents:", ", ".join(bad), file=sys.stderr)
    sys.exit(1)
print("  hashes match the packaged contents")
PYCHECK

SHA=$(shasum -a 256 app/private_multisig.lgx | awk '{print $1}')
SIZE=$(wc -c < app/private_multisig.lgx | tr -d ' ')
log "packaged"
info "app/private_multisig.lgx"
info "sha256 $SHA"
info "bytes  $SIZE"
echo
echo "Record these in the release notes and SOLUTION (plan gate W12)."
