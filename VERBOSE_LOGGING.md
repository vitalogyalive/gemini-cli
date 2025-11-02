# Verbose Logging Feature

## Overview

The Gemini CLI now includes a verbose logging feature that displays real-time
information about API calls, execution times, and CLI operations. This is useful
for debugging, monitoring performance, and understanding what the CLI is doing
behind the scenes.

## Usage

To enable verbose logging, use the `--verbose` flag when starting the Gemini
CLI:

```bash
gemini --verbose
```

**Note**: There is no short alias for verbose (e.g., `-v` is reserved for
`--version`).

You can combine it with other flags:

```bash
gemini --verbose -p "Write a hello world program in Python"
```

## What Gets Logged

When verbose logging is enabled, you will see real-time information about:

1. **API Call Start**: When a request to the Gemini API begins
   - Model being used
   - Unique prompt ID for tracking

2. **API Call End**: When a request completes successfully
   - Model used
   - Total execution time in seconds
   - Prompt ID

3. **API Call Errors**: If a request fails
   - Model used
   - Error message
   - Execution time before failure
   - Prompt ID

## Example Output

When verbose logging is enabled, you'll see logs like this in your terminal:

```
[14:23:45] 🚀 Starting API call to gemini-2.0-flash-exp
[14:23:47] ✅ API call to gemini-2.0-flash-exp completed in 1.85s
```

Or in case of an error:

```
[14:23:45] 🚀 Starting API call to gemini-2.0-flash-exp
[14:23:47] ❌ API call to gemini-2.0-flash-exp failed after 1.23s: Network timeout
```

## Technical Details

### Implementation

The verbose logging feature is implemented through:

1. **RealtimeCliLogger Service**
   (`packages/core/src/services/realtimeCliLogger.ts`): A singleton service that
   manages logging events
2. **LoggingContentGenerator Integration**: The logger is integrated into the
   API call lifecycle
3. **Configuration**: Controlled via the `verboseLogging` config parameter

### Log Output

Logs are output to `stderr` to avoid interfering with normal CLI output on
`stdout`. This means:

- Normal CLI responses and results go to stdout
- Verbose logs go to stderr
- You can redirect them separately if needed

### Event Types

The logger emits the following event types:

- `api_call_start`: When an API call begins
- `api_call_end`: When an API call completes successfully
- `api_call_error`: When an API call fails
- `info`: General informational messages

## Configuration

### Via Command Line

```bash
gemini --verbose
```

### Programmatic Usage

If you're using the Gemini CLI as a library:

```typescript
import { Config, RealtimeCliLogger } from '@google/gemini-cli-core';

// Enable verbose logging in config
const config = new Config({
  // ... other config
  verboseLogging: true,
});

// Or control the logger directly
const logger = RealtimeCliLogger.getInstance();
logger.setEnabled(true);

// Subscribe to log events
const unsubscribe = logger.onLogEvent((event) => {
  console.log(`[${event.type}] ${event.message}`);
});
```

## Use Cases

1. **Debugging**: See exactly when API calls are made and how long they take
2. **Performance Monitoring**: Track response times to identify slow operations
3. **Development**: Understand the flow of API calls during development
4. **Troubleshooting**: Get detailed error information when things go wrong

## Disabling Verbose Logging

Simply run the CLI without the `--verbose` flag:

```bash
gemini
```

Verbose logging is disabled by default.
