# Load required libraries with error checking
for(pkg in c("GWmodel", "sf", "sp", "dplyr")) {
  if(!require(pkg, character.only = TRUE)) {
    stop(paste("Package", pkg, "is not installed"))
  }
}

# Read data with error checking
tryCatch({
  data <- read.csv('data.csv', header = TRUE)
  print("Data loaded successfully")
  print(paste("Data dimensions:", nrow(data), "x", ncol(data)))
}, error = function(e) {
  stop(paste("Error reading data.csv:", e$message))
})

tryCatch({
  geometry <- st_read('geometry.shp')
  print("Geometry loaded successfully")
  print(paste("Geometry dimensions:", nrow(geometry), "x", ncol(geometry)))
}, error = function(e) {
  stop(paste("Error reading geometry.shp:", e$message))
})

# Merge datasets with validation
tryCatch({
  print("\nChecking WardID_ in both datasets:")
  print("WardID_ in data:", length(unique(data$WardID_)))
  print("WardID_ in geometry:", length(unique(geometry$WardID_)))
  
  merged_data <- merge(geometry[, c("WardID_", "geometry")], data, by = "WardID_", all.x = TRUE)
  print(paste("Merged data dimensions:", nrow(merged_data), "x", ncol(merged_data)))
  
  if(nrow(merged_data) != nrow(geometry)) {
    warning("Number of rows in merged data differs from geometry")
  }
}, error = function(e) {
  stop(paste("Error merging data:", e$message))
})

# Define variables for PCA
vars <- c("Elderly", "Under5", "LowIncome", "NoEducation", 
          "Unemployed", "InformalDwelling", "NoPiped", "NoElectricity",
          "NoRefuse", "NoInternet")

# Validate variables exist
missing_vars <- vars[!vars %in% names(merged_data)]
if(length(missing_vars) > 0) {
  stop(paste("Missing variables in data:", paste(missing_vars, collapse=", ")))
}

# Create non-geometric data frame
merged_data_no_geom <- st_drop_geometry(merged_data)

# Print detailed diagnostics
print("\nDetailed data check:")
print("Summary of variables:")
print(summary(merged_data_no_geom[, vars]))

print("\nMissing values per variable:")
missing_counts <- colSums(is.na(merged_data_no_geom[, vars]))
print(missing_counts)

if(any(missing_counts > 0)) {
  warning("Missing values detected in variables")
}

# Scale the data with validation
tryCatch({
  data_scaled <- scale(as.matrix(merged_data_no_geom[, vars]))
  print("\nScaled data summary:")
  print(summary(data_scaled))
  
  # Check for NaN or Inf values
  if(any(is.na(data_scaled)) || any(is.infinite(data_scaled))) {
    stop("Invalid values (NA/Inf) found in scaled data")
  }
}, error = function(e) {
  stop(paste("Error scaling data:", e$message))
})

# Create spatial data frame with validation
tryCatch({
  coords <- st_coordinates(st_centroid(merged_data))
  print("\nCoordinate summary:")
  print(summary(coords))
  
  if(any(is.na(coords))) {
    stop("NA values found in coordinates")
  }
  
  sp_data <- SpatialPointsDataFrame(
    coords = coords,
    data = as.data.frame(data_scaled),
    proj4string = CRS(st_crs(merged_data)$wkt)
  )
  
  print("\nSpatial data frame created successfully")
  print(paste("Number of points:", nrow(sp_data)))
  print("Coordinate reference system:")
  print(proj4string(sp_data))
}, error = function(e) {
  stop(paste("Error creating spatial data frame:", e$message))
})

# Calculate bandwidth with detailed error checking
print("\nCalculating bandwidth...")
bw_optimal <- tryCatch({
  bw <- bw.gwpca(
    sp_data,
    vars = colnames(data_scaled),
    k = 3,
    adaptive = TRUE
  )
  print(paste("Optimal bandwidth found:", bw))
  bw
}, error = function(e) {
  warning(paste("Error in bandwidth selection:", e$message))
  bw_default <- nrow(sp_data) * 0.1
  print(paste("Using default bandwidth:", bw_default))
  bw_default
})

# Run GWPCA with detailed error checking
print("\nRunning GWPCA...")
gwpca_result <- tryCatch({
  result <- gwpca(
    data = sp_data,
    vars = colnames(data_scaled),
    k = 3,
    adaptive = TRUE,
    bw = bw_optimal,
    scores = TRUE
  )
  
  print("\nGWPCA completed successfully")
  print("Variance explained:")
  print(result$var)
  print("\nProportion of variance explained:")
  print(result$var/sum(result$var))
  
  # Save results
  saveRDS(result, "gwpca_debug_result.rds")
  result
  
}, error = function(e) {
  stop(paste("Error in GWPCA:", e$message))
})

# Create diagnostic plots if GWPCA succeeded
if(exists("gwpca_result")) {
  tryCatch({
    print("\nCreating diagnostic plots...")
    pdf("gwpca_diagnostic_plots.pdf")
    
    # 1. Scree plot
    barplot(gwpca_result$var, 
            names.arg = paste0("PC", 1:length(gwpca_result$var)),
            main = "Variance Explained by Components",
            ylab = "Variance Explained (%)")
    
    # 2. Loadings plot for PC1
    local_loadings <- gwpca_result$loadings[, , 1]
    barplot(colMeans(abs(local_loadings)),
            names.arg = colnames(local_loadings),
            main = "Average Absolute Loadings on PC1",
            las = 2)
    
    dev.off()
    print("Plots saved to gwpca_diagnostic_plots.pdf")
    
  }, error = function(e) {
    warning(paste("Error creating plots:", e$message))
  })
}

print("\nDebug script completed")
