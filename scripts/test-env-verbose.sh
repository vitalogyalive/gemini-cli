#!/bin/bash

# Test script for GEMINI_VERBOSE environment variable

echo "=============================================="
echo "Testing GEMINI_VERBOSE Environment Variable"
echo "=============================================="
echo ""

echo "Test 1: WITHOUT GEMINI_VERBOSE"
echo "----------------------------------------------"
echo "Command: node packages/cli --help | grep verbose"
echo ""
node packages/cli --help | grep verbose
echo ""

echo "Test 2: WITH GEMINI_VERBOSE=true"
echo "----------------------------------------------"
echo "Setting: export GEMINI_VERBOSE=true"
export GEMINI_VERBOSE=true
echo "Command: node scripts/test-verbose-simple.js"
echo ""
echo "Expected: Logger should be enabled by default"
echo ""

# Quick check with the logger test
node -e "
import { Config } from './packages/core/dist/index.js';

// Simulate what happens when GEMINI_VERBOSE is set
const verboseFromEnv = process.env['GEMINI_VERBOSE'] === 'true';
console.log('GEMINI_VERBOSE env var:', process.env['GEMINI_VERBOSE']);
console.log('Verbose enabled:', verboseFromEnv);

const config = new Config({
  sessionId: 'test',
  targetDir: process.cwd(),
  debugMode: false,
  verboseLogging: verboseFromEnv,
  cwd: process.cwd(),
  model: 'gemini-2.0-flash-exp'
});

console.log('Config.getVerboseLogging():', config.getVerboseLogging());
"

echo ""
echo "=============================================="
echo "Test Complete!"
echo "=============================================="
echo ""
echo "To enable verbose logging by default in your shell:"
echo "  1. Add to ~/.bashrc or ~/.zshrc:"
echo "     export GEMINI_VERBOSE=true"
echo ""
echo "  2. Reload:"
echo "     source ~/.bashrc"
echo ""
echo "  3. Then just run:"
echo "     gemini-dev -p \"test\" 2>&1"
echo ""
echo "     (No --verbose flag needed!)"
echo "=============================================="
