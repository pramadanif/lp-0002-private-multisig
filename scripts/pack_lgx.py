#!/usr/bin/env python3
"""Write a .lgx package Basecamp can actually install.

`lgx` 0.1.0 — the current release of the packaging tool — writes manifestVersion 0.5.0 packages,
with the icon in a top-level `assets/` directory. Logos Basecamp 0.2.3 reads the 0.3.0 layout, where
everything including the icon and metadata.json lives inside the variant. A 0.5.0 package installs
with no error and no effect: the log records `installPlugin` and then nothing, and the module never
appears. So this builds the archive directly rather than shelling out to a tool that cannot yet
produce what the host reads.

The hash scheme is not documented anywhere; it was derived by testing candidates against a package
that does install — logos_delivery_demo 0.2.1 from the official repository — until all three of its
recorded hashes reproduced exactly:

    hashes["variants/<v>"] = sha256( concat over files sorted by path of
                                     "<path within variant>\\0<sha256 of contents>\\n" )
    hashes["variants"]     = sha256( concat over variants sorted by name of
                                     "<variant>\\0<that variant's hash>\\n" )
    hashes["root"]         = sha256( "variants\\0<the variants hash>\\n" )

    pack_lgx.py <out.lgx> <variant> <staging-dir> <manifest.json> [--metadata <file>]

Every file under the staging directory goes into the variant. Paths are stored with forward slashes
and sorted, so the same inputs give the same archive.
"""
from __future__ import annotations

import argparse
import gzip
import hashlib
import io
import json
import os
import sys
import tarfile

DESCRIPTIVE = (
    "author", "category", "dependencies", "description", "homepage",
    "icon", "license", "name", "type", "version", "view",
)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def collect(stage: str) -> dict[str, bytes]:
    out: dict[str, bytes] = {}
    for root, _, names in os.walk(stage):
        for n in names:
            full = os.path.join(root, n)
            rel = os.path.relpath(full, stage).replace(os.sep, "/")
            with open(full, "rb") as f:
                out[rel] = f.read()
    if not out:
        sys.exit(f"FATAL: {stage} is empty — there is nothing to package")
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("variant")
    ap.add_argument("stage")
    ap.add_argument("manifest")
    ap.add_argument("--metadata", help="metadata.json to place inside the variant")
    a = ap.parse_args()

    try:
        manifest = json.load(open(a.manifest, encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as e:
        sys.exit(f"FATAL: cannot read {a.manifest}: {e}")

    files = collect(a.stage)
    if a.metadata:
        with open(a.metadata, "rb") as f:
            files["metadata.json"] = f.read()

    main_name = manifest.get("main", {}).get(a.variant)
    if not main_name:
        sys.exit(f"FATAL: {a.manifest} names no `main` for variant {a.variant}")
    if main_name not in files:
        sys.exit(f"FATAL: main is {main_name} but that file is not in {a.stage}")
    icon = manifest.get("icon")
    if manifest.get("type") == "ui_qml":
        if not icon:
            sys.exit("FATAL: a ui_qml package needs an icon")
        if icon not in files:
            sys.exit(f"FATAL: icon is {icon} but that file is not in {a.stage} — in the 0.3.0 "
                     "layout the icon lives inside the variant, not in a top-level assets/")
        view = manifest.get("view")
        if not view or view not in files:
            sys.exit(f"FATAL: a ui_qml package needs `view`; {view!r} is not in {a.stage}")
        if "qml/qmldir" not in files:
            sys.exit("FATAL: qml/qmldir is missing — Qt cannot register a QML module without one")

    variant_hash = sha("".join(f"{p}\0{sha(d)}\n" for p, d in sorted(files.items())).encode())
    variants_hash = sha(f"{a.variant}\0{variant_hash}\n".encode())
    root_hash = sha(f"variants\0{variants_hash}\n".encode())

    out_manifest = {k: manifest[k] for k in DESCRIPTIVE if k in manifest}
    out_manifest["main"] = manifest["main"]
    out_manifest["manifestVersion"] = "0.3.0"
    out_manifest["hashes"] = {
        "root": root_hash,
        "variants": variants_hash,
        f"variants/{a.variant}": variant_hash,
    }

    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w") as tar:
        def add_dir(name: str) -> None:
            ti = tarfile.TarInfo(name)
            ti.type = tarfile.DIRTYPE
            ti.mode = 0o755
            tar.addfile(ti)

        def add(name: str, data: bytes, mode: int = 0o644) -> None:
            ti = tarfile.TarInfo(name)
            ti.size = len(data)
            ti.mode = mode
            tar.addfile(ti, io.BytesIO(data))

        add("manifest.json", json.dumps(out_manifest, indent=2, sort_keys=True).encode() + b"\n")
        add_dir("variants")
        add_dir(f"variants/{a.variant}")
        seen: set[str] = set()
        for path, data in sorted(files.items()):
            parent = os.path.dirname(path)
            if parent and parent not in seen:
                add_dir(f"variants/{a.variant}/{parent}")
                seen.add(parent)
            executable = path.endswith((".dylib", ".so"))
            add(f"variants/{a.variant}/{path}", data, 0o755 if executable else 0o644)

    with gzip.open(a.out, "wb") as gz:
        gz.write(buf.getvalue())

    size = os.path.getsize(a.out)
    with open(a.out, "rb") as f:
        digest = sha(f.read())
    print(f"wrote {a.out}")
    print(f"  variant  {a.variant}, {len(files)} files")
    print(f"  bytes    {size}")
    print(f"  sha256   {digest}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
