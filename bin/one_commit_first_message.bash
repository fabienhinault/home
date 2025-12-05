#!/bin/bash

PARENT=$(git merge-base HEAD origin/master)
SUBJECT="$(git log --format=%s HEAD "^$PARENT" | tail -n 1)"
NEW_HEAD=$(git commit-tree HEAD: -p "$PARENT" -m "$SUBJECT")
git reset --hard "$NEW_HEAD"
