# Title: day1-04-raster-multi-band-in-r_terra.R
# Terra rewrite of the raster/rgdal version

library(terra)    # replaces raster + rgdal
library(sf)       # optional, for gdal_utils-style metadata if desired
library(ggplot2)
library(dplyr)
library(gridExtra)

# -------------------------------------------------------------------
# Getting Started with Multi-Band Data in R (terra)
# -------------------------------------------------------------------
# In terra, use rast() to read multi-band rasters. You can read a single
# band with lyrs=, or all bands by default.

# Read ONLY band 1 (red)
RGB_band1_HARV <- rast(
  "data/NEON-DS-Airborne-Remote-Sensing/HARV/RGB_Imagery/HARV_RGB_Ortho.tif",
  lyrs = 1
)

# Convert to data frame for ggplot
RGB_band1_HARV_df <- as.data.frame(RGB_band1_HARV, xy = TRUE)

ggplot() +
  geom_raster(data = RGB_band1_HARV_df,
              aes(x = x, y = y, alpha = HARV_RGB_Ortho_1)) +
  coord_quickmap()

## Challenge (terra version)
# Attributes: dimensions, CRS, resolution, min/max, band count?
RGB_band1_HARV                # prints summary
nlyr(RGB_band1_HARV)          # number of layers in this object (should be 1)

# If you want to know total bands in the file, read all layers:
RGB_all_tmp <- rast("data/NEON-DS-Airborne-Remote-Sensing/HARV/RGB_Imagery/HARV_RGB_Ortho.tif")
nlyr(RGB_all_tmp)             # 3

# -------------------------------------------------------------------
# Import a specific band: green (band 2)
# -------------------------------------------------------------------
RGB_band2_HARV <- rast(
  "data/NEON-DS-Airborne-Remote-Sensing/HARV/RGB_Imagery/HARV_RGB_Ortho.tif",
  lyrs = 2
)

RGB_band2_HARV_df <- as.data.frame(RGB_band2_HARV, xy = TRUE)

ggplot() +
  geom_raster(data = RGB_band2_HARV_df,
              aes(x = x, y = y, alpha = HARV_RGB_Ortho_2)) +
  coord_equal()

# Side-by-side comparison (red vs green)
g1 <- ggplot() +
  geom_raster(data = RGB_band1_HARV_df,
              aes(x = x, y = y, alpha = HARV_RGB_Ortho_1)) +
  coord_quickmap()

g2 <- ggplot() +
  geom_raster(data = RGB_band2_HARV_df,
              aes(x = x, y = y, alpha = HARV_RGB_Ortho_2)) +
  coord_quickmap()

grid.arrange(g1, g2)

# Overlaid histograms of band 1 and band 2
ggplot() +
  geom_histogram(data = RGB_band1_HARV_df, aes(HARV_RGB_Ortho_1), fill = "red",   alpha = 0.2) +
  geom_histogram(data = RGB_band2_HARV_df, aes(HARV_RGB_Ortho_2), fill = "green", alpha = 0.2)

# Optional: grayscale palette and quick base plot of all bands
grayscale_colors <- gray.colors(100, start = 0.0, end = 1.0, gamma = 2.2)

# Read ALL bands as a single SpatRaster
RGB_stack_HARV <- rast("data/NEON-DS-Airborne-Remote-Sensing/HARV/RGB_Imagery/HARV_RGB_Ortho.tif")

plot(RGB_stack_HARV, col = grayscale_colors)

# -------------------------------------------------------------------
# Raster “Stacks” in terra (multi-band SpatRaster)
# -------------------------------------------------------------------

RGB_stack_HARV               # prints metadata (nrows, ncols, resolution, crs, #layers, etc.)
names(RGB_stack_HARV)        # layer (band) names
nlyr(RGB_stack_HARV)         # number of bands

# Inspect a specific band by index (returns a one-layer SpatRaster)
RGB_stack_HARV[[2]]

# Convert entire 3-band raster to data frame for ggplot
RGB_stack_HARV_df <- as.data.frame(RGB_stack_HARV, xy = TRUE)
str(RGB_stack_HARV_df)

# Histogram of band 1
ggplot() +
  geom_histogram(data = RGB_stack_HARV_df, aes(HARV_RGB_Ortho_1))

# Raster plot of band 2
ggplot() +
  geom_raster(data = RGB_stack_HARV_df,
              aes(x = x, y = y, alpha = HARV_RGB_Ortho_2)) +
  coord_quickmap()

# -------------------------------------------------------------------
# Create a three-band RGB image (terra::plotRGB)
# -------------------------------------------------------------------
# plotRGB works with SpatRaster; r/g/b are band indices (1-based).
plotRGB(RGB_stack_HARV, r = 1, g = 2, b = 3)

# Stretches (linear / histogram); 'scale' is used to normalize display
plotRGB(RGB_stack_HARV, r = 1, g = 2, b = 3, scale = 255, stretch = "lin")
plotRGB(RGB_stack_HARV, r = 1, g = 2, b = 3, scale = 255, stretch = "hist")

# -------------------------------------------------------------------
# Challenge – NoData values with plotRGB (terra version)
# -------------------------------------------------------------------
# 1–3) Inspect attributes / NoData / bands
# terra replacements for GDALinfo:
#   terra::describe(path)  or  sf::gdal_utils("info", path, options=c("-stats"))

terra::describe("data/NEON-DS-Airborne-Remote-Sensing/HARV/RGB_Imagery/HARV_Ortho_wNA.tif")

# 4) Load the multi-band raster file
HARV_NA <- rast("data/NEON-DS-Airborne-Remote-Sensing/HARV/RGB_Imagery/HARV_Ortho_wNA.tif")

# 5) Plot true color
plotRGB(HARV_NA, r = 1, g = 2, b = 3)

# 6–7) NA behavior:
NAflag(HARV_NA)   # e.g., -9999 if encoded; terra will treat those as NA for display/ops
NAflag(RGB_stack_HARV)  # often 0 or not set; edges may appear black if 0s, not NA

# (Optional) show info for the original RGB ortho
terra::describe("data/NEON-DS-Airborne-Remote-Sensing/HARV/RGB_Imagery/HARV_RGB_Ortho.tif")

# -------------------------------------------------------------------
# Terra note: Stack vs Brick
# -------------------------------------------------------------------
# In terra, there is no Stack/Brick split—multi-band rasters are SpatRaster.
# Whether data live on-disk or in-memory is managed internally (use inMemory()).

object.size(RGB_stack_HARV)  # size of R object (pointers/metadata), not file size
inMemory(RGB_stack_HARV)     # FALSE usually—data are read on demand
# To force into memory (not generally needed): 
# RGB_stack_HARV <- read(RGB_stack_HARV); inMemory(RGB_stack_HARV)  # TRUE

# plotRGB works the same regardless
plotRGB(RGB_stack_HARV)

# -------------------------------------------------------------------
# Challenge – methods() in terra
# -------------------------------------------------------------------
# In terra, both the full multi-band object and a single band are class "SpatRaster".
# So methods(class=...) will be essentially the same.

methods(class = class(RGB_stack_HARV))
methods(class = class(RGB_stack_HARV[[1]]))
# The method sets won’t differ much because they share the same class in terra.
