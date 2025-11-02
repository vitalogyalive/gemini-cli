# Debugging Verbose Logging in Development

## Problem

When running `gemini-dev-verbose`, you see version info but the CLI doesn't
launch.

## Common Causes & Solutions

### 1. Missing API Authentication

The CLI needs API credentials to work. Check if you have authentication set up:

```bash
# Check if you have API key or authentication configured
ls ~/.gemini/

# If no directory exists, you need to set up authentication
```

**Solution**: Set up authentication first:

```bash
# Option A: Use API key
export GEMINI_API_KEY="your-api-key-here"

# Option B: Use gcloud authentication
gcloud auth application-default login

# Then try again
node scripts/start.js --verbose -p "Hello world"
```

### 2. Interactive Mode Requires TTY

When launching without a prompt, the CLI expects an interactive terminal.

**Test Cases**:

```bash
# ✅ Non-interactive mode with prompt (should work)
node scripts/start.js --verbose -p "Write hello world in Python"

# ✅ Interactive mode (launches the CLI interface)
node scripts/start.js --verbose

# ❌ May not work without proper TTY/authentication
echo "test" | node scripts/start.js --verbose
```

### 3. Verify Verbose Logging is Working

To test if verbose logging is actually enabled:

```bash
# Run with a simple prompt and watch for logs
node scripts/start.js --verbose -p "Say hello" 2>&1 | tee output.log

# You should see logs like:
# [HH:MM:SS] 🚀 Starting API call to gemini-2.0-flash-exp
# [HH:MM:SS] ✅ API call to gemini-2.0-flash-exp completed in X.XXs
```

### 4. Check Build Status

Make sure the build is current:

```bash
npm run build
```

### 5. Test with Different Flags

```bash
# Test 1: Just version (should exit quickly)
node scripts/start.js --version

# Test 2: Help (should show options including --verbose)
node scripts/start.js --help | grep verbose

# Test 3: Non-interactive with verbose
node scripts/start.js --verbose -p "test prompt"

# Test 4: Interactive with verbose
node scripts/start.js --verbose
# (Then type a prompt in the CLI)
```

## Recommended Aliases

Add these to your `~/.bashrc` or `~/.zshrc`:

```bash
# For Windows WSL with correct path
export GEMINI_DEV_PATH="/mnt/c/dev/gemini-cli"

# Basic development launch
alias gemini-dev="node $GEMINI_DEV_PATH/scripts/start.js"

# With verbose logging
alias gemini-dev-v="node $GEMINI_DEV_PATH/scripts/start.js --verbose"

# Quick test with verbose
alias gemini-dev-test="node $GEMINI_DEV_PATH/scripts/start.js --verbose -p"

# Usage examples:
# gemini-dev-v                           # Interactive mode with verbose
# gemini-dev-test "your prompt here"     # One-shot with verbose
```

## Full Test Command

Here's a complete test to verify everything works:

```bash
cd /mnt/c/dev/gemini-cli

# 1. Ensure build is up to date
npm run build

# 2. Set API key if needed (or use gcloud auth)
export GEMINI_API_KEY="your-key"

# 3. Test verbose logging with a simple prompt
node scripts/start.js --verbose -p "Say hello in one word" 2>&1

# You should see:
# - Build status check
# - [timestamp] 🚀 Starting API call to gemini-2.0-flash-exp
# - [timestamp] ✅ API call completed...
# - The actual response
```

## Debugging Output

If it still doesn't work, capture full output:

```bash
# Capture all output (stdout + stderr)
node scripts/start.js --verbose -p "test" 2>&1 | tee gemini-debug.log

# Check the log
cat gemini-debug.log
```

## Expected Verbose Log Output

When working correctly, you should see:

```
Checking build status...
Build is up-to-date.
[14:23:45] 🚀 Starting API call to gemini-2.0-flash-exp
[14:23:47] ✅ API call to gemini-2.0-flash-exp completed in 1.85s

Response:
Hello! 👋
```

## If Authentication is the Issue

```bash
# Check authentication status
gcloud auth application-default print-access-token

# If that fails, authenticate:
gcloud auth application-default login

# Or use API key:
echo 'export GEMINI_API_KEY="your-key"' >> ~/.bashrc
source ~/.bashrc
```

## Testing in WSL

If you're using WSL, make sure paths are correct:

```bash
# Check if path exists
ls -la /mnt/c/dev/gemini-cli/scripts/start.js

# If not, adjust your alias paths accordingly
# Find your actual path:
find /mnt/c -name "gemini-cli" -type d 2>/dev/null
```

## Environment Variables for Development

```bash
# Add to ~/.bashrc for development
export GEMINI_DEV_PATH="/mnt/c/dev/gemini-cli"
export NODE_ENV="development"
export DEV="true"

# Optional: Enable debug logs
export DEBUG="1"

# Reload
source ~/.bashrc
```
