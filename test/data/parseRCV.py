import xml.etree.ElementTree as ET
import pandas as pd
import os

# Load the XML file
xml_file = 'rcv-old-test.xml'

if not os.path.exists(xml_file):
    raise FileNotFoundError(f"The file '{xml_file}' does not exist. Please check the file path and try again.")

# Parse the XML file
tree = ET.parse(xml_file)
root = tree.getroot()

# Namespace if needed (update if the namespace changes)
namespace = {'xsi': 'http://www.w3.org/2001/XMLSchema-instance'}

# Extract ClinVarSet nodes
records = []
for clinvarset in root.findall('ClinVarSet', namespace):
    record_id = clinvarset.attrib.get('ID')
    record_content = ET.tostring(clinvarset, encoding='unicode', method='xml')
    records.append({'id': record_id, 'content': record_content})

0# Convert to DataFrame
clinvar_df = pd.DataFrame(records)

# Save to CSV for BigQuery upload
output_file = 'clinvarset_records.csv'
clinvar_df.to_csv(output_file, index=False, encoding='utf-8')

print(f"Extracted {len(records)} records to {output_file}.")