#!/bin/bash

# Script to test verbose logging
# This will show the difference between normal and verbose mode

echo "======================================"
echo "Testing Verbose Logging Feature"
echo "======================================"
echo ""

# Check if build is current
if [ ! -d "packages/cli/dist" ]; then
    echo "❌ Build not found. Run 'npm run build' first."
    exit 1
fi

# Test prompt
TEST_PROMPT="Say hello in one word"

echo "📋 Test Setup:"
echo "  - Prompt: '$TEST_PROMPT'"
echo "  - Build: packages/cli"
echo ""

# Check if authenticated
if [ ! -d "$HOME/.gemini/credentials" ]; then
    echo "⚠️  Warning: No credentials found at ~/.gemini/credentials"
    echo "   You may need to authenticate first."
    echo ""
fi

# Test 1: WITHOUT verbose (redirect stderr to show what happens)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 1: WITHOUT --verbose flag"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Command: node packages/cli -p \"$TEST_PROMPT\""
echo ""
echo "Expected: NO verbose logs (only the response)"
echo ""
echo "--- Output (stdout) ---"
timeout 30 node packages/cli -p "$TEST_PROMPT" 2>/tmp/test-stderr.log
echo ""
echo "--- Stderr (verbose logs should be empty) ---"
cat /tmp/test-stderr.log | grep -E "🚀|✅|❌" || echo "(No verbose logs - this is correct!)"
echo ""

sleep 2

# Test 2: WITH verbose
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 2: WITH --verbose flag"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Command: node packages/cli --verbose -p \"$TEST_PROMPT\""
echo ""
echo "Expected: Verbose logs with timestamps + response"
echo ""
echo "--- Output (stdout) ---"
timeout 30 node packages/cli --verbose -p "$TEST_PROMPT" 2>/tmp/test-verbose-stderr.log
echo ""
echo "--- Stderr (verbose logs SHOULD appear here) ---"
cat /tmp/test-verbose-stderr.log | grep -E "🚀|✅|❌" || echo "(❌ ERROR: No verbose logs found!)"
echo ""

# Summary
echo ""
echo "======================================"
echo "Summary"
echo "======================================"
echo ""

# Check if verbose logs were found
if grep -q "🚀" /tmp/test-verbose-stderr.log; then
    echo "✅ VERBOSE LOGGING IS WORKING!"
    echo ""
    echo "Verbose logs detected:"
    grep -E "🚀|✅|❌" /tmp/test-verbose-stderr.log
else
    echo "❌ VERBOSE LOGGING IS NOT WORKING!"
    echo ""
    echo "No verbose logs found in stderr."
    echo "This means the --verbose flag is not being processed correctly."
fi

echo ""
echo "======================================"
echo ""

# Cleanup
rm -f /tmp/test-stderr.log /tmp/test-verbose-stderr.log
