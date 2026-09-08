#!/usr/bin/env python3
"""The criteria checklist's summary must agree with its own rows.

It drifted once — the summary claimed 10 met while the rows showed 19 — and a submission's own
account of what it has done is the first thing a reviewer reads. A count that contradicts the
evidence beneath it is the kind of thing that closes a PR.
"""
import re
import sys
from collections import Counter

PATH = "docs/criteria-checklist.md"

try:
    text = open(PATH, encoding="utf-8").read()
except OSError as exc:
    sys.exit(f"FATAL: cannot read {PATH}: {exc}")

rows = re.findall(r"^\| \*\*P-[A-Z0-9]+\*\* \|[^|]+\|\s*([✅◐⛔])\s*\|", text, re.M)
if not rows:
    sys.exit(f"FATAL: no criterion rows found in {PATH} — has the table format changed?")
counted = Counter(rows)

claimed = {}
for symbol, label in (("✅", "evidence exists"), ("◐", "partial"), ("⛔", "not met")):
    m = re.search(rf"\|\s*{symbol} {label}\s*\|\s*\*\*(\d+)\*\*\s*\|", text)
    if not m:
        sys.exit(f"FATAL: the summary has no row for {symbol} {label}")
    claimed[symbol] = int(m.group(1))

bad = [
    f"  {sym}: summary says {claimed[sym]}, rows have {counted.get(sym, 0)}"
    for sym in ("✅", "◐", "⛔")
    if claimed[sym] != counted.get(sym, 0)
]
if bad:
    print(f"FAILED: {PATH} disagrees with itself", file=sys.stderr)
    print("\n".join(bad), file=sys.stderr)
    sys.exit(1)

total = sum(counted.values())
print(f"criteria summary matches its rows: {counted.get('✅',0)} met, "
      f"{counted.get('◐',0)} partial, {counted.get('⛔',0)} unmet, {total} total")
