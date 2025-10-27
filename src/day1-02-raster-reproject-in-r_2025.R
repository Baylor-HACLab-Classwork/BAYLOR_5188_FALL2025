# Title: day1-02-raster-reproject-in-r_terra.R
# Terra rewrite of your raster/rgdal lesson

library(terra)   # replaces raster + rgdal I/O & reprojection
library(sf)      # optional: for gdal_utils() style metadata
library(ggplot2)
library(dplyr)

# --- Import data -------------------------------------------------------------

# DTM (UTM meters) and DTM hillshade (WGS84 lon/lat)
DTM_HARV <- rast("data/NEON-DS-Airborne-Remote-Sensing/HARV/DTM/HARV_dtmCrop.tif")
DTM_hill_HARV <- rast("data/NEON-DS-Airborne-Remote-Sensing/HARV/DTM/HARV_DTMhill_WGS84.tif")

# Convert to data frames for ggplot
DTM_HARV_df <- as.data.frame(DTM_HARV, xy = TRUE)
DTM_hill_HARV_df <- as.data.frame(DTM_hill_HARV, xy = TRUE)

# Layer DTM over hillshade (will not render yet because CRSs differ)
ggplot() +
  geom_raster(data = DTM_HARV_df,
              aes(x = x, y = y, fill = HARV_dtmCrop)) +
  geom_raster(data = DTM_hill_HARV_df,
              aes(x = x, y = y, alpha = HARV_DTMhill_WGS84)) +
  scale_fill_gradientn(name = "Elevation", colors = terrain.colors(10)) +
  coord_quickmap()

# Plot each alone
ggplot() +
  geom_raster(data = DTM_HARV_df,
              aes(x = x, y = y, fill = HARV_dtmCrop)) +
  scale_fill_gradientn(name = "Elevation", colors = terrain.colors(10)) +
  coord_quickmap()

ggplot() +
  geom_raster(data = DTM_hill_HARV_df,
              aes(x = x, y = y, alpha = HARV_DTMhill_WGS84)) +
  coord_quickmap()

# --- Inspect CRS -------------------------------------------------------------

# terra::crs() returns WKT by default; proj=TRUE shows +proj string
crs(DTM_HARV)                 # UTM, units meters (WKT)
crs(DTM_HARV, proj = TRUE)    # +proj=utm +zone=18 +datum=WGS84 +units=m ...
crs(DTM_hill_HARV, proj = TRUE) # +proj=longlat +datum=WGS84 +no_defs ...

# --- Reprojecting with terra -------------------------------------------------

# In terra, use project(x, y, ...) where:
#   - y can be another SpatRaster (match its grid)
#   - or y can be a CRS string; you can also set res= to force resolution

# Option A (recommended): project hillshade to EXACT grid of DTM_HARV
DTM_hill_UTMZ18N_HARV <- project(DTM_hill_HARV, DTM_HARV, method = "bilinear")

# Compare CRSs and extents
crs(DTM_hill_UTMZ18N_HARV, proj = TRUE)
crs(DTM_hill_HARV, proj = TRUE)

ext(DTM_hill_UTMZ18N_HARV)   # terra::ext; analogous to raster::extent
ext(DTM_hill_HARV)

# --- Resolution handling -----------------------------------------------------

# If you want to explicitly set output resolution to 1 m when giving only a CRS,
# you can do:
# DTM_hill_UTMZ18N_HARV <- project(DTM_hill_HARV, crs(DTM_HARV),
#                                  method = "bilinear", res = 1)

# Since we projected to the template raster (DTM_HARV), the res already matches:
res(DTM_hill_UTMZ18N_HARV)
res(DTM_HARV)

# Prepare df for plotting
DTM_hill_HARV_2_df <- as.data.frame(DTM_hill_UTMZ18N_HARV, xy = TRUE)

# Plot: DTM draped over (reprojected) hillshade
ggplot() +
  geom_raster(data = DTM_HARV_df,
              aes(x = x, y = y, fill = HARV_dtmCrop)) +
  geom_raster(data = DTM_hill_HARV_2_df,
              aes(x = x, y = y, alpha = HARV_DTMhill_WGS84)) +
  scale_fill_gradientn(name = "Elevation", colors = terrain.colors(10)) +
  coord_quickmap()

# --- Challenge: Reproject, then Plot (SJER) ----------------------------------

# Import DSM and its WGS84 hillshade
DSM_SJER <- rast("data/NEON-DS-Airborne-Remote-Sensing/SJER/DSM/SJER_dsmCrop.tif")
DSM_hill_SJER_WGS <- rast("data/NEON-DS-Airborne-Remote-Sensing/SJER/DSM/SJER_DSMhill_WGS84.tif")

# Reproject hillshade to DSM grid (matches CRS + resolution)
DTM_hill_UTMZ18N_SJER <- project(DSM_hill_SJER_WGS, DSM_SJER, method = "bilinear")

# Data frames
DSM_SJER_df <- as.data.frame(DSM_SJER, xy = TRUE)
DSM_hill_SJER_df <- as.data.frame(DTM_hill_UTMZ18N_SJER, xy = TRUE)

ggplot() +
  geom_raster(data = DSM_hill_SJER_df,
              aes(x = x, y = y, alpha = SJER_DSMhill_WGS84)) +
  geom_raster(data = DSM_SJER_df,
              aes(x = x, y = y, fill = SJER_dsmCrop, alpha = 0.8)) +
  scale_fill_gradientn(name = "Elevation", colors = terrain.colors(10)) +
  coord_quickmap()
