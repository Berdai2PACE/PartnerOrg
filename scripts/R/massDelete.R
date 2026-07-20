library(salesforcer)
library(googlesheets4)
library(tidyverse)
library(stringr)
library(lubridate)
confirm_execution <- function(message, target_phrase = c("Y", 'YES')) {
  user_input <- ""
  
  # Keep asking until they type the specific target_phrase
  while (!toupper(user_input) %in% target_phrase) {
    user_input <- readline(prompt = paste0("Type '", paste(target_phrase,collapse="' or '"), "' ", message, ", or 'ESC' to stop: "))
    
    # Optional: Allow a way to bail out
    if (toupper(user_input) == "ESC") {
      stop("Script halted by user.")
    }
    
    paste0("Invalid input. You must type '",
        target_phrase,
        "' exactly.\n")
    
  }
  
  message("Confirmation received. Proceeding...")
}
# --- Configuration ---
# template DO NOT EDIT OR I SWEAR I AM GOING TO ..... AND TO .... AND THEN I WILL ....
# https://docs.google.com/spreadsheets/d/1gIB7gNTAsImWqEJcl1bbzklnzhlkt-Fg44J7LeZsyUQ/edit?gid=2113404341#gid=2113404341
gs_url <- "GOOGLESHEET_URL_TO_UPDATE"
bulk_threshold <- 1000
dry_run <- TRUE    # Set TRUE to simulate only
verbose <- FALSE     # Set TRUE for real-time console logs

#sf_auth(login_url = "https://2p1772545329255.my.salesforce.com")
sf_auth(login_url = "MYDOMAIN_TO_COMPLETE")
gs4_auth()

# 1. Load Queries
input_data <- read_sheet(gs_url, sheet = "queries")
queries <- input_data$Query

# 2. Functional Logic
process_sf_query <- function(soql_query,
                             is_dry_run = TRUE,
                             is_verbose = FALSE,
                             is_sample = FALSE,
                             sample_size = 5) {
  print(paste("treating ", soql_query))
  # Regex to get SObject name
  sobject <- str_extract(soql_query, "(?i)(?<=from\\s)\\w+")
  message(paste0("\n>>> Target: ", sobject))
  
  # Count records to determine API strategy
  where_clause <- str_extract(soql_query, "(?i)where.+$")
  count_query <- paste("SELECT count(Id) FROM",
                       sobject,
                       ifelse(is.na(where_clause), "", where_clause))
  
  start_count <- tryCatch({
    sf_query(count_query)$expr0
  }, error = function(e) {
    message("!! SOQL Error: ", e$message)
    return(-1)
  })
  
  # Decision Logic
  if (is_dry_run) {
    status_msg <- "Dry Run - No Action"
    num_failures <- start_count
    message(paste("Dry Run logic: Found", start_count, "records."))
    
  } else if (start_count <= 0) {
    status_msg <- ifelse(start_count == 0, "No records found", "Query Error")
    num_failures <- 0
    message(paste("Result:", status_msg))
    
  } else {
    maxId <- start_count
    if (is_sample == TRUE) {
      maxId <- min(maxId, sample_size)
    }
    # Determine API Type based on volume
    api_choice <- ifelse (maxId >= bulk_threshold, "Bulk 1.0", "REST")
    
    # Query IDs
    id_query <- paste("SELECT Id FROM", sobject, ifelse(is.na(where_clause), "", where_clause))
    
    message(paste("Volume:", start_count, "| API Strategy:", api_choice))
    records_to_delete <- sf_query(
      id_query,
      object_name = sobject,
      api_type = api_choice,
      verbose = is_verbose
    )
    
    # Execute Deletion using the SAME api_type
    message("Executing deletion...")
    
    delete_results <- sf_delete(
      records_to_delete$Id[1:maxId],
      object_name = sobject,
      api_type = api_choice,
      verbose = is_verbose
    )
    
    # Error checking (REST returns 'success', Bulk returns 'success' or 'Success')
    # Use tolower to normalize field names across API responses
    names(delete_results) <- tolower(names(delete_results))
    num_failures <- sum(delete_results$success == FALSE |
                          delete_results$success == "false")
    if (num_failures > 0) {
      if (api_choice == "REST") {
        print(delete_results$errors[!delete_results$success])
      } else{
        print(delete_results$error[!delete_results$success])
      }
    }
    status_msg <- ifelse(num_failures == 0, "Success", "Fail")
    
    message(paste("Done. Failures:", num_failures))
  }
  
  # RETURN A TIBBLE (This prevents the "dictionaryish" error)
  return(
    c(
      Timestamp = as.character(as.character(Sys.time())),
      SObject = as.character(sobject),
      Start_Count = as.numeric(start_count) ,
      Failures = as.numeric(num_failures) ,
      API_Used = as.character(ifelse(
        exists("api_choice"), api_choice, "N/A"
      )),
      Status = as.character(status_msg)
    )
  )
}

# 3. Apply Function
results_matrix <- sapply(
  queries,
  process_sf_query,
  is_dry_run = TRUE,
  is_verbose = verbose,
  USE.NAMES = FALSE
)


# 4. Final Output to Google Sheet
sheet_name <- paste(
  "Dry_Run_Results",
  year(now()),
  month(now()),
  day(now()),
  hour(now()),
  minute(now()),
  sep = "-"
)
sheet_write(data = as.data.frame(t(results_matrix))   ,
            ss = gs_url,
            sheet = sheet_name)

confirm_execution(" to proceed to the deletion of up to 5 records")
# 5. Apply Function with sample

results_matrix <- sapply(
  queries,
  process_sf_query,
  is_dry_run = FALSE,
  is_verbose = verbose,
  is_sample = TRUE,
  USE.NAMES = FALSE
)


# 6. Sample Output to Google Sheet
sheet_name <- paste("Sample",
                    year(now()),
                    month(now()),
                    day(now()),
                    hour(now()),
                    minute(now()),
                    sep = "-")
sheet_write(data = as.data.frame(t(results_matrix))   ,
            ss = gs_url,
            sheet = sheet_name)

confirm_execution(" to proceed to the deletion of ALL queried records")

# 7. Apply Function to all data
dry_run <- FALSE
results_matrix <- sapply(
  queries,
  process_sf_query,
  is_dry_run = dry_run,
  is_verbose = verbose,
  is_sample = TRUE,
  USE.NAMES = FALSE
)


# 8. Sample Output to Google Sheet
sheet_name <- paste("Purge_History",
                    year(now()),
                    month(now()),
                    day(now()),
                    hour(now()),
                    minute(now()),
                    sep = "-")
sheet_write(data = as.data.frame(t(results_matrix))   ,
            ss = gs_url,
            sheet = sheet_name)