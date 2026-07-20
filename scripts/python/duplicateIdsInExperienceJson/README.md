# JSON ID Duplicate Scanner

A robust, dependency-free Python command-line tool designed to recursively scan directories for `.json` files and detect duplicate identifiers. 

While general-purpose, this tool is highly useful for **Salesforce DX projects** using **Experience Bundles (LWR sites)**, where duplicate component IDs within layout files (e.g., `content.json`, `tablet.json`, `mobile.json`) can prevent successful metadata deployment or cause runtime rendering issues.

---

## Key Features

- **Single-File Scope (Default)**: Finds duplicate IDs used multiple times within the same file.
- **Cross-File Scope (Optional)**: Detects duplicate IDs defined across different files under the repository (via the `--check-global` flag).
- **Duplicate Key Check**: Detects duplicate dictionary keys at the same JSON object level (e.g., `{"id": "foo", "id": "bar"}`).
- **Deep Nesting Support**: Recursively parses and scans properties containing stringified JSON values (commonly used by Salesforce for complex properties like `sectionConfig` and `imageInfo`).
- **CI/CD Integration**: Exits with code `1` when duplicates are found and `0` when the check passes, making it ideal for pre-commit hooks and deployment pipelines.
- **JSON Output**: Produces structured JSON output for easy consumption by other scripts or webhooks.
- **macOS Safe**: Automatically ignores AppleDouble metadata files (`._*`) to avoid false-positive parsing warnings.

---

## Requirements

- **Python 3.3+** (Uses only the standard library; no external dependencies or packages needed).

---

## Installation & Setup

1. Place the [check_duplicate_ids.py](file:///Users/bchalal/projets/SF_FRANCE_ON_SITE/scripts/check_duplicate_ids.py) script in your repository's `scripts/` directory.
2. Mark the script as executable:
   ```bash
   chmod +x scripts/check_duplicate_ids.py
   ```

---

## Usage

```bash
python3 scripts/check_duplicate_ids.py [PATH] [OPTIONS]
```

### Arguments

- `PATH` (Optional): The directory to scan. Defaults to the current directory (`.`).

### Options

| Flag | Type | Description |
| :--- | :--- | :--- |
| `-h`, `--help` | - | Show the help message and exit. |
| `--keys` | List | Space-separated list of JSON keys to treat as identifiers. Defaults to `id`. |
| `--case-sensitive` | Flag | Perform exact case-sensitive matching for identifier keys (e.g. `Id` vs `id`). Defaults to case-insensitive. |
| `--check-global` | Flag | Also scan for duplicate IDs used across different files. Disabled by default. |
| `--ignore-nested` | Flag | Disable the scanning/parsing of nested stringified JSON properties. |
| `--exclude-dirs` | List | Directories to ignore during traversal. Defaults to: `.git`, `node_modules`, `.sf`, `.sfdx`, and `.vscode`. |
| `--no-color` | Flag | Strip ANSI colors from command line stdout. |
| `--json-output` | Flag | Output the final report in structured JSON format. |

---

## Command Examples

### 1. Run a Standard Scan
Scans for duplicate `id` keys (case-insensitive) inside single files under the current directory:
```bash
python3 scripts/check_duplicate_ids.py
```

### 2. Search for Custom Keys
Look for both `id` and `UUID` identifiers:
```bash
python3 scripts/check_duplicate_ids.py --keys id UUID
```

### 3. Check for Global/Cross-File Duplicates
Check for duplicates within files AND warn if different files share matching IDs:
```bash
python3 scripts/check_duplicate_ids.py . --check-global
```

### 4. Output Results to a JSON File
Scan a specific project path and dump the results to a file for ingestion:
```bash
python3 scripts/check_duplicate_ids.py force-app/main/default --json-output > scan_report.json
```

---

## Output Examples

### Standard Human-Readable Console Output (Errors Found)
```
=== JSON ID Duplicate Scanner ===
Directory: /Users/username/projects/SF_FRANCE_ON_SITE
Scanned files: 2039
Target ID keys: id (Case-sensitive: False)
========================================

❌ Duplicate IDs within individual files (1 files):
  - force-app/main/default/digitalExperiences/site/ESGCAMPUS/sfdc_cms__themeLayout/scopedHeaderAndFooter/tablet/tablet.json:
    * ID: 'fd2df84f-fa90-4575-befa-dcc07fd9fa5f' (found 2 times)
      path: contentBody.component.children[0].id
      path: contentBody.component.children[1].id

Scan complete. Duplicates were found.
```

### JSON Output
```json
{
  "summary": {
    "directory_scanned": "/Users/username/projects/SF_FRANCE_ON_SITE",
    "files_scanned": 2039,
    "files_with_errors": 0,
    "has_duplicates": true
  },
  "errors": {},
  "duplicate_keys": {},
  "local_duplicates": {
    "force-app/main/default/digitalExperiences/site/ESGCAMPUS/sfdc_cms__themeLayout/scopedHeaderAndFooter/tablet/tablet.json": {
      "fd2df84f-fa90-4575-befa-dcc07fd9fa5f": [
        "contentBody.component.children[0].id",
        "contentBody.component.children[1].id"
      ]
    }
  }
}
```
