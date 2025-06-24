import re
import pandas as pd
import io


def to_snake_case(s):
    """Convert a string to snake_case."""
    # Case-insensitive replacement of clinvar with Clinvar
    s = re.sub(r"clinvar", "Clinvar", s, flags=re.IGNORECASE)
    # Replace any non-alphanumeric characters with spaces
    s = re.sub(r"[^a-zA-Z0-9]", " ", s)
    s = re.sub(
        r"\s+", "_", s.strip()
    )  # replace multiple spaces with single underscores
    s = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", s)  # camelCase → camel_case
    return s.lower()


def convert_to_bigquery_date(date_value):
    """
    Convert various date formats to BigQuery DATE format (YYYY-MM-DD).
    Returns pd.NaT for invalid/empty dates to allow BigQuery to handle as NULL.
    """
    if pd.isna(date_value) or date_value == "" or str(date_value).strip() == "":
        return pd.NaT

    try:
        parsed_date = pd.to_datetime(date_value, errors="raise")
        if pd.isna(parsed_date):
            return pd.NaT
        return parsed_date.strftime("%Y-%m-%d")
    except (ValueError, TypeError):
        return pd.NaT


def process_tsv_data(tsv_data, table_config):
    """
    Process TSV data string into a DataFrame based on table configuration.
    Args:
        tsv_data (str): TSV data as string.
        table_config (dict): Table configuration with id_column, list_columns, and schema.
    Returns:
        pd.DataFrame: Processed DataFrame ready for BigQuery.
    """
    id_column = table_config.get("id_column")
    list_columns = table_config.get("list_columns", [])
    schema = table_config.get("schema", [])

    df = pd.read_csv(io.StringIO(tsv_data), sep="\t")

    # Rename columns: id_column -> 'id', others to snake_case
    renamed_columns = {}
    for col in df.columns:
        if col.strip() == id_column:
            renamed_columns[col] = "id"
        else:
            renamed_columns[col] = to_snake_case(col)
    df.rename(columns=renamed_columns, inplace=True)

    # Convert 'id' to STRING
    if "id" in df.columns:
        df["id"] = df["id"].astype(str)

    # Convert specified columns to list of strings, splitting on pipe '|'
    for col in list_columns:
        if col in df.columns:
            df[col] = (
                df[col]
                .fillna("")
                .apply(lambda x: [s.strip() for s in x.split("|")] if x else [])
            )

    # Convert columns based on schema types for BigQuery compatibility
    date_columns = []
    integer_columns = []

    for field in schema:
        if field.field_type == "DATE":
            date_columns.append(field.name)
        elif field.field_type == "INTEGER":
            integer_columns.append(field.name)

    # Convert DATE columns
    for col in date_columns:
        if col in df.columns:
            df[col] = df[col].apply(convert_to_bigquery_date)

    # Ensure INTEGER columns are properly typed and handle NaN
    for col in integer_columns:
        if col in df.columns:
            # Convert to nullable integer type to handle NaN values properly
            df[col] = pd.to_numeric(df[col], errors="coerce").astype("Int64")

    # Convert empty strings to None for STRING columns to ensure proper NULL handling
    string_columns = [field.name for field in schema if field.field_type == "STRING"]
    for col in string_columns:
        if col in df.columns:
            # Replace empty strings with None for proper NULL handling
            df[col] = df[col].replace("", None)

    return df
