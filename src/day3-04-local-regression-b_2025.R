#Title: day3-04-local-regression.R
#BCB503 Geospatial Workshop, April 20th, 22nd, 27th, and 29th, 2021
#University of Idaho
#Data Carpentry Advanced Geospatial Analysis
#Instructors: Erich Seamon, University of Idaho - Li Huang, University of Idaho


#One short example with California precipitation data
#if (!require("rspatial")) devtools::install_github('rspatial/rspatial')
#library(rspatial)

library( spgwr )
library(sf)

datafolder <- "data/GWR/"
# best way to build paths
shp_path <- file.path(datafolder, "counties.shp")
counties <- st_read(shp_path)   
p <- read.csv(paste0(datafolder, "precipitation.csv", sep=""))

head(p)
plot(counties)
points(p[,c('LONG', 'LAT')], col='red', pch=20)

#Compute annual average precipitation
p$pan <- rowSums(p[,7:18])

#Global regression model
m <- lm(pan ~ ALT, data=p)
m

# Your custom Albers Equal Area target CRS (keep your parameters)
alb <- "+proj=aea +lat_1=34 +lat_2=40.5 +lat_0=0 +lon_0=-120 +x_0=0 +y_0=-4000000 +ellps=GRS80 +datum=NAD83 +units=m +no_defs"

# p is a data.frame with LONG / LAT columns (in NAD83 lon/lat)
p_sf <- st_as_sf(p, coords = c("LONG","LAT"), crs = "+proj=longlat +datum=NAD83")

# If counties is already sf, just set/confirm its CRS; if it's not, read it with st_read() first
# counties <- st_read("path/to/counties.shp")
st_crs(counties) <- "+proj=longlat +datum=NAD83"

# Reproject both to your Albers CRS
spt  <- st_transform(p_sf, alb)
ctst <- st_transform(counties, alb)

bw <- gwr.sel(pan ~ ALT, data=spt)
bw

r <- raster(ctst, res=10000)
r <- rasterize(ctst, r)
newpts <- rasterToPoints(r)


#Run the gwr function
g <- gwr(pan ~ ALT, data=spt, bandwidth=bw, fit.points=newpts[, 1:2])
g



# 1) observations (unchanged)
Xy  <- sf::st_coordinates(spt)            # obs coords
dat <- sf::st_drop_geometry(spt)          # obs attributes

# 2) your grid locations (fit_xy already has x,y)
fit_sf <- sf::st_as_sf(as.data.frame(fit_xy), coords = c("x","y"),
                       crs = sf::st_crs(spt))

# 3) get ALT at those locations (ALT_rast is a SpatRaster of altitude)
ALT_grid <- terra::extract(ALT_rast, terra::vect(fit_sf))[, 2]  # pick the ALT column

# 4) build SpatialPointsDataFrame with ALT
fit_spdf <- SpatialPointsDataFrame(
  coords      = as.matrix(fit_xy),
  data        = data.frame(ALT = ALT_grid),
  proj4string = CRS(sf::st_crs(spt)$proj4string)
)

# 5) run GWR
g <- gwr(
  pan ~ ALT,
  data       = dat,
  coords     = Xy,
  bandwidth  = bw,
  fit.points = fit_spdf,     # <-- now includes ALT
  hatmatrix  = TRUE,
  se.fit     = TRUE
)
g




# 1) make a 10 km grid raster over ctst and burn polygons
r <- rast(ctst, res = 10000)
r <- rasterize(ctst, r, field = 1, background = NA)
r <- r[[1]] 

# 3) Get non-NA cell centers as a data.frame, then make points
df <- as.data.frame(r, xy = TRUE, na.rm = TRUE)  # cols: x, y, layer
if (nrow(df) == 0) stop("No non-NA cells — check polygon/raster overlap or res.")

newpts <- vect(df[, c("x","y")], geom = c("x","y"), crs = crs(r))
# coords if needed
xy <- as.matrix(df[, c("x","y")])

# 2) points at cell centers for non-NA cells
#newpts <- as.points(r, values = TRUE, na.rm = TRUE)   # SpatVector
# or, if you need a data.frame:
newpts_df <- as.data.frame(r, xy = TRUE, na.rm = TRUE)


#Run the gwr function
# terra SpatVector -> coords matrix
fit_xy <- terra::crds(newpts, df = TRUE)  # columns x, y
g <- gwr(pan ~ ALT, data = spt, bandwidth = bw, fit.points = as.matrix(fit_xy))


#Link the results back to the raster
coef_slope <- r
intercept <- r
coef_slope[!is.na(coef_slope)] <- g$SDF$ALT
intercept[!is.na(intercept)] <- g$SDF$'(Intercept)'
s <- stack(coef_slope, intercept)
names(s) <- c('slope of coefficient', 'intercept')
plot(s)
