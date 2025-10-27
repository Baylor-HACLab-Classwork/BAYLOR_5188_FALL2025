# --- packages
suppressPackageStartupMessages({
  library(terra)     # replaces raster + rgdal I/O
  library(sf)        # vectors/CRS utilities
  library(ggplot2)
  library(dplyr)
  library(scales)
})

## Introduce the data / View Raster File Attributes

# raster::GDALinfo(...)  -->  terra metadata helpers (no full load)
#terra::sources("data/NEON-DS-Airborne-Remote-Sensing/HARV/DSM/HARV_dsmCrop.tif")
terra::describe("data/NEON-DS-Airborne-Remote-Sensing/HARV/DSM/HARV_dsmCrop.tif")

# If you want a character vector like capture.output(GDALinfo(...)):

HARV_dsmCrop_info <- capture.output(terra::describe("data/NEON-DS-Airborne-Remote-Sensing/HARV/DSM/HARV_dsmCrop.tif"))
HARV_dsmCrop_info

## Open a Raster in R

# raster(...)  -->  rast(...)
DSM_HARV <- rast("data/NEON-DS-Airborne-Remote-Sensing/HARV/DSM/HARV_dsmCrop.tif")
DSM_HARV

# summary() works, but like raster it samples unless told otherwise.
summary(DSM_HARV)

# Force min/max over all cells (and cache them in object)
minmax(DSM_HARV)   # computes & stores
summary(DSM_HARV)

# Convert to data frame for ggplot (same API name)
DSM_HARV_df <- as.data.frame(DSM_HARV, xy = TRUE)
str(DSM_HARV_df)

ggplot() +
  geom_raster(data = DSM_HARV_df , aes(x = x, y = y, fill = HARV_dsmCrop)) +
  scale_fill_viridis_c() +
  coord_quickmap()

# Quick base plot (terra::plot)
plot(DSM_HARV)

### View CRS (proj string and units)

# crs() returns WKT by default; use proj=TRUE for PROJ string
crs(DSM_HARV)                # WKT2
crs(DSM_HARV, proj = TRUE)   # +proj=utm +zone=18 +datum=WGS84 +units=m +...

# Units are meters in this projected CRS.

## Calculate Raster Min and Max Values
# raster::minValue/maxValue/setMinMax --> terra::global/minmax
global(DSM_HARV, "min", na.rm = TRUE)[[1]]
global(DSM_HARV, "max", na.rm = TRUE)[[1]]

# Ensure cached:
minmax(DSM_HARV)
global(DSM_HARV, c("min","max"), na.rm = TRUE)

## Raster Bands
# raster::nlayers --> terra::nlyr
nlyr(DSM_HARV)

## Dealing with Missing Data (RGB example)

# raster::stack(...) --> rast(...) (multi-band reads automatically)
RGB_stack <- rast("data/NEON-DS-Airborne-Remote-Sensing/HARV/RGB_Imagery/HARV_RGB_Ortho.tif")

# aggregate(..., fact=8, fun=median)
RGB_2m <- aggregate(RGB_stack, fact = 8, fun = median, na.rm = TRUE)

# Optionally coerce to integer-like values (for consistent appearance)
values(RGB_2m) <- as.integer(round(values(RGB_2m)))

# To data frame for ggplot
RGB_2m_df <- as.data.frame(RGB_2m, xy = TRUE)
names(RGB_2m_df) <- c("x","y","red","green","blue")

ggplot() +
  geom_raster(data = RGB_2m_df , aes(x = x, y = y, fill = red), show.legend = FALSE) +
  scale_fill_gradient(low = "black", high = "red") +
  ggtitle("Orthographic Imagery", subtitle = "Red Band") +
  coord_quickmap()

# Build hex colors from three bands
RGB_2m_df_nd <- RGB_2m_df
RGB_2m_df_nd$hex <- rgb(RGB_2m_df_nd$red, RGB_2m_df_nd$green, RGB_2m_df_nd$blue, maxColorValue = 255)
RGB_2m_df_nd$hex[RGB_2m_df_nd$hex == "#000000"] <- NA_character_

ggplot() +
  geom_raster(data = RGB_2m_df_nd, aes(x = x, y = y, fill = hex)) +
  scale_fill_identity() +
  ggtitle("Orthographic Imagery", subtitle = "All bands") +
  coord_quickmap()

# Robust NA-masking where *all three* bands are zero (terra way)
zeros_count <- app(RGB_2m == 0, fun = sum, na.rm = TRUE)   # per-pixel count of zeros
RGB_2m_nas  <- mask(RGB_2m, zeros_count, maskvalues = nlyr(RGB_2m))

RGB_2m_nas_df <- as.data.frame(RGB_2m_nas, xy = TRUE)

ggplot() +
  geom_raster(data = RGB_2m_nas_df, aes(x = x, y = y, fill = HARV_RGB_Ortho_3)) +
  scale_fill_gradient(low = "grey90", high = "blue", na.value = "deeppink") +
  ggtitle("Orthographic Imagery", subtitle = "Blue band, with NA highlighted") +
  coord_quickmap()

rm(RGB_2m, RGB_stack, RGB_2m_df_nd, RGB_2m_df, RGB_2m_nas_df, zeros_count)

## NoDataValue lookup (on-disk NA flag)
NAflag(DSM_HARV)  # often -9999 for these NEON tiles

## Bad Data Values in Rasters (reclassify)

# raster::reclassify(...) --> terra::classify(...)
# Build a 3-column matrix: from, to, becomes
rcl <- matrix(c(0, 400, NA,   400, 420, 1),
              ncol = 3, byrow = TRUE)

DSM_highvals <- classify(DSM_HARV, rcl = rcl, include.lowest = TRUE)
DSM_highvals_df <- as.data.frame(DSM_highvals, xy = TRUE) |>
  tidyr::drop_na()

ggplot() +
  geom_raster(data = DSM_HARV_df, aes(x = x, y = y, fill = HARV_dsmCrop)) +
  scale_fill_viridis_c() +
  annotate(
    geom = "raster",
    x = DSM_highvals_df$x,
    y = DSM_highvals_df$y,
    fill = colour_ramp("deeppink")(DSM_highvals_df$HARV_dsmCrop)
  ) +
  ggtitle("Elevation Data", subtitle = "Highlighting values > 400m") +
  coord_quickmap()

rm(DSM_highvals, DSM_highvals_df)

## Histogram of raster values (unchanged logic)
ggplot() +
  geom_histogram(data = DSM_HARV_df, aes(HARV_dsmCrop))

ggplot() +
  geom_histogram(data = DSM_HARV_df, aes(HARV_dsmCrop), bins = 40)

## Challenge with GDALinfo -> use terra::describe and friends
terra::describe("data/NEON-DS-Airborne-Remote-Sensing/HARV/DSM/HARV_DSMhill.tif")
rast_hill <- rast("data/NEON-DS-Airborne-Remote-Sensing/HARV/DSM/HARV_DSMhill.tif")

# 1. Same CRS?
same_crs <- crs(rast_hill) == crs(DSM_HARV)
same_crs

# 2. NoData value?
NAflag(rast_hill)

# 3. Resolution?
res(rast_hill)   # e.g., c(1,1)

# 4. Size of 5x5 pixels on ground (meters)
prod(res(rast_hill) * 5)   # 25 m^2; footprint is 5m x 5m

# 5. Bands?
nlyr(rast_hill)  # 1 = single-band
