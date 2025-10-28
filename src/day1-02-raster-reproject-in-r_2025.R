#Title: day1-02-raster-reproject-in-r_2025.R
#Baylor ENV5188 Fall 2025
#Instructor: Erich Seamon

library(terra)   # replaces raster + rgdal I/O & reprojection
library(sf)      # optional: for gdal_utils() style metadata
library(ggplot2)
library(dplyr)

# --- Import data -------------------------------------------------------------

#Sometimes we encounter raster datasets that do not "line up" when plotted or
#analyzed. Rasters that don't line up are most often in different Coordinate
#Reference Systems (CRS). This episode explains how to deal with rasters in 
#different, known CRSs. It will walk though reprojecting rasters in R using the `projectRaster()`
#function in the `raster` package.

## Raster Projection in R

#In the [Plot Raster Data in R]({{ site.baseurl }}/02-raster-plot/)
#episode, we learned how to layer a raster file on top of a hillshade 
#for a nice looking basemap. In that episode, all of our data were 
#in the same CRS. What happens when things don't line up?

#For this episode, we will be working with the Harvard Forest Digital Terrain
#Model data. This differs from the surface model data we've been 
#working with so far in that the digital surface model (DSM) 
#includes the tops of trees, while the digital terrain model (DTM) 
#shows the ground level.

#We'll be looking at another model (the canopy height model) later
#and will see how to calculate the CHM from the DSM and DTM. 
#Here, we will create a map of the Harvard Forest Digital
#Terrain Model (`DTM_HARV`) draped or layered on top of 
#the hillshade (`DTM_hill_HARV`).

#First, we need to import the DTM and DTM hillshade data.

# DTM (UTM meters) and DTM hillshade (WGS84 lon/lat)
DTM_HARV <- rast("data/NEON-DS-Airborne-Remote-Sensing/HARV/DTM/HARV_dtmCrop.tif")
DTM_hill_HARV <- rast("data/NEON-DS-Airborne-Remote-Sensing/HARV/DTM/HARV_DTMhill_WGS84.tif")

#Next, we will convert each of these datasets to a dataframe for 
#plotting with `ggplot`.

DTM_HARV_df <- as.data.frame(DTM_HARV, xy = TRUE)
DTM_hill_HARV_df <- as.data.frame(DTM_hill_HARV, xy = TRUE)

#Now we can create a map of the DTM layered over the hillshade.
#Alpha refers to the opacity of a geom. Values of alpha range from 
#0 to 1, with lower values corresponding to more transparent colors.

ggplot() +
  geom_raster(data = DTM_HARV_df,
              aes(x = x, y = y, fill = HARV_dtmCrop)) +
  geom_raster(data = DTM_hill_HARV_df,
              aes(x = x, y = y, alpha = HARV_DTMhill_WGS84)) +
  scale_fill_gradientn(name = "Elevation", colors = terrain.colors(10)) +
  coord_quickmap()

# Plot each alone

#Our results are curious - neither the Digital Terrain Model (`DTM_HARV_df`) 
#nor the DTM Hillshade (`DTM_hill_HARV_df`) plotted.
#Let's try to plot the DTM on its own to make sure there are data there.


ggplot() +
  geom_raster(data = DTM_HARV_df,
              aes(x = x, y = y, fill = HARV_dtmCrop)) +
  scale_fill_gradientn(name = "Elevation", colors = terrain.colors(10)) +
  coord_quickmap()

#Our DTM seems to contain data and plots just fine.

#Next we plot the DTM Hillshade on its own to see whether everything is OK.

ggplot() +
  geom_raster(data = DTM_hill_HARV_df,
              aes(x = x, y = y, alpha = HARV_DTMhill_WGS84)) +
  coord_quickmap()

# --- Inspect CRS -------------------------------------------------------------

#If we look at the axes, we can see that the projections of the two 
#rasters are different. When this is the case, `ggplot` won't render 
#the image. It won't even throw an error message to tell you something 
#has gone wrong. We can look at Coordinate Reference Systems (CRSs) 
#of the DTM and the hillshade data to see how they differ.

## Exercise

#View the CRS for each of these two datasets. What projection does each use?

## Solution

# terra::crs() returns WKT by default; proj=TRUE shows +proj string
crs(DTM_HARV)                 # UTM, units meters (WKT)
crs(DTM_HARV, proj = TRUE)    # +proj=utm +zone=18 +datum=WGS84 +units=m ...
crs(DTM_hill_HARV, proj = TRUE) # +proj=longlat +datum=WGS84 +no_defs ...

# --- Reprojecting with terra -------------------------------------------------

#`DTM_HARV` is in the UTM projection, with units of meters.
#`DTM_hill_HARV` is in `Geographic WGS84` - which is represented 
#by latitude and longitude values.

#Because the two rasters are in different CRSs, they don't line 
#up when plotted in R. We need to reproject (or change the projection of) 
#`DTM_hill_HARV` into the UTM CRS. Alternatively, we could 
#reproject `DTM_HARV` into WGS84.

## Reproject Rasters

#We can use the `projectRaster()` function to reproject a 
#raster into a new CRS. Keep in mind that reprojection only 
#works when you first have a defined CRS for the raster object 
#that you want to reproject. It cannot be used if no
#CRS is defined. Lucky for us, the `DTM_hill_HARV` has a defined CRS.

## Data Tip
#When we reproject a raster, we move it from one "grid" 
#to another. Thus, we are modifying the data! Keep this in 
#mind as we work with raster data.

#To use the `projectRaster()` function, we need to define two things:

#1. the object we want to reproject and
#2. the CRS that we want to reproject it to.

#The syntax is `projectRaster(RasterObject, crs = CRSToReprojectTo)`

#We want the CRS of our hillshade to match the `DTM_HARV` raster. 
#We can thus assign the CRS of our `DTM_HARV` to our hillshade 
#within the `projectRaster()` function as follows: `crs = crs(DTM_HARV)`. 
#Note that we are using the `projectRaster()` function on the raster object,
#not the `data.frame()` we use for plotting with `ggplot`.

#First we will reproject our `DTM_hill_HARV` raster data to 
#match the `DTM_HARV` raster CRS:

DTM_hill_UTMZ18N_HARV <- project(DTM_hill_HARV, DTM_HARV, method = "bilinear")

#Now we can compare the CRS of our original DTM hillshade and 
#our new DTM hillshade, to see how they are different.

crs(DTM_hill_UTMZ18N_HARV, proj = TRUE)
crs(DTM_hill_HARV, proj = TRUE)

#We can also compare the extent of the two objects.

ext(DTM_hill_UTMZ18N_HARV)   # terra::ext; analogous to raster::extent
ext(DTM_hill_HARV)

# --- Resolution handling -----------------------------------------------------

# If you want to explicitly set output resolution to 1 m when giving only a CRS,
# you can do:
# DTM_hill_UTMZ18N_HARV <- project(DTM_hill_HARV, crs(DTM_HARV),
#                                  method = "bilinear", res = 1)



#Notice in the output above that the `crs()` of `DTM_hill_UTMZ18N_HARV` 
#is now UTM. However, the extent values of `DTM_hillUTMZ18N_HARV` 
#are different from `DTM_hill_HARV`.

## Challenge: Extent Change with CRS Change

#Why do you think the two extents differ?

## Answers

#The extent for DTM_hill_UTMZ18N_HARV is in UTMs so the extent 
#is in meters. The extent for DTM_hill_HARV is in lat/long 
#so the extent is expressed in decimal degrees.


## Deal with Raster Resolution

#Let's next have a look at the resolution of our reprojected hillshade versus 
#our original DTM data, that we are looking to overlay

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


#We have now successfully draped the Digital Terrain Model on top of our
#hillshade to produce a nice looking, textured map!

## Challenge: Reproject, then Plot a Digital Terrain Model

#Reproject the data as necessary to make things line up!

## Answers

# import DSM

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

## Answers

#The maps look identical. Which is what they should be as the only difference
#is this one was reprojected from WGS84 to UTM prior to plotting.
