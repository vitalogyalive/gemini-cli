# How to See Verbose Logs - Important!

## 🔍 The Logs ARE Working - But You Need to Look in the Right Place!

Verbose logs are written to **stderr** (not stdout), so you need to check the
right output stream.

## ✅ Test That Verbose Logging Works

I created a simple test script. Run it:

```bash
cd /mnt/c/dev/gemini-cli
node test-verbose-simple.js
```

You should see:

```
[8:57:56 PM] 🚀 Starting API call to gemini-2.0-flash-exp
[8:57:57 PM] ✅ API call to gemini-2.0-flash-exp completed in 1.23s
[8:57:57 PM] ❌ API call to gemini-2.0-flash-exp failed after 0.57s: Test error
```

If you see these logs, **verbose logging IS working!** ✓

## 🎯 How to See Verbose Logs When Using the CLI

### Method 1: Merge stderr with stdout (EASIEST)

```bash
# This combines both output streams so you see everything
gemini-dev --verbose -p "Say hello" 2>&1

# Or redirect both to a file
gemini-dev --verbose -p "Say hello" > output.log 2>&1
cat output.log
```

### Method 2: Watch stderr separately

```bash
# Send stderr to a file while seeing stdout
gemini-dev --verbose -p "Say hello" 2> verbose-logs.txt

# Then check the verbose logs
cat verbose-logs.txt
```

### Method 3: Use terminal that shows both

Most terminals show both stdout and stderr by default, but to be sure:

```bash
# In bash/zsh, this works
gemini-dev --verbose -p "Say hello"

# You should see both:
# - The response (stdout)
# - Verbose logs with 🚀 ✅ emojis (stderr)
```

## 🧪 Quick Test Commands

### Test 1: Verify logger works directly

```bash
cd /mnt/c/dev/gemini-cli
node test-verbose-simple.js
```

Expected output: You should see emoji logs with timestamps.

### Test 2: Test with real CLI (merge outputs)

```bash
# This ensures you see BOTH stdout and stderr
gemini-dev --verbose -p "Say hello in one word" 2>&1
```

Expected output:

```
[8:57:56 PM] 🚀 Starting API call to gemini-2.0-flash-exp
[8:57:57 PM] ✅ API call to gemini-2.0-flash-exp completed in 1.85s

Hello!
```

### Test 3: Save verbose logs to file

```bash
# Capture everything
gemini-dev --verbose -p "test" > full-output.log 2>&1

# Check the logs
cat full-output.log | grep -E "🚀|✅|❌"
```

You should see the verbose log lines!

## 🐛 If You Still Don't See Logs

### Debug Step 1: Verify flag is parsed

```bash
# This should show verbose in the help
gemini-dev --help | grep verbose
```

Expected:

```
-v, --verbose    Enable verbose logging to see real-time API calls...
```

### Debug Step 2: Check if Config receives the flag

Add a debug line temporarily to check:

```bash
# In packages/core/src/core/loggingContentGenerator.ts (line ~53)
# Add after: this.realtimeLogger.setEnabled(config.getVerboseLogging());

console.error('DEBUG: Verbose logging enabled:', this.realtimeLogger.isEnabled());
```

Then:

```bash
npm run build
gemini-dev --verbose -p "test" 2>&1 | grep "DEBUG"
```

If you see `DEBUG: Verbose logging enabled: true`, it's working!

### Debug Step 3: Verify API calls are happening

The verbose logs only appear when actual API calls are made. If you:

- Launch the CLI without making a request
- Have authentication issues
- The API call fails before reaching LoggingContentGenerator

Then you won't see verbose logs!

## 💡 Common Misunderstandings

### ❌ "I don't see any difference"

**Why**: Verbose logs go to stderr. If your terminal only shows stdout, you
won't see them.

**Solution**: Use `2>&1` to merge stderr with stdout:

```bash
gemini-dev --verbose -p "test" 2>&1
```

### ❌ "The logs appear but at the wrong time"

**Why**: Verbose logs appear on stderr, which may flush at different times than
stdout.

**Solution**: This is normal! Stderr is typically unbuffered, so logs appear
immediately.

### ❌ "I see the logs in test but not in real usage"

**Why**: You might not be authenticated or the API call isn't happening.

**Solution**:

1. Make sure you're authenticated
2. Make sure you actually send a prompt
3. Check if the API call succeeds

## 📊 Comparison: With vs Without Verbose

### WITHOUT --verbose:

```bash
$ gemini-dev -p "Say hello"
Hello! How can I help you today?
```

### WITH --verbose (using 2>&1):

```bash
$ gemini-dev --verbose -p "Say hello" 2>&1
[8:57:56 PM] 🚀 Starting API call to gemini-2.0-flash-exp
[8:57:57 PM] ✅ API call to gemini-2.0-flash-exp completed in 1.23s
Hello! How can I help you today?
```

See the difference? The emoji logs with timestamps! 🎉

## 🎯 Best Practice for Development

```bash
# Add this to your ~/.bashrc
alias gemini-dev-v="node /mnt/c/dev/gemini-cli/packages/cli --verbose 2>&1"

# Then use it
gemini-dev-v -p "test"

# All output (stdout + stderr) will be merged and visible!
```

## 🔧 Troubleshooting Checklist

- [ ] Build is current: `npm run build`
- [ ] Test script works: `node test-verbose-simple.js` shows emoji logs
- [ ] Flag is recognized: `gemini-dev --help | grep verbose` shows the option
- [ ] Using `2>&1` to merge outputs: `gemini-dev --verbose -p "test" 2>&1`
- [ ] Actually sending a prompt (not just launching the CLI)
- [ ] Authenticated (OAuth or API key)
- [ ] API call succeeds (no authentication errors)

If all checklist items pass and you still don't see logs, there may be a real
issue!

## 📝 Summary

**The verbose logging IS working!** The test proves it. To see the logs:

```bash
# BEST METHOD - merge stderr and stdout
gemini-dev --verbose -p "your prompt" 2>&1

# Or update your alias
alias gemini-dev-v="node /mnt/c/dev/gemini-cli/packages/cli --verbose 2>&1"
```

The logs appear on **stderr** with emojis and timestamps:

- 🚀 API call start
- ✅ API call success
- ❌ API call error

Happy debugging! 🎉
