-- The schema table functions are also used to manage clinvar release dates.
-- Since we are only planning on standing up the schemas for releases starting
-- on Jan.07.2023 we will need to supplement the release data information 
-- for the historic releases. This is needed because we have pulled in 
-- some historic data into the clinvar_ingest.clinvar_scvs table to address the
-- need to have the data that was available for the cvc-curated annotations before
-- Jan.07.2023, which ended up being about 289 records in the clinvar_scvs table.
-- In order to make sure clinvar's historic release dates are complete we will 
-- put all known release dates in based on previous historic analysis on the clinvar releases.
-- This historic release table will only be for the releases prior to Jan.07.2023, all 
-- release dates on or after that date will be inferred from the schemas in clingen-dev itself.

-- the create table statement for the historic release dates and the insert statements for the release dates
-- can be found at the end of this script.

CREATE OR REPLACE TABLE FUNCTION `clinvar_ingest.all_releases`()
AS (
    -- the state of al clinvar schemas available at the moment
    WITH r AS (
        SELECT
            CAST(
                REGEXP_REPLACE(
                    iss.schema_name, 
                    r'clinvar_(\d{4})_(\d{2})_(\d{2}).*', 
                    '\\1-\\2-\\3'
                ) as DATE
            ) AS release_date
        FROM INFORMATION_SCHEMA.SCHEMATA iss
        WHERE 
            REGEXP_CONTAINS(iss.schema_name, r'^clinvar_\d{4}_\d{2}_\d{2}_v\d_\d+_\d+$')
        UNION ALL
        SELECT
            null,
            release_date
        FROM `clingen-dev.clinvar_ingest.historic_release_dates`
    )
    SELECT 
        r.release_date,
        LAG(r.release_date, 1, DATE('0001-01-01')) OVER (ORDER BY r.release_date ASC) AS prev_release_date,
        LEAD(r.release_date, 1, DATE('9999-12-31')) OVER (ORDER BY r.release_date ASC) AS next_release_date
    FROM r
    ORDER BY 1
);

CREATE OR REPLACE TABLE FUNCTION `clinvar_ingest.release_on`(on_date DATE) AS (
SELECT
                x.release_date,
                x.prev_release_date,
                x.next_release_date
            FROM `clinvar_ingest.all_releases`() x
            WHERE on_date >= x.release_date
            ORDER BY 2 DESC
            LIMIT 1
);



-- the main all_schemas() table function used by all other specialized functions.
CREATE OR REPLACE TABLE FUNCTION `clinvar_ingest.all_schemas`()
AS (
    -- the state of al clinvar schemas available at the moment
    WITH r AS (
        SELECT
            iss.schema_name,
            CAST(
                REGEXP_REPLACE(
                    iss.schema_name, 
                    r'clinvar_(\d{4})_(\d{2})_(\d{2}).*', 
                    '\\1-\\2-\\3'
                ) as DATE
            ) AS release_date
        FROM INFORMATION_SCHEMA.SCHEMATA iss
        WHERE 
            REGEXP_CONTAINS(iss.schema_name, r'^clinvar_\d{4}_\d{2}_\d{2}_v\d_\d+_\d+$')
    )
    SELECT 
        r.schema_name,
        r.release_date,
        x.prev_release_date,
        x.next_release_date
    FROM r
    JOIN `clinvar_ingest.all_releases`() x
    ON r.release_date = x.release_date
    ORDER BY 2
);


CREATE OR REPLACE TABLE FUNCTION `clinvar_ingest.schema_on`(on_date DATE)
AS (
    -- the state of schemas available on a certain date
    -- if the date lands on a schema release date then that will be the schema
    -- otherwise the schema with the release date just prior to that date will be the schema
    SELECT
        x.schema_name,
        x.release_date,
        x.prev_release_date,
        x.next_release_date
    FROM `clinvar_ingest.all_schemas`() x
    WHERE on_date >= x.release_date
    ORDER BY 2 DESC
    LIMIT 1
);

CREATE OR REPLACE TABLE FUNCTION `clinvar_ingest.schemas_on_or_after`(on_or_after_date DATE)
AS (
    -- the state of schemas available on or after a certain date
    -- if the date lands on a schema release date then that will be the first schema
    -- if the date is prior to the earliest release date then return all schemas
    -- otherwise the schema with the release date just prior to that date will be the first schema
    SELECT
        x.schema_name,
        x.release_date,
        x.prev_release_date,
        x.next_release_date
    FROM `clinvar_ingest.all_schemas`() x
    WHERE (on_or_after_date > x.prev_release_date AND on_or_after_date < x.next_release_date) OR on_or_after_date <= x.release_date
    ORDER BY 2
);

CREATE OR REPLACE TABLE FUNCTION `clinvar_ingest.schemas_on_or_before`(on_or_before_date DATE)
AS (
    -- the state of schemas available on or before a certain date
    -- if the date lands on a schema release date then that will be the last schema
    -- otherwise the schema with the release date just prior to that date will be the last schema
    SELECT
        x.schema_name,
        x.release_date,
        x.prev_release_date,
        x.next_release_date
    FROM `clinvar_ingest.all_schemas`() x
    WHERE on_or_before_date >= x.release_date
    ORDER BY 2
);


CREATE TABLE IF NOT EXISTS `clinvar_ingest.historic_release_dates`
(
  release_date DATE NOT NULL
);

INSERT INTO `clinvar_ingest.historic_release_dates` (release_date) VALUES
('2012-11-16'),
('2013-01-24'),
('2013-04-08'),
('2013-05-06'),
('2013-08-09'),
('2013-09-12'),
('2013-10-01'),
('2013-11-06'),
('2013-12-05'),
('2014-01-02'),
('2014-02-13'),
('2014-03-07'),
('2014-04-03'),
('2014-05-01'),
('2014-06-05'),
('2014-07-03'),
('2014-08-07'),
('2014-09-04'),
('2014-10-03'),
('2014-11-06'),
('2014-12-04'),
('2015-01-09'),
('2015-02-05'),
('2015-03-06'),
('2015-04-02'),
('2015-05-07'),
('2015-06-08'),
('2015-07-09'),
('2015-08-06'),
('2015-09-10'),
('2015-10-01'),
('2015-11-05'),
('2015-12-03'),
('2016-01-07'),
('2016-02-04'),
('2016-03-03'),
('2016-04-12'),
('2016-05-05'),
('2016-06-02'),
('2016-07-07'),
('2016-08-04'),
('2016-09-01'),
('2016-10-06'),
('2016-11-03'),
('2016-12-01'),
('2017-01-05'),
('2017-02-02'),
('2017-03-02'),
('2017-04-06'),
('2017-05-04'),
('2017-06-01'),
('2017-07-06'),
('2017-08-03'),
('2017-09-07'),
('2017-10-06'),
('2017-11-02'),
('2017-12-07'),
('2018-01-04'),
('2018-02-01'),
('2018-03-01'),
('2018-04-05'),
('2018-05-03'),
('2018-06-07'),
('2018-07-05'),
('2018-08-02'),
('2018-09-06'),
('2018-10-04'),
('2018-11-01'),
('2018-12-06'),
('2019-01-03'),
('2019-02-07'),
('2019-03-07'),
('2019-04-04'),
('2019-05-03'),
('2019-06-06'),
('2019-07-01'),
('2019-07-31'),
('2019-09-02'),
('2019-10-01'),
('2019-11-05'),
('2019-12-02'),
('2019-12-31'),
('2020-02-03'),
('2020-03-02'),
('2020-03-30'),
('2020-05-06'),
('2020-06-02'),
('2020-06-09'),
('2020-06-15'),
('2020-06-22'),
('2020-06-29'),
('2020-07-06'),
('2020-07-17'),
('2020-07-20'),
('2020-07-28'),
('2020-08-03'),
('2020-08-10'),
('2020-08-17'),
('2020-08-24'),
('2020-08-30'),
('2020-09-05'),
('2020-09-14'),
('2020-09-20'),
('2020-09-28'),
('2020-10-03'),
('2020-10-10'),
('2020-10-20'),
('2020-10-26'),
('2020-10-31'),
('2020-11-07'),
('2020-11-14'),
('2020-11-22'),
('2020-11-29'),
('2020-12-08'),
('2020-12-12'),
('2020-12-19'),
('2020-12-26'),
('2021-01-02'),
('2021-01-10'),
('2021-01-19'),
('2021-01-23'),
('2021-01-28'),
('2021-01-31'),
('2021-02-08'),
('2021-02-13'),
('2021-02-21'),
('2021-03-02'),
('2021-03-08'),
('2021-03-15'),
('2021-03-23'),
('2021-03-28'),
('2021-04-04'),
('2021-04-15'),
('2021-04-18'),
('2021-04-24'),
('2021-05-01'),
('2021-05-11'),
('2021-05-17'),
('2021-05-24'),
('2021-05-29'),
('2021-06-09'),
('2021-06-16'),
('2021-06-19'),
('2021-06-26'),
('2021-07-07'),
('2021-07-10'),
('2021-07-18'),
('2021-07-24'),
('2021-07-31'),
('2021-08-07'),
('2021-08-14'),
('2021-08-21'),
('2021-08-28'),
('2021-09-08'),
('2021-09-12'),
('2021-09-19'),
('2021-09-27'),
('2021-09-29'),
('2021-10-02'),
('2021-10-09'),
('2021-10-10'),
('2021-10-16'),
('2021-10-25'),
('2021-10-30'),
('2021-11-07'),
('2021-11-13'),
('2021-11-21'),
('2021-11-30'),
('2021-12-04'),
('2021-12-12'),
('2021-12-18'),
('2021-12-25'),
('2022-01-04'),
('2022-01-09'),
('2022-01-15'),
('2022-01-22'),
('2022-01-29'),
('2022-02-05'),
('2022-02-13'),
('2022-02-23'),
('2022-02-28'),
('2022-03-06'),
('2022-03-13'),
('2022-03-20'),
('2022-03-30'),
('2022-04-03'),
('2022-04-13'),
('2022-04-16'),
('2022-04-25'),
('2022-04-30'),
('2022-05-07'),
('2022-05-17'),
('2022-05-25'),
('2022-05-28'),
('2022-06-06'),
('2022-06-11'),
('2022-06-19'),
('2022-06-20'),
('2022-06-26'),
('2022-07-02'),
('2022-07-10'),
('2022-07-19'),
('2022-07-24'),
('2022-08-01'),
('2022-08-13'),
('2022-08-17'),
('2022-08-24'),
('2022-08-29'),
('2022-09-03'),
('2022-09-10'),
('2022-09-19'),
('2022-09-24'),
('2022-10-01'),
('2022-10-09'),
('2022-10-15'),
('2022-10-22'),
('2022-10-30'),
('2022-11-05'),
('2022-11-13'),
('2022-11-20'),
('2022-11-29'),
('2022-12-03'),
('2022-12-11'),
('2022-12-17'),
('2022-12-24'),
('2022-12-31');