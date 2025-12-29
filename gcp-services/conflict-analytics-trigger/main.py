"""
Cloud Function to trigger the Conflict Resolution Analytics pipeline.

This function loads SQL scripts from GCS and executes them to update the
BigQuery tables and views used by Google Sheets dashboards.

SQL Files Location:
    gs://clinvar-ingest/conflict-analytics-sql/

Deployment:
    gcloud functions deploy conflict-analytics-trigger \
        --runtime python311 \
        --trigger-http \
        --allow-unauthenticated \
        --entry-point run_analytics_pipeline \
        --timeout 540s \
        --memory 512MB \
        --region us-central1 \
        --project clingen-dev

For authenticated access (recommended for production):
    Remove --allow-unauthenticated and configure IAM:
    gcloud functions add-iam-policy-binding conflict-analytics-trigger \
        --member="serviceAccount:YOUR_SERVICE_ACCOUNT" \
        --role="roles/cloudfunctions.invoker"
"""

import functions_framework
from google.cloud import bigquery
from google.cloud import storage
from flask import jsonify
import traceback
from datetime import datetime

# GCS bucket and folder containing SQL files
SQL_BUCKET = "clinvar-ingest"
SQL_FOLDER = "conflict-analytics-sql"

# SQL files in execution order
SQL_SCRIPTS = [
    ("01-get-monthly-conflicts.sql", "Creating monthly_conflict_snapshots"),
    ("02-monthly-conflict-changes.sql", "Creating monthly_conflict_changes"),
    ("04-monthly-conflict-scv-snapshots.sql", "Creating monthly_conflict_scv_snapshots"),
    ("05-monthly-conflict-scv-changes.sql", "Creating monthly_conflict_scv_changes"),
    ("06-resolution-modification-analytics.sql", "Creating conflict_resolution_analytics"),
    ("07-google-sheets-analytics.sql", "Creating Google Sheets views"),
]

# Default project
DEFAULT_PROJECT = "clingen-dev"

# Storage client (initialized on first use)
_storage_client = None


def get_storage_client():
    """Get or create storage client."""
    global _storage_client
    if _storage_client is None:
        _storage_client = storage.Client()
    return _storage_client


def load_sql_from_gcs(script_name: str) -> str:
    """Load SQL content from GCS bucket."""
    client = get_storage_client()
    bucket = client.bucket(SQL_BUCKET)
    blob = bucket.blob(f"{SQL_FOLDER}/{script_name}")

    if not blob.exists():
        raise FileNotFoundError(
            f"SQL file not found: gs://{SQL_BUCKET}/{SQL_FOLDER}/{script_name}"
        )

    return blob.download_as_text()


def check_new_data(client: bigquery.Client) -> int:
    """Check if there are new monthly releases to process."""
    query = """
    WITH latest_snapshot AS (
      SELECT MAX(snapshot_release_date) AS latest_snapshot_date
      FROM `clinvar_ingest.monthly_conflict_snapshots`
    ),
    new_months AS (
      SELECT COUNT(DISTINCT DATE_TRUNC(release_date, MONTH)) AS new_month_count
      FROM `clinvar_ingest.all_schemas`()
      WHERE release_date >= DATE'2023-01-01'
        AND DATE_TRUNC(release_date, MONTH) > (
          SELECT COALESCE(DATE_TRUNC(latest_snapshot_date, MONTH), DATE'2022-12-01')
          FROM latest_snapshot
        )
    )
    SELECT new_month_count FROM new_months
    """
    result = client.query(query).result()
    for row in result:
        return row.new_month_count
    return 0


def run_sql_script(client: bigquery.Client, sql_content: str, description: str) -> dict:
    """Execute a SQL script and return timing info."""
    start_time = datetime.now()

    # Execute the SQL
    job = client.query(sql_content)
    job.result()  # Wait for completion

    end_time = datetime.now()
    duration = (end_time - start_time).total_seconds()

    return {
        "description": description,
        "duration_seconds": duration,
        "status": "success"
    }


@functions_framework.http
def run_analytics_pipeline(request):
    """
    HTTP Cloud Function to run the conflict resolution analytics pipeline.

    Query Parameters:
        force (bool): Force rebuild even if no new data (default: false)
        skip_check (bool): Skip the new data check (default: false)
        check_only (bool): Only check if rebuild is needed (default: false)
        project (str): GCP project ID (default: clingen-dev)
        views_only (bool): Only run the views script (07-google-sheets-analytics.sql)

    Returns:
        JSON response with execution status and timing
    """
    try:
        # Parse parameters
        force = request.args.get("force", "false").lower() == "true"
        skip_check = request.args.get("skip_check", "false").lower() == "true"
        check_only = request.args.get("check_only", "false").lower() == "true"
        views_only = request.args.get("views_only", "false").lower() == "true"
        project_id = request.args.get("project", DEFAULT_PROJECT)

        # Initialize BigQuery client
        client = bigquery.Client(project=project_id)

        results = {
            "project": project_id,
            "started_at": datetime.now().isoformat(),
            "sql_source": f"gs://{SQL_BUCKET}/{SQL_FOLDER}/",
            "steps": [],
            "status": "success"
        }

        # Check for new data unless skipped or forced
        if not skip_check and not force and not views_only:
            new_months = check_new_data(client)
            results["new_months_found"] = new_months

            if new_months == 0:
                results["status"] = "skipped"
                results["message"] = "No new monthly releases to process"
                if check_only:
                    results["rebuild_needed"] = False
                return jsonify(results)
            else:
                if check_only:
                    results["rebuild_needed"] = True
                    results["message"] = f"Found {new_months} new month(s) to process"
                    return jsonify(results)

        if check_only:
            return jsonify(results)

        # Determine which scripts to run
        if views_only:
            scripts_to_run = [
                ("07-google-sheets-analytics.sql", "Creating Google Sheets views")
            ]
        else:
            scripts_to_run = SQL_SCRIPTS

        # Load and execute SQL scripts from GCS
        for script_name, description in scripts_to_run:
            try:
                sql_content = load_sql_from_gcs(script_name)
                step_result = run_sql_script(client, sql_content, description)
                step_result["script"] = script_name
                results["steps"].append(step_result)
            except FileNotFoundError as e:
                results["steps"].append({
                    "description": description,
                    "script": script_name,
                    "status": "error",
                    "error": str(e)
                })
                results["status"] = "partial_failure"
            except Exception as e:
                results["steps"].append({
                    "description": description,
                    "script": script_name,
                    "status": "error",
                    "error": str(e)
                })
                results["status"] = "partial_failure"

        results["completed_at"] = datetime.now().isoformat()

        # Calculate total duration
        if results["steps"]:
            total_duration = sum(
                s.get("duration_seconds", 0)
                for s in results["steps"]
                if s.get("status") == "success"
            )
            results["total_duration_seconds"] = total_duration

        return jsonify(results)

    except Exception as e:
        return jsonify({
            "status": "error",
            "error": str(e),
            "traceback": traceback.format_exc()
        }), 500
