#!/usr/bin/env Rscript
# List of required packages
packages <- c("googlesheets4", "purrr", "fs","httpuv")

# Install missing packages automatically
new_packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new_packages)) install.packages(new_packages, repos='https://cran.rstudio.com/')

# Load libraries
library(googlesheets4)
library(purrr)
library(fs)

# ... rest of your script

# Get arguments from command line
args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0) {
  stop("Error: No Google Sheet URL provided.", call. = FALSE)
}

gs_url <- args[1] # The first parameter passed

# Authenticate (Non-interactive mode recommended for repeated tasks)
gs4_auth(email = TRUE) 

sheet_names <- sheet_names(gs_url)
# 2. Function to generate XML content
generate_gvs_xml <- function(sheet_name) {
  
  # Read the data from the specific tab
  # Expects Column A (Value/API), Column B (Label), and Cell I2 for Description
  df <- read_sheet(gs_url, sheet = sheet_name)
  
  # Salesforce XML structure components
  header <- '<?xml version="1.0" encoding="UTF-8"?>\n<GlobalValueSet xmlns="http://soap.sforce.com/2006/04/metadata">'
  
  # Loop over rows to create <customValue> blocks
  # Assumes Column 1 is API Name (fullName) and Column 2 is Label
  values_xml <- pmap_chr(df, function(...) {
    row <- list(...)
    paste0(
      '    <customValue>\n',
      '        <fullName>', row[[1]], '</fullName>\n',
      '        <default>false</default>\n',
      '        <label>', row[[2]], '</label>\n',
      '    </customValue>'
    )
  }) %>% paste(collapse = "\n")
  
  # Get description from Cell I2 (Row 1 of Column 9 in the dataframe)
  # Note: read_sheet might shift indices depending on empty rows; adjust as needed.
  description <- ifelse(!is.null(df[[1, 9]]), df[[1, 9]], "")
  
  footer <- paste0(
    '\n    <description>', description, '</description>\n',
    '    <masterLabel>', sheet_name, '</masterLabel>\n',
    '    <sorted>false</sorted>\n',
    '</GlobalValueSet>'
  )
  
  # Combine everything
  full_xml <- paste(header, values_xml, footer, sep = "\n")
  
  # 3. Save to file
  file_name <- paste0("force-app/main/default/globalValueSets/",sheet_name, ".globalValueSet-meta.xml")
  writeLines(full_xml, file_name)
  message(paste("Successfully created:", file_name))
}

# Execute for all tabs
walk(sheet_names, generate_gvs_xml)
# 2. Function to generate Field Metadata
generate_field_metadata <- function(sheet_name) {
  
  # Read the data
  df <- read_sheet(gs_url, sheet = sheet_name)
  
  # Iterate through each row to create Field files
  pwalk(df, function(...) {
    row <- list(...)
    
    # Mapping columns based on your requirement:
    # C = row[[3]] (Object Name), D = row[[4]] (Label), E = row[[5]] (Field API)
    # F = row[[6]] (Description), G = row[[7]] required check H = row[[8]] (Multiselect check)
    
    obj_name   <- row[[3]]
    field_label <- row[[4]]
    field_api   <- row[[5]]
    description <- row[[6]]
    isRequired <- !is.na(row[[8]]) # True if H is not empty
    is_multi    <- !is.na(row[[7]]) # True if G is not empty
    
    # Define XML Logic
    field_type <- if(is_multi) "MultiselectPicklist" else "Picklist"
    is_required <- if(is_multi) "true" else "false"
    
    field_xml <- paste0(
      '<?xml version="1.0" encoding="UTF-8"?>\n',
      '<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">\n',
      '    <fullName>', field_api, '__c</fullName>\n',
      '    <description>', description, '</description>\n',
      '    <label>', field_label, '</label>\n',
      '    <required>', is_required, '</required>\n',
      '    <trackFeedHistory>false</trackFeedHistory>\n',
      '    <type>', field_type, '</type>\n',
      '    <valueSet>\n',
      '        <restricted>true</restricted>\n',
      '        <valueSetName>', sheet_name, '</valueSetName>\n',
      '    </valueSet>\n',
      '    <visibleLines>4</visibleLines>\n',
      '</CustomField>'
    )
    
    # 3. Create Directory Path
    # Path: force-app/main/default/objects/ObjectName/fields/FieldName.field-meta.xml
    dir_path <- file.path("force-app", "main", "default", "objects", obj_name, "fields")
    dir_create(dir_path) # Creates the folder if it doesn't exist
    
    # 4. Save the file
    file_path <- file.path(dir_path, paste0(field_api, "__c.field-meta.xml"))
    writeLines(field_xml, file_path)
  })
  
  message(paste("Completed field generation for tab:", sheet_name))
}

# Execute for all tabs
walk(sheet_names, generate_field_metadata)