#Title: day1-01-raster-structure_2025.R
#Baylor ENV5188 Fall 2025
#Instructor: Erich Seamon

# --- packages
suppressPackageStartupMessages({
  library(terra)     # replaces raster + rgdal I/O
  library(sf)        # vectors/CRS utilities
  library(ggplot2)
  library(dplyr)
  library(scales)
})

#In this episode, we will introduce the fundamental principles, 
#packages and metadata/raster attributes that are needed to work 
#with raster data in R. We will discuss some of the core metadata 
#elements that we need to understand to work with rasters in R, 
#including CRS and resolution. We will also explore missing and 
#bad data values as stored in a raster and how R handles these elements.

#We will continue to work with the `dplyr` and `ggplot2` packages 
#that were introduced previously. We will use the 'terra' package
#for rasters. Make sure that you have these packages loaded.
## Introduce the data / View Raster File Attributes

# raster::GDALinfo(...)  -->  terra metadata helpers (no full load)
#terra::sources("data/NEON-DS-Airborne-Remote-Sensing/HARV/DSM/HARV_dsmCrop.tif")
terra::describe("data/NEON-DS-Airborne-Remote-Sensing/HARV/DSM/HARV_dsmCrop.tif")

# If you want a character vector like capture.output(GDALinfo(...)):

HARV_dsmCrop_info <- capture.output(terra::describe("data/NEON-DS-Airborne-Remote-Sensing/HARV/DSM/HARV_dsmCrop.tif"))
HARV_dsmCrop_info


#Each line of text that was printed to the console is now stored as 
#an element of the character vector `HARV_dsmCrop_info`. We will be 
#exploring this data throughout this episode. By the end of this 
#episode, you will be able to explain and understand the output above.

## Open a Raster in R

#Now that we've previewed the metadata for our GeoTIFF, let's import 
#this raster dataset into R and explore its metadata more closely. We 
#can use the `raster()` function to open a raster in R.

## Data Tip - Object names

#To improve code readability, file and object names should be used 
#that make it clear what is in the file. The data for this episode 
#were collected from Harvard Forest so we'll use a naming convention 
#of `datatype_HARV`.

#First we will load our raster file into R and view the data structure.

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

#We can use `ggplot()` to plot this data. We will set the color scale 
#to `scale_fill_viridis_c` which is a color-blindness friendly color scale.
#We will also use the `coord_quickmap()` function to use an approximate 
#Mercator projection for our plots. This approximation is suitable for 
#small areas that are not too close to the poles. Other coordinate 
#systems are available in ggplot2 if needed, you can learn about them 
#at their help page `?coord_map`.

ggplot() +
  geom_raster(data = DSM_HARV_df , aes(x = x, y = y, fill = HARV_dsmCrop)) +
  scale_fill_viridis_c() +
  coord_quickmap()

# Quick base plot (terra::plot)
plot(DSM_HARV)

### View CRS (proj string and units)

#This map shows the elevation of our study site in Harvard Forest. 
#From the legend, we can see that the maximum elevation is ~400, but 
#we can't tell whether this is 400 feet or 400 meters because the 
#legend doesn't show us the units. We can look at the metadata of 
#our object to see what the units are. Much of the metadata that 
#we're interested in is part of the CRS. We introduced the concept of a CRS earlier.

#Now we will see how features of the CRS appear in our data file 
#and what meanings they have.

### View Raster Coordinate Reference System (CRS) in R
#We can view the CRS string associated with our R object using the`crs()` function.

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
## Raster Bands

#The Digital Surface Model object (`DSM_HARV`) that we've been working 
#with is a single band raster. This means that there is only one dataset 
#stored in the raster: surface elevation in meters for one time period.

#A raster dataset can contain one or more bands. We can use the `raster()` 
#function to import one single band from a single or multi-band raster. We 
#can view the number of bands in a raster using the `nlayers()` function.

nlyr(DSM_HARV)

#However, raster data can also be multi-band, meaning that one raster file 
#contains data for more than one variable or time period for each cell. By 
#default the `raster()` function only imports the first band in a raster 
#regardless of whether it has one or more bands. Jump to a later episode 
#in this series for information on working with multi-band rasters:

## Dealing with Missing Data

#Raster data often has a `NoDataValue` associated with it. This is a 
#value assigned to pixels where data is missing or no data were collected.

#By default the shape of a raster is always rectangular. So if we have  
#a dataset that has a shape that isn't rectangular, some pixels at the 
#edge of the raster will have `NoDataValue`s. This often happens when 
#the data were collected by an airplane which only flew over some part 
#of a defined region.

#In the image below, the pixels that are black have `NoDataValue`s. 
#The camera did not collect data in these areas.

# raster::stack(...) --> rast(...) (multi-band reads automatically)
RGB_stack <- rast("data/NEON-DS-Airborne-Remote-Sensing/HARV/RGB_Imagery/HARV_RGB_Ortho.tif")

# aggregate(..., fact=8, fun=median)
# aggregate cells from 0.25m to 2m for plotting to speed up the lesson and 
# save memory
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
