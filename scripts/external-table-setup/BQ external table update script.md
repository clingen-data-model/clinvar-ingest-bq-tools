
Some hints....

```
gcloud auth login --enable-gdrive-access

gcloud config set project clingen-stage
```

if you want to use the `autodetect` feature with a google sheet to generate an external table definition you can try with the following (see [here](https://cloud.google.com/bigquery/docs/external-table-definition#use_auto-detect_with_a_data_source))
```
>bq mkdef \
   --autodetect \
   --source_format=GOOGLE_SHEETS \
"https://docs.google.com/spreadsheets/d/1bADskBcobHTmmXungY09beWPDEa1nqM-PP__86yGVj0/edit\#gid\=2067576827" > report_submitters.def
```
but if you want to point to a range other than the first sheet you will need to open the file and add the `range` 
```
>more report_submitters.def
{
  "autodetect": true,
  "sourceFormat": "GOOGLE_SHEETS",
  "sourceUris": [
    "https://docs.google.com/spreadsheets/d/1bADskBcobHTmmXungY09beWPDEa1nqM-PP__86yGVj0/edit\\#gid\\=2067576827"
  ],
  "range": "'Report Submitter List'!A:G"
}
```


A word of caution...if using the `autodetect: true` please reference the data type conversion and naming rules (headings or no headings) [here](https://cloud.google.com/bigquery/docs/schema-detect#schema_auto-detection_for_external_data_sources).

```
bq mk \
--external_table_definition=report_submitters.def \
clinvar_ingest.report_submitter
```
this will create a table called `report_submitter` in the `clingen-stage.clinvar_ingest` dataset based on the google sheet link and range from the `report_submitters.def` file definition.

<h2>What's the best approach to managing the updates to external tables built on google sheets?</h2>
I think there are 2 reasonable options

1. Use autodetect and treat the google sheet range as the source of truth for the column names and data types.  
	1. OK. but can be unreliable and finicky especially if others begin editing the sheet column names or entering data that is not correct for the data type in that column.  Debugging could be harder as unexpected results can occur.
2. Do NOT use autodetect and explicitly list the schema in the table definition file, making it the source of truth.
	1. Better. having the table definition file contain the explicit schema is much more transparent for controlling the outcome. Failures on updates or creates will likely lie with the google sheet range itself which should be much easier to debug than figuring out why certain columns got misnamed or mistyped.
	2. NOTE: The additional issue here is that coordinating the change in both the sheet and the table definition have to be done independently. I suppose a script could be created to read the google sheet and produce the updated schema (but I digress).



