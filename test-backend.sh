#!/bin/bash

# Backend API Security Test Script
# Run this to test the new Express backend

echo "🚀 Starting Backend API Security Test..."

# Set test variables (get FIREBASE_API_KEY from .env)
export API_BASE="http://localhost:3000"
export FIREBASE_API_KEY=$(grep "^FIREBASE_API_KEY=" /Users/umerfaroq/Documents/GitHub/cognify-flutter/backend/.env | cut -d '=' -f2)
export TEST_EMAIL="test@cognify.com"
export TEST_PASSWORD="testpass123"

# Get RC_WEBHOOK_SECRET if available
export RC_WEBHOOK_SECRET=$(grep "^RC_WEBHOOK_SECRET=" /Users/umerfaroq/Documents/GitHub/cognify-flutter/backend/.env | cut -d '=' -f2)

# Run tests directly with node
cd /Users/umerfaroq/Documents/GitHub/cognify-flutter/backend
node tests/api-security.test.js

echo ""
echo "✅ Test completed!"

