# Load required library
library(corrplot)

# Using the previously created simplified correlation matrix
simplified_cor <- matrix(1, nrow=3, ncol=3)
rownames(simplified_cor) <- c("Environmental", "Health", "Socioeconomic")
colnames(simplified_cor) <- c("Environmental", "Health", "Socioeconomic")

# Fill in the mean correlations
simplified_cor[1,2] <- simplified_cor[2,1] <- mean(cor_matrix[environmental_vars, health_vars])
simplified_cor[1,3] <- simplified_cor[3,1] <- mean(cor_matrix[environmental_vars, socioeconomic_vars])
simplified_cor[2,3] <- simplified_cor[3,2] <- mean(cor_matrix[health_vars, socioeconomic_vars])

# Alternative: Create a simplified heatmap using ggplot2
library(reshape2)

# Convert correlation matrix to long format
melted_cor <- melt(simplified_cor)

# Create heatmap
ggplot(data = melted_cor, aes(x = Var1, y = Var2, fill = value)) +
  geom_tile() +
  scale_fill_gradient2(low = "blue", mid = "white", high = "red",
                       midpoint = 0, limits = c(-1, 1)) +
  theme_minimal() +
  labs(title = "Simplified Group Correlations",
       fill = "Correlation",
       x = "",
       y = "") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        plot.title = element_text(hjust = 0.5)) +
  # Add correlation values
  geom_text(aes(label = round(value, 2)), color = "black")

print("Mean correlations between groups:")
print(simplified_cor)