CREATE OR REPLACE TABLE FUNCTION `clinvar_ingest.release_date_as_of`(as_of_date DATE) AS (
SELECT max(release_date) as release_date
    FROM `clinvar_ingest.clinvar_releases` 
    WHERE release_date <= as_of_date
);