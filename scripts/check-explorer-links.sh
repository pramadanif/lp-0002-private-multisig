#!/usr/bin/env bash
# check-explorer-links.sh — every evidence URL in the submission must actually resolve (plan gate W2).
#
# A prior submission to this prize was marked down for a documentation link that 404'd at the pinned
# commit, and testnet wipes routinely kill transaction links. So this runs in CI and, per plan gate
# SC-G.12, must be re-run on the day the PR is opened.
#
# Fails on: a dead link, a 404, or an explorer page that resolves but reports no such transaction.
# A missing DEPLOYMENT.md is also a failure once Phase G has run — silence is not success.

set -euo pipefail
cd "$(dirname "$0")/.." || { echo "cannot cd to repo root" >&2; exit 1; }

command -v curl >/dev/null 2>&1 || { echo "FATAL: curl is required." >&2; exit 1; }

echo "check-explorer-links.sh"
echo "  commit: $(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
echo

if [[ ! -f docs/DEPLOYMENT.md ]]; then
  echo "docs/DEPLOYMENT.md does not exist yet (Phase G has not run)."
  echo "Nothing to check — but note this is NOT evidence of anything."
  exit 0
fi

# Collect every http(s) URL in the deployment record and the solution draft.
mapfile_compat() {                       # bash 3.2 has no mapfile
  local __arr="$1"; shift
  local __line; eval "$__arr=()"
  while IFS= read -r __line; do [[ -n "$__line" ]] && eval "$__arr+=(\"\$__line\")"; done < <("$@")
}
collect() {
  grep -ohE 'https?://[A-Za-z0-9./_%#?=&:+-]+' docs/DEPLOYMENT.md docs/SOLUTION_DRAFT.md 2>/dev/null \
    | sed 's/[.,)]*$//' | sort -u
}
mapfile_compat urls collect

if (( ${#urls[@]:-0} == 0 )); then
  echo "FATAL: docs/DEPLOYMENT.md exists but contains no URLs." >&2
  echo "       Phase G must publish explorer links as evidence." >&2
  exit 1
fi

# The explorer's index trails the sequencer. A transaction written minutes ago serves the same
# 2,416-byte loading shell as a hash that cannot exist — measured on this run's own transactions,
# while a transaction from block 4459 returns 400 KB. So "the explorer does not show it" cannot,
# on its own, distinguish "not yet indexed" from "not there".
#
# The chain is the authority; the explorer is a convenience index over it. When a transaction page
# looks empty, ask the sequencer directly: if the RPC has the transaction, the evidence is real and
# the index is merely behind — reported, not failed. If neither has it, that is still a failure.
RPC_FOR_INDEX="${PMSIG_RPC:-https://testnet.lez.logos.co}"
pending=0
chain_has() {
  local h="$1"
  [[ ${#h} -eq 64 ]] || return 1
  curl -s -X POST "$RPC_FOR_INDEX" -H 'content-type: application/json' \
    --data "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"getTransaction\",\"params\":[\"$h\"]}" \
    --max-time 20 2>/dev/null | grep -q '"result"[[:space:]]*:[[:space:]]*[^n]'
}

fail=0
for url in "${urls[@]}"; do
  code=$(curl -s -o /tmp/explorer-body.$$ -w '%{http_code}' -L --max-time 25 "$url" || echo 000)
  body_says_missing=0
  if grep -qiE 'not found|no such transaction|does not exist|null' /tmp/explorer-body.$$ 2>/dev/null; then
    # Only treat this as fatal for transaction/account pages, where an empty result is the failure
    # mode that matters (a wiped testnet still serves a 200 page).
    [[ "$url" == *"/transaction/"* || "$url" == *"/account/"* ]] && body_says_missing=1
  fi
  rm -f /tmp/explorer-body.$$

  if [[ "$code" == "200" && $body_says_missing -eq 0 ]]; then
    printf '  OK   %s\n' "$url"
  elif [[ $body_says_missing -eq 1 ]]; then
    hash=${url##*/}
    if [[ "$url" == *"/transaction/"* ]] && chain_has "$hash"; then
      printf '  WAIT %s\n       the sequencer has this transaction; the explorer has not indexed it yet\n' "$url"
      pending=$((pending + 1))
    else
      printf '  DEAD %s  (HTTP %s, and the sequencer does not have it either)\n' "$url" "$code"
      fail=1
    fi
  else
    printf '  FAIL %s  (HTTP %s)\n' "$url" "$code"
    fail=1
  fi
done

echo
if (( fail )); then
  echo "FAILED: at least one evidence URL does not resolve." >&2
  echo "Re-deploy and update docs/DEPLOYMENT.md before submitting (SC-G.12)." >&2
  exit 1
fi
if (( pending )); then
  echo "$((${#urls[@]} - pending)) of ${#urls[@]} evidence URLs resolve; $pending are on chain but not yet"
  echo "indexed by the explorer. Re-run this before opening the PR — the links must render for a"
  echo "reviewer, and a submission is not finished while any of them still says WAIT."
  # Not a pass and not a failure. Exiting 0 here would let preflight report PF-09 green while a
  # reviewer clicking the link still sees an empty page.
  exit 75
fi
echo "All ${#urls[@]} evidence URLs resolve."
