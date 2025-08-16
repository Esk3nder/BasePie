#!/bin/bash

# Validation script for PieFactory implementation
echo "===== PieFactory Validation Script ====="
echo ""

# Check if Foundry is installed
if ! command -v forge &> /dev/null; then
    echo "⚠️  Foundry not installed. Please install it first:"
    echo "   curl -L https://foundry.paradigm.xyz | bash"
    echo "   foundryup"
    exit 1
fi

echo "✓ Foundry detected"
echo ""

# Build contracts
echo "Building contracts..."
forge build
if [ $? -eq 0 ]; then
    echo "✓ Contracts compiled successfully"
else
    echo "✗ Contract compilation failed"
    exit 1
fi
echo ""

# Run tests
echo "Running tests..."
forge test --match-contract PieFactoryTest -vv
if [ $? -eq 0 ]; then
    echo "✓ All tests passed"
else
    echo "✗ Some tests failed"
    exit 1
fi
echo ""

# Gas report
echo "Gas report for PieFactory..."
forge test --match-contract PieFactoryTest --gas-report
echo ""

echo "===== Validation Complete ====="