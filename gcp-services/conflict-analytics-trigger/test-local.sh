#!/bin/bash
# Test the Cloud Function locally using functions-framework

set -e

echo "Starting local function server..."
echo "Test endpoints:"
echo "  Check only:   curl 'http://localhost:8080?check_only=true'"
echo "  Views only:   curl 'http://localhost:8080?views_only=true'"
echo "  Full run:     curl 'http://localhost:8080?force=true'"
echo ""

# Install dependencies if needed
pip install -q functions-framework google-cloud-bigquery flask

# Run the function locally
functions-framework --target=run_analytics_pipeline --port=8080
