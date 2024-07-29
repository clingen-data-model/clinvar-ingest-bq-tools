CREATE OR REPLACE FUNCTION `clinvar_curator.normalizeAndKeyById`(json JSON)
RETURNS JSON
LANGUAGE js  
  OPTIONS (
    library=['gs://clinvar-gk-pilot/libraries/bq-utils.js'])
AS r"""
  return normalizeAndKeyById(json);
""";

-- test
WITH x as (

  SELECT JSON '{"id": "100", "extensions": [{"name": "label1.1", "value_string": "test"}],"start": "null", "end": "[100,null]"}' as json_data
  UNION ALL
  SELECT JSON '{"id": "101", "members": [{"location":{"type":"SeqLoc","copies":"15","start":"[3409240,3204928]","end":"[93423432,null]"}}],"start": "null", "end": "[100,null]"}' as json_data
  UNION ALL
  SELECT JSON '{"id": "200", "extensions": [{"name": "label2.1", "value_string": "test"}, {"name": "label2.2", "value_coding": {"code": "mycode", "system": "mysystem", "label": "value_label"}}]}' as json_data
  UNION ALL
  SELECT JSON '{"id": "300", "extensions": [{"name": "label3.1", "value_string": "test"}], "location": {"id": "loc1", "extensions": [{"name": "label3.1.1", "value_coding": {"code": "mycode", "system": "mysystem", "label": "value_label"}}]}}' as json_data
)
select 
  x.json_data as before,
  `clinvar_curator.normalizeAndKeyById`(json_data) as after 
from x;
