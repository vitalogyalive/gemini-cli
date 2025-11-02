# Quick Start: Verbose Logging

## TL;DR - What Works

```bash
# Add to ~/.bashrc or ~/.zshrc
alias gemini-dev="node /mnt/c/dev/gemini-cli/packages/cli"
alias gemini-dev-v="node /mnt/c/dev/gemini-cli/packages/cli --verbose"

# Then use it
gemini-dev-v
```

## That's It!

1. **Launch with verbose**: `gemini-dev-v`
2. **Select**: "Login with Google" (default option)
3. **See logs**: Every API call shows timing info

```
[14:23:45] 🚀 Starting API call to gemini-2.0-flash-exp
[14:23:47] ✅ API call to gemini-2.0-flash-exp completed in 1.85s
```

## Important

✅ Use: `node packages/cli --verbose` ❌ Don't use:
`node scripts/start.js --verbose`

See [CORRECT_USAGE.md](./CORRECT_USAGE.md) for details.
