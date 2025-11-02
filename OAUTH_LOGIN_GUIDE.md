# Using "Login with Google" (OAuth) with Verbose Logging

## Yes, You CAN Use OAuth Login! 🎉

The "Login with Google" option is **fully supported** and is actually the
**default authentication method** in Gemini CLI. Here's how to use it properly.

## Why the Auth Dialog Might Not Appear

### Common Issues:

1. **Non-Interactive Terminal**
   - The CLI needs a proper TTY (interactive terminal) to show the auth dialog
   - Running in background or through pipes won't work

2. **Authentication Already Cached**
   - If you previously authenticated, credentials are cached
   - The CLI will use cached credentials automatically

3. **Environment Variables Set**
   - If `GEMINI_API_KEY` is set, it may skip the auth dialog
   - Other auth-related env vars can affect the flow

## How to Launch with OAuth Login

### Method 1: Launch Normally (Interactive Mode)

```bash
# Just launch the CLI - the auth dialog will appear
cd /mnt/c/dev/gemini-cli
node scripts/start.js

# Or with your alias
gemini-dev

# With verbose logging
node scripts/start.js --verbose
```

**What you'll see:**

```
┌─────────────────────────────────────┐
│ Choose authentication method:       │
├─────────────────────────────────────┤
│ ● Login with Google                 │  <- Default option!
│   Use Gemini API Key                │
│   Vertex AI                         │
└─────────────────────────────────────┘
```

### Method 2: Clear Cached Credentials First

If you want to re-authenticate:

```bash
# Remove cached credentials
rm -rf ~/.gemini/credentials/

# Then launch
node scripts/start.js --verbose
```

### Method 3: Force OAuth in Settings

Create or edit `~/.gemini/settings.yaml`:

```yaml
security:
  auth:
    selectedType: oauth-personal # Force OAuth login
```

Then launch:

```bash
node scripts/start.js --verbose
```

## Using OAuth with Verbose Logging

### Step-by-Step:

```bash
# 1. Clear any existing API keys from environment
unset GEMINI_API_KEY
unset GOOGLE_API_KEY

# 2. Launch the CLI in interactive mode
cd /mnt/c/dev/gemini-cli
node scripts/start.js --verbose

# 3. Select "Login with Google" when prompted (should be default)

# 4. Follow the browser OAuth flow

# 5. Once authenticated, you'll see verbose logs for all API calls!
```

### Expected Flow:

```
Checking build status...
Build is up-to-date.

┌─────────────────────────────────────┐
│ Choose authentication method:       │
├─────────────────────────────────────┤
│ ● Login with Google                 │
│   Use Gemini API Key                │
│   Vertex AI                         │
└─────────────────────────────────────┘

Opening browser for authentication...
✓ Authentication successful!

gemini> Say hello

[14:23:45] 🚀 Starting API call to gemini-2.0-flash-exp
[14:23:47] ✅ API call to gemini-2.0-flash-exp completed in 1.85s

Hello! 👋
```

## OAuth vs API Key: What's the Difference?

| Feature         | OAuth Login          | API Key                               |
| --------------- | -------------------- | ------------------------------------- |
| Setup           | Browser login        | Need to get key from Google AI Studio |
| Credentials     | Cached locally       | Environment variable                  |
| Rotation        | Automatic            | Manual                                |
| Interactive CLI | ✅ Works great       | ✅ Works great                        |
| Non-interactive | ❌ Needs credentials | ✅ Works                              |
| Verbose Logging | ✅ Full support      | ✅ Full support                       |

## Troubleshooting OAuth

### Issue: "Auth dialog doesn't appear"

**Solution:**

```bash
# Make sure you're in interactive mode
node scripts/start.js --verbose
# NOT: echo "test" | node scripts/start.js --verbose
```

### Issue: "Browser doesn't open"

**Check:**

```bash
# Is NO_BROWSER set?
echo $NO_BROWSER

# If set, unset it:
unset NO_BROWSER
```

**Or set browser manually:**

```bash
export BROWSER=chrome  # or firefox, etc.
node scripts/start.js --verbose
```

### Issue: "Using old credentials"

**Clear cache:**

```bash
# View cached credentials
ls -la ~/.gemini/credentials/

# Remove them
rm -rf ~/.gemini/credentials/

# Re-authenticate
node scripts/start.js --verbose
```

### Issue: "WSL browser issues"

In WSL, the browser might not open automatically:

```bash
# Set WSL browser helper
export BROWSER=wslview  # or /mnt/c/Program\ Files/Google/Chrome/Application/chrome.exe

# Then launch
node scripts/start.js --verbose
```

## Testing OAuth + Verbose Logging Together

### Full Test:

```bash
# 1. Clean slate
unset GEMINI_API_KEY
rm -rf ~/.gemini/credentials/

# 2. Launch in interactive mode
cd /mnt/c/dev/gemini-cli
node scripts/start.js --verbose

# 3. Select "Login with Google"
# 4. Complete OAuth in browser
# 5. Type a prompt in the CLI

# You should see:
# [timestamp] 🚀 Starting API call to gemini-2.0-flash-exp
# [timestamp] ✅ API call completed in X.XXs
```

## Recommended Workflow

### For Development:

```bash
# First time: Authenticate with OAuth
node scripts/start.js

# Then use verbose for debugging
node scripts/start.js --verbose

# Credentials are cached, so you don't need to re-authenticate each time
```

### Aliases for OAuth + Verbose:

```bash
# Add to ~/.bashrc
alias gemini-dev="node /mnt/c/dev/gemini-cli/scripts/start.js"
alias gemini-dev-v="node /mnt/c/dev/gemini-cli/scripts/start.js --verbose"
alias gemini-oauth="rm -rf ~/.gemini/credentials/ && gemini-dev"

# Usage:
# gemini-dev        # Normal launch (uses cached OAuth)
# gemini-dev-v      # With verbose logging (uses cached OAuth)
# gemini-oauth      # Force re-authentication
```

## Advanced: Check Current Auth Method

To see which auth method is being used:

```bash
# Check settings
cat ~/.gemini/settings.yaml | grep -A 5 "auth:"

# Check cached credentials
ls -la ~/.gemini/credentials/

# Check environment variables
env | grep -E "GEMINI|GOOGLE_API|GOOGLE_CLOUD"
```

## Summary

**YES, you can use OAuth!** In fact, it's the recommended method for interactive
development:

✅ **To use OAuth + Verbose Logging:**

```bash
cd /mnt/c/dev/gemini-cli
node scripts/start.js --verbose
# Select "Login with Google" when prompted (it's the default!)
```

✅ **To force OAuth (clear cache):**

```bash
rm -rf ~/.gemini/credentials/
node scripts/start.js --verbose
```

✅ **To keep using OAuth (credentials cached):**

```bash
# Just launch normally - credentials are remembered
node scripts/start.js --verbose
```

The verbose logging feature works **identically** with all auth methods:

- 🔐 OAuth (Login with Google)
- 🔑 Gemini API Key
- ☁️ Vertex AI
- 🐚 Cloud Shell

Choose whichever auth method works best for you! 🚀
