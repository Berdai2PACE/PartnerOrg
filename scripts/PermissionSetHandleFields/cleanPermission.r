# ==============================================================================
# 🧹 SALESFORCE PERMISSION SET CLEANER (Version ULTIME : Champs + Objets + Tabs)
# ==============================================================================

if (!require("xml2")) install.packages("xml2")
if (!require("stringr")) install.packages("stringr")
if (!require("here")) install.packages("here")
if (!require("jsonlite")) install.packages("jsonlite")

library(xml2)
library(stringr)
library(here)
library(jsonlite)

# ==============================================================================
# 1. CHARGEMENT CONFIG & CHEMINS
# ==============================================================================

config_file <- here("scripts", "conf.json")
if (!file.exists(config_file)) config_file <- "../conf.json"
if (!file.exists(config_file)) config_file <- here("scripts", "R script", "conf.json")
if (!file.exists(config_file)) stop("❌ Fichier conf.json introuvable !")

config <- fromJSON(config_file)
targets <- config$targets

# Définition des dossiers racines
perm_set_dir <- here("force-app", "main", "default", "permissionsets")
objects_root <- here("force-app", "main", "default", "objects")
classes_root <- here("force-app", "main", "default", "classes")
pages_root <- here("force-app", "main", "default", "pages")
custom_perms_root <- here("force-app", "main", "default", "customPermissions")

# ==============================================================================
# 2. SÉLECTION DES FICHIERS
# ==============================================================================

files_to_process <- c()

if (is.null(targets) || length(targets) == 0 || "ALL" %in% targets) {
  print("🌍 Mode : TOUS les Permission Sets.")
  files_to_process <- list.files(perm_set_dir, pattern = "\\.permissionset-meta\\.xml$", full.names = TRUE)
} else {
  print(paste("🎯 Mode : Liste spécifique (", length(targets), "fichiers )"))
  for (name in targets) {
    fname <- ifelse(str_ends(name, "\\.xml"), name, paste0(name, ".permissionset-meta.xml"))
    fpath <- file.path(perm_set_dir, fname)
    if (file.exists(fpath)) {
      files_to_process <- c(files_to_process, fpath)
    } else {
      warning(paste("⚠️ Fichier introuvable :", fname))
    }
  }
}

if (length(files_to_process) == 0) stop("❌ Aucun fichier à traiter.")

# ==============================================================================
# 3. FONCTION DE NETTOYAGE (CORE LOGIC)
# ==============================================================================

clean_one_file <- function(file_path) {
  doc <- read_xml(file_path)
  ns <- xml_ns(doc)
  file_name <- basename(file_path)

  deleted_fields <- 0
  deleted_objects <- 0
  deleted_tabs <- 0
  deleted_classes <- 0
  deleted_pages <- 0
  deleted_custom_perms <- 0
  deleted_record_types <- 0

  # ----------------------------------------------------------------------------
  # PARTIE A : Nettoyage des CHAMPS (fieldPermissions)
  # ----------------------------------------------------------------------------
  field_perms <- xml_find_all(doc, ".//d1:fieldPermissions", ns = ns)

  for (node in field_perms) {
    field_full_name <- xml_text(xml_find_first(node, ".//d1:field", ns = ns))

    if (str_detect(field_full_name, "__c")) {
      parts <- str_split(field_full_name, "\\.")[[1]]
      if (length(parts) >= 2) {
        obj_name <- parts[1]
        field_name <- parts[2]
        field_file_path <- file.path(objects_root, obj_name, "fields", paste0(field_name, ".field-meta.xml"))

        if (!file.exists(field_file_path)) {
          xml_remove(node)
          deleted_fields <- deleted_fields + 1
        }
      }
    }
  }

  # ----------------------------------------------------------------------------
  # PARTIE B : Nettoyage des OBJETS (objectPermissions)
  # ----------------------------------------------------------------------------
  obj_perms <- xml_find_all(doc, ".//d1:objectPermissions", ns = ns)

  for (node in obj_perms) {
    obj_name <- xml_text(xml_find_first(node, ".//d1:object", ns = ns))

    if (str_detect(obj_name, "__c")) {
      obj_file_path <- file.path(objects_root, obj_name, paste0(obj_name, ".object-meta.xml"))

      if (!file.exists(obj_file_path)) {
        xml_remove(node)
        deleted_objects <- deleted_objects + 1
      }
    }
  }

  # ----------------------------------------------------------------------------
  # PARTIE C : Nettoyage des ONGLETS (tabSettings)
  # ----------------------------------------------------------------------------
  tab_perms <- xml_find_all(doc, ".//d1:tabSettings", ns = ns)

  for (node in tab_perms) {
    tab_name <- xml_text(xml_find_first(node, ".//d1:tab", ns = ns))

    # On ne vérifie que les onglets liés à des objets Custom (__c)
    # Pour ne pas casser les onglets standards (standard-Account) ou Web Tabs
    if (str_detect(tab_name, "__c")) {
      # On assume que pour un objet Custom, le nom de l'onglet = nom de l'objet
      obj_file_path <- file.path(objects_root, tab_name, paste0(tab_name, ".object-meta.xml"))

      if (!file.exists(obj_file_path)) {
        # print(paste("   ❌ Onglet orphelin supprimé :", tab_name)) # Debug
        xml_remove(node)
        deleted_tabs <- deleted_tabs + 1
      }
    }
  }

  # ----------------------------------------------------------------------------
  # PARTIE D : Nettoyage des CLASSES (classAccesses)
  # ----------------------------------------------------------------------------
  class_perms <- xml_find_all(doc, ".//d1:classAccesses", ns = ns)

  for (node in class_perms) {
    class_name <- xml_text(xml_find_first(node, ".//d1:apexClass", ns = ns))

    # Skip classes with a prefix/namespace (SBQQ__, etc.)
    if (str_detect(class_name, "__")) {
      next
    }

    class_file_path <- file.path(classes_root, paste0(class_name, ".cls-meta.xml"))

    if (!file.exists(class_file_path)) {
      xml_remove(node)
      deleted_classes <- deleted_classes + 1
    }
  }

  # ----------------------------------------------------------------------------
  # PARTIE E : Nettoyage des PAGES (pageAccesses)
  # ----------------------------------------------------------------------------
  page_perms <- xml_find_all(doc, ".//d1:pageAccesses", ns = ns)

  for (node in page_perms) {
    page_name <- xml_text(xml_find_first(node, ".//d1:apexPage", ns = ns))
    page_file_path <- file.path(pages_root, paste0(page_name, ".page-meta.xml"))

    if (!file.exists(page_file_path)) {
      xml_remove(node)
      deleted_pages <- deleted_pages + 1
    }
  }

  # ----------------------------------------------------------------------------
  # PARTIE F : Nettoyage des CUSTOM PERMISSIONS (customPermissions)
  # ----------------------------------------------------------------------------
  cp_perms <- xml_find_all(doc, ".//d1:customPermissions", ns = ns)

  for (node in cp_perms) {
    cp_name <- xml_text(xml_find_first(node, ".//d1:name", ns = ns))
    cp_file_path <- file.path(custom_perms_root, paste0(cp_name, ".customPermission-meta.xml"))

    if (!file.exists(cp_file_path)) {
      xml_remove(node)
      deleted_custom_perms <- deleted_custom_perms + 1
    }
  }

  # ----------------------------------------------------------------------------
  # PARTIE G : Nettoyage des RECORD TYPES (recordTypeVisibilities)
  # ----------------------------------------------------------------------------
  rt_perms <- xml_find_all(doc, ".//d1:recordTypeVisibilities", ns = ns)

  for (node in rt_perms) {
    record_type_full <- xml_text(xml_find_first(node, ".//d1:recordType", ns = ns))
    parts <- str_split(record_type_full, "\\.")[[1]]

    if (length(parts) == 2) {
      obj_name <- parts[1]
      rt_name <- parts[2]
      rt_file_path <- file.path(objects_root, obj_name, "recordTypes", paste0(rt_name, ".recordType-meta.xml"))

      if (!file.exists(rt_file_path)) {
        xml_remove(node)
        deleted_record_types <- deleted_record_types + 1
      }
    }
  }

  # ----------------------------------------------------------------------------
  # SAUVEGARDE
  # ----------------------------------------------------------------------------
  total_deleted <- deleted_fields + deleted_objects + deleted_tabs +
    deleted_classes + deleted_pages + deleted_custom_perms + deleted_record_types

  if (total_deleted > 0) {
    write_xml(doc, file_path)
    print(paste0(
      "✅ [NETTOYÉ] ", file_name, " -> ",
      deleted_fields, " champs | ",
      deleted_objects, " objets | ",
      deleted_tabs, " onglets | ",
      deleted_classes, " classes | ",
      deleted_pages, " pages | ",
      deleted_custom_perms, " custom perms | ",
      deleted_record_types, " record types supprimés."
    ))
  }
}

# ==============================================================================
# 4. EXÉCUTION
# ==============================================================================

print(paste("🚀 Démarrage du traitement sur", length(files_to_process), "fichiers..."))

for (f in files_to_process) {
  tryCatch(
    {
      clean_one_file(f)
    },
    error = function(e) {
      print(paste("❌ Erreur sur", basename(f), ":", e$message))
    }
  )
}

print("🏁 Traitement terminé.")
