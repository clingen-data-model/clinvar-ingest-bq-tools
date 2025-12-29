# Conflict Analytics Trigger

A Google Cloud Function and Apps Script integration for triggering the ClinVar Conflict Resolution Analytics pipeline from Google Sheets.

## Overview

This service allows you to:

1. **Refresh BigQuery views** directly from Google Sheets
2. **Run the full analytics pipeline** when new monthly data is available
3. **Schedule automatic monthly updates** using Apps Script triggers
4. **Monitor pipeline status** from a custom menu in Google Sheets

## Architecture

```
┌─────────────────────┐     HTTP      ┌─────────────────────┐
│   Google Sheets     │ ────────────► │   Cloud Function    │
│   (Apps Script)     │               │   (Python)          │
└─────────────────────┘               └──────────┬──────────┘
                                                 │
                                                 ▼
                                      ┌─────────────────────┐
                                      │     BigQuery        │
                                      │   (clinvar_ingest)  │
                                      └─────────────────────┘
```

## Setup

### Step 1: Deploy the Cloud Function

```bash
# From this directory
gcloud functions deploy conflict-analytics-trigger \
    --runtime python311 \
    --trigger-http \
    --allow-unauthenticated \
    --entry-point run_analytics_pipeline \
    --timeout 540s \
    --memory 512MB \
    --region us-central1 \
    --project clingen-dev
```

After deployment, note the function URL (e.g., `https://us-central1-clingen-dev.cloudfunctions.net/conflict-analytics-trigger`).

### Step 2: Add Apps Script to Google Sheets

1. Open your Google Sheets dashboard
2. Go to **Extensions → Apps Script**
3. Delete any existing code in `Code.gs`
4. Copy the contents of `apps-script/ConflictAnalytics.gs` into the editor
5. Update `CLOUD_FUNCTION_URL` in the `CONFIG` object with your function URL
6. Save the project (Ctrl+S)
7. Refresh your Google Sheet

You should now see a **ClinVar Analytics** menu in your sheet.

### Step 3: (Optional) Set Up Monthly Automation

From the **ClinVar Analytics** menu, select **Setup Monthly Trigger**.

This creates a trigger that runs the pipeline on the 15th of each month at 6 AM.

## Usage

### From the Google Sheets Menu

| Menu Item | Description |
|-----------|-------------|
| Check for New Data | See if new monthly ClinVar releases are available |
| Refresh Views Only | Update only the Google Sheets views (fast) |
| Run Full Pipeline | Execute the complete 6-step analytics pipeline |
| Force Full Rebuild | Rebuild everything regardless of new data status |
| Refresh Connected Data | Refresh BigQuery data sources in the sheet |
| Run Pipeline & Refresh Data | Full pipeline + refresh (typical monthly workflow) |

### From Apps Script

You can also call the functions directly:

```javascript
// Check for new data
checkForNewData();

// Refresh just the views
refreshViews();

// Run the full pipeline
runFullPipeline();

// Run with force flag
runFullPipeline({ force: true });
```

### Via HTTP (Direct Cloud Function)

```bash
# Check for new data
curl "https://YOUR_FUNCTION_URL?check_only=true&project=clingen-dev"

# Refresh views only
curl "https://YOUR_FUNCTION_URL?views_only=true&project=clingen-dev"

# Run full pipeline
curl "https://YOUR_FUNCTION_URL?project=clingen-dev"

# Force rebuild
curl "https://YOUR_FUNCTION_URL?force=true&project=clingen-dev"
```

## Cloud Function Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `project` | string | clingen-dev | GCP project ID |
| `check_only` | bool | false | Only check if rebuild is needed |
| `views_only` | bool | false | Only run View 7 (sheets_* views) |
| `force` | bool | false | Force rebuild even if no new data |
| `skip_check` | bool | false | Skip the new data check |

## Response Format

```json
{
  "project": "clingen-dev",
  "started_at": "2024-01-15T06:00:00.000000",
  "completed_at": "2024-01-15T06:05:30.000000",
  "status": "success",
  "new_months_found": 1,
  "steps": [
    {
      "description": "Creating monthly_conflict_snapshots",
      "duration_seconds": 45.2,
      "status": "success"
    },
    ...
  ],
  "total_duration_seconds": 330.5
}
```

## Views Created

The Cloud Function creates/updates these BigQuery views:

| View | Purpose |
|------|---------|
| `sheets_conflict_summary` | Monthly totals with net change |
| `sheets_conflict_changes` | Change status breakdown (long format) |
| `sheets_change_reasons` | Primary reason for changes |
| `sheets_multi_reason_detail` | All contributing reasons |
| `sheets_monthly_overview` | Single row per month |
| `sheets_change_status_wide` | Change status as columns |
| `sheets_change_reasons_wide` | Reasons as columns |
| `sheets_reason_combinations` | SCV reasons with single/multi counts |
| `sheets_reason_combinations_wide` | SCV reasons as columns |

## Security

### Option 1: Public Access (Current)

The function is deployed with `--allow-unauthenticated` for simplicity. This is acceptable if:
- The function only reads/writes to BigQuery tables you control
- No sensitive data is exposed in responses
- The function URL is not publicly documented

### Option 2: Authenticated Access (Recommended for Production)

1. Deploy without `--allow-unauthenticated`:
   ```bash
   gcloud functions deploy conflict-analytics-trigger \
       --runtime python311 \
       --trigger-http \
       --entry-point run_analytics_pipeline \
       --timeout 540s \
       --memory 512MB \
       --region us-central1 \
       --project clingen-dev
   ```

2. Grant invoker permission to Apps Script:
   ```bash
   gcloud functions add-iam-policy-binding conflict-analytics-trigger \
       --member="allUsers" \
       --role="roles/cloudfunctions.invoker" \
       --region=us-central1
   ```

3. Update Apps Script to use identity tokens:
   ```javascript
   const token = ScriptApp.getIdentityToken();
   options.headers['Authorization'] = 'Bearer ' + token;
   ```

## Troubleshooting

### "Permission Denied" Error

- Ensure the Cloud Function service account has BigQuery permissions
- Check that `--allow-unauthenticated` is set (or use authenticated access)

### "Timeout" Error

- The function has a 540s (9 min) timeout
- For very large datasets, consider running the shell script directly

### "No new data to process"

- The function checks for new monthly releases automatically
- Use `force=true` to rebuild anyway
- Use `skip_check=true` to skip the check

### Views Not Updating in Sheet

After running the pipeline:
1. Wait a few seconds for BigQuery to propagate changes
2. Use **Refresh Connected Data** from the menu
3. Or manually refresh via **Data → Data connectors → Refresh data**

## Files

```
conflict-analytics-trigger/
├── main.py                 # Cloud Function code
├── requirements.txt        # Python dependencies
├── README.md              # This file
└── apps-script/
    └── ConflictAnalytics.gs  # Google Apps Script code
```

## Related Documentation

- [GOOGLE-SHEETS-SETUP.md](../../scripts/conflict-resolution-analysis/GOOGLE-SHEETS-SETUP.md) - Dashboard setup guide
- [00-run-all-analytics.sh](../../scripts/conflict-resolution-analysis/00-run-all-analytics.sh) - Shell script for full pipeline
- [07-google-sheets-analytics.sql](../../scripts/conflict-resolution-analysis/07-google-sheets-analytics.sql) - View definitions
