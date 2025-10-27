# Title: day1-03-raster-calculations-in-r_terra.R
# Terra rewrite of the raster/rgdal version

library(terra)   # replaces raster + rgdal I/O & math
library(sf)      # optional: for gdal-utils-style metadata if you want it
library(ggplot2)
library(dplyr)
library(gridExtra)

# -------------------------------------------------------------------
# Load data (DSM/DTM for HARV and SJER)
# -------------------------------------------------------------------

DSM_HARV <- rast("data/NEON-DS-Airborne-Remote-Sensing/HARV/DSM/HARV_dsmCrop.tif")
DTM_HARV <- rast("data/NEON-DS-Airborne-Remote-Sensing/HARV/DTM/HARV_dtmCrop.tif")

DSM_SJER <- rast("data/NEON-DS-Airborne-Remote-Sensing/SJER/DSM/SJER_dsmCrop.tif")
DTM_SJER <- rast("data/NEON-DS-Airborne-Remote-Sensing/SJER/DTM/SJER_dtmCrop.tif")

# Convert to data frames for plotting
DSM_HARV_df <- as.data.frame(DSM_HARV, xy = TRUE)
DTM_HARV_df <- as.data.frame(DTM_HARV, xy = TRUE)

DSM_SJER_df <- as.data.frame(DSM_SJER, xy = TRUE)
DTM_SJER_df <- as.data.frame(DTM_SJER, xy = TRUE)

# -------------------------------------------------------------------
# (Optional) “GDALinfo” equivalents
# terra::describe(...) or sf::gdal_utils(util="info", ...)
# -------------------------------------------------------------------
# terra::describe("path/to.tif")
# sf::gdal_utils("info","path/to.tif", options=c("-stats"))

# -------------------------------------------------------------------
# Quick plots of inputs (unchanged logic)
# -------------------------------------------------------------------

ggplot() +
  geom_raster(data = DTM_HARV_df , aes(x = x, y = y, fill = HARV_dtmCrop)) +
  scale_fill_gradientn(name = "Elevation", colors = terrain.colors(10)) +
  coord_quickmap()

ggplot() +
  geom_raster(data = DSM_HARV_df , aes(x = x, y = y, fill = HARV_dsmCrop)) +
  scale_fill_gradientn(name = "Elevation", colors = terrain.colors(10)) +
  coord_quickmap()

# -------------------------------------------------------------------
# Two ways to perform raster calculations in terra
# -------------------------------------------------------------------

# A) Direct raster math (DSM - DTM)
CHM_HARV <- DSM_HARV - DTM_HARV
names(CHM_HARV) <- "layer"                # keep ggplot column name identical
CHM_HARV_df <- as.data.frame(CHM_HARV, xy = TRUE)

ggplot() +
  geom_raster(data = CHM_HARV_df , aes(x = x, y = y, fill = layer)) +
  scale_fill_gradientn(name = "Canopy Height", colors = terrain.colors(10)) +
  coord_quickmap()

# Histogram
ggplot(CHM_HARV_df) + geom_histogram(aes(layer))

# Challenge answers: min/max etc.
min(CHM_HARV_df$layer, na.rm = TRUE)
max(CHM_HARV_df$layer, na.rm = TRUE)

ggplot(CHM_HARV_df) +
  geom_histogram(aes(layer), colour = "black", fill = "darkgreen", bins = 6)

custom_bins <- c(0, 10, 20, 30, 40)
CHM_HARV_df <- CHM_HARV_df %>%
  mutate(canopy_discrete = cut(layer, breaks = custom_bins))

ggplot() +
  geom_raster(data = CHM_HARV_df , aes(x = x, y = y, fill = canopy_discrete)) +
  scale_fill_manual(values = terrain.colors(4)) +
  coord_quickmap()

# B) Efficient processing with terra::lapp (overlay equivalent)
# In terra, use lapp() for multi-layer functions and app() for single raster.
# Here we pass both rasters and a two-arg function: r1 - r2.
CHM_ov_HARV <- lapp(c(DSM_HARV, DTM_HARV), fun = function(r1, r2) r1 - r2)
names(CHM_ov_HARV) <- "layer"
CHM_ov_HARV_df <- as.data.frame(CHM_ov_HARV, xy = TRUE)

ggplot() +
  geom_raster(data = CHM_ov_HARV_df, aes(x = x, y = y, fill = layer)) +
  scale_fill_gradientn(name = "Canopy Height", colors = terrain.colors(10)) +
  coord_quickmap()

# Side-by-side comparison
g1 <- ggplot() +
  geom_raster(data = CHM_HARV_df , aes(x = x, y = y, fill = layer)) +
  scale_fill_gradientn(name = "Canopy Height", colors = terrain.colors(10)) +
  coord_quickmap()

g2 <- ggplot() +
  geom_raster(data = CHM_ov_HARV_df, aes(x = x, y = y, fill = layer)) +
  scale_fill_gradientn(name = "Canopy Height", colors = terrain.colors(10)) +
  coord_quickmap()

grid.arrange(g1, g2, ncol = 2)

# -------------------------------------------------------------------
# Export a GeoTIFF (terra::writeRaster)
# -------------------------------------------------------------------
# terra uses filetype= rather than format=
writeRaster(
  CHM_ov_HARV,
  "outputs/CHM_HARV.tif",
  overwrite = TRUE,
  NAflag = -9999
)


# -------------------------------------------------------------------
# Challenge (SJER): create CHM with lapp and export
# -------------------------------------------------------------------

CHM_ov_SJER <- lapp(c(DSM_SJER, DTM_SJER), fun = function(r1, r2) r1 - r2)
names(CHM_ov_SJER) <- "layer"

CHM_ov_SJER_df <- as.data.frame(CHM_ov_SJER, xy = TRUE)

ggplot(CHM_ov_SJER_df) + geom_histogram(aes(layer))

ggplot() +
  geom_raster(data = CHM_ov_SJER_df, aes(x = x, y = y, fill = layer)) +
  scale_fill_gradientn(name = "Canopy Height", colors = terrain.colors(10)) +
  coord_quickmap()

writeRaster(
  CHM_ov_SJER,
  "outputs/chm_ov_SJER.tiff",
  filetype = "GTiff",
  overwrite = TRUE,
  NAflag = -9999
)

# Compare distributions
ggplot(CHM_HARV_df) + geom_histogram(aes(layer))
ggplot(CHM_ov_SJER_df) + geom_histogram(aes(layer))
