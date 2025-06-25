CREATE OR REPLACE FUNCTION `clinvar_ingest.parseXRefs`(json STRING)
RETURNS ARRAY<STRUCT<db STRING, id STRING, type STRING, status STRING, url STRING, ref_field STRING>>
LANGUAGE js
  OPTIONS (
    library=['gs://clinvar-ingest/bq-tools/parse-utils.js'])
AS r"""
  return parseXRefs(json);
""";

CREATE OR REPLACE FUNCTION `clinvar_ingest.parseXRefItems`(json_xrefs ARRAY<STRING>)
RETURNS ARRAY<STRUCT<db STRING, id STRING, type STRING, status STRING, url STRING, ref_field STRING>>
LANGUAGE js
  OPTIONS (
    library=['gs://clinvar-ingest/bq-tools/parse-utils.js'])
AS r"""
  return parseXRefItems(json_xrefs);
""";


-- test
WITH xrefs as (
  SELECT
    1 as key,
    """{"@DB": "OMIM","@ID": "123456","@Type": "MIM number","@URL": "https://omim.org/entry/123456","@Status": "current"}""" as c,
    """{"db": "MedGen","id": "9678","type": null,"url": "https://omim.org/entry/9678","status": "old"}""" as i
  UNION ALL
    SELECT
    1 as key,
    """{"@DB": "MONDO","@ID": "223234","@Type": "MONDO ID","@URL": "https://mondo/223234","@Status": "alternate"}""" as c,
    """{"db": "ORPHA","id": "72473","type": "Orphanet","url": null,"status": "foo"}""" as i
),
recs as (
  SELECT
  '{"XRef": ['||ARRAY_TO_STRING(ARRAY_AGG(c),',')||']}' as content,
    ARRAY_AGG(i) as xrefs

  from xrefs
  group by key
)
select
  `clinvar_ingest.parseXRefItems`(recs.xrefs) as xref_items,
  `clinvar_ingest.parseXRefs`(recs.content) as xrefs
from recs;
