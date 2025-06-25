CREATE OR REPLACE FUNCTION `clinvar_ingest.normalizeHpId`(value STRING)
RETURNS STRING
LANGUAGE js
  OPTIONS (
    library=['gs://clinvar-ingest/bq-tools/bq-utils.js'])
AS r"""
  return normalizeHpId(value);
""";

-- test
SELECT
  hp_id,
  `clinvar_ingest.normalizeHpId`(hp_id) AS normalized_hp_id
FROM UNNEST([
  'HP:0001234',
  '1234',
  'HP:HP:1234',
  '0000123',
  'HP:0001234567',
  'HP:00000001234567',
  'HP:ABC1234',
  'foobar',
  'HP:HP:12345678',
  'HP:HP:0',
  'HP:HP:23'
]) AS hp_id;
