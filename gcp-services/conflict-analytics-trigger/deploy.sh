#!/bin/bash
# Deploy the conflict-analytics-trigger Cloud Function

set -e

# Configuration
PROJECT_ID="${PROJECT_ID:-clingen-dev}"
REGION="${REGION:-us-central1}"
FUNCTION_NAME="conflict-analytics-trigger"

echo "Deploying $FUNCTION_NAME to $PROJECT_ID..."

gcloud functions deploy "$FUNCTION_NAME" \
    --project="$PROJECT_ID" \
    --region="$REGION" \
    --runtime=python311 \
    --trigger-http \
    --allow-unauthenticated \
    --entry-point=run_analytics_pipeline \
    --timeout=540s \
    --memory=512MB \
    --set-env-vars="PROJECT_ID=$PROJECT_ID"

echo ""
echo "Deployment complete!"
echo ""
echo "Function URL:"
gcloud functions describe "$FUNCTION_NAME" \
    --project="$PROJECT_ID" \
    --region="$REGION" \
    --format='value(httpsTrigger.url)'
echo ""
echo "Test with:"
echo "  curl \"\$(gcloud functions describe $FUNCTION_NAME --project=$PROJECT_ID --region=$REGION --format='value(httpsTrigger.url)')?check_only=true\""
