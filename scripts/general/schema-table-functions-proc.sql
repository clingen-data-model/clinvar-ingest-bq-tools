BEGIN
    DECLARE project_id STRING;
    DECLARE sql_stmt STRING DEFAULT "";
    DECLARE where_clause STRING DEFAULT "";

    SET project_id = (
        SELECT 
            catalog_name as paroject_id
        FROM `INFORMATION_SCHEMA.SCHEMATA`
        WHERE 
            schema_name = 'clinvar_ingest'
    );

    IF (project_id = 'clingen-stage') THEN
        SET sql_stmt = FORMAT("""
            SELECT
                'clinvar_2019_06_01_v0' as schema_name,
                v.release_date
            FROM `clinvar_2019_06_01_v0.variation` v
            GROUP BY 
                v.release_date
            UNION ALL
        """);
        SET where_clause = "AND iss.schema_name <> 'clinvar_2019_06_01_v0'";
    END IF;

    EXECUTE IMMEDIATE FORMAT("""
        CREATE OR REPLACE TABLE FUNCTION `clinvar_ingest.all_schemas`()
        AS (
            -- the state of al clinvar schemas available at the moment
            SELECT 
                r.schema_name,
                r.release_date,
                LAG(r.release_date, 1, DATE('0001-01-01')) OVER (ORDER BY r.release_date ASC) AS prev_release_date,
                LEAD(r.release_date, 1, DATE('9999-12-31')) OVER (ORDER BY r.release_date ASC) AS next_release_date
            FROM (
                %s
                SELECT
                    iss.schema_name,
                    CAST(
                        REGEXP_REPLACE(
                            iss.schema_name, 
                            r'clinvar_(\\d{4})_(\\d{2})_(\\d{2}).*', 
                            '\\\\1-\\\\2-\\\\3'
                        ) as DATE
                    ) AS release_date
                FROM INFORMATION_SCHEMA.SCHEMATA iss
                WHERE (
                    REGEXP_CONTAINS(iss.schema_name, r'^clinvar_\\d{4}_\\d{2}_\\d{2}_v\\d_\\d+_\\d+$')
                )
                %s
            ) r
            ORDER BY 2
        )
    """, sql_stmt, where_clause );

    EXECUTE IMMEDIATE FORMAT("""
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
        )
    """);

    EXECUTE IMMEDIATE FORMAT("""
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
        )
    """);
    
    EXECUTE IMMEDIATE FORMAT("""
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
        )
    """);

END;