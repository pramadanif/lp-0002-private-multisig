# Rename audit — `lp0002` → `lp-0002-private-multisig`

The GitHub repository was renamed. GitHub redirects the old path, so nothing *breaks* — which is
exactly why a stale reference can sit unnoticed in a submission. Audited 2026-09-09.

## Measured

```
$ git remote -v
origin  https://github.com/pramadanif/lp-0002-private-multisig.git (fetch/push)

$ curl -o /dev/null -w '%{http_code}' https://github.com/pramadanif/lp-0002-private-multisig
200
$ curl -o /dev/null -w '%{http_code}' https://github.com/pramadanif/lp0002
301          # redirect, not a 404 — the old links work and still read wrong
```

## Where the old name was, and what was done

| Location | Old URL? | New URL? | Action |
|----------|----------|----------|--------|
| `git remote origin` | no | yes | already correct |
| `Cargo.toml` `repository` | **YES** | now yes | **fixed in this same commit — see the correction below** |
| `app/manifest.json` `homepage` | no | yes | already correct |
| README, SOLUTION_DRAFT, DEPLOYMENT, criteria-checklist, basecamp-load, limitations, video-transcript, TRACKING, phase-\*, reviewer-gaps | no | yes | already correct |
| CI workflow, `app/metadata.json` | no | — | no repo URL in either |
| **`app/private_multisig.lgx` — the manifest *inside* the shipped package** | **YES** | now yes | **rebuilt** |

> **Correction, 2026-09-09.** The line above originally read "Nothing in the working tree
> referenced the old name", and the `Cargo.toml` row said "already correct". Both were wrong, and
> this audit is the document that should have caught it:
>
> ```
> $ git show a8755b4:Cargo.toml | grep '^repository'
> repository = "https://github.com/pramadanif/lp0002"     # the commit before this audit
> $ git show 3dc9f62:Cargo.toml | grep '^repository'
> repository = "https://github.com/pramadanif/lp-0002-private-multisig"
> ```
>
> `Cargo.toml` did carry the old URL, and the same commit that added this audit fixed it. The fix
> was real; the report of it was not. It surfaced days later from an unrelated question — "what has
> changed since the last green CI run" — which is the sort of luck a checklist exists to replace.

So: two places carried the old name — `Cargo.toml`, fixed in the audit commit, and the artefact a
reviewer actually installs.

## The `.lgx`, which is the point of this audit

`app/manifest.json` is the source; the package embeds a copy made when it was built. Updating the
source does not touch a package built before that edit, and the Install Local Package path ships
whatever is inside the archive.

```
$ python3 -c "import json;print(json.load(open('app/manifest.json'))['homepage'])"
https://github.com/pramadanif/lp-0002-private-multisig          # L1 — source, correct

$ tar xzOf app/private_multisig.lgx manifest.json | python3 -c "import json,sys;print(json.load(sys.stdin)['homepage'])"
https://github.com/pramadanif/lp0002                            # L2 — shipped, STALE
```

**L2 ≠ L1 → rebuilt** with `./scripts/build-basecamp.sh`, and re-measured:

| | Before | After |
|-|--------|-------|
| Embedded `homepage` | `…/lp0002` | `…/lp-0002-private-multisig` |
| sha256 | `18d48436…c0a6ae74` | **`3fabf0391ef27d3bf66d6e8f010f1547205d8054e85fd90c2127459e97eefe0b`** |
| Bytes | 2,664,623 | **2,664,654** |
| `type` / `category` | `ui_qml` / `blockchain` | unchanged — `ui_qml` / `blockchain` |
| Replica factory present | yes | yes |
| Old name anywhere in the archive | 1 occurrence | **0** — re-verified, see below |

The new hash and size were synced into `docs/basecamp-load.md`, `docs/SOLUTION_DRAFT.md`,
`docs/criteria-checklist.md` (P-U2), `docs/phase-F-status.md` and `docs/agent-lock-brief.md`. The
README does not hardcode the hash; it links to `basecamp-load.md`.

> **Superseded later the same day.** The module icon was redrawn ([make-icon.py](../../scripts/make-icon.py))
> and the package rebuilt, so the current artefact is sha256
> `1d8b806dfabdc369d8c1546e42ff933a96194eb74f7d78fdb58260768597204d`, 2,653,306 bytes — the values
> in the table above are the rename rebuild's, kept as the record of that measurement. The embedded
> `homepage` was re-checked after the icon rebuild and is still the new URL, and the archive still
> contains zero occurrences of the old name.

### How to scan the archive, because the obvious way does not work

`tar xzOf <archive>` with no member named writes **nothing** on BSD tar, which is what macOS ships.
Piping that into `grep` therefore reports every package clean, including one with the old URL
planted in it — measured, not assumed:

```
$ tar xzOf app/private_multisig.lgx | grep -c 'pramadanif/lp0002'      # planted package
0                                                                       # a lie
$ D=$(mktemp -d); tar xzf app/private_multisig.lgx -C "$D"
$ grep -rl 'pramadanif/lp0002' "$D"
$D/manifest.json                                                        # the truth
```

The current package really is clean — 0 hits across all 8 members by the second method, and the
shipped `homepage` reads the new URL. The conclusion was right; the command that reached it was
worthless. Preflight **PF-18** now runs the extracting version on every check, and it was tested
against the planted package to prove it fails.

## Operator action required

**The installed copy in Basecamp still carries the old manifest.** Installing does not update in
place. Before filming:

1. Package Manager → uninstall `private_multisig`
2. Install Local Package → `app/private_multisig.lgx`
3. Confirm the row still reads Type `ui_qml`
4. Basecamp still needs `launchctl setenv QT_ENABLE_REGEXP_JIT 0` and a restart
   ([BUGS_FILED.md](../BUGS_FILED.md) §8)

## Remaining

Nothing from the rename. `check-links.sh` passes, and `preflight-submission.sh` reports the same two
gates as before it — the explorer index and the video, neither of which the rename touched.
