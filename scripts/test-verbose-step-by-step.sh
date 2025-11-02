#!/bin/bash

# Step-by-step guide to test verbose logging
# This helps you get authentication working first, then test verbose

echo "================================================"
echo "Step-by-Step: Testing Verbose Logging"
echo "================================================"
echo ""

# Step 1: Check authentication
echo "Step 1: Checking authentication..."
if [ -d "$HOME/.gemini/credentials" ]; then
    echo "✓ Credentials found at $HOME/.gemini/credentials"
    HAS_AUTH=true
else
    echo "✗ No credentials found"
    HAS_AUTH=false
fi

if [ -n "$GEMINI_API_KEY" ]; then
    echo "✓ GEMINI_API_KEY is set"
    HAS_AUTH=true
else
    echo "✗ GEMINI_API_KEY not set"
fi

echo ""

# Step 2: Setup authentication if needed
if [ "$HAS_AUTH" = false ]; then
    echo "Step 2: Authentication Required!"
    echo "----------------------------------------"
    echo ""
    echo "You need to authenticate first. Choose ONE option:"
    echo ""
    echo "Option A - Use API Key (Fastest for testing):"
    echo "  1. Get API key from: https://aistudio.google.com/app/apikey"
    echo "  2. Run: export GEMINI_API_KEY='your-key-here'"
    echo "  3. Then run this script again"
    echo ""
    echo "Option B - Use OAuth (Interactive):"
    echo "  1. Run: node packages/cli"
    echo "  2. Select 'Login with Google'"
    echo "  3. Complete browser authentication"
    echo "  4. Exit CLI (Ctrl+C)"
    echo "  5. Then run this script again"
    echo ""
    exit 1
else
    echo "Step 2: ✓ Authentication configured!"
fi

echo ""

# Step 3: Test without verbose
echo "Step 3: Testing WITHOUT --verbose (baseline)"
echo "----------------------------------------"
echo ""
echo "Command: node packages/cli -p \"Say hello in one word\""
echo ""
echo "Expected: Just the response, NO verbose logs"
echo ""
echo "--- OUTPUT ---"
timeout 30 node packages/cli -p "Say hello in one word" 2>&1
EXIT_CODE=$?
echo ""
if [ $EXIT_CODE -ne 0 ]; then
    echo "❌ ERROR: Command failed with exit code $EXIT_CODE"
    echo ""
    echo "This might be an authentication issue. Please:"
    echo "1. Make sure you're authenticated"
    echo "2. Try running: node packages/cli"
    echo "3. Check if the interactive CLI works"
    exit 1
fi

echo "✓ Command succeeded!"
echo ""
sleep 2

# Step 4: Test WITH verbose
echo "Step 4: Testing WITH --verbose"
echo "----------------------------------------"
echo ""
echo "Command: node packages/cli --verbose -p \"Say hello in one word\" 2>&1"
echo ""
echo "Expected: Verbose logs BEFORE the response:"
echo "  [HH:MM:SS] 🚀 Starting API call to gemini-..."
echo "  [HH:MM:SS] ✅ API call to gemini-... completed in X.XXs"
echo "  Response text"
echo ""
echo "--- OUTPUT ---"
timeout 30 node packages/cli --verbose -p "Say hello in one word" 2>&1 | tee /tmp/verbose-test.log
EXIT_CODE=$?
echo ""

if [ $EXIT_CODE -ne 0 ]; then
    echo "❌ ERROR: Command failed with exit code $EXIT_CODE"
    exit 1
fi

# Step 5: Verify verbose logs
echo ""
echo "Step 5: Verifying verbose logs..."
echo "----------------------------------------"
echo ""

if grep -q "🚀" /tmp/verbose-test.log; then
    echo "✅ SUCCESS! Verbose logging is WORKING!"
    echo ""
    echo "Found verbose logs:"
    grep -E "🚀|✅|❌" /tmp/verbose-test.log
    echo ""
    echo "================================================"
    echo "VERBOSE LOGGING TEST: PASSED ✓"
    echo "================================================"
else
    echo "❌ FAILED: No verbose logs found!"
    echo ""
    echo "Full output was:"
    cat /tmp/verbose-test.log
    echo ""
    echo "Debugging info:"
    echo "- Check if Config.getVerboseLogging() returns true"
    echo "- Check if LoggingContentGenerator.setEnabled() is called"
    echo "- Verify RealtimeCliLogger.isEnabled() returns true"
    echo ""
    echo "================================================"
    echo "VERBOSE LOGGING TEST: FAILED ✗"
    echo "================================================"
fi

# Cleanup
rm -f /tmp/verbose-test.log
