/**
 * CVC Impact Analysis Refresh — Apps Script Integration
 *
 * Add this to the existing Apps Script that finalizes batches.
 * Call refreshCvcImpactAnalysis() after the batch is finalized
 * and cvc_clinvar_batches is updated.
 *
 * SETUP:
 * 1. In the Apps Script editor, go to Services > Add a service > BigQuery API (v2)
 * 2. Add this code to the existing script
 * 3. Call refreshCvcImpactAnalysis() after batch finalization
 *
 * The procedure takes 2-5 minutes to run. It rebuilds all 14 materialized
 * tables in the CVC Impact Analysis pipeline in dependency order.
 *
 * Uses Jobs.insert (async) instead of Jobs.query (sync) since the procedure
 * runs longer than the Apps Script UI timeout. The job is submitted, then
 * polled for completion.
 */

const IMPACT_CONFIG = {
  PROJECT_ID: 'clingen-dev',
  PROCEDURE: 'CALL `clinvar_curator.refresh_cvc_impact_analysis`()'
};

/**
 * Calls the BigQuery stored procedure to refresh all CVC impact analysis tables.
 * Designed to be called after batch finalization.
 *
 * Submits the job asynchronously and polls for completion.
 *
 * @returns {boolean} true if successful, false if failed
 */
function refreshCvcImpactAnalysis() {
  const ui = SpreadsheetApp.getUi();

  try {
    const confirm = ui.alert(
      'Refresh Impact Analysis?',
      'This will rebuild all CVC impact analysis tables (2-5 minutes).\n\n' +
      'Continue?',
      ui.ButtonSet.YES_NO
    );

    if (confirm !== ui.Button.YES) return false;

    // Submit the job asynchronously via Jobs.insert
    const job = {
      configuration: {
        query: {
          query: IMPACT_CONFIG.PROCEDURE,
          useLegacySql: false
        }
      }
    };

    const response = BigQuery.Jobs.insert(job, IMPACT_CONFIG.PROJECT_ID);
    const jobId = response.jobReference.jobId;

    Logger.log('Submitted impact analysis refresh job: ' + jobId);

    // Poll for completion
    return pollForCompletion(jobId);

  } catch (error) {
    ui.alert(
      'Refresh Failed',
      'Error refreshing impact analysis tables:\n\n' + error.message +
      '\n\nTry running manually in BigQuery console:\n' +
      IMPACT_CONFIG.PROCEDURE,
      ui.ButtonSet.OK
    );
    Logger.log('Impact analysis refresh error: ' + error.message);
    return false;
  }
}

/**
 * Polls a BigQuery job until completion.
 * @param {string} jobId - The BigQuery job ID to poll
 * @returns {boolean} true if job completed successfully
 */
function pollForCompletion(jobId) {
  const ui = SpreadsheetApp.getUi();
  const maxAttempts = 60; // 10 minutes at 10-second intervals

  for (let i = 0; i < maxAttempts; i++) {
    Utilities.sleep(10000); // 10 seconds

    const job = BigQuery.Jobs.get(IMPACT_CONFIG.PROJECT_ID, jobId);
    const status = job.status;

    if (status.state === 'DONE') {
      if (status.errorResult) {
        ui.alert(
          'Refresh Failed',
          'BigQuery job completed with error:\n\n' + status.errorResult.message,
          ui.ButtonSet.OK
        );
        return false;
      }

      ui.alert(
        'Refresh Complete',
        'All CVC impact analysis tables have been rebuilt successfully.\n\n' +
        'Google Sheets charts will reflect the new data after refreshing ' +
        'the data connector (Data > Data connectors > Refresh data).',
        ui.ButtonSet.OK
      );
      return true;
    }
  }

  ui.alert(
    'Refresh Timeout',
    'The refresh job is still running after 10 minutes.\n' +
    'Check BigQuery console for job status: ' + jobId,
    ui.ButtonSet.OK
  );
  return false;
}
