#!/usr/bin/env bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "Running smoke tests..."

# Setup temporary config directory
TMP_CONFIG=$(mktemp -d -t cmdh-test-config-XXXXXX)
export XDG_CONFIG_HOME="$TMP_CONFIG"

echo "Using temporary config: $TMP_CONFIG"

# Ensure cmdh binary exists
if [ ! -f "./cmdh" ]; then
    echo -e "${RED}FAIL: cmdh binary not found${NC}"
    exit 1
fi

# Test 1: Add a command
echo "Test 1: Adding a command..."
./cmdh add "echo hello" 0
if [ $? -ne 0 ]; then
    echo -e "${RED}FAIL: Could not add command${NC}"
    rm -rf "$TMP_CONFIG"
    exit 1
fi
echo -e "${GREEN}PASS: Command added successfully${NC}"

# Test 2: Verify DB file exists
echo "Test 2: Checking if database file exists..."
DB_FILE="$TMP_CONFIG/.config/cmdh/sqlite.db"
if [ ! -f "$DB_FILE" ]; then
    echo -e "${RED}FAIL: Database file not created at $DB_FILE${NC}"
    rm -rf "$TMP_CONFIG"
    exit 1
fi
echo -e "${GREEN}PASS: Database file exists${NC}"

# Test 3: Verify table exists and has data
echo "Test 3: Verifying table and data..."
if command -v sqlite3 &> /dev/null; then
    COUNT=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM cmd_history;")
    if [ "$COUNT" -lt 1 ]; then
        echo -e "${RED}FAIL: No data in cmd_history table${NC}"
        rm -rf "$TMP_CONFIG"
        exit 1
    fi
    echo -e "${GREEN}PASS: Table contains data (count: $COUNT)${NC}"
else
    echo "sqlite3 not available, skipping data verification"
fi

# Test 4: Add another command with different exit code
echo "Test 4: Adding command with non-zero exit code..."
./cmdh add "false" 1
if [ $? -ne 0 ]; then
    echo -e "${RED}FAIL: Could not add command with exit code 1${NC}"
    rm -rf "$TMP_CONFIG"
    exit 1
fi
echo -e "${GREEN}PASS: Command with exit code 1 added${NC}"

# Test 5: Test invalid exit code (should fail gracefully)
echo "Test 5: Testing invalid exit code..."
./cmdh add "test" "invalid" 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${RED}FAIL: Should have rejected invalid exit code${NC}"
    rm -rf "$TMP_CONFIG"
    exit 1
fi
echo -e "${GREEN}PASS: Invalid exit code rejected${NC}"

# Cleanup
rm -rf "$TMP_CONFIG"

echo -e "${GREEN}All smoke tests passed!${NC}"
exit 0
