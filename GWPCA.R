# Load required libraries
library(GWmodel)
library(sp)
library(sf)
library(dplyr)
library(ggplot2)
library(viridis)
library(corrplot)
library(rlang)
library(psych)  # For descriptive statistics
library(tidyr)   # For pivot_longer function

# Set working directory
setwd("C:/Users/CraigParker/OneDrive - Wits PHR/Desktop/HVI_Johannesburg")

# Read data
data <- read.csv('data.csv', header = TRUE)
geometry <- st_read("geometry.shp")
geometry <- st_transform(geometry, crs = 32735)

# Ensure consistent IDs
data$WardID_ <- as.character(data$WardID_)
geometry$WardID_ <- as.character(geometry$WardID_)

# Merge datasets
merged_data <- merge(geometry[, c("WardID_", "geometry")], data, by = "WardID_", all.x = TRUE)

# Define variables
vars <- c(
  "Crowded.dwellings", "No.piped.water", "Using.public.healthcare.facilities",
  "Poor.health.status", "Failed.to.find.healthcare.when.needed",
  "No.medical.insurance", "Household.hunger.risk",
  "Benefiting.from.school.feeding.scheme", "UTFVI", "LST", "NDVI",
  "NDBI__mean", "concern_he", "cancer_pro", "diabetes_p", "pneumonia_",
  "heart_dise", "hypertensi", "hiv_prop", "tb_prop", "covid_prop",
  "X60_plus_pr"
)

# Check for missing variables
missing_vars <- setdiff(vars, names(merged_data))
if (length(missing_vars) > 0) {
  stop("Missing variables: ", paste(missing_vars, collapse = ", "))
}

# Ensure variables are numeric
for (var in vars) {
  if (!is.numeric(merged_data[[var]])) {
    merged_data[[var]] <- as.numeric(as.character(merged_data[[var]]))
  }
}

# Remove rows with missing data
merged_data_no_geom <- st_drop_geometry(merged_data)
rows_complete <- complete.cases(merged_data_no_geom[vars])
merged_data <- merged_data[rows_complete, ]
merged_data_no_geom <- merged_data_no_geom[rows_complete, ]

# Compute descriptive statistics
summary_stats <- merged_data_no_geom %>%
  select(all_of(vars)) %>%
  summarise(across(everything(), list(
    mean = ~mean(.),
    sd = ~sd(.),
    median = ~median(.),
    min = ~min(.),
    max = ~max(.)
  )))

# Reshape to long format using names_pattern
summary_stats_long <- summary_stats %>%
  pivot_longer(
    cols = everything(),
    names_to = c("Variable", "Statistic"),
    names_pattern = "^(.*)_(mean|sd|median|min|max)$"
  )

print("Summary Statistics:")
print(summary_stats_long)


# Compute correlation matrix
corr_matrix <- cor(merged_data_no_geom[vars], use = "complete.obs")

corrplot(corr_matrix, method = "color", type = "upper", order = "hclust",
         tl.cex = 0.6, tl.col = "black", tl.srt = 45,
         addCoef.col = "black", number.cex = 0.5,
         title = "Correlation Matrix of Variables")


# Convert to Spatial object
cleaned_data_sp <- as(merged_data, "Spatial")

# Check CRS
if (is.na(proj4string(cleaned_data_sp))) {
  stop("Spatial object has no CRS defined.")
} else {
  cat("CRS of spatial data:", proj4string(cleaned_data_sp), "\n")
}

# Estimate bandwidth
bw <- bw.gwpca(
  data = cleaned_data_sp,
  vars = vars,
  k = 2,
  robust = TRUE,
  adaptive = TRUE
)

cat("Optimal adaptive bandwidth estimated:", bw, "\n")

# Perform GWPCA
gwpca_result <- gwpca(
  data = cleaned_data_sp,
  vars = vars,
  k = 2,
  robust = TRUE,
  bw = bw,
  adaptive = TRUE,
  scores = TRUE
)

# Extract scores
num_components <- 2
scores_matrix <- matrix(NA, nrow = length(gwpca_result$gwpca.scores), ncol = num_components)
colnames(scores_matrix) <- paste0("PC", 1:num_components)

for (i in 1:length(gwpca_result$gwpca.scores)) {
  local_scores <- gwpca_result$gwpca.scores[[i]]
  if (!is.null(local_scores)) {
    if (ncol(local_scores) >= num_components) {
      scores_matrix[i, ] <- local_scores[1, 1:num_components]
    } else {
      scores_matrix[i, 1:ncol(local_scores)] <- local_scores[1, ]
    }
  }
}

# Add scores to gwpca_sf
gwpca_sf <- st_as_sf(gwpca_result$SDF)
gwpca_sf <- cbind(gwpca_sf, as.data.frame(scores_matrix))

# Verify score columns
print("Columns in gwpca_sf after adding scores:")
print(names(gwpca_sf))

# Plot PC1 scores
plot_pc1 <- ggplot(gwpca_sf) +
  geom_sf(aes(fill = PC1)) +
  scale_fill_viridis() +
  theme_minimal() +
  labs(title = "GWPCA - PC1 Scores", fill = "PC1 Score")
print(plot_pc1)

# Plot PC2 scores
plot_pc2 <- ggplot(gwpca_sf) +
  geom_sf(aes(fill = PC2)) +
  scale_fill_viridis() +
  theme_minimal() +
  labs(title = "GWPCA - PC2 Scores", fill = "PC2 Score")
print(plot_pc2)

# Calculate HVI
gwpca_sf$HVI <- scale(gwpca_sf$PC1)

# Plot HVI
plot_hvi <- ggplot(gwpca_sf) +
  geom_sf(aes(fill = HVI)) +
  scale_fill_viridis() +
  theme_minimal() +
  labs(title = "Heat Vulnerability Index", fill = "HVI")
print(plot_hvi)

# Sort the data by HVI in descending order and select the top 10 most vulnerable wards
top_10_vulnerable_wards <- gwpca_sf %>%
  arrange(desc(HVI)) %>%
  slice(1:10)

# Print the result
print("Top 10 Most Vulnerable Wards:")
print(top_10_vulnerable_wards)

# Plot the top 10 most vulnerable wards
plot_top_10_hvi <- ggplot(top_10_vulnerable_wards) +
  geom_sf(aes(fill = HVI)) +
  scale_fill_viridis() +
  theme_minimal() +
  labs(title = "Top 10 Most Vulnerable Wards in Johannesburg", fill = "HVI")
print(plot_top_10_hvi)

# Extract loadings array
loadings_array <- gwpca_result$loadings  # Dimensions: locations x variables x components

# Compute the mean loadings across all locations
mean_loadings <- apply(loadings_array, c(2,3), mean, na.rm = TRUE)  # Result is variables x components

# Ensure the length of vars matches the number of rows in mean_loadings
if (nrow(mean_loadings) == length(vars)) {
  rownames(mean_loadings) <- vars
} else {
  stop("Mismatch between the number of rows in mean_loadings and the length of vars.")
}

# Extract loadings for the first principal component
pc1_loadings <- mean_loadings[, 1]

# Create a data frame of variables and their loadings for PC1
loadings_df <- data.frame(Variable = rownames(mean_loadings), PC1_Loading = pc1_loadings)

# Sort the loadings by absolute value to find the most contributing variables
loadings_df <- loadings_df %>%
  mutate(Absolute_Loading = abs(PC1_Loading)) %>%
  arrange(desc(Absolute_Loading))

# Display the top contributing variables to PC1
top_contributing_variables <- loadings_df[1:10, ]

# Print the top contributing variables in a cleaner format
cat("Top contributing variables to PC1:\n")
print(top_contributing_variables, row.names = FALSE)

# Visualize the loadings for PC1
plot_loadings <- ggplot(loadings_df, aes(x = reorder(Variable, PC1_Loading), y = PC1_Loading)) +
  geom_bar(stat = "identity", fill = "steelblue") +
  coord_flip() +
  theme_minimal() +
  labs(title = "Loadings for PC1", x = "Variables", y = "PC1 Loading")
print(plot_loadings)



