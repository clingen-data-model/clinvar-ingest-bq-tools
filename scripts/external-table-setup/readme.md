## Setting up External Tables to support cvc_curation, clinvar_ingest and variation_tracker
The `setup-external-tables.sh` script creates the external tables used by cvc_curation, clinvar_ingest and variation_tracker. clinvar_ingest and variation_tracker require that each external table be sync'd with an internal table whenever they are updated. So an appscript is being made available in the source google sheet to allow users that have the admin rights to update the related tables to re-sync the external tables with the internal "read-only" representations used in clinvar_ingest and variation_tracker stored procs and pipelines.

Below are the sql commands to sync the external tables with the internal tables.

See `scripts/external-table-setup/refersh-external-table-copies-proc` that MUST be executed whenever the `setup-eternal-tables.sh` is run or whenever the data in the source google sheets for ANY of the tables with copies of permanent tables are modified in any way.
