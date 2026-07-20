# 📂 Salesforce Email Masking Tool (R)

This tool automatically detects all email fields on specified Salesforce objects and appends `.invalid` to them. It is designed for use in **Sandboxes** to prevent accidental emails to real customers during testing.

---

## 🚀 Getting Started

### 1. Prerequisites
Before running the script, ensure you have the following installed on your machine:
* **R:** [Download here](https://cran.r-project.org/)
* **VS Code:** [Download here](https://code.visualstudio.com/)
* **VS Code R Extension:** Search for `R` in the VS Code extensions marketplace and install it.

### 2. Setup
1. Open your project folder in VS Code.
2. Open the script file (e.g., `scripts/R/emailInvalidR/emailInvalid.R`).
3. If this is your first time running it, the script will automatically download the necessary R libraries (like `salesforcer`, `dplyr`, and `cli`).

---

## ⚙️ Configuration
At the top of the script, you will see a section labeled **`# 2. CONFIGURATION`**. Update these parameters before running:

| Parameter | Purpose | Example Value |
| :--- | :--- | :--- |
| `target_objects` | A list of Salesforce objects you want to scan. | `c("Contact", "Lead", "Custom_Obj__c")` |
| `API_THRESHOLD` | The record count limit. If a table is larger than this, it uses the **Bulk API** for better performance. | `1000` |
| `login_url` | The URL for your Salesforce environment (usually a sandbox). | `https://2pace-uat.sandbox.my.salesforce.com` |

---

## 🏃 How to Run
1. **Highlight All Code:** Press `Ctrl + A` (Windows) or `Cmd + A` (Mac).
2. **Execute:** Press `Ctrl + Enter` (Windows) or `Cmd + Enter` (Mac).
3. **Log In:** A browser window will pop up asking you to log into Salesforce. Use your Sandbox credentials. 
4. **Monitor:** Switch back to the VS Code **Terminal/Console**. You will see real-time updates:
   * 🔵 **Blue (Info):** Tells you which object is being scanned.
   * ✅ **Green (Success):** Confirms records were updated.
   * ❌ **Red (Error):** Lists records that failed (usually due to Salesforce validation rules).

---

## 🛠️ How it Works (Step-by-Step)
The script follows a 5-step automated process:
1. **Metadata Inspection:** It asks Salesforce for the "blueprint" of your object to find every field marked as an "Email" type.
2. **Volume Check:** It counts the records to decide if it should use the **REST API** (fast for small data) or **Bulk API** (efficient for large data).
3. **Data Download:** It pulls the IDs and current email addresses into R.
4. **The Transformation:** It appends `.invalid` to addresses that don't already have it (it skips empty cells or emails already marked).
5. **Delta Update:** It compares the old data to the new data and **only** uploads the records that actually changed, saving you API credits.

---

## ⚠️ Important Safety Notes
* **Backup First:** Always ensure you have a data backup or have tested the script on a single object first by setting `target_objects <- c("Contact")`.
* **Validation Rules:** If Salesforce has a rule requiring a specific email format, the `.invalid` suffix might cause an error. These errors will be listed in the **Final Error Summary** at the end of the run.
* **Email Deliverability:** Even though we are changing addresses to be invalid, it is a "best practice" to set **Email Deliverability** to "System Email Only" in Salesforce Setup during large data updates.