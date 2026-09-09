#!/usr/bin/env bash
# Do the "must not find" gates actually fire?
#
# A gate that searches for something forbidden has a failure mode a gate that searches for something
# required does not: if its input is empty, or its pattern misses the shape the world actually
# produces, it passes for ever and looks healthy doing it. Three real examples from this repository,
# each found by planting the thing the gate forbids and watching it pass:
#
#   · PF-18 scanned the shipped .lgx with `tar xzOf <archive> | grep`. With no member named, BSD tar
#     writes nothing at all, so the gate was grepping an empty stream. A package with the old
#     repository URL planted in its manifest passed.
#   · PF-16 required a `0x` prefix, which the CLI emits and a human retyping `--witness {"nsk":…}`
#     does not. A spending key written by hand into a tracked document passed.
#   · Earlier, and the reason this file exists: the first test for a spending key in the guest
#     journal scanned for raw bytes, but risc0 word-encodes each one. See docs/tried-failed.md.
#
# So: plant a violation, require the gate to fail, restore. Run this whenever a gate is added or its
# pattern is touched. It is slow — each probe runs the whole preflight, which reaches the testnet —
# and it is deliberately not in CI, because it rewrites tracked files.
#
#     ./scripts/check-gates-fire.sh
set -uo pipefail
cd "$(dirname "$0")/.." || { echo "cannot cd to repo root" >&2; exit 1; }

die() { printf '\n%s\n' "$*" >&2; exit 1; }

# This script writes to tracked files and restores them with `git checkout --`. On a dirty tree that
# would destroy uncommitted work, so it refuses rather than being careful.
[[ -z "$(git status --porcelain -- demo.sh scripts docs app 2>/dev/null)" ]] \
  || die "the working tree has uncommitted changes under demo.sh, scripts/, docs/ or app/.
This script plants violations in tracked files and restores them with 'git checkout --',
which would discard that work. Commit or stash first."

# The package is tracked, so git restores it like everything else. The first version of this kept a
# copy in a temp file and deleted that copy inside restore() — which runs after every probe, so the
# copy was gone before the probe that needed it. The drill finished "all caught" and left a .lgx
# with the old repository URL planted in it sitting in the working tree. PF-18 would have caught it
# at the next commit, which is the system working, but a drill that leaves live damage behind is not
# one anybody will keep running.
PKG=app/private_multisig.lgx
TOUCHED=(demo.sh scripts/deploy-testnet.sh docs/limitations.md "$PKG")

restore() { git checkout -- "${TOUCHED[@]}" 2>/dev/null; return 0; }
trap restore EXIT

drills=0; missed=0

# The baseline every probe is measured against. A gate that is already failing would report "fires"
# for any planted violation, including one that does nothing — which is exactly what happened when
# this script put RISC0_DEV_MODE on the submission path merely by containing the string. So: read
# the gates once on a clean tree first, and refuse to test any that are not passing.
echo "  reading the clean baseline first — a gate already failing cannot be shown to fire"
BASELINE=$(./scripts/preflight-submission.sh 2>&1)

# probe <id> <description> — the gate must PASS clean and FAIL while the violation is planted
probe() {
  local id="$1" what="$2" line base
  drills=$((drills+1))
  base=$(printf '%s\n' "$BASELINE" | grep -E "^(PASS|FAIL|PENDING) +$id " | head -1)
  if [[ "$base" != PASS* ]]; then
    missed=$((missed+1))
    printf '  UNTESTABLE %-6s %s\n' "$id" "$what"
    printf '             it is not passing on a clean tree, so failing proves nothing: %s\n' \
           "${base:-<no line for $id at all>}"
    restore
    return
  fi
  line=$(./scripts/preflight-submission.sh 2>&1 | grep -E "^(PASS|FAIL|PENDING) +$id " | head -1)
  if [[ "$line" == FAIL* ]]; then
    printf '  fires   %-6s %s\n' "$id" "$what"
  else
    missed=$((missed+1))
    printf '  MISSED  %-6s %s\n' "$id" "$what"
    printf '          the gate said: %s\n' "${line:-<no line for $id at all>}"
  fi
  restore
}

echo "check-gates-fire.sh — planting violations, each must be caught"
echo

printf '\nif ! command -v definitely_not_a_real_tool >/dev/null; then\n  echo skipping\n  exit 0\nfi\n' >> demo.sh
probe PF-03 "a missing-tool branch that still exits 0"

# Split, so this file does not itself put the literal on the submission path. It did, and PF-04
# started failing on the drill that tests PF-04. Same shape as the needle below.
printf '\n%s\n' "RISC0_DEV_MODE=""1" >> scripts/deploy-testnet.sh
probe PF-04 "dev mode forced on, on the submission path"

# Three shapes of the same secret. The fake keys below are literals, never a real nsk.
printf '\n  witness = 0x%s\n' "$(printf '1%.0s' {1..64})" >> docs/limitations.md
probe PF-16 "a witness in the CLI's own form"

printf '\n--witness {"nsk":"%s","path":[]}\n' "$(printf '3%.0s' {1..64})" >> docs/limitations.md
probe PF-16 "a witness as a human would retype the argument"

printf '\n    [deadbeef, cafebabe, 01234567, 89abcdef]\n' >> docs/limitations.md
probe PF-16 "a witness as serialised u32 words"

printf '\nSee https://github.com/pramadanif/lp%s for details.\n' "0002" >> docs/limitations.md
probe PF-18 "the old repository name in a tracked file"

if [[ -f $PKG ]]; then
  python3 - "$PKG" <<'PY'
import gzip, io, json, sys, tarfile
src = tarfile.open(sys.argv[1], "r:gz")
buf = io.BytesIO()
out = tarfile.open(fileobj=buf, mode="w")
for m in src.getmembers():
    data = src.extractfile(m).read() if m.isfile() else None
    if m.name == "manifest.json":
        j = json.loads(data)
        j["homepage"] = "https://github.com/pramadanif/lp" + "0002"
        data = json.dumps(j, indent=2, sort_keys=True).encode() + b"\n"
        m.size = len(data)
    out.addfile(m, io.BytesIO(data) if data is not None else None)
out.close()
with open(sys.argv[1], "wb") as f:
    with gzip.GzipFile(filename="", mode="wb", fileobj=f, mtime=0) as gz:
        gz.write(buf.getvalue())
PY
  probe PF-18 "the old repository name inside the shipped .lgx"
else
  echo "  skipped PF-18 package probe — $PKG is not built"
fi

# Belt and braces: prove the drill put everything back, so a later commit cannot pick up a planted
# violation as if it were real work.
if [[ -n "$(git status --porcelain -- "${TOUCHED[@]}" 2>/dev/null)" ]]; then
  echo
  echo "the drill did not restore: $(git status --porcelain -- "${TOUCHED[@]}" | tr '\n' ' ')"
  exit 1
fi

echo
if (( missed > 0 )); then
  echo "$missed of $drills planted violations went undetected — a gate that cannot fail is not a gate."
  exit 1
fi
echo "all $drills planted violations were caught."
