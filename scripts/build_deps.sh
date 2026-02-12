#!/bin/bash

VERSION=3510200
SQLITE_DOWNLOAD_URL="https://sqlite.org/2026/sqlite-autoconf-$VERSION.tar.gz"

WORK_DIR="tmp"
LIB_NAME="libsqlite3.a"

OS=$(uname -s | tr '[:upper:]' '[:lower:]') # darwin, linux
ARCH=$(uname -m) # x86_64, arm64

OUTPUT_DIR="../deps/sqlite3/lib/${OS}_${ARCH}"

# Create working directory
mkdir -p $WORK_DIR
cd $WORK_DIR || return  

wget $SQLITE_DOWNLOAD_URL -O sqlite.tar.gz
tar -xzvf sqlite.tar.gz
cd sqlite-autoconf-* || return

if [ "$1" == "RELEASE" ]; then
    CFLAGS="-O3" 
    echo "Building SQLite in RELEASE mode (CFLAGS=$CFLAGS)"
else
    CFLAGS="-g"  
    echo "Building SQLite in DEBUG mode (CFLAGS=$CFLAGS)"
fi


./configure CFLAGS="$CFLAGS"
make clean
make

mkdir -p ../"$OUTPUT_DIR"
mv ./$LIB_NAME ../"$OUTPUT_DIR"

# Go back and cleanup the work dir
cd ../../
rm -rf $WORK_DIR

echo "Build complete. Sqlite is located in $OUTPUT_DIR/$LIB_NAME"

