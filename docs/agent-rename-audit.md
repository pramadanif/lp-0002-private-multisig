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
| `Cargo.toml` `repository` | no | yes | already correct |
| `app/manifest.json` `homepage` | no | yes | already correct |
| README, SOLUTION_DRAFT, DEPLOYMENT, criteria-checklist, basecamp-load, limitations, video-transcript, TRACKING, phase-\*, reviewer-gaps | no | yes | already correct |
| CI workflow, `app/metadata.json` | no | — | no repo URL in either |
| **`app/private_multisig.lgx` — the manifest *inside* the shipped package** | **YES** | now yes | **rebuilt** |

Nothing in the working tree referenced the old name. The one place that did was the artefact a
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
| Old name anywhere in the archive | 1 occurrence | **0** |

The new hash and size were synced into `docs/basecamp-load.md`, `docs/SOLUTION_DRAFT.md`,
`docs/criteria-checklist.md` (P-U2), `docs/phase-F-status.md` and `docs/agent-lock-brief.md`. The
README does not hardcode the hash; it links to `basecamp-load.md`.

## Operator action required

**The installed copy in Basecamp still carries the old manifest.** Installing does not update in
place. Before filming:

1. Package Manager → uninstall `private_multisig`
2. Install Local Package → `app/private_multisig.lgx`
3. Confirm the row still reads Type `ui_qml`
4. Basecamp still needs `launchctl setenv QT_ENABLE_REGEXP_JIT 0` and a restart
   ([BUGS_FILED.md](BUGS_FILED.md) §8)

## Remaining

Nothing from the rename. `check-links.sh` passes, and `preflight-submission.sh` reports the same two
gates as before it — the explorer index and the video, neither of which the rename touched.
