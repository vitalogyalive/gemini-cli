# Correct Way to Use Verbose Logging in Development

## ✅ The RIGHT Way (What Works)

```bash
# This is the CORRECT alias
alias gemini-dev="node /mnt/c/dev/gemini-cli/packages/cli"

# With verbose logging
alias gemini-dev-v="node /mnt/c/dev/gemini-cli/packages/cli --verbose"
```

## Usage

```bash
# Launch with OAuth + verbose logging
gemini-dev --verbose

# Or use the verbose alias
gemini-dev-v

# With a prompt
gemini-dev --verbose -p "Say hello"
```

## ❌ What DOESN'T Work

```bash
# DON'T use scripts/start.js (doesn't work properly)
node scripts/start.js --verbose  # ❌ Wrong!

# USE packages/cli directly instead
node packages/cli --verbose       # ✅ Correct!
```

## Why Use `packages/cli` Instead of `scripts/start.js`?

- `packages/cli` is the actual built CLI application
- `scripts/start.js` is a development wrapper with extra overhead
- Direct `packages/cli` usage gives you the real CLI behavior
- OAuth authentication dialog works correctly
- All features work as expected

## Complete Setup for Development

Add to your `~/.bashrc` or `~/.zshrc`:

```bash
# Set the base path
export GEMINI_DEV_PATH="/mnt/c/dev/gemini-cli"

# Correct aliases
alias gemini-dev="node $GEMINI_DEV_PATH/packages/cli"
alias gemini-dev-v="node $GEMINI_DEV_PATH/packages/cli --verbose"
alias gemini-dev-vv="node $GEMINI_DEV_PATH/packages/cli --verbose --debug"

# Then reload
source ~/.bashrc
```

## Testing Verbose Logging

### Interactive Mode with OAuth:

```bash
# Launch the CLI
gemini-dev-v

# You'll see:
# 1. Authentication dialog (select "Login with Google")
# 2. OAuth flow in browser
# 3. CLI prompt
# 4. When you send a message, you'll see verbose logs:

gemini> Say hello

[14:23:45] 🚀 Starting API call to gemini-2.0-flash-exp
[14:23:47] ✅ API call to gemini-2.0-flash-exp completed in 1.85s

Hello! 👋
```

### Non-Interactive Mode:

```bash
# One-shot command with verbose
gemini-dev --verbose -p "Write a Python hello world"

# You'll see the verbose logs:
[14:23:45] 🚀 Starting API call to gemini-2.0-flash-exp
[14:23:47] ✅ API call to gemini-2.0-flash-exp completed in 1.85s

# Followed by the response
```

## Full Example Session

```bash
# 1. Make sure build is current
cd /mnt/c/dev/gemini-cli
npm run build

# 2. Launch with verbose
gemini-dev-v

# 3. Choose "Login with Google" from the menu
┌─────────────────────────────────────┐
│ Choose authentication method:       │
├─────────────────────────────────────┤
│ ● Login with Google                 │
│   Use Gemini API Key                │
│   Vertex AI                         │
└─────────────────────────────────────┘

# 4. Complete OAuth in browser

# 5. Use the CLI - you'll see verbose logs for every API call!
gemini> test the verbose logging

[14:23:45] 🚀 Starting API call to gemini-2.0-flash-exp
[14:23:47] ✅ API call to gemini-2.0-flash-exp completed in 1.85s

I can see the verbose logging is working! The API call took 1.85 seconds.
```

## Troubleshooting

### Issue: "Command not found: gemini-dev"

**Solution:**

```bash
# Reload your shell config
source ~/.bashrc  # or source ~/.zshrc

# Or use the full command
node /mnt/c/dev/gemini-cli/packages/cli --verbose
```

### Issue: "Build is out of date"

**Solution:**

```bash
cd /mnt/c/dev/gemini-cli
npm run build
```

### Issue: "No verbose logs appear"

**Check:**

```bash
# 1. Verify the flag is recognized
node /mnt/c/dev/gemini-cli/packages/cli --help | grep verbose

# Should show:
# -v, --verbose    Enable verbose logging...

# 2. Make sure you're using --verbose flag
gemini-dev --verbose  # ✅ Correct
gemini-dev -v         # ✅ Also correct
gemini-dev            # ❌ Won't show verbose logs
```

### Issue: "Authentication doesn't work"

**Solution:**

```bash
# Clear any conflicting environment variables
unset GEMINI_API_KEY
unset GOOGLE_API_KEY

# Clear cached credentials if needed
rm -rf ~/.gemini/credentials/

# Launch
gemini-dev-v
```

## Summary

### ✅ CORRECT Command:

```bash
node /mnt/c/dev/gemini-cli/packages/cli --verbose
```

### ❌ INCORRECT Command:

```bash
node /mnt/c/dev/gemini-cli/scripts/start.js --verbose
```

### 🎯 Best Practice Aliases:

```bash
alias gemini-dev="node /mnt/c/dev/gemini-cli/packages/cli"
alias gemini-dev-v="node /mnt/c/dev/gemini-cli/packages/cli --verbose"
```

### 🚀 Quick Test:

```bash
gemini-dev-v -p "test"
# Should show:
# [timestamp] 🚀 Starting API call...
# [timestamp] ✅ API call completed...
```

That's it! The key is using `packages/cli` directly, not the `scripts/start.js`
wrapper. 🎉
