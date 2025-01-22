# Load required packages
library(GWmodel)
library(sp)
library(sf)
library(dplyr)

# Define variables
vars <- c("Elderly", "Under5", "LowIncome", "NoEducation", 
          "Unemployed", "InformalDwelling", "NoPiped", "NoElectricity",
          "NoRefuse", "NoInternet")

# Read data
data <- read.csv('data.csv')
geometry <- st_read('geometry.shp')

# Print initial data info
print("Initial data dimensions:")
print(dim(data))
print(dim(geometry))

# Check variables
print("\nVariables in data:")
print(names(data))

# Check for missing values
print("\nMissing values:")
print(colSums(is.na(data[, vars])))

# Remove rows with missing values
complete_data <- data[complete.cases(data[, vars]), ]
print("\nRows after removing missing values:")
print(nrow(complete_data))

# Scale the data
scaled_data <- scale(as.matrix(complete_data[, vars]))
print("\nScaled data dimensions:")
print(dim(scaled_data))

# Create spatial points
coords <- st_coordinates(st_centroid(geometry))
print("\nCoordinate dimensions:")
print(dim(coords))

# Create spatial data frame
sp_data <- try({
  SpatialPointsDataFrame(
    coords = coords,
    data = as.data.frame(scaled_data),
    proj4string = CRS(st_crs(geometry)$wkt)
  )
})

if(inherits(sp_data, "try-error")) {
  print("Error creating spatial data frame:")
  print(attr(sp_data, "condition")$message)
} else {
  print("\nSpatial data frame created successfully")
  print("Dimensions:")
  print(dim(sp_data@data))
}

# Try GWPCA
if(!inherits(sp_data, "try-error")) {
  print("\nAttempting GWPCA...")
  gwpca_result <- try({
    gwpca(
      data = sp_data,
      vars = colnames(scaled_data),
      k = 3,
      adaptive = TRUE,
      bw = nrow(sp_data) * 0.1,
      robust = FALSE,
      scores = TRUE
    )
  })
  
  if(inherits(gwpca_result, "try-error")) {
    print("GWPCA failed:")
    print(attr(gwpca_result, "condition")$message)
  } else {
    print("GWPCA completed successfully")
    print("Variance explained:")
    print(gwpca_result$var)
  }
}
