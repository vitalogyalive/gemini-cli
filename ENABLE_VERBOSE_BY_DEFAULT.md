# Enable Verbose Logging by Default

## 🎯 Quick Solution

Instead of typing `--verbose` every time, enable it by default with an
environment variable:

```bash
# Add to ~/.bashrc or ~/.zshrc
export GEMINI_VERBOSE=true

# Reload your shell
source ~/.bashrc

# Now verbose logging is ALWAYS enabled!
gemini-dev -p "test" 2>&1
```

No more `--verbose` flag needed! 🎉

## Why This is Better

**Before** (typing `--verbose` every time):

```bash
gemini-dev --verbose -p "test" 2>&1
gemini-dev --verbose -p "another test" 2>&1
gemini-dev --verbose -p "yet another test" 2>&1
```

**After** (set once, works forever):

```bash
# Set once in ~/.bashrc
export GEMINI_VERBOSE=true

# Then just use normally
gemini-dev -p "test" 2>&1
gemini-dev -p "another test" 2>&1
gemini-dev -p "yet another test" 2>&1
```

## Complete Setup for Development

### Step 1: Add to Shell Configuration

Edit your `~/.bashrc` or `~/.zshrc`:

```bash
# Gemini CLI Development Settings
export GEMINI_VERBOSE=true  # Always show verbose logs
export GEMINI_DEV_PATH="/mnt/c/dev/gemini-cli"

# Aliases
alias gemini-dev="node $GEMINI_DEV_PATH/packages/cli"
alias gemini-dev-stderr="node $GEMINI_DEV_PATH/packages/cli 2>&1"

# Note: With GEMINI_VERBOSE=true, no need for --verbose flag!
```

### Step 2: Reload Shell

```bash
source ~/.bashrc  # or source ~/.zshrc
```

### Step 3: Test

```bash
# Just run normally - verbose is enabled automatically!
gemini-dev -p "Say hello" 2>&1
```

You should see:

```
[timestamp] 🚀 Starting API call to gemini-2.0-flash-exp
[timestamp] ✅ API call completed in X.XXs
Hello!
```

## How It Works

The CLI checks for verbose logging in this order:

1. **Command-line flag**: `--verbose` (highest priority)
2. **Environment variable**: `GEMINI_VERBOSE=true` (default for dev)
3. **Default**: `false` (if nothing set)

So you can:

- Set `GEMINI_VERBOSE=true` for always-on verbose
- Override with `--verbose` if needed (but not necessary)
- Disable temporarily by unsetting the env var

## Configuration Options

### Option 1: Always Verbose (Recommended for Development)

```bash
# ~/.bashrc
export GEMINI_VERBOSE=true
```

Result: Every command shows verbose logs automatically.

### Option 2: Verbose Only in Specific Terminal

```bash
# Don't add to ~/.bashrc
# Just set in your current terminal session
export GEMINI_VERBOSE=true

# Verbose only for this terminal window
gemini-dev -p "test" 2>&1
```

### Option 3: Per-Command Verbose

```bash
# Don't set environment variable
# Use inline for specific commands
GEMINI_VERBOSE=true gemini-dev -p "test" 2>&1
```

### Option 4: Conditional Verbose

```bash
# ~/.bashrc
# Enable verbose only when in dev directory
if [ "$PWD" = "/mnt/c/dev/gemini-cli" ]; then
  export GEMINI_VERBOSE=true
fi
```

## Disable Verbose Temporarily

If you have `GEMINI_VERBOSE=true` set but want to disable it once:

```bash
# Unset for current command
GEMINI_VERBOSE=false gemini-dev -p "test"

# Or unset for session
unset GEMINI_VERBOSE
gemini-dev -p "test"
```

## Troubleshooting

### "Verbose logs not appearing"

Check if environment variable is set:

```bash
echo $GEMINI_VERBOSE
# Should output: true
```

If empty:

```bash
export GEMINI_VERBOSE=true
```

### "Logs still not showing"

Make sure you're merging stderr with stdout:

```bash
# Add 2>&1 at the end
gemini-dev -p "test" 2>&1
```

Or update your alias:

```bash
alias gemini-dev="node /path/to/packages/cli 2>&1"
```

### "Want to see if it's working"

Run the test script:

```bash
cd /mnt/c/dev/gemini-cli
bash scripts/test-env-verbose.sh
```

## Complete Example

```bash
# 1. Edit ~/.bashrc
nano ~/.bashrc

# 2. Add these lines
export GEMINI_VERBOSE=true
export GEMINI_DEV_PATH="/mnt/c/dev/gemini-cli"
alias gemini-dev="node $GEMINI_DEV_PATH/packages/cli 2>&1"

# 3. Save and reload
source ~/.bashrc

# 4. Test - verbose logs appear automatically!
gemini-dev -p "Say hello"

# Output:
# [timestamp] 🚀 Starting API call to gemini-2.0-flash-exp
# [timestamp] ✅ API call completed in 1.23s
# Hello!
```

## Environment Variables Summary

| Variable          | Default | Description                          |
| ----------------- | ------- | ------------------------------------ |
| `GEMINI_VERBOSE`  | `false` | Enable verbose logging by default    |
| `GEMINI_API_KEY`  | (none)  | API key for authentication           |
| `GEMINI_DEV_PATH` | (none)  | Path to gemini-cli (for convenience) |

## Priority Order

When determining if verbose should be enabled:

```
1. --verbose flag (if present) ✅ Highest priority
   ↓
2. GEMINI_VERBOSE env var (if set)
   ↓
3. false (default)
```

So `--verbose` flag always wins, even if `GEMINI_VERBOSE=false`.

## Recommended for Different Use Cases

### For Active Development

```bash
# Always verbose
export GEMINI_VERBOSE=true
```

### For Testing/QA

```bash
# Verbose on demand
alias gemini-verbose="GEMINI_VERBOSE=true gemini-dev"
```

### For Production/Normal Use

```bash
# No verbose by default
# (don't set GEMINI_VERBOSE)
```

## Summary

**Best Practice for Development:**

1. Set `export GEMINI_VERBOSE=true` in `~/.bashrc`
2. Set up alias: `alias gemini-dev="node /path/to/packages/cli 2>&1"`
3. Just run: `gemini-dev -p "your prompt"`
4. Verbose logs appear automatically! 🚀

**No more typing `--verbose` every single time!** ✨
