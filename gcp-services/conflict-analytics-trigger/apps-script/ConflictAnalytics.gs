/**
 * Google Apps Script functions for triggering ClinVar Conflict Resolution Analytics.
 *
 * These functions call a Cloud Function to update BigQuery views that power
 * the Google Sheets dashboard.
 *
 * Setup:
 * 1. Deploy the Cloud Function (see main.py)
 * 2. Copy this code into your Google Sheet's Apps Script editor
 *    (Extensions → Apps Script)
 * 3. Update CLOUD_FUNCTION_URL with your deployed function URL
 * 4. Run setupTriggers() once to create automated monthly refresh
 *
 * Usage:
 * - refreshViews(): Manually refresh just the Google Sheets views
 * - runFullPipeline(): Run the complete analytics pipeline
 * - checkForNewData(): Check if new monthly data is available
 * - refreshConnectedData(): Refresh BigQuery connected data in the sheet
 */

// Configuration - UPDATE THIS with your Cloud Function URL
const CONFIG = {
  // Cloud Function URL (update after deployment)
  CLOUD_FUNCTION_URL: 'https://us-central1-clingen-dev.cloudfunctions.net/conflict-analytics-trigger',

  // GCP Project ID
  PROJECT_ID: 'clingen-dev',

  // Timeout for HTTP requests (in seconds)
  REQUEST_TIMEOUT: 540,

  // Sheet name for logging (optional)
  LOG_SHEET_NAME: 'Pipeline Log'
};


/**
 * Refresh only the Google Sheets views (fast operation).
 * This updates Views 1-9 in BigQuery without running the full pipeline.
 *
 * Use this when:
 * - You've made changes to the view definitions
 * - You want to quickly refresh the dashboard
 * - The underlying tables are already up to date
 */
function refreshViews() {
  const result = callCloudFunction({ views_only: true });

  if (result.status === 'success') {
    showNotification('Views Refreshed', `Successfully refreshed views in ${result.total_duration_seconds}s`);
    logToSheet('Views refreshed successfully', result);
  } else {
    showNotification('Refresh Failed', result.error || result.message || 'Unknown error');
    logToSheet('Views refresh failed', result);
  }

  return result;
}


/**
 * Run the complete analytics pipeline.
 * This executes all SQL scripts (01-07) to rebuild all tables and views.
 *
 * Use this when:
 * - New monthly ClinVar data is available
 * - You need to rebuild all analytics from scratch
 * - Monthly scheduled refresh
 *
 * Options:
 * - force: true to rebuild even if no new data detected
 */
function runFullPipeline(options = {}) {
  const params = {
    force: options.force || false,
    skip_check: options.skip_check || false
  };

  showNotification('Pipeline Starting', 'Running full analytics pipeline. This may take several minutes...');

  const result = callCloudFunction(params);

  if (result.status === 'success') {
    const stepSummary = result.steps
      .map(s => `${s.description}: ${s.duration_seconds}s`)
      .join('\n');
    showNotification('Pipeline Complete', `Total time: ${result.total_duration_seconds}s`);
    logToSheet('Full pipeline completed', result);
  } else if (result.status === 'skipped') {
    showNotification('Pipeline Skipped', result.message || 'No new data to process');
    logToSheet('Pipeline skipped - no new data', result);
  } else {
    showNotification('Pipeline Failed', result.error || 'Unknown error');
    logToSheet('Pipeline failed', result);
  }

  return result;
}


/**
 * Check if new monthly data is available without running the pipeline.
 */
function checkForNewData() {
  const result = callCloudFunction({ check_only: true });

  if (result.rebuild_needed) {
    showNotification('New Data Available', `Found ${result.new_months_found} new month(s) to process`);
  } else {
    showNotification('Up to Date', 'No new monthly releases to process');
  }

  return result;
}


/**
 * Force a full pipeline rebuild regardless of new data status.
 */
function forceFullRebuild() {
  return runFullPipeline({ force: true });
}


/**
 * Refresh all Connected Sheets (BigQuery data) in the spreadsheet.
 * Call this after running the pipeline to update the sheet with new data.
 */
function refreshConnectedData() {
  try {
    // Get all data source sheets
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const sheets = ss.getSheets();

    let refreshCount = 0;
    for (const sheet of sheets) {
      const dataSources = sheet.getDataSourceTables();
      for (const ds of dataSources) {
        ds.refreshData();
        refreshCount++;
      }
    }

    if (refreshCount > 0) {
      showNotification('Data Refreshed', `Refreshed ${refreshCount} connected data source(s)`);
    } else {
      showNotification('No Data Sources', 'No BigQuery connected data sources found in this sheet');
    }

    return { status: 'success', refreshed: refreshCount };
  } catch (e) {
    showNotification('Refresh Failed', e.message);
    return { status: 'error', error: e.message };
  }
}


/**
 * Run the pipeline and then refresh connected data.
 * This is the typical monthly workflow.
 */
function runPipelineAndRefresh() {
  const pipelineResult = runFullPipeline();

  if (pipelineResult.status === 'success') {
    // Wait a moment for BigQuery to propagate changes
    Utilities.sleep(2000);
    refreshConnectedData();
  }

  return pipelineResult;
}


// ============================================================================
// Menu and UI Functions
// ============================================================================

/**
 * Create a custom menu when the spreadsheet opens.
 */
function onOpen() {
  const ui = SpreadsheetApp.getUi();
  ui.createMenu('ClinVar Analytics')
    .addItem('Check for New Data', 'checkForNewData')
    .addSeparator()
    .addItem('Refresh Views Only', 'refreshViews')
    .addItem('Run Full Pipeline', 'runFullPipeline')
    .addItem('Force Full Rebuild', 'forceFullRebuild')
    .addSeparator()
    .addItem('Refresh Connected Data', 'refreshConnectedData')
    .addItem('Run Pipeline & Refresh Data', 'runPipelineAndRefresh')
    .addSeparator()
    .addItem('Setup Monthly Trigger', 'setupMonthlyTrigger')
    .addItem('Remove All Triggers', 'removeAllTriggers')
    .addToUi();
}


/**
 * Show a toast notification.
 */
function showNotification(title, message) {
  SpreadsheetApp.getActiveSpreadsheet().toast(message, title, 10);
}


/**
 * Log an action to a sheet for audit purposes.
 */
function logToSheet(action, details) {
  try {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    let logSheet = ss.getSheetByName(CONFIG.LOG_SHEET_NAME);

    // Create log sheet if it doesn't exist
    if (!logSheet) {
      logSheet = ss.insertSheet(CONFIG.LOG_SHEET_NAME);
      logSheet.appendRow(['Timestamp', 'Action', 'Status', 'Details']);
      logSheet.getRange(1, 1, 1, 4).setFontWeight('bold');
    }

    // Add log entry
    logSheet.appendRow([
      new Date(),
      action,
      details.status || 'unknown',
      JSON.stringify(details)
    ]);
  } catch (e) {
    console.log('Failed to log to sheet:', e.message);
  }
}


// ============================================================================
// Trigger Management
// ============================================================================

/**
 * Set up a monthly trigger to run the pipeline on the 15th of each month.
 * Running on the 15th gives time for monthly ClinVar releases (typically early month).
 */
function setupMonthlyTrigger() {
  // Remove existing triggers first
  removeAllTriggers();

  // Create new monthly trigger
  ScriptApp.newTrigger('runPipelineAndRefresh')
    .timeBased()
    .onMonthDay(15)
    .atHour(6)
    .create();

  showNotification('Trigger Created', 'Monthly pipeline will run on the 15th at 6 AM');
}


/**
 * Remove all triggers for this script.
 */
function removeAllTriggers() {
  const triggers = ScriptApp.getProjectTriggers();
  for (const trigger of triggers) {
    ScriptApp.deleteTrigger(trigger);
  }
  showNotification('Triggers Removed', `Removed ${triggers.length} trigger(s)`);
}


/**
 * List all current triggers.
 */
function listTriggers() {
  const triggers = ScriptApp.getProjectTriggers();
  const info = triggers.map(t => ({
    function: t.getHandlerFunction(),
    type: t.getEventType().toString()
  }));
  console.log('Current triggers:', JSON.stringify(info, null, 2));
  return info;
}


// ============================================================================
// HTTP Helper Functions
// ============================================================================

/**
 * Call the Cloud Function with the given parameters.
 */
function callCloudFunction(params = {}) {
  const url = buildUrl(CONFIG.CLOUD_FUNCTION_URL, {
    ...params,
    project: CONFIG.PROJECT_ID
  });

  const options = {
    method: 'get',
    muteHttpExceptions: true,
    headers: {
      'Accept': 'application/json'
    }
  };

  // Add authentication if using authenticated Cloud Function
  // Uncomment if your function requires authentication:
  // const token = ScriptApp.getIdentityToken();
  // options.headers['Authorization'] = 'Bearer ' + token;

  try {
    const response = UrlFetchApp.fetch(url, options);
    const responseCode = response.getResponseCode();
    const responseText = response.getContentText();

    if (responseCode >= 200 && responseCode < 300) {
      return JSON.parse(responseText);
    } else {
      return {
        status: 'error',
        error: `HTTP ${responseCode}: ${responseText}`
      };
    }
  } catch (e) {
    return {
      status: 'error',
      error: e.message
    };
  }
}


/**
 * Build a URL with query parameters.
 */
function buildUrl(baseUrl, params) {
  const queryString = Object.entries(params)
    .filter(([_, v]) => v !== undefined && v !== null && v !== '')
    .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`)
    .join('&');

  return queryString ? `${baseUrl}?${queryString}` : baseUrl;
}


// ============================================================================
// Testing Functions
// ============================================================================

/**
 * Test the Cloud Function connection.
 */
function testConnection() {
  const result = callCloudFunction({ check_only: true });
  console.log('Connection test result:', JSON.stringify(result, null, 2));

  if (result.status === 'error') {
    showNotification('Connection Failed', result.error);
  } else {
    showNotification('Connection OK', 'Successfully connected to Cloud Function');
  }

  return result;
}
