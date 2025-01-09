import re
import xmltodict
import json
import pandas as pd
import gzip

def save_records_to_csv(records, file_counter, output_prefix):
    # Convert to DataFrame
    clinvar_df = pd.DataFrame(records)

    # Save to CSV for BigQuery upload
    output_file = f'{output_prefix}_part{str(file_counter).zfill(3)}.csv'
    clinvar_df.to_csv(output_file, index=False, encoding='utf-8', header=False)

def split_clinvarset_file(file_path, output_prefix):
    # Define the pattern to match whitespace between </ClinVarSet> and <ClinVarSet
    pattern = r"</ClinVarSet>\n"
    regex = re.compile(pattern)
    chunk_size = 1024 * 1024  # 1MB chunks
    file_counter = 1
    record_counter = 1
    buffer = ""
    records = []

    with gzip.open(file_path, 'rt', encoding='utf-8') as large_file:
        # Skip the first line
        large_file.readline()        
        # file_size = large_file.seek(0, 2)  # Get the total file size

        while True:
            chunk = large_file.read(chunk_size)
            if not chunk:
                break

            # Add the new chunk to the buffer
            buffer += chunk

            # Split the buffer based on the pattern
            splits = regex.split(buffer)

            # Keep the last part of the buffer to ensure complete patterns
            buffer = splits.pop()  # Save the leftover part for the next chunk

            # Write each split to a new file
            for split_content in splits:
                
                # Add back the pattern to the start of the next split
                if split_content.strip():
                    
                    # Print the progress 
                    # progress = ((large_file.tell() - len(chunk)) / file_size) * 100
                    # print(f'\rProcessed records: {record_counter} - {progress:.2f}% complete', end='', flush=True)
                    print(f'\rProcessed records: {record_counter}', end='', flush=True)
                    
                    xml_content = split_content.strip() + '\n</ClinVarSet>'

                    # if file_counter > 30:
                    # Convert XML to a dictionary
                    data_dict = xmltodict.parse(xml_content)

                    record_id = data_dict['ClinVarSet']['@ID']
                    record_content = json.dumps(data_dict)

                    records.append({'id': record_id, 'content': record_content})

                    # Write the record to a csv file every 100,000 records
                    if record_counter % 100000 == 0:
                        
                        # if file_counter > 30:
                        save_records_to_csv(records, file_counter, output_prefix)

                        # Reset the records list
                        records = []
                        file_counter += 1

                    # # Convert the dictionary to JSON
                    # with open(json_file, 'w', encoding='utf-8') as file:
                    #     json.dump(data_dict, file)

                    record_counter += 1

        # Do NOT Write the last bit of content since it will be the </ReleaseSet>
        # if buffer.strip():
        #     output_file = f"{output_prefix}_part{file_counter}.txt"
        #     with open(output_file, 'w', encoding='utf-8') as output:
        #         output.write(buffer.strip())

        # Save the remaining records to a CSV file  
        save_records_to_csv(records, file_counter, output_prefix)

# Usage example
file_path = "/Users/lbabb/Downloads/rcv3/ClinVarFullRelease_2024-01.xml.gz"
output_prefix = "/Users/lbabb/Downloads/rcv3/rcv_clinvarset_recs"
split_clinvarset_file(file_path, output_prefix)