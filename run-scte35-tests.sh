#!/bin/bash

# SCTE-35 Multi-Format Test Runner
# 
# This script runs comprehensive tests for SCTE-35 functionality across all streaming formats
#
# © 2024 Morus Broadcasting Pvt Ltd. All rights reserved.

echo "🎬 SCTE-35 Multi-Format Test Runner"
echo "=================================="

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js to run the tests."
    exit 1
fi

# Check if the test script exists
if [ ! -f "test-scte35-formats.js" ]; then
    echo "❌ Test script not found. Please ensure test-scte35-formats.js exists."
    exit 1
fi

# Check if the development server is running
echo "🔍 Checking if development server is running..."
if curl -s http://localhost:3000/api/health > /dev/null 2>&1; then
    echo "✅ Development server is running"
else
    echo "❌ Development server is not running. Please start it with 'npm run dev'"
    exit 1
fi

# Install node-fetch if not already installed
echo "📦 Checking dependencies..."
if ! node -e "require('node-fetch')" 2>/dev/null; then
    echo "Installing node-fetch..."
    npm install node-fetch@2
fi

# Run the tests
echo "🧪 Running SCTE-35 multi-format tests..."
echo "========================================"

node test-scte35-formats.js

echo ""
echo "🎉 Test execution completed!"
echo "Check the console output for detailed results and the generated JSON report."