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
    Returns None for invalid/empty dates to allow pandas to_datetime to handle as NaT.
    """
    if pd.isna(date_value) or date_value == "" or str(date_value).strip() == "":
        return None

    try:
        parsed_date = pd.to_datetime(date_value, errors="raise")
        if pd.isna(parsed_date):
            return None
        return parsed_date.strftime("%Y-%m-%d")
    except (ValueError, TypeError):
        return None


def process_tsv_data(tsv_data, table_config):
    """
    Process TSV data string into a DataFrame based on table configuration.
    Args:
        tsv_data (str): TSV data as string.
        table_config (dict): Table configuration with id_column, schema, and delimiter.
                           - delimiter: Character to split REPEATED columns (default: ",")
    Returns:
        pd.DataFrame: Processed DataFrame ready for BigQuery.
    """
    id_column = table_config.get("id_column")
    schema = table_config.get("schema", [])
    delimiter = table_config.get("delimiter", ",")

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

    # Process each column based on its schema definition
    for field in schema:
        col_name = field.name
        if col_name not in df.columns:
            continue

        is_repeated = hasattr(field, "mode") and field.mode == "REPEATED"

        if is_repeated:
            # First split REPEATED columns using the configured delimiter
            df[col_name] = (
                df[col_name]
                .fillna("")
                .apply(
                    lambda x: [s.strip() for s in str(x).split(delimiter)]
                    if str(x).strip()
                    else []
                )
            )

            # Then apply type conversion to each element in the REPEATED column
            if field.field_type == "DATE":
                df[col_name] = df[col_name].apply(
                    lambda x: [convert_to_bigquery_date(item) for item in x]
                    if x
                    else []
                )
                # Convert each date string to date object
                df[col_name] = df[col_name].apply(
                    lambda x: [
                        pd.to_datetime(item, errors="coerce").date() if item else None
                        for item in x
                    ]
                    if x
                    else []
                )
            elif field.field_type == "INTEGER":
                df[col_name] = df[col_name].apply(
                    lambda x: [pd.to_numeric(item, errors="coerce") for item in x]
                    if x
                    else []
                )
            # STRING REPEATED columns are already processed (split into list of strings)

        else:
            # Process non-REPEATED columns
            if field.field_type == "DATE":
                df[col_name] = df[col_name].apply(convert_to_bigquery_date)
                # Convert to date objects for PyArrow compatibility
                df[col_name] = pd.to_datetime(df[col_name], errors="coerce").dt.date
            elif field.field_type == "INTEGER":
                # Convert to nullable integer type to handle NaN values properly
                df[col_name] = pd.to_numeric(df[col_name], errors="coerce").astype(
                    "Int64"
                )
            elif field.field_type == "STRING":
                # Replace empty strings with None for proper NULL handling
                df[col_name] = df[col_name].replace("", None)

    return df
