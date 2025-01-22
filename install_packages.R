# List of required packages
packages <- c(
  "knitr",
  "rmarkdown",
  "GWmodel",
  "sp",
  "sf",
  "dplyr",
  "ggplot2",
  "viridis",
  "corrplot",
  "rlang",
  "psych",
  "tidyr",
  "spdep",
  "RColorBrewer",
  "factoextra",
  "mice"
)

# Function to install missing packages
install_if_missing <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    message(paste("Installing package:", pkg))
    install.packages(pkg, repos = "https://cran.rstudio.com/")
  } else {
    message(paste("Package already installed:", pkg))
  }
}

# Install required packages
install.packages(c("GWmodel", "sp", "sf", "dplyr", "ggplot2", "viridis", "corrplot", "rlang", "psych", "tidyr", "spdep", "RColorBrewer", "factoextra", "mice"), dependencies = TRUE)

# Load packages to verify installation
library(GWmodel)
library(sp)
library(sf)
library(dplyr)
library(ggplot2)
library(viridis)
library(corrplot)
library(rlang)
library(psych)
library(tidyr)
library(spdep)
library(RColorBrewer)
library(factoextra)
library(mice)

# Install packages
for (pkg in packages) {
  tryCatch({
    install_if_missing(pkg)
  }, error = function(e) {
    message(paste("Error installing", pkg, ":", e$message))
  })
}

# Check which packages were successfully loaded
loaded_packages <- sapply(packages, require, character.only = TRUE)
print("Package loading status:")
print(loaded_packages)
