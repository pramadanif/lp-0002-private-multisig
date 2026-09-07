#!/usr/bin/env python3
"""Merge our descriptive metadata into the manifest.json inside an .lgx archive.

An .lgx is a gzipped tar. `lgx add` writes its own manifest, which drops the fields we filled in
(author, licence, homepage, description). An earlier version of this script put ours back by
replacing the file wholesale — and that made `lgx verify` fail, because the manifest lgx writes also
carries the variant list and the content hashes of everything in the package. Overwriting it
declared six variants for a package holding one, and removed every hash.

So this merges: lgx's manifest is the base, and only descriptive fields are taken from ours. The
package's own structure — `main`, variants, hashes, manifestVersion — is never touched, because lgx
is the thing that knows it.

    patch_lgx_manifest.py <pkg.lgx> <manifest.json>
"""
import gzip
import io
import json
import shutil
import sys
import tarfile


def main() -> int:
    if len(sys.argv) != 3:
        print(f"usage: {sys.argv[0]} <pkg.lgx> <manifest.json>", file=sys.stderr)
        return 2
    lgx_path, manifest_path = sys.argv[1], sys.argv[2]

    try:
        with open(manifest_path, "rb") as f:
            ours = json.loads(f.read())
    except (OSError, json.JSONDecodeError) as e:
        print(f"FATAL: cannot read {manifest_path}: {e}", file=sys.stderr)
        return 1

    # Everything else in the manifest describes the package's structure and belongs to lgx.
    DESCRIPTIVE = ("author", "category", "description", "homepage", "license", "version")

    with gzip.open(lgx_path, "rb") as gz:
        raw = gz.read()

    out = io.BytesIO()
    replaced = False
    with tarfile.open(fileobj=io.BytesIO(raw)) as src, \
         tarfile.open(fileobj=out, mode="w") as dst:
        for member in src.getmembers():
            if member.name.lstrip("./") == "manifest.json":
                base_f = src.extractfile(member)
                if base_f is None:
                    print("FATAL: manifest.json is not a regular file", file=sys.stderr)
                    return 1
                try:
                    merged = json.loads(base_f.read())
                except json.JSONDecodeError as e:
                    print(f"FATAL: the manifest lgx wrote is not valid JSON: {e}", file=sys.stderr)
                    return 1
                for key in DESCRIPTIVE:
                    if key in ours:
                        merged[key] = ours[key]
                manifest = json.dumps(merged, indent=2, sort_keys=True).encode()
                member.size = len(manifest)
                dst.addfile(member, io.BytesIO(manifest))
                replaced = True
            else:
                extracted = src.extractfile(member)
                dst.addfile(member, extracted)

    if not replaced:
        print("FATAL: no manifest.json at the root of the archive", file=sys.stderr)
        return 1

    shutil.copyfile(lgx_path, lgx_path + ".bak")
    with gzip.open(lgx_path, "wb") as gz:
        gz.write(out.getvalue())
    print(f"Patched {lgx_path}: merged {len(DESCRIPTIVE)} descriptive fields from {manifest_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
