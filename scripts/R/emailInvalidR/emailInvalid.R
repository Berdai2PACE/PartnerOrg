# ==============================================================================
# 1. PACKAGE MANAGEMENT
# ==============================================================================

# Create a list of 'tools' (libraries) we need for this task
required_packages <- c("salesforcer", "dplyr", "stringr", "cli", "purrr", "tidyr")

# Check which tools are NOT yet installed on this computer
missing_packages <- required_packages[!(required_packages %in% installed.packages()[, "Package"])]

# If any tools are missing, download and install them
if (length(missing_packages) > 0) install.packages(missing_packages)

# 'Open' the toolboxes so we can use their specific functions (quietly)
invisible(lapply(required_packages, library, character.only = TRUE))


# ==============================================================================
# 2. CONFIGURATION
# ==============================================================================

# Define which Salesforce tables (Objects) we want to clean up
target_objects <- c("Contact", "Account", "Lead")

# If an object has more than 1000 records, we'll use 'Bulk' mode (faster for large data)
API_THRESHOLD  <- 1000 

# Log into your specific Salesforce Sandbox environment
sf_auth(login_url = "https://azergo--preprod.sandbox.my.salesforce.com")


# ==============================================================================
# 3. THE PROCESSING FUNCTION (The "Recipe")
# ==============================================================================

mask_emails_for_object <- function(obj_name, threshold) {
  
  # Print a big header in the console so we can see which object is starting
  cli_h1("Processing Object: {obj_name}")
  
  # Ask Salesforce for the 'Blueprint' (metadata) of the object to find email fields
  metadata <- sf_describe_object_fields(obj_name)
  
  # Keep only the fields where the type is 'email' and we have permission to edit them
  email_fields <- metadata %>% 
    filter(type == "email", updateable == 'true') %>% 
    pull(name)
  
  # If the object doesn't even have an email field, stop here and move to the next
  if (length(email_fields) == 0) return(list(summary = "No email fields"))
  
  # Check how many records exist in this object total
  recordCount <- sf_query(paste("Select count(id) from", obj_name))
  
  # Decide how to pull the data: Standard (REST) or high-volume (Bulk)
  apiQueryType <- "REST"
  if(recordCount$expr0 >= threshold){
    apiQueryType <- "Bulk 1.0"  
  }
  
  # Construct the "Order": "Select the ID and all Email columns from this Object"
  query <- sprintf("SELECT %s FROM %s", paste(c("Id", email_fields), collapse = ", "), obj_name)
  
  # Actually download the data from Salesforce into R
  records <- sf_query(query, object_name = obj_name, api_type = apiQueryType)
  
  # If the table is empty, stop here
  if (nrow(records) == 0) return(list(summary = "No records found"))
  
  # DATA TRANSFORMATION:
  # For every email field found, add '.invalid' to the end UNLESS it's empty or already done
  updated_records <- records %>%
    mutate(across(all_of(email_fields), ~ case_when(
      is.na(.) | . == "" ~ .,                          # Leave empty cells alone
      str_ends(., fixed(".invalid")) ~ .,              # Don't add it twice
      TRUE ~ paste0(., ".invalid")                     # Add the suffix
    )))
  
  # Compare the 'New' data vs the 'Old' data; only keep rows that actually changed
  to_upload <- updated_records[rowSums(records != updated_records, na.rm = TRUE) > 0, ]
  row_count <- nrow(to_upload)
  
  # If there is data to fix, send it back to Salesforce
  if (row_count > 0) {
    # Again, choose the best 'shipping method' (API) based on volume
    chosen_api <- if (row_count >= threshold) "Bulk 2.0" else "REST"
    
    cli_alert_info("Updating {row_count} records via {chosen_api}...")
    
    # Push the updates. 'allOrNone = FALSE' means if one record fails, the others still save.
    results <- sf_update(to_upload, object_name = obj_name, api_type = chosen_api,
                         control = sf_control(AllOrNoneHeader = list(allOrNone = FALSE)))
    
    # Look through the results and find rows that have an error message
    errors <- results[!(is.na(results$sf__Error)), ]
    
    # Return a summary list of what happened for this specific object
    return(list(
      total = row_count,
      success_count = row_count - nrow(errors),
      error_count = nrow(errors),
      failed_records = errors
    ))
  } 
  
  return(list(summary = "All records already masked"))
}


# ==============================================================================
# 4. EXECUTION
# ==============================================================================

# Run the recipe above for each object in our 'target_objects' list
update_results <- lapply(target_objects, mask_emails_for_object, threshold = API_THRESHOLD)

# Label the results with the names of the objects
names(update_results) <- target_objects


# ==============================================================================
# 5. SUMMARY REPORT
# ==============================================================================

# Draw a line in the console
cli_rule(left = "FINAL ERROR SUMMARY")

# Loop through our results and print a pretty report
final_summary <- lapply(names(update_results), function(name) {
  res <- update_results[[name]]
  
  if (!is.null(res$error_count)) {
    if (res$error_count > 0) {
      # If there were errors, show a red alert and the first few failed records
      cli_alert_danger("{name}: {res$error_count} failures out of {res$total} attempted.")
      print(head(res$failed_records %>% select(any_of(c("Id", "sf__Error", "Email")))))
    } else {
      # If everything worked, show a green success message
      cli_alert_success("{name}: All {res$total} records updated successfully.")
    }
  } else {
    # If the object was skipped (e.g., no records found), show a blue info message
    cli_alert_info("{name}: {res$summary}")
  }
})