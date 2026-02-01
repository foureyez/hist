#!/bin/bash
# Smoke test for cmdh - validates basic functionality

set -e

echo "Starting smoke test..."

# Create a temporary config directory for testing
export TEMP_CONFIG="$GITHUB_WORKSPACE/tmp_config"
if [ -z "$GITHUB_WORKSPACE" ]; then
  TEMP_CONFIG="$(pwd)/tmp_config"
fi

# Clean up any previous test artifacts
rm -rf "$TEMP_CONFIG"
mkdir -p "$TEMP_CONFIG"

# Set XDG_CONFIG_HOME to use temporary directory
export XDG_CONFIG_HOME="$TEMP_CONFIG"
export HOME="$TEMP_CONFIG"

echo "Using temporary config directory: $TEMP_CONFIG"

# Check if cmdh binary exists
if [ ! -f "./cmdh" ]; then
  echo "Error: cmdh binary not found"
  exit 1
fi

echo "Step 1: Initialize database by running cmdh version"
./cmdh version || true

# Check if database was created
DB_PATH="$TEMP_CONFIG/.config/cmdh/sqlite.db"
if [ ! -f "$DB_PATH" ]; then
  echo "Error: Database file was not created at $DB_PATH"
  exit 1
fi
echo "✓ Database initialized successfully"

echo "Step 2: Add a test command"
./cmdh add "echo hello" 0
if [ $? -ne 0 ]; then
  echo "Error: Failed to add command"
  exit 1
fi
echo "✓ Command added successfully"

echo "Step 3: Add another test command"
./cmdh add "ls -la" 0
if [ $? -ne 0 ]; then
  echo "Error: Failed to add second command"
  exit 1
fi
echo "✓ Second command added successfully"

echo "Step 4: List commands (non-interactive test)"
# Since list command uses TUI, we'll just verify it runs without error
# In a real environment, this would be interactive
timeout 1 ./cmdh list 2>/dev/null || true
echo "✓ List command executed"

echo "Step 5: Validate database contents"
# Use sqlite3 if available to verify data
if command -v sqlite3 &> /dev/null; then
  COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM cmd_history;")
  if [ "$COUNT" -ge 2 ]; then
    echo "✓ Database contains $COUNT commands (expected at least 2)"
  else
    echo "Error: Database should contain at least 2 commands, but found $COUNT"
    exit 1
  fi
  
  # Check if our test command is in the database
  RESULT=$(sqlite3 "$DB_PATH" "SELECT cmd FROM cmd_history WHERE cmd LIKE '%echo hello%';")
  if [ -n "$RESULT" ]; then
    echo "✓ Test command found in database: $RESULT"
  else
    echo "Error: Test command 'echo hello' not found in database"
    exit 1
  fi
else
  echo "⚠ sqlite3 not available, skipping database content validation"
fi

echo "Step 6: Test invalid exit code (should fail)"
./cmdh add "test command" "invalid" 2>/dev/null
if [ $? -eq 0 ]; then
  echo "Error: Command should have failed with invalid exit code"
  exit 1
fi
echo "✓ Invalid exit code properly rejected"

# Clean up
rm -rf "$TEMP_CONFIG"

echo ""
echo "✅ All smoke tests passed!"
exit 0
