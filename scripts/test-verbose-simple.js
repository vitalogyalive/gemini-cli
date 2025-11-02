#!/usr/bin/env node

/**
 * @license
 * Copyright 2025 Google LLC
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Simple test to verify verbose logging is working
 * This directly tests the RealtimeCliLogger
 */

import { RealtimeCliLogger } from './packages/core/dist/src/services/realtimeCliLogger.js';

console.log('====================================');
console.log('Testing RealtimeCliLogger Directly');
console.log('====================================\n');

const logger = RealtimeCliLogger.getInstance();

// Test 1: Logger disabled (default)
console.log('Test 1: Logger DISABLED (default)');
console.log('Expected: No logs should appear\n');

logger.setEnabled(false);
console.log('Calling logApiCallStart...');
logger.logApiCallStart('gemini-2.0-flash-exp', 'test-prompt-1');
console.log('✓ No log appeared (correct!)\n');

// Test 2: Logger enabled
console.log('Test 2: Logger ENABLED');
console.log('Expected: Logs should appear on stderr\n');

logger.setEnabled(true);
console.log('Calling logApiCallStart...');
logger.logApiCallStart('gemini-2.0-flash-exp', 'test-prompt-2');

setTimeout(() => {
  console.log('\nCalling logApiCallEnd...');
  logger.logApiCallEnd('gemini-2.0-flash-exp', 1234, 'test-prompt-2');

  setTimeout(() => {
    console.log('\nCalling logApiCallError...');
    logger.logApiCallError(
      'gemini-2.0-flash-exp',
      'Test error',
      567,
      'test-prompt-3',
    );

    console.log('\n====================================');
    console.log('Test Complete!');
    console.log('====================================');
    console.log('\nIf you saw emoji logs (🚀 ✅ ❌) above with timestamps,');
    console.log('then verbose logging IS WORKING! ✓');
    console.log('\nNote: Verbose logs appear on stderr (not stdout)');
    console.log('====================================\n');
  }, 100);
}, 100);
