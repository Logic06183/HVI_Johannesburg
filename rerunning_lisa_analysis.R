# Load required libraries
library(spdep)
library(sf)
library(ggplot2)

# Load the saved GWPCA results that contain your HVI values
gwpca_sf <- readRDS("gwpca_sf_with_hvi.rds")

# Get the HVI values
hvi_values <- as.vector(gwpca_sf$HVI)

# Create spatial weights
coords <- st_coordinates(st_centroid(gwpca_sf))
nb <- dnearneigh(coords, 0, 10000)  # Using 10km distance as in your original code
w <- nb2listw(nb, style="W")

# Calculate Local Moran's I
local_moran <- localmoran(hvi_values, w)

# Add results back to our spatial dataframe
gwpca_sf$LocalI <- local_moran[, "Ii"]
gwpca_sf$LocalI_P <- local_moran[, "Pr(z != E(Ii))"]
hvi_lag <- lag.listw(w, hvi_values)

# Calculate mean for high/low classification
hvi_mean <- mean(hvi_values)

# Create LISA cluster categories with p-value information
gwpca_sf$LISA_cluster <- NA
gwpca_sf$LISA_cluster[hvi_values > hvi_mean & 
                        hvi_lag > hvi_mean & 
                        gwpca_sf$LocalI_P < 0.05] <- "High-High (p < 0.05)"
gwpca_sf$LISA_cluster[hvi_values < hvi_mean & 
                        hvi_lag < hvi_mean & 
                        gwpca_sf$LocalI_P < 0.05] <- "Low-Low (p < 0.05)"
gwpca_sf$LISA_cluster[hvi_values > hvi_mean & 
                        hvi_lag < hvi_mean & 
                        gwpca_sf$LocalI_P < 0.05] <- "High-Low (p < 0.05)"
gwpca_sf$LISA_cluster[hvi_values < hvi_mean & 
                        hvi_lag > hvi_mean & 
                        gwpca_sf$LocalI_P < 0.05] <- "Low-High (p < 0.05)"
gwpca_sf$LISA_cluster[gwpca_sf$LocalI_P >= 0.05] <- "Not Significant (p ≥ 0.05)"

# Create publication-ready LISA map
lisa_plot <- ggplot(gwpca_sf) +
  geom_sf(aes(fill = LISA_cluster), color = "grey30", size = 0.1) +
  scale_fill_manual(values = c(
    "High-High (p < 0.05)" = "#d73027",      # Dark red
    "Low-Low (p < 0.05)" = "#4575b4",        # Dark blue
    "High-Low (p < 0.05)" = "#fc8d59",       # Light red
    "Low-High (p < 0.05)" = "#91bfdb",       # Light blue
    "Not Significant (p ≥ 0.05)" = "#f7f7f7"  # Light grey
  )) +
  theme_minimal(base_size = 12, base_family = "Arial") +
  labs(
    title = "Spatial Clustering of Heat Vulnerability in Johannesburg",
    subtitle = paste0(
      "Global Moran's I p-value: ", 
      format.pval(moran.test(hvi_values, w)$p.value, digits = 3)
    ),
    caption = "Data source: Heat Vulnerability Index analysis\nMethod: Local Indicators of Spatial Association (LISA)",
    fill = "LISA Cluster Type"
  ) +
  theme(
    plot.title = element_text(size = 16, face = "bold", margin = margin(b = 10)),
    plot.subtitle = element_text(size = 12, color = "grey40", margin = margin(b = 20)),
    plot.caption = element_text(size = 10, color = "grey40", margin = margin(t = 10)),
    legend.position = "right",
    legend.title = element_text(size = 12, face = "bold"),
    legend.text = element_text(size = 10),
    panel.grid = element_blank(),
    panel.background = element_rect(fill = "white"),
    plot.background = element_rect(fill = "white", color = NA),
    axis.text = element_text(size = 10, color = "grey40"),
    plot.margin = margin(20, 20, 20, 20)
  )

# Save the plot in high resolution
ggsave(
  "lisa_clusters_map.png", 
  lisa_plot, 
  width = 10, 
  height = 8,
  dpi = 300,
  bg = "white"
)

# Also save in vector format for publication
ggsave(
  "lisa_clusters_map.pdf", 
  lisa_plot, 
  width = 10, 
  height = 8,
  device = cairo_pdf
)

# Print Global Moran's I
print(moran.test(hvi_values, w))

# Print summary of clusters
print(table(gwpca_sf$LISA_cluster))
