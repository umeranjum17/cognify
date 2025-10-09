#!/bin/bash

# API Security Test Script
# Run this in a new terminal window

echo "🚀 Starting API Security Test..."

# Set environment variables
export API_BASE="http://localhost:3000"
export FIREBASE_API_KEY="AIzaSyDQZw5pKiJ4XTK0sQxNcYW1Fe0hZI2yIwM"
export TEST_EMAIL="test@cognify.com"
export TEST_PASSWORD="testpass123"

# Navigate to API directory and run tests
cd /Users/umerfaroq/Documents/GitHub/cognify-flutter/api
npm run test:api-security

echo "✅ Test completed!"
