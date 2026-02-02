#!/bin/bash

VERSION=3510200
SQLITE_DOWNLOAD_URL="https://sqlite.org/2026/sqlite-autoconf-$VERSION.tar.gz"

WORK_DIR="tmp"
LIB_NAME="libsqlite3.a"

OS=$(uname -s | tr '[:upper:]' '[:lower:]') # Get OS name (lowercase)
ARCH=$(uname -m)            

OUTPUT_DIR="../deps/sqlite3/lib/${OS}_${ARCH}"

# Create working directory
mkdir -p $WORK_DIR
cd $WORK_DIR

# Download and extract SQLite
wget $SQLITE_DOWNLOAD_URL -O sqlite.tar.gz
tar -xzvf sqlite.tar.gz
cd sqlite-autoconf-*

if [ "$1" == "RELEASE" ]; then
    CFLAGS="-O3" # Release mode with maximum optimization
    echo "Building SQLite in RELEASE mode (CFLAGS=$CFLAGS)"
else
    CFLAGS="-g"  # Debug mode with debugging symbols
    echo "Building SQLite in DEBUG mode (CFLAGS=$CFLAGS)"
fi
# Build SQLite as a static library in release mode
./configure CFLAGS="$CFLAGS"
make clean
make

# Move the static library to the output directory
mkdir -p ../$OUTPUT_DIR
mv ./$LIB_NAME ../$OUTPUT_DIR

# Go back to the original directory and clean up
cd ../../
rm -rf $WORK_DIR

echo "Build complete. Sqlite is located in $OUTPUT_DIR/$LIB_NAME"

