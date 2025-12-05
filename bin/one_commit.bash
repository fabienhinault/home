#!/bin/bash

if [ $# -eq 0 ]
  then
    echo "No arguments supplied"
    exit 1
fi

PARENT=$(git merge-base HEAD origin/master)
NEW_HEAD=$(git commit-tree HEAD: -p "$(git merge-base HEAD origin/master)" -m "$1")
git reset --hard "$NEW_HEAD"
