# Load essential libraries
library(sf)
library(dplyr)
library(ggplot2)
library(viridis)
library(psych)
library(RColorBrewer)

# Read data
data <- read.csv('data.csv', header = TRUE)
geometry <- st_read("geometry.shp")
geometry <- st_transform(geometry, crs = 32735)

# Merge spatial and attribute data
data$WardID_ <- as.character(data$WardID_)
geometry$WardID_ <- as.character(geometry$WardID_)
merged_data <- merge(geometry, data, by = "WardID_", all.x = TRUE)

# First, let's check what variables we actually have
print("First few column names:")
print(head(names(merged_data), 20))

# Update vars using the actual column names from your data
vars <- c(
  "Crowded.dw", 
  "No.piped.w", 
  "Using.publ",
  "Poor.healt", 
  "Failed.to",
  "No.medical", 
  "Household",
  "Benefiting", 
  "UTFVI.x", 
  "LST.x", 
  "NDVI.x",
  "NDBI__mean.x", 
  "concern_he.x", 
  "cancer_pro.x", 
  "diabetes_p.x",
  "pneumonia_.x",
  "heart_dise.x", 
  "hypertensi.x", 
  "hiv_prop.x", 
  "tb_prop.x", 
  "covid_prop.x",
  "X60_plus_pr.x"
)

# Convert to data frame for complete cases check
merged_data_df <- st_drop_geometry(merged_data)
complete_rows <- complete.cases(merged_data_df[vars])
merged_data_clean <- merged_data[complete_rows, ]

# Calculate HVI using PCA
pca_data <- scale(st_drop_geometry(merged_data_clean)[vars])
pca_result <- prcomp(pca_data)
merged_data_clean$HVI <- scale(pca_result$x[,1])
merged_data_clean$HVI_normalized <- scales::rescale(merged_data_clean$HVI, to = c(0, 1))

# Create main HVI map
ggplot(merged_data_clean) +
  geom_sf(aes(fill = HVI_normalized)) +
  scale_fill_viridis_c(
    option = "inferno",
    name = "Heat Vulnerability\nIndex",
    limits = c(0, 1)
  ) +
  theme_minimal() +
  labs(
    title = "Heat Vulnerability Index in Johannesburg",
    subtitle = "Higher values indicate greater vulnerability"
  ) +
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    legend.title = element_text(size = 10),
    legend.text = element_text(size = 8)
  )

# Identify and map top 10 most vulnerable wards
top_10_wards <- merged_data_clean %>%
  arrange(desc(HVI_normalized)) %>%
  slice_head(n = 10)

# Print details of top 10 wards
print("Top 10 Most Vulnerable Wards:")
print(top_10_wards %>%
        st_drop_geometry() %>%
        select(WardID_, HVI_normalized) %>%
        arrange(desc(HVI_normalized)))

# Create highlighted map of top 10 wards
ggplot() +
  geom_sf(data = merged_data_clean, 
          aes(fill = HVI_normalized),
          alpha = 0.7) +
  geom_sf(data = top_10_wards,
          fill = "red",
          color = "black",
          size = 0.5,
          alpha = 0.8) +
  geom_sf_text(data = top_10_wards,
               aes(label = WardID_),
               size = 3,
               color = "white",
               fontface = "bold") +
  scale_fill_viridis_c(
    option = "magma",
    name = "Heat Vulnerability\nIndex",
    limits = c(0, 1)
  ) +
  theme_minimal() +
  labs(
    title = "Top 10 Most Heat-Vulnerable Wards in Johannesburg",
    subtitle = "Red areas indicate highest vulnerability"
  ) +
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    legend.title = element_text(size = 10),
    legend.text = element_text(size = 8)
  )


# Create highlighted map of top 10 wards without labels
ggplot() +
  geom_sf(data = merged_data_clean, 
          aes(fill = HVI_normalized),
          alpha = 0.7) +
  geom_sf(data = top_10_wards,
          fill = "red",
          color = "black",
          size = 0.5,
          alpha = 0.8) +
  scale_fill_viridis_c(
    option = "magma",
    name = "Heat Vulnerability\nIndex",
    limits = c(0, 1)
  ) +
  theme_minimal() +
  labs(
    title = "Top 10 Most Heat-Vulnerable Wards in Johannesburg",
    subtitle = "Red areas indicate highest vulnerability"
  ) +
  theme(
    plot.title = element_text(size = 14, face = "bold"),
    legend.title = element_text(size = 10),
    legend.text = element_text(size = 8)
  )

# Transform the data to WGS84 (longitude/latitude)
merged_data_clean_wgs84 <- st_transform(merged_data_clean, 4326)
top_10_wards_wgs84 <- st_transform(top_10_wards, 4326)

# Get the bounding box in lon/lat
bbox_wgs84 <- st_bbox(merged_data_clean_wgs84)

# Now try getting the base map
map_base <- get_googlemap(
  center = c(lon = mean(c(bbox_wgs84["xmin"], bbox_wgs84["xmax"])),
             lat = mean(c(bbox_wgs84["ymin"], bbox_wgs84["ymax"]))),
  zoom = 11,
  maptype = "roadmap"
)

# Create the map
ggmap(map_base) +
  geom_sf(data = merged_data_clean_wgs84, 
          aes(fill = HVI_normalized),
          alpha = 0.7,
          inherit.aes = FALSE) +
  geom_sf(data = top_10_wards_wgs84,
          fill = "red",
          color = "black",
          size = 0.5,
          alpha = 0.8,
          inherit.aes = FALSE) +
  scale_fill_viridis_c(
    option = "magma",
    name = "Heat Vulnerability\nIndex",
    limits = c(0, 1)
  ) +
  theme_minimal() +
  labs(
    title = "Heat Vulnerability in Johannesburg",
    subtitle = "Red areas indicate highest vulnerability"
  )

library(osmdata)

# Transform data to WGS84
merged_data_clean_wgs84 <- st_transform(merged_data_clean, 4326)
top_10_wards_wgs84 <- st_transform(top_10_wards, 4326)

# Create the map with OpenStreetMap background
ggplot() +
  annotation_map_tile(type = "osm", zoom = 11) +
  geom_sf(data = merged_data_clean_wgs84, 
          aes(fill = HVI_normalized),
          alpha = 0.7) +
  geom_sf(data = top_10_wards_wgs84,
          fill = "red",
          color = "black",
          size = 0.5,
          alpha = 0.8) +
  scale_fill_viridis_c(
    option = "magma",
    name = "Heat Vulnerability\nIndex",
    limits = c(0, 1)
  ) +
  theme_minimal() +
  labs(
    title = "Heat Vulnerability in Johannesburg",
    subtitle = "Red areas indicate highest vulnerability"
  )





# Load required libraries
library(leaflet)

# Transform data to WGS84 if not already
merged_data_clean_wgs84 <- st_transform(merged_data_clean, 4326)
top_10_wards_wgs84 <- st_transform(top_10_wards, 4326)

# Create interactive map
leaflet() %>%
  # Add base map tiles
  addTiles() %>%
  # Add all wards with HVI coloring
  addPolygons(data = merged_data_clean_wgs84,
              fillColor = ~colorNumeric("magma", HVI_normalized)(HVI_normalized),
              fillOpacity = 0.7,
              weight = 1,
              color = "white",
              opacity = 0.5) %>%
  # Add high vulnerability wards
  addPolygons(data = top_10_wards_wgs84,
              fillColor = "red",
              fillOpacity = 0.8,
              weight = 2,
              color = "black",
              opacity = 1) %>%
  # Add legend
  addLegend(position = "bottomright",
            pal = colorNumeric("magma", domain = merged_data_clean_wgs84$HVI_normalized),
            values = merged_data_clean_wgs84$HVI_normalized,
            title = "Heat Vulnerability Index",
            opacity = 1)



