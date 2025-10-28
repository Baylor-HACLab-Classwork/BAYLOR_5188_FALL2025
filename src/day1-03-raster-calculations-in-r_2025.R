# Title: day1-03-raster-calculations-in-r_2025.R
#Baylor ENV5188 Fall 2025
#Instructor: Erich Seamon

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

#We've already loaded and worked with these two data files in
#earlier episodes. Let's plot them each once more to remind ourselves
#what this data looks like. First we'll plot the DTM elevation data: 

ggplot() +
  geom_raster(data = DTM_HARV_df , aes(x = x, y = y, fill = HARV_dtmCrop)) +
  scale_fill_gradientn(name = "Elevation", colors = terrain.colors(10)) +
  coord_quickmap()

#And then the DSM elevation data: 

ggplot() +
  geom_raster(data = DSM_HARV_df , aes(x = x, y = y, fill = HARV_dsmCrop)) +
  scale_fill_gradientn(name = "Elevation", colors = terrain.colors(10)) +
  coord_quickmap()

# -------------------------------------------------------------------
# Two ways to perform raster calculations in terra
# -------------------------------------------------------------------

# A) Direct raster math (DSM - DTM)

## Two Ways to Perform Raster Calculations

#We can calculate the difference between two rasters in two different ways:

# 1. by directly subtracting the two rasters in R using raster math

#2. or for more efficient processing - particularly if our rasters are 
#large and/or the calculations we are performing are complex: using 
#the `overlay()` function.

## Raster Math & Canopy Height Models

#We can perform raster calculations by subtracting (or adding,
#multiplying, etc) two rasters. In the geospatial world, we call this
#"raster math".

#Let's subtract the DTM from the DSM to create a Canopy Height Model. 
#After subtracting, let's create a dataframe so we can plot with `ggplot`.

CHM_HARV <- DSM_HARV - DTM_HARV
names(CHM_HARV) <- "layer"                # keep ggplot column name identical
CHM_HARV_df <- as.data.frame(CHM_HARV, xy = TRUE)

#We can now plot the output CHM.

ggplot() +
  geom_raster(data = CHM_HARV_df , aes(x = x, y = y, fill = layer)) +
  scale_fill_gradientn(name = "Canopy Height", colors = terrain.colors(10)) +
  coord_quickmap()

# Histogram
#Let's have a look at the distribution of values in our newly created
#Canopy Height Model (CHM).

ggplot(CHM_HARV_df) + geom_histogram(aes(layer))

#Notice that the range of values for the output CHM is between 0 and 30 
#meters. Does this make sense for trees in Harvard Forest?

## Challenge: Explore CHM Raster Values

#It's often a good idea to explore the range of values in a raster dataset just like we might explore a dataset that we collected in the field.

#1. What is the min and maximum value for the Harvard Forest Canopy Height Model (`CHM_HARV`) that we just created?
#2. What are two ways you can check this range of data for `CHM_HARV`?
#3. What is the distribution of all the pixel values in the CHM?
#4. Plot a histogram with 6 bins instead of the default and change the color of the histogram.
#5. Plot the `CHM_HARV` raster using breaks that make sense for the data. 
#Include an appropriate color palette for the data, plot title and 
#no axes ticks / labels.

## Answers
#1. What is the min and maximum value for the Harvard Forest Canopy Height Model (`CHM_HARV`) that we just created?
#1) There are missing values in our data, so we need to specify 
#`na.rm = TRUE`. 

min(CHM_HARV_df$layer, na.rm = TRUE)
max(CHM_HARV_df$layer, na.rm = TRUE)

#4. Plot a histogram with 6 bins instead of the default and change the color of the histogram.
#4)

ggplot(CHM_HARV_df) +
  geom_histogram(aes(layer), colour = "black", fill = "darkgreen", bins = 6)

#5. Plot the `CHM_HARV` raster using breaks that make sense for the data. 
#5) 

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

#Next we need to convert our new object to a data frame for plotting with 
#`ggplot`. 

CHM_ov_HARV_df <- as.data.frame(CHM_ov_HARV, xy = TRUE)

#Now we can plot the CHM:

ggplot() +
  geom_raster(data = CHM_ov_HARV_df, aes(x = x, y = y, fill = layer)) +
  scale_fill_gradientn(name = "Canopy Height", colors = terrain.colors(10)) +
  coord_quickmap()

#How do the plots of the CHM created with manual raster math 
#and the `overlay()` function compare?

#side by side

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
