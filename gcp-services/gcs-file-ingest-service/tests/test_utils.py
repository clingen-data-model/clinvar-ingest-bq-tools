import unittest
import sys
import os
import pandas as pd

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))
from utils import to_snake_case, process_tsv_data, convert_to_bigquery_date  # noqa: E402

# Try to import google.cloud.bigquery, skip tests if not available
try:
    from google.cloud import bigquery  # noqa: E402

    BIGQUERY_AVAILABLE = True
except ImportError:
    BIGQUERY_AVAILABLE = False

    # Create a mock SchemaField for testing
    class MockSchemaField:
        def __init__(self, name, field_type, mode=None):
            self.name = name
            self.field_type = field_type
            self.mode = mode

    bigquery = type("MockBigQuery", (), {"SchemaField": MockSchemaField})()


class TestToSnakeCase(unittest.TestCase):
    def test_various_cases(self):
        cases = [
            ("CamelCase", "camel_case"),
            ("snake_case", "snake_case"),
            ("kebab-case", "kebab_case"),
            ("with spaces", "with_spaces"),
            ("with-mixed Spaces-And-Hyphens", "with_mixed_spaces_and_hyphens"),
            ("already_snake_case", "already_snake_case"),
            ("  leading and trailing  ", "leading_and_trailing"),
            ("simple", "simple"),
            ("", ""),
            ("A", "a"),
            ("aB", "a_b"),
            ("someID", "some_id"),
        ]
        for input_str, expected in cases:
            with self.subTest(input_str=input_str):
                self.assertEqual(to_snake_case(input_str), expected)

    def test_tsv_header_conversion(self):
        tsv_header = (
            "#organization\torganization ID\tinstitution type\tstreet address\tcity\tcountry\t"
            "number of ClinVar submissions\tdate last submitted\tmaximum review status\t"
            "collection methods\tnovel and updates\tclinical significance categories submitted\t"
            "number of submissions from clinical testing\tnumber of submissions from research\t"
            "number of submissions from literature only\tnumber of submissions from curation\t"
            "number of submissions from phenotyping\tsomatic clinical impact values submitted\t"
            "somatic oncogenicity values submitted"
        )
        columns = tsv_header.lstrip("#").split("\t")
        expected = [
            "organization",
            "organization_id",
            "institution_type",
            "street_address",
            "city",
            "country",
            "number_of_clinvar_submissions",
            "date_last_submitted",
            "maximum_review_status",
            "collection_methods",
            "novel_and_updates",
            "clinical_significance_categories_submitted",
            "number_of_submissions_from_clinical_testing",
            "number_of_submissions_from_research",
            "number_of_submissions_from_literature_only",
            "number_of_submissions_from_curation",
            "number_of_submissions_from_phenotyping",
            "somatic_clinical_impact_values_submitted",
            "somatic_oncogenicity_values_submitted",
        ]
        result = [to_snake_case(col) for col in columns]
        self.assertEqual(result, expected)


class TestProcessTsvData(unittest.TestCase):
    def test_process_tsv_data_organization_summary(self):
        # Read the actual organization_summary.txt file from data folder
        data_file_path = os.path.join(
            os.path.dirname(__file__), "..", "data", "organization_summary.txt"
        )
        with open(data_file_path, "r") as f:
            tsv_data = f.read()

        # Define the table config for submitter_organization
        table_config = {"id_column": "organization ID", "delimiter": ","}

        # Call the function
        df = process_tsv_data(tsv_data, table_config)

        # Check that the DataFrame has the expected columns (snake_case converted)
        expected_columns = [
            "organization",  # '#organization' -> 'organization'
            "id",  # 'organization ID' -> 'id'
            "institution_type",
            "street_address",
            "city",
            "country",
            "number_of_clinvar_submissions",
            "date_last_submitted",
            "maximum_review_status",
            "collection_methods",
            "novel_and_updates",
            "clinical_significance_categories_submitted",
            "number_of_submissions_from_clinical_testing",
            "number_of_submissions_from_research",
            "number_of_submissions_from_literature_only",
            "number_of_submissions_from_curation",
            "number_of_submissions_from_phenotyping",
            "somatic_clinical_impact_values_submitted",
            "somatic_oncogenicity_values_submitted",
        ]

        self.assertEqual(list(df.columns), expected_columns)

        # Check that we have data rows (should be > 0)
        self.assertGreater(len(df), 0)

        # Check that the 'id' column contains string values
        self.assertTrue(df["id"].dtype == "object")  # pandas string type

        # Check a few sample values to ensure data was parsed correctly
        first_row = df.iloc[0]
        self.assertEqual(first_row["organization"], "OMIM; Johns Hopkins University")
        self.assertEqual(first_row["id"], "3")
        self.assertEqual(first_row["institution_type"], "resource")
        self.assertEqual(first_row["city"], "Baltimore")
        self.assertEqual(first_row["country"], "United States")


class TestDateConversion(unittest.TestCase):
    def test_convert_to_bigquery_date(self):
        """Test the convert_to_bigquery_date function with various date formats."""
        test_cases = [
            # (input, expected_output)
            ("Jun 26, 2025", "2025-06-26"),
            ("June 26, 2025", "2025-06-26"),
            ("2023-12-01", "2023-12-01"),
            ("12/31/2023", "2023-12-31"),
            ("31/12/2023", "2023-12-31"),  # pandas should handle this
            ("2025-02-28", "2025-02-28"),
            ("", None),
            (None, None),
            ("invalid date", None),
            ("2025-02-30", None),  # invalid date
            ("   ", None),  # whitespace only
        ]

        for input_date, expected in test_cases:
            with self.subTest(input_date=input_date):
                result = convert_to_bigquery_date(input_date)
                if expected is None:
                    self.assertIsNone(result)
                else:
                    self.assertEqual(result, expected)

    def test_process_tsv_data_with_date_conversion(self):
        """Test that process_tsv_data converts DATE columns based on schema."""
        # Create mock schema with DATE field
        mock_schema = [
            bigquery.SchemaField("id", "STRING"),
            bigquery.SchemaField("organization", "STRING"),
            bigquery.SchemaField("date_last_submitted", "DATE"),
            bigquery.SchemaField("city", "STRING"),
        ]

        # Create test TSV data with various date formats
        test_tsv = """organization ID\torganization\tdate last submitted\tcity
123\tTest Org\tJun 26, 2025\tNew York
456\tAnother Org\t12/31/2023\tBoston
789\tThird Org\t\tChicago
999\tFourth Org\t2024-01-15\tSeattle"""

        # Create table config with schema
        table_config = {
            "id_column": "organization ID",
            "schema": mock_schema,
            "delimiter": ",",
        }

        # Process the data
        df = process_tsv_data(test_tsv, table_config)

        # Check that date column was converted properly to date objects
        expected_date_strings = ["2025-06-26", "2023-12-31", None, "2024-01-15"]
        actual_dates = df["date_last_submitted"]

        # Check that the column contains Python date objects or NaT
        for i, expected_str in enumerate(expected_date_strings):
            actual = actual_dates.iloc[i]
            if expected_str is None:
                self.assertTrue(pd.isna(actual), f"Row {i}: expected NaT, got {actual}")
            else:
                import datetime

                expected_date = datetime.datetime.strptime(
                    expected_str, "%Y-%m-%d"
                ).date()
                self.assertEqual(
                    actual,
                    expected_date,
                    f"Row {i}: expected {expected_date}, got {actual}",
                )
                self.assertIsInstance(
                    actual,
                    datetime.date,
                    f"Row {i}: expected date object, got {type(actual)}",
                )

        # Check that other columns weren't affected
        self.assertEqual(
            df["organization"].tolist(),
            ["Test Org", "Another Org", "Third Org", "Fourth Org"],
        )
        self.assertEqual(df["id"].tolist(), ["123", "456", "789", "999"])
        self.assertEqual(
            df["city"].tolist(), ["New York", "Boston", "Chicago", "Seattle"]
        )

    def test_process_tsv_data_no_schema_no_date_conversion(self):
        """Test that without schema, no date conversion occurs."""
        # Test TSV data
        test_tsv = """id\tname\tdate_field
1\tTest\tJun 26, 2025
2\tAnother\t12/31/2023"""

        # Table config without schema
        table_config = {"id_column": "id", "delimiter": "|"}

        # Process the data
        df = process_tsv_data(test_tsv, table_config)

        # Check that date field was NOT converted (remains as original string)
        self.assertEqual(df["date_field"].tolist(), ["Jun 26, 2025", "12/31/2023"])

    def test_process_tsv_data_with_repeated_columns_custom_delimiter(self):
        """Test that process_tsv_data handles REPEATED columns with custom delimiter."""
        # Create mock schema with REPEATED fields
        mock_schema = [
            bigquery.SchemaField("id", "STRING"),
            bigquery.SchemaField("name", "STRING"),
            bigquery.SchemaField("tags", "STRING", mode="REPEATED"),
            bigquery.SchemaField("categories", "STRING", mode="REPEATED"),
        ]

        # Create test TSV data with comma-separated values
        test_tsv = """id\tname\ttags\tcategories
1\tItem A\ttag1,tag2,tag3\tcat1,cat2
2\tItem B\tsingle_tag\tcat3
3\tItem C\t\t"""

        # Create table config with custom delimiter
        table_config = {
            "id_column": "id",
            "schema": mock_schema,
            "delimiter": ",",  # Custom delimiter for REPEATED columns
        }

        # Process the data
        df = process_tsv_data(test_tsv, table_config)

        # Check that REPEATED columns were converted properly
        expected_tags = [["tag1", "tag2", "tag3"], ["single_tag"], []]
        expected_categories = [["cat1", "cat2"], ["cat3"], []]

        self.assertEqual(df["tags"].tolist(), expected_tags)
        self.assertEqual(df["categories"].tolist(), expected_categories)

        # Check that non-REPEATED columns weren't affected
        self.assertEqual(df["name"].tolist(), ["Item A", "Item B", "Item C"])

    def test_process_tsv_data_with_repeated_columns_default_delimiter(self):
        """Test that process_tsv_data uses comma delimiter by default for REPEATED columns."""
        # Create mock schema with REPEATED fields
        mock_schema = [
            bigquery.SchemaField("id", "STRING"),
            bigquery.SchemaField("values", "STRING", mode="REPEATED"),
        ]

        # Create test TSV data with comma-separated values
        test_tsv = """id\tvalues
1\tval1,val2,val3
2\tsingle_val"""

        # Create table config without custom delimiter (should use default ,)
        table_config = {
            "id_column": "id",
            "schema": mock_schema,
            # No delimiter specified - should default to ","
        }

        # Process the data
        df = process_tsv_data(test_tsv, table_config)

        # Check that REPEATED columns were converted properly with comma delimiter
        expected_values = [["val1", "val2", "val3"], ["single_val"]]
        self.assertEqual(df["values"].tolist(), expected_values)


if __name__ == "__main__":
    unittest.main()
