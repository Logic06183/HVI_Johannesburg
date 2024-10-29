# First, let's properly prepare the data
hvi_values <- as.vector(merged_data_clean$HVI_normalized)
nb <- poly2nb(merged_data_clean)
w <- nb2listw(nb, style="W")
local_moran <- localmoran(hvi_values, w)

# Add results back to our spatial dataframe
merged_data_clean$LocalI <- local_moran[, "Ii"]
merged_data_clean$LocalI_P <- local_moran[, "Pr(z != E(Ii))"]
hvi_lag <- lag.listw(w, hvi_values)

# Create LISA cluster categories with p-value information
merged_data_clean$LISA_cluster <- NA
merged_data_clean$LISA_cluster[merged_data_clean$HVI_normalized > mean(merged_data_clean$HVI_normalized) & 
                                 hvi_lag > mean(hvi_values) & 
                                 merged_data_clean$LocalI_P < 0.05] <- "High-High (p < 0.05)"
merged_data_clean$LISA_cluster[merged_data_clean$HVI_normalized < mean(merged_data_clean$HVI_normalized) & 
                                 hvi_lag < mean(hvi_values) & 
                                 merged_data_clean$LocalI_P < 0.05] <- "Low-Low (p < 0.05)"
merged_data_clean$LISA_cluster[merged_data_clean$HVI_normalized > mean(merged_data_clean$HVI_normalized) & 
                                 hvi_lag < mean(hvi_values) & 
                                 merged_data_clean$LocalI_P < 0.05] <- "High-Low (p < 0.05)"
merged_data_clean$LISA_cluster[merged_data_clean$HVI_normalized < mean(merged_data_clean$HVI_normalized) & 
                                 hvi_lag > mean(hvi_values) & 
                                 merged_data_clean$LocalI_P < 0.05] <- "Low-High (p < 0.05)"
merged_data_clean$LISA_cluster[merged_data_clean$LocalI_P >= 0.05] <- "Not Significant (p ≥ 0.05)"

# Create LISA map with updated legend
ggplot(merged_data_clean) +
  geom_sf(aes(fill = LISA_cluster)) +
  scale_fill_manual(values = c("High-High (p < 0.05)" = "red",
                               "Low-Low (p < 0.05)" = "blue",
                               "High-Low (p < 0.05)" = "pink",
                               "Low-High (p < 0.05)" = "lightblue",
                               "Not Significant (p ≥ 0.05)" = "white")) +
  theme_minimal() +
  labs(title = "LISA Clusters for Heat Vulnerability",
       subtitle = paste("Global Moran's I p-value:", format.pval(moran.test(hvi_values, w)$p.value, digits = 3)),
       fill = "Cluster Type") +
  theme(plot.title = element_text(size = 14, face = "bold"),
        legend.position = "right",
        legend.text = element_text(size = 8))

# Print Global Moran's I
print(moran.test(hvi_values, w))

# Print summary of clusters
print(table(merged_data_clean$LISA_cluster))