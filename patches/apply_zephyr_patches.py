#!/usr/bin/env python3
# Copyright (c) 2026
# SPDX-License-Identifier: Apache-2.0
"""Apply the SlimeNRF Zephyr patch series to the Zephyr tree, idempotently.

The list passed on the command line is an ordered series: patch N applies on
top of patches 1..N-1, and several patches may touch the same file. A single
`git apply` check cannot classify such a patch once a later patch in the series
has changed the surrounding lines: on an already patched tree the patch is
neither applicable nor reverse-applicable, which is indistinguishable from a
genuine conflict.

This helper therefore simulates the whole series on a private index and
compares every intermediate state with the worktree, which yields the number of
patches already applied:

    0 .. n-1   apply the remaining patches (a partially applied tree recovers)
    n          nothing to do, the series is fully applied

A worktree that matches no simulated state (unrelated local edits, a moved base
revision, a hand-edited patched file) fails the build instead of guessing.
"""

import argparse
import os
import subprocess
import sys
import tempfile


def run(args, env=None, check=True):
    full = dict(os.environ)
    full.update(env or {})
    proc = subprocess.run(args, capture_output=True, text=True, env=full)
    if check and proc.returncode != 0:
        sys.stderr.write(proc.stdout + proc.stderr)
        raise SystemExit("ERROR: {} failed with status {}".format(
            " ".join(args), proc.returncode))
    return proc


def git(zephyr_base, *args, **kwargs):
    return run(["git", "-C", zephyr_base] + list(args), **kwargs)


def patch_targets(patch):
    """Return the tree-relative paths a patch touches, in first-seen order."""
    paths = []
    with open(patch, encoding="utf-8", errors="replace") as handle:
        for line in handle:
            for prefix in ("+++ b/", "--- a/"):
                if line.startswith(prefix):
                    path = line[len(prefix):].strip()
                    if path != "/dev/null" and path not in paths:
                        paths.append(path)
    return paths


def worktree_matches_index(zephyr_base, paths, env):
    """True when every path in the private index equals the worktree copy."""
    proc = git(zephyr_base, "diff", "--quiet", "--", *paths, env=env, check=False)
    if proc.returncode not in (0, 1):
        sys.stderr.write(proc.stdout + proc.stderr)
        raise SystemExit("ERROR: git diff failed with status {}".format(
            proc.returncode))
    return proc.returncode == 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--zephyr-base", required=True,
                        help="root of the Zephyr tree the patches apply to")
    parser.add_argument("--patch", action="append", default=[], required=True,
                        help="patch file, in series order (repeatable)")
    args = parser.parse_args()

    zephyr_base = os.path.abspath(args.zephyr_base)
    patches = [os.path.abspath(patch) for patch in args.patch]

    for patch in patches:
        if not os.path.isfile(patch):
            raise SystemExit("ERROR: missing Zephyr patch: {}".format(patch))

    targets = []
    for patch in patches:
        for path in patch_targets(patch):
            if path not in targets:
                targets.append(path)

    with tempfile.TemporaryDirectory() as tmp:
        # A private index keeps the simulation away from the user's index and
        # worktree, and `git apply --cached` needs exactly the state that a
        # real `git apply` would produce.
        env = {"GIT_INDEX_FILE": os.path.join(tmp, "index")}
        git(zephyr_base, "read-tree", "HEAD", env=env)

        applied = []
        if worktree_matches_index(zephyr_base, targets, env):
            applied.append(0)

        for count, patch in enumerate(patches, start=1):
            proc = git(zephyr_base, "apply", "--cached", patch, env=env,
                       check=False)
            if proc.returncode != 0:
                sys.stderr.write(proc.stdout + proc.stderr)
                raise SystemExit(
                    "ERROR: {} does not apply on top of the preceding patches; "
                    "the patch series or its base revision changed".format(patch))
            if worktree_matches_index(zephyr_base, targets, env):
                applied.append(count)

    if not applied:
        raise SystemExit(
            "ERROR: the Zephyr tree matches neither revision {} nor any state of "
            "the SlimeNRF patch series; conflicting paths: {}".format(
                git(zephyr_base, "rev-parse", "--short", "HEAD").stdout.strip(),
                ", ".join(targets)))

    done = max(applied)

    for index, patch in enumerate(patches):
        if index < done:
            print("Zephyr patch already applied: {}".format(patch))
        else:
            git(zephyr_base, "apply", patch)
            print("Applied Zephyr patch: {}".format(patch))

    if done == len(patches):
        print("Zephyr patch series is up to date ({} patches)".format(done))
    elif done:
        print("Zephyr patch series resumed from patch {} of {}".format(
            done + 1, len(patches)))


if __name__ == "__main__":
    main()
