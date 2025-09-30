CREATE OR REPLACE FUNCTION `clinvar_ingest.normalizeAndKeyById`(json JSON, skipKeyById BOOL)
RETURNS JSON
LANGUAGE js
  OPTIONS (
    library=['gs://clinvar-ingest/bq-tools/bq-utils.js'])
AS r"""
  // Set default for skipKeyById to 'false' if it's null or undefined
  const shouldSkip = skipKeyById ?? false;

  // Now use 'shouldSkip' in your function call
  return normalizeAndKeyById(json, shouldSkip);
""";

-- test #1
WITH x as (

  SELECT JSON '{"id": "100", "extensions": [{"name": "label1.1", "value_string": "test"}],"start": "null", "end": "[100,null]"}' as json_data
  UNION ALL
  SELECT JSON '{"id": "101", "members": [{"location":{"type":"SeqLoc","copies":"15","start":"[3409240,3204928]","end":"[93423432,null]"}}],"start": "null", "end": "[100,null]"}' as json_data
  UNION ALL
  SELECT JSON '{"id": "clinvar:200", "extensions": [{"name": "label2.1", "value_string": "test"}, {"name": "label2.2", "value_coding": {"code": "mycode", "system": "mysystem", "label": "value_label"}}]}' as json_data
  UNION ALL
  SELECT JSON '{"id": "300", "extensions": [{"name": "label3.1", "value_string": "test"}], "location": {"id": "loc1", "extensions": [{"name": "label3.1.1", "value_coding": {"code": "mycode", "system": "mysystem", "label": "value_label"}}]}}' as json_data
)
select
  x.json_data as before,
  `clinvar_ingest.normalizeAndKeyById`(json_data, false) as after
from x;

-- test #2
WITH x as (

  SELECT JSON '{"id": "100", "extensions": [{"name": "label1.1", "value_string": "test"}],"start": null, "end": "[100,null]"}' as json_data
  UNION ALL
  SELECT JSON '{"id": "101", "members": [{"location":{"type":"SeqLoc","copies":"15","start":"[3409240,3204928]","end":"[93423432,null]"}}],"start": "null", "end": "[100,null]"}' as json_data
  UNION ALL
  SELECT JSON '{"id": "clinvar:200", "extensions": [{"name": "label2.1", "value_string": "test"}, {"name": "label2.2", "value_coding": {"code": "mycode", "system": "mysystem", "label": "value_label"}}]}' as json_data
  UNION ALL
  SELECT JSON '{"id": "300", "extensions": [{"name": "label3.1", "value_string": "test"}], "location": {"id": "loc1", "extensions": [{"name": "label3.1.1", "value_coding": {"code": "mycode", "system": "mysystem", "label": "value_label"}}]}}' as json_data
)
select
  x.json_data as before,
  `clinvar_ingest.normalizeAndKeyById`(json_data, true) as after
from x;
