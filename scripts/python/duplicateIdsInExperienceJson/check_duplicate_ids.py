#!/usr/bin/env python3
import os
import sys
import json
import argparse
from collections import defaultdict

# ANSI colors for terminal output
COLOR_RED = "\033[91m"
COLOR_GREEN = "\033[92m"
COLOR_YELLOW = "\033[93m"
COLOR_BLUE = "\033[94m"
COLOR_BOLD = "\033[1m"
COLOR_RESET = "\033[0m"

def disable_colors():
    global COLOR_RED, COLOR_GREEN, COLOR_YELLOW, COLOR_BLUE, COLOR_BOLD, COLOR_RESET
    COLOR_RED = ""
    COLOR_GREEN = ""
    COLOR_YELLOW = ""
    COLOR_BLUE = ""
    COLOR_BOLD = ""
    COLOR_RESET = ""

def parse_args():
    parser = argparse.ArgumentParser(
        description="Scan repository JSON files for duplicate 'Id' nodes/values."
    )
    parser.head = "JSON ID Duplicate Checker"
    parser.add_argument(
        "path",
        nargs="?",
        default=".",
        help="Path to the repository/directory to check (default: current directory)."
    )
    parser.add_argument(
        "--case-sensitive",
        action="store_true",
        help="Perform case-sensitive matching for the 'Id' key (matches exactly 'Id')."
    )
    parser.add_argument(
        "--ignore-nested",
        action="store_true",
        help="Do not attempt to parse and scan nested JSON strings (e.g. sectionConfig attributes)."
    )
    parser.add_argument(
        "--no-color",
        action="store_true",
        help="Disable colored output."
    )
    parser.add_argument(
        "--json-output",
        action="store_true",
        help="Output the final report in JSON format."
    )
    parser.add_argument(
        "--exclude-dirs",
        nargs="*",
        default=[".git", "node_modules", ".sf", ".sfdx", ".vscode"],
        help="Directories to ignore during scanning."
    )
    parser.add_argument(
        "--keys",
        nargs="+",
        default=["id"],
        help="JSON keys to treat as identifiers (default: 'id'). If case-insensitive, 'id' matches 'Id', 'ID', etc."
    )
    parser.add_argument(
        "--check-global",
        action="store_true",
        help="Also check for duplicate IDs across different files (disabled by default)."
    )
    return parser.parse_args()

def extract_ids_from_data(data, path="", match_keys=None, case_sensitive=False, parse_nested=True):
    """
    Recursively scans parsed JSON data for keys representing identifiers.
    Returns a list of dicts: {"id": value, "path": path}
    """
    if match_keys is None:
        match_keys = {"id"}
    
    results = []

    # Check if string contains nested JSON
    if parse_nested and isinstance(data, str):
        stripped = data.strip()
        if (stripped.startswith('{') and stripped.endswith('}')) or (stripped.startswith('[') and stripped.endswith(']')):
            try:
                nested_data = json.loads(stripped)
                return extract_ids_from_data(
                    nested_data, 
                    path + " (nested)", 
                    match_keys, 
                    case_sensitive, 
                    parse_nested
                )
            except Exception:
                pass # Treat as normal string if parsing fails
                
    if isinstance(data, dict):
        for k, v in data.items():
            current_path = f"{path}.{k}" if path else k
            
            is_match = False
            if case_sensitive:
                is_match = k in match_keys
            else:
                k_lower = k.lower()
                is_match = any(mk.lower() == k_lower for mk in match_keys)
                
            if is_match and isinstance(v, (str, int, float)):
                results.append({"id": str(v), "path": current_path})
                
            # Recurse into dictionary values
            results.extend(
                extract_ids_from_data(v, current_path, match_keys, case_sensitive, parse_nested)
            )
            
    elif isinstance(data, list):
        for idx, item in enumerate(data):
            current_path = f"{path}[{idx}]"
            results.extend(
                extract_ids_from_data(item, current_path, match_keys, case_sensitive, parse_nested)
            )
            
    return results

def scan_file(filepath, match_keys, case_sensitive, parse_nested):
    """
    Parses a single JSON file and finds all IDs and checks for duplicate keys.
    Returns: (ids_list, duplicate_keys_list, error_msg)
    """
    duplicate_keys = []
    
    # Custom hook to check for duplicate keys at the same dictionary level
    def object_pairs_hook(pairs):
        seen = set()
        res = {}
        for k, v in pairs:
            if k in seen:
                duplicate_keys.append(k)
            seen.add(k)
            res[k] = v
        return res

    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
            if not content.strip():
                return [], [], None # Empty file, not duplicates
            
            data = json.loads(content, object_pairs_hook=object_pairs_hook)
            ids = extract_ids_from_data(
                data, 
                path="", 
                match_keys=match_keys, 
                case_sensitive=case_sensitive, 
                parse_nested=parse_nested
            )
            return ids, duplicate_keys, None
    except json.JSONDecodeError as e:
        return [], [], f"JSON syntax error: {str(e)}"
    except Exception as e:
        return [], [], f"Failed to read/parse: {str(e)}"

def run():
    args = parse_args()
    
    if args.no_color or args.json_output:
        disable_colors()
        
    search_dir = os.path.abspath(args.path)
    if not os.path.exists(search_dir):
        print(f"{COLOR_RED}Error: Path '{search_dir}' does not exist.{COLOR_RESET}", file=sys.stderr)
        sys.exit(1)
        
    match_keys = set(args.keys)
    exclude_dirs = set(args.exclude_dirs)
    
    # Trackers
    files_scanned = 0
    files_with_errors = {}
    
    # Within-file duplicate tracker: filepath -> id_value -> list of paths
    local_duplicates = defaultdict(lambda: defaultdict(list))
    # Within-file duplicate key tracker: filepath -> list of duplicate keys
    local_duplicate_keys = defaultdict(list)
    
    # Across-file global tracker: id_value -> list of (filepath, json_path)
    global_ids = defaultdict(list)
    
    # Crawl the directory tree
    for root, dirs, files in os.walk(search_dir):
        # Modifying dirs in-place to skip excluded directories
        dirs[:] = [d for d in dirs if d not in exclude_dirs]
        
        for file in files:
            if file.endswith('.json') and not file.startswith('._'):
                filepath = os.path.join(root, file)
                rel_path = os.path.relpath(filepath, search_dir)
                files_scanned += 1
                
                ids, dup_keys, err = scan_file(
                    filepath, 
                    match_keys, 
                    args.case_sensitive, 
                    not args.ignore_nested
                )
                
                if err:
                    files_with_errors[rel_path] = err
                    continue
                    
                if dup_keys:
                    local_duplicate_keys[rel_path].extend(dup_keys)
                    
                # Track IDs in the current file
                file_id_counts = defaultdict(list)
                for id_info in ids:
                    id_val = id_info["id"]
                    id_path = id_info["path"]
                    
                    file_id_counts[id_val].append(id_path)
                    global_ids[id_val].append((rel_path, id_path))
                    
                # Identify local duplicates (within this file)
                for id_val, paths in file_id_counts.items():
                    if len(paths) > 1:
                        local_duplicates[rel_path][id_val] = paths

    # Format output
    has_duplicates = bool(local_duplicates) or bool(local_duplicate_keys)
    
    # Calculate global duplicates if requested
    global_duplicates = {}
    global_cross_file_duplicates = {}
    if args.check_global:
        for id_val, occurrences in global_ids.items():
            if len(occurrences) > 1:
                global_duplicates[id_val] = occurrences
                files_involved = {occ[0] for occ in occurrences}
                if len(files_involved) > 1:
                    global_cross_file_duplicates[id_val] = occurrences
        
        if global_cross_file_duplicates:
            has_duplicates = True

    if args.json_output:
        # Construct JSON output
        report = {
            "summary": {
                "directory_scanned": search_dir,
                "files_scanned": files_scanned,
                "files_with_errors": len(files_with_errors),
                "has_duplicates": has_duplicates
            },
            "errors": files_with_errors,
            "duplicate_keys": {f: keys for f, keys in local_duplicate_keys.items()},
            "local_duplicates": {
                f: {id_val: paths for id_val, paths in ids_map.items()} 
                for f, ids_map in local_duplicates.items()
            }
        }
        if args.check_global:
            report["global_duplicates"] = {
                id_val: [{"file": occ[0], "path": occ[1]} for occ in occurrences]
                for id_val, occurrences in global_cross_file_duplicates.items()
            }
        print(json.dumps(report, indent=2))
    else:
        # Human-readable output
        print(f"{COLOR_BOLD}=== JSON ID Duplicate Scanner ==={COLOR_RESET}")
        print(f"Directory: {search_dir}")
        print(f"Scanned files: {files_scanned}")
        print(f"Target ID keys: {', '.join(match_keys)} (Case-sensitive: {args.case_sensitive})")
        print("=" * 40)
        
        # 1. Print syntax/read errors
        if files_with_errors:
            print(f"\n{COLOR_RED}{COLOR_BOLD}⚠️  Files with parsing errors ({len(files_with_errors)}):{COLOR_RESET}")
            for file, err in files_with_errors.items():
                print(f"  - {COLOR_YELLOW}{file}{COLOR_RESET}: {err}")
                
        # 2. Print duplicate dictionary keys
        if local_duplicate_keys:
            print(f"\n{COLOR_RED}{COLOR_BOLD}⚠️  Duplicate JSON Keys found in same object ({len(local_duplicate_keys)} files):{COLOR_RESET}")
            for file, keys in local_duplicate_keys.items():
                print(f"  - {COLOR_YELLOW}{file}{COLOR_RESET}:")
                for key in set(keys):
                    count = keys.count(key) + 1
                    print(f"    * Key '{COLOR_RED}{key}{COLOR_RESET}' defined {count} times")

        # 3. Print local duplicates (within the same file)
        if local_duplicates:
            print(f"\n{COLOR_RED}{COLOR_BOLD}❌ Duplicate IDs within individual files ({len(local_duplicates)} files):{COLOR_RESET}")
            for file, ids_map in local_duplicates.items():
                print(f"  - {COLOR_YELLOW}{file}{COLOR_RESET}:")
                for id_val, paths in ids_map.items():
                    print(f"    * ID: '{COLOR_RED}{id_val}{COLOR_RESET}' (found {len(paths)} times)")
                    for p in paths:
                        print(f"      path: {p}")

        # 4. Print global duplicates (across files) if enabled
        if args.check_global and global_cross_file_duplicates:
            print(f"\n{COLOR_RED}{COLOR_BOLD}❌ Cross-File Duplicate IDs ({len(global_cross_file_duplicates)} unique IDs):{COLOR_RESET}")
            for id_val, occurrences in global_cross_file_duplicates.items():
                print(f"  - ID: '{COLOR_RED}{id_val}{COLOR_RESET}' (defined across {len({o[0] for o in occurrences})} files):")
                for file, path in occurrences:
                    print(f"    * {COLOR_BLUE}{file}{COLOR_RESET} -> {path}")

        if not has_duplicates and not files_with_errors:
            print(f"\n{COLOR_GREEN}{COLOR_BOLD}✓ No duplicate IDs or JSON parsing errors found!{COLOR_RESET}")
        elif has_duplicates:
            print(f"\n{COLOR_RED}{COLOR_BOLD}Scan complete. Duplicates were found.{COLOR_RESET}")

    # Return exit code
    if has_duplicates:
        sys.exit(1)
    else:
        sys.exit(0)

if __name__ == "__main__":
    run()
