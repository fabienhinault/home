#!/bin/bash


if [ $# = 0 ]
then
     echo "ERROR: no argument"
    exit 1
fi

if [ ! -f "$1" ]
then
    echo "ERROR: $1 is not a file" 
    exit 1
fi

CSV_FILE_NAME="$(basename "$1")"
CSV_DIR="$(dirname "$1")"
CSV_BASE="$(basename "$1" .csv)"


docker run --rm -it \
    -v "$CSV_DIR":/workspace \
    -w /workspace \
    alpine/sqlite -batch -cmd ".import \"/workspace/$CSV_FILE_NAME\" csv --csv"  "$CSV_BASE.db" ".quit"
