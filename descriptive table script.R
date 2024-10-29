# Load necessary libraries
library(sf)
library(dplyr)
library(tidyr)
library(kableExtra)
library(gt)

# Convert cleaned_data_sp to an sf object
gwpca_data <- st_as_sf(cleaned_data_sp)

# Select numeric variables and clean column names
numeric_vars <- gwpca_data %>%
  st_set_geometry(NULL) %>%
  select(where(is.numeric))

# Replace periods with underscores in column names
colnames(numeric_vars) <- gsub("\\.", "_", colnames(numeric_vars))

# Filter only the specific variables for the summary statistics
filtered_vars <- numeric_vars %>%
  select(
    Crowded_dwellings, No_piped_water, Using_public_healthcare_facilities,
    Poor_health_status, Failed_to_find_healthcare_when_needed, No_medical_insurance,
    Household_hunger_risk, Benefiting_from_school_feeding_scheme, UTFVI, LST, NDVI,
    NDBI__mean, concern_he, cancer_pro, diabetes_p, pneumonia_, heart_dise,
    hypertensi, hiv_prop, tb_prop, covid_prop, X60_plus_pr
  )

# Compute summary statistics
summary_stats <- filtered_vars %>%
  summarise(across(everything(), list(
    mean = ~mean(.x, na.rm = TRUE),
    sd = ~sd(.x, na.rm = TRUE),
    median = ~median(.x, na.rm = TRUE),
    min = ~min(.x, na.rm = TRUE),
    max = ~max(.x, na.rm = TRUE)
  ), .names = "{.col}_{.fn}"))

# Reshape data to long format using names_pattern
summary_stats_long <- summary_stats %>%
  pivot_longer(
    cols = everything(),
    names_to = c("Variable", "Statistic"),
    names_pattern = "^(.*)_(mean|sd|median|min|max)$",
    values_to = "Value"
  )

# Replace abbreviations with full labels
full_labels <- c(
  "Crowded_dwellings" = "Crowded Dwellings (%)",
  "No_piped_water" = "Households Without Piped Water (%)",
  "Using_public_healthcare_facilities" = "Using Public Healthcare Facilities (%)",
  "Poor_health_status" = "Poor Health Status (%)",
  "Failed_to_find_healthcare_when_needed" = "Failed to Find Healthcare When Needed (%)",
  "No_medical_insurance" = "No Medical Insurance (%)",
  "Household_hunger_risk" = "Household Hunger Risk (%)",
  "Benefiting_from_school_feeding_scheme" = "Benefiting from School Feeding Scheme (%)",
  "UTFVI" = "Urban Thermal Field Variance Index",
  "LST" = "Land Surface Temperature (°C)",
  "NDVI" = "Normalized Difference Vegetation Index (NDVI)",
  "NDBI__mean" = "Normalized Difference Built-up Index (Mean)",
  "concern_he" = "Concerned About Heat (%)",
  "cancer_pro" = "Cancer Proportion (%)",
  "diabetes_p" = "Diabetes Proportion (%)",
  "pneumonia_" = "Pneumonia Proportion (%)",
  "heart_dise" = "Heart Disease Proportion (%)",
  "hypertensi" = "Hypertension Proportion (%)",
  "hiv_prop" = "HIV Proportion (%)",
  "tb_prop" = "Tuberculosis Proportion (%)",
  "covid_prop" = "COVID-19 Proportion (%)",
  "X60_plus_pr" = "60+ Population Proportion (%)"
)

# Replace variable names with full labels
summary_stats_long <- summary_stats_long %>%
  mutate(
    Variable = recode(Variable, !!!full_labels, .default = Variable),
    Statistic = recode(Statistic,
                       "mean" = "Mean",
                       "sd" = "Standard Deviation",
                       "median" = "Median",
                       "min" = "Minimum",
                       "max" = "Maximum")
  )

# Convert back to wide format
summary_stats_wide <- summary_stats_long %>%
  pivot_wider(names_from = Statistic, values_from = Value)

# Display the table using kableExtra with 2 decimal points
summary_stats_wide %>%
  mutate(across(where(is.numeric), ~round(.x, 6))) %>%
  kbl(caption = "Descriptive Statistics for Selected Heat Vulnerability Variables in Johannesburg") %>%
  kable_styling(full_width = FALSE, bootstrap_options = c("striped", "hover", "condensed", "responsive"))
