import xml.etree.ElementTree as ET
from collections import defaultdict
import argparse
import os
import sys

def find_duplicates(file_path):
    # 1. Verify file exists
    if not os.path.exists(file_path):
        print(f"Error: The file '{file_path}' was not found.")
        sys.exit(1)

    # 2. Parse the XML file
    try:
        tree = ET.parse(file_path)
        root = tree.getroot()
    except ET.ParseError:
        print(f"Error: Could not parse '{file_path}'. It may not be valid XML.")
        sys.exit(1)

    # 3. Strip Namespaces
    for elem in root.iter():
        if '}' in elem.tag:
            elem.tag = elem.tag.split('}', 1)[1]

    print(f"--- Scanning: {file_path} ---\n")
    total_issues = 0

    # ==========================================
    # CHECK 1: Profile Action Overrides
    # ==========================================
    print(">>> Checking <profileActionOverrides>...")
    profile_entries = defaultdict(list)
    
    for override in root.findall('profileActionOverrides'):
        # Key identifiers
        profile = override.findtext('profile', 'No Profile')
        action = override.findtext('actionName', 'Unknown Action')
        sobject = override.findtext('pageOrSobjectType', 'Unknown Object')
        record_type = override.findtext('recordType', 'Default Record Type')
        form_factor = override.findtext('formFactor', 'All Factors')
        
        # Target content
        content = override.findtext('content', 'Unknown Content')

        # Unique Key: Profile + Action + Object + RecordType + FormFactor
        unique_key = (profile, action, sobject, record_type, form_factor)
        profile_entries[unique_key].append(content)

    # Report Profile Duplicates
    p_dupes = 0
    for key, contents in profile_entries.items():
        if len(contents) > 1:
            p_dupes += 1
            total_issues += 1
            print(f"\n[!] DUPLICATE PROFILE OVERRIDE:")
            print(f"    Profile:    {key[0]}")
            print(f"    Action:     {key[1]} | Object: {key[2]}")
            print(f"    RecordType: {key[3]} | FormFactor: {key[4]}")
            print(f"    Targets:    {', '.join(contents)}")
            
    if p_dupes == 0:
        print("    No duplicates found.")


    # ==========================================
    # CHECK 2: Action Overrides (Global)
    # ==========================================
    print("\n>>> Checking <actionOverrides>...")
    action_entries = defaultdict(list)

    for override in root.findall('actionOverrides'):
        # Key identifiers (Note: No Profile or RecordType here usually)
        action = override.findtext('actionName', 'Unknown Action')
        sobject = override.findtext('pageOrSobjectType', 'Unknown Object')
        form_factor = override.findtext('formFactor', 'All Factors')
        
        # Target content
        content = override.findtext('content', 'Unknown Content')

        # Unique Key: Action + Object + FormFactor
        unique_key = (action, sobject, form_factor)
        action_entries[unique_key].append(content)

    # Report Action Duplicates
    a_dupes = 0
    for key, contents in action_entries.items():
        if len(contents) > 1:
            a_dupes += 1
            total_issues += 1
            print(f"\n[!] DUPLICATE ACTION OVERRIDE:")
            print(f"    Action:     {key[0]}")
            print(f"    Object:     {key[1]}")
            print(f"    FormFactor: {key[2]}")
            print(f"    Targets:    {', '.join(contents)}")

    if a_dupes == 0:
        print("    No duplicates found.")

    # ==========================================
    # SUMMARY
    # ==========================================
    print("-" * 40)
    if total_issues == 0:
        print("✅ SUCCESS: File is clean. No duplicates found.")
    else:
        print(f"❌ ISSUES FOUND: {total_issues} duplicate sets detected.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Detect duplicates in Salesforce application metadata.')
    parser.add_argument('file_path', help='Path to the Salesforce XML metadata file')
    args = parser.parse_args()
    
    find_duplicates(args.file_path)