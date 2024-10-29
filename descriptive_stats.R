## Summary Statistics: Enhanced Table with Full Labels

To create a well-formatted and visually appealing table of descriptive statistics with full labels instead of abbreviations, you can use the `kableExtra` package or `gt` for an attractive output. Here is a revised code snippet to make the summary statistics more presentable in tabular form.

### Install Required Packages

```r
# Install required packages if not already installed
if (!require("sf")) install.packages("sf")
if (!require("dplyr")) install.packages("dplyr")
if (!require("kableExtra")) install.packages("kableExtra")
if (!require("gt")) install.packages("gt")
```

### Load Libraries

```r
# Load the necessary libraries
library(sf)          # Spatial data operations
library(dplyr)       # Data manipulation
library(kableExtra)  # To create well-formatted tables
library(gt)          # Another option for attractive tables
```

### Create a Summary Statistics Table

```r
# Compute summary statistics
summary_stats <- gwpca_data %>%
  st_set_geometry(NULL) %>%
  summarise(across(everything(), list(
    mean = mean, sd = sd, median = median, min = min, max = max
  ), .names = "{.col}_{.fn}"))

# Reshape data for better display
summary_stats_long <- summary_stats %>%
  pivot_longer(cols = everything(),
               names_to = c("Variable", "Statistic"),
               names_sep = "_",
               values_to = "Value")

# Replace abbreviations with full labels
full_labels <- c(
  "OBJECTID_" = "Object ID",
  "WardID_" = "Ward ID",
  "WardNo_" = "Ward Number",
  "Crowded dwellings" = "Crowded Dwellings (%)",
  "No piped water" = "Households Without Piped Water (%)",
  "Using public healthcare facilities" = "Using Public Healthcare Facilities (%)",
  "Poor health status" = "Poor Health Status (%)",
  "Failed to find healthcare when needed" = "Failed to Find Healthcare When Needed (%)",
  "No medical insurance" = "No Medical Insurance (%)",
  "Household hunger risk" = "Household Hunger Risk (%)",
  "Benefiting from school feeding scheme" = "Benefiting from School Feeding Scheme (%)",
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
  "60_plus_pr" = "60+ Population Proportion (%)",
  "Ward_HVI_1_OBJECTID_" = "Ward HVI Object ID",
  "Ward_HVI_1_WardNo_" = "Ward Number (HVI)",
  "Ward_HVI_1_HVI_PC1" = "HVI Principal Component 1",
  "Ward_HVI_1_HVI_weighted" = "HVI Weighted Score",
  "Ward_HVI_1_HVI_PC1_standardized" = "Standardized HVI PC1",
  "Ward_HVI_1_HVI_weighted_standardized" = "Standardized HVI Weighted",
  "HVI_PC1" = "Heat Vulnerability Index (PC1)",
  "HVI_PC1_standardized" = "Standardized Heat Vulnerability Index (PC1)",
  "HVI_weighted" = "Heat Vulnerability Weighted Score",
  "HVI_weighted_standardized" = "Standardized Heat Vulnerability Weighted Score",
  "Climate_PC1" = "Climate Principal Component 1",
  "SocioEcon_PC1" = "Socioeconomic Principal Component 1",
  "LISA_Cluster" = "LISA Cluster Type",
  "LISA_Type" = "LISA Type Description",
  "CVI" = "Climate Vulnerability Index",
  "CVI_standardized" = "Standardized Climate Vulnerability Index",
  "Ward_Category" = "Ward Category",
  "Cluster" = "Cluster ID",
  "coord_x" = "X Coordinate",
  "coord_y" = "Y Coordinate"
)

summary_stats_long <- summary_stats_long %>%
  mutate(
    Variable = recode(Variable, !!!full_labels),
    Statistic = recode(Statistic,
                       "mean" = "Mean",
                       "sd" = "Standard Deviation",
                       "median" = "Median",
                       "min" = "Minimum",
                       "max" = "Maximum")
  )

# Convert to a wide format for better presentation
summary_stats_wide <- summary_stats_long %>%
  pivot_wider(names_from = Statistic, values_from = Value)

# Display the summary statistics in a nicely formatted table using kableExtra
summary_stats_wide %>%
  kbl(caption = "Descriptive Statistics for Heat Vulnerability Variables in Johannesburg") %>%
  kable_styling(full_width = FALSE, bootstrap_options = c("striped", "hover", "condensed", "responsive"))
```

### Alternative: Using `gt` for Enhanced Tables

```r
# Create a summary table using the gt package
summary_stats_gt <- summary_stats_wide %>%
  gt() %>%
  tab_header(
    title = "Descriptive Statistics for Heat Vulnerability Variables",
    subtitle = "Johannesburg Heat Vulnerability Analysis"
  ) %>%
  fmt_number(
    columns = vars(Mean, `Standard Deviation`, Median, Minimum, Maximum),
    decimals = 2
  ) %>%
  cols_label(
    Variable = "Variable Name",
    Mean = "Mean",
    `Standard Deviation` = "Standard Deviation",
    Median = "Median",
    Minimum = "Minimum",
    Maximum = "Maximum"
  ) %>%
  tab_style(
    style = cell_text(weight = "bold"),
    locations = cells_title(groups = "title")
  )

# Print the gt table
print(summary_stats_gt)
```

### Notes
- The `kableExtra` and `gt` packages are used to create aesthetically pleasing tables directly in RMarkdown or Jupyter notebooks.
- `kableExtra` provides more flexibility in styling, while `gt` can be a bit more intuitive for interactive reports.
- Adjust the number of decimals and other formatting options as needed to suit your audience.

