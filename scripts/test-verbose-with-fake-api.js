#!/usr/bin/env node

/**
 * @license
 * Copyright 2025 Google LLC
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * Test verbose logging with a simulated API call
 * This bypasses authentication to test the verbose logging directly
 */

 

import { RealtimeCliLogger } from '../packages/core/dist/src/services/realtimeCliLogger.js';

console.log('==============================================');
console.log('Testing Verbose Logging (with simulated API)');
console.log('==============================================\n');

const logger = RealtimeCliLogger.getInstance();

console.log('Step 1: Enable verbose logging');
logger.setEnabled(true);
console.log('✓ Logger enabled:', logger.isEnabled());
console.log('');

console.log('Step 2: Simulate API call lifecycle\n');
console.log('--- BEGIN SIMULATED API CALL ---\n');

// Simulate start
logger.logApiCallStart('gemini-2.0-flash-exp', 'test-prompt-123');

// Simulate processing delay
await new Promise((resolve) => setTimeout(resolve, 1500));

// Simulate end
logger.logApiCallEnd('gemini-2.0-flash-exp', 1234, 'test-prompt-123');

console.log('\n--- END SIMULATED API CALL ---\n');

console.log('==============================================');
console.log('Test Complete!');
console.log('==============================================');
console.log('\nIf you saw emoji logs (🚀 ✅) with timestamps above,');
console.log('then verbose logging is WORKING correctly!');
console.log('\nThese logs appear on stderr (not stdout)');
console.log('==============================================\n');
