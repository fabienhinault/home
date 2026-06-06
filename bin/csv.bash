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

CSV_DIR="$(realpath "$(dirname "$1")")"
CSV_BASE="$(basename "$1" .csv)"

if [ ! -f "$CSV_DIR/$CSV_BASE.db" ]
then
    csv_import "$1"
fi


if [ $# = 1 ]
then
    docker run --rm -it \
        -e SQLITE_HISTORY=/.csv/.sqlite_history \
        -v "${HOME}/.csv":/.csv \
        -v "$CSV_DIR":/workspace \
        -w /workspace \
        alpine/sqlite -interactive  "$CSV_BASE.db"
    exit 0
fi

if [ ! -f "$2" ]
then
    echo "ERROR: $2 is not a file" 
    exit 1
fi

echo ".mode box" > "$CSV_DIR/tmp.sql"
sed "s/{}/$3/" "$2" >> "$CSV_DIR/tmp.sql"
docker run --rm -it \
    -v "$CSV_DIR":/workspace \
    -w /workspace \
    alpine/sqlite -batch -init /workspace/tmp.sql "$CSV_BASE.db" ".quit"
