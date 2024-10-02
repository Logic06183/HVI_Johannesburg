# Load libraries
library(GWmodel)
library(sp)
library(sf)
library(dplyr)

# Read attribute data
data <- read.csv('data.csv', header = TRUE)

# Load shapefile
shapefile_path <- "geometry.shp"
geometry <- st_read(shapefile_path)

# Project the geometry to a suitable CRS (e.g., UTM Zone 35S)
geometry <- st_transform(geometry, crs = 32735)

# Ensure 'WardID_' is consistent in both datasets
data$WardID_ <- as.character(data$WardID_)
geometry$WardID_ <- as.character(geometry$WardID_)

# Merge datasets
merged_data <- merge(geometry, data, by = "WardID_", all.x = TRUE)

# View column names
names(merged_data)

# Clean variable names in merged_data
names(merged_data) <- make.names(names(merged_data), unique = TRUE)

# Convert to Spatial object
cleaned_data_sp <- as(merged_data, "Spatial")

# Define variables and standardize names
vars <- c(
  "Crowded dwellings", "No piped water", "Using public healthcare facilities", "Poor health status",
  "Failed to find healthcare when needed", "No medical insurance", "Household hunger risk",
  "Benefiting from school feeding scheme", "UTFVI", "LST", "NDVI", "NDBI__mean", "concern_he",
  "cancer_pro", "diabetes_p", "pneumonia_", "heart_dise", "hypertensi", "hiv_prop", "tb_prop",
  "covid_prop", "60_plus_pr"
)

# Standardize variable names
vars <- make.names(vars)

# Check for missing variables
missing_vars <- setdiff(vars, names(cleaned_data_sp@data))
if (length(missing_vars) > 0) {
  warning(paste("The following variables are missing:", paste(missing_vars, collapse = ", ")))
} else {
  print("All variables are present.")
}

# Proceed with GWPCA if no variables are missing
if (length(missing_vars) == 0) {
  # Determine optimal bandwidth
  bw <- bw.gwpca(cleaned_data_sp, vars = vars, k = 2, robust = TRUE)
  
  # Perform GWPCA
  gwpca_result <- gwpca(cleaned_data_sp, vars = vars, bw = bw, k = 2, robust = TRUE)
  
  # View summary
  summary(gwpca_result)
  
  # Extract and plot results as before
}
