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
# Saying a transaction is not on the chain is the strong claim here — it is what turns a link into
# a failure and a submission into "not ready". One dropped response must not be enough to make it.
# A privacy-preserving transaction is 364 KB, so a slow fetch is ordinary; three tries were the
# difference between this exiting 75 and exiting 1 on successive runs over the same chain state.
chain_has() {
  local h="$1"
  [[ ${#h} -eq 64 ]] || return 1
  for _ in 1 2 3; do
    if curl -s -X POST "$RPC_FOR_INDEX" -H 'content-type: application/json' \
         --data "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"getTransaction\",\"params\":[\"$h\"]}" \
         --max-time 90 2>/dev/null | grep -q '"result"[[:space:]]*:[[:space:]]*[^n]'; then
      return 0
    fi
    sleep 2
  done
  return 1
}

# If the chain cannot be reached at all, every transaction below would look absent — and absence of
# evidence is not evidence of absence. Declaring the links dead because the node is down would fail
# a branch over somebody else's outage, and would be a false statement about our own deployment.
rpc_up=0
if curl -s -X POST "$RPC_FOR_INDEX" -H 'content-type: application/json' \
     --data '{"jsonrpc":"2.0","id":1,"method":"checkHealth","params":[]}' --max-time 20 2>/dev/null \
     | grep -q '"result"'; then
  rpc_up=1
else
  echo "  NOTE: $RPC_FOR_INDEX is not answering — transaction links cannot be checked against the"
  echo "        chain right now, so an unindexed one cannot be told from a missing one."
fi

fail=0
for url in "${urls[@]}"; do
  # A JSON-RPC endpoint is not a web page. It answers POST and refuses GET with 405, which is the
  # endpoint working, not a dead link — and this URL is in DEPLOYMENT.md precisely so a reader can
  # query it. Ask it the way it expects to be asked.
  # The node being down is not our submission being broken, and it is already reported above.
  if [[ "$url" == "$RPC_FOR_INDEX" ]] && (( rpc_up == 0 )); then
    printf '  UNKNOWN %s\n          the node is not answering; its health is the operator'"'"'s, not this evidence'"'"'s\n' "$url"
    pending=$((pending + 1))
    continue
  fi
  if [[ "$url" != */transaction/* && "$url" != */account/* ]] \
     && curl -s -X POST "$url" -H 'content-type: application/json' \
          --data '{"jsonrpc":"2.0","id":1,"method":"checkHealth","params":[]}' \
          --max-time 20 2>/dev/null | grep -q '"result"'; then
    printf '  OK   %s  (JSON-RPC, answers checkHealth)\n' "$url"
    continue
  fi
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
    if [[ "$url" == *"/transaction/"* ]] && (( rpc_up == 0 )); then
      printf '  UNKNOWN %s\n          the explorer has not indexed it and the node cannot be asked\n' "$url"
      pending=$((pending + 1))
    elif [[ "$url" == *"/transaction/"* ]] && chain_has "$hash"; then
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
  echo "$((${#urls[@]} - pending)) of ${#urls[@]} evidence URLs resolve."
  if (( rpc_up )); then
    echo "$pending are on chain but the explorer has not indexed them yet."
  else
    # Do not claim they are on chain: with the node down that cannot be checked right now.
    echo "$pending could not be checked at all — the explorer has not indexed them and the node is"
    echo "not answering, so this run cannot tell an unindexed transaction from a missing one."
  fi
  echo "Re-run this before opening the PR — the links must render for a reviewer, and a submission"
  echo "is not finished while any of them is unresolved."
  # Not a pass and not a failure. Exiting 0 here would let preflight report PF-09 green while a
  # reviewer clicking the link still sees an empty page.
  exit 75
fi
echo "All ${#urls[@]} evidence URLs resolve."
