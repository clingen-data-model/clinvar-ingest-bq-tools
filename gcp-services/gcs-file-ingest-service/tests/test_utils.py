import unittest
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))
from utils import to_snake_case, process_tsv_data  # noqa: E402


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
        table_config = {"id_column": "organization ID", "list_columns": []}

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


if __name__ == "__main__":
    unittest.main()
