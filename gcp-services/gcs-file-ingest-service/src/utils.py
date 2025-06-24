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


def process_tsv_data(tsv_data, table_config):
    """
    Process TSV data string into a DataFrame based on table configuration.
    Args:
        tsv_data (str): TSV data as string.
        table_config (dict): Table configuration with id_column and list_columns.
    Returns:
        pd.DataFrame: Processed DataFrame ready for BigQuery.
    """
    id_column = table_config.get("id_column")
    list_columns = table_config.get("list_columns", [])

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

    return df
