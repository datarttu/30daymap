library(sf)
library(dplyr)
library(data.table)
library(ggplot2)
library(lubridate)

#' Read station points; they have been converted to GK25 in QGIS.
#' Alternatively, you could use `st_transform()`.
sts_pt <- st_read(dsn = 'data/stations.gpkg',
                  layer = 'stations',
                  stringsAsFactors = FALSE) %>%
  mutate(stid = as.integer(ID)) %>%
  select(stid)

#' Apply k-means clustering by the point location, use `k` clusters.
#' Each point thus gets a cluster id.
k <- 20
sts_kme <- sts_pt %>%
  cbind(clust = kmeans(st_coordinates(.), centers = k)$cluster)

#' Form Voronoi polygons from the points, clip a hand-drawn polygon
#' around the citybike area as an envelope.
#' `st_voronoi()` works with Multipoints instead of separate Points.
#' See https://www.jla-data.net/eng/creating-and-pruning-random-points-and-polygons/.
#' Join the point data attributes back to the polygons.
envel <- st_read(dsn = 'data/stations.gpkg',
                 layer = 'viz_boundary')
vor_pol <- st_geometry(sts_pt) %>%
  st_union() %>%
  st_voronoi() %>%
  st_collection_extract(type = 'POLYGON') %>%
  st_intersection(envel) %>%
  st_sf() %>%
  st_join(sts_kme)

plot(vor_pol['clust'])

#' Dissolve the polygons by the cluster id.
#' The resulting polygons are then used on the background to indicate
#' the cluster boundaries 
#' as well as a basis for the OD line start and end points.
vor_areas <- vor_pol %>%
  group_by(clust) %>%
  summarise(a = sum(1)) %>%
  select(-a)
plot(vor_areas['clust'])

#' Save the dissolved polygons.
st_write(vor_areas,
         dsn = 'data/voronoi.gpkg',
         layer = sprintf('vor_areas_k%d', k),
         layer_options = 'OVERWRITE=YES')

#' Extract and save the center points and ids of the dissolved polygons.
vor_centroids <- vor_areas %>%
  st_centroid()
st_write(vor_centroids,
         dsn = 'data/voronoi.gpkg',
         layer = sprintf('vor_centroids_k%d', k),
         layer_options = 'OVERWRITE=YES')

#' Extract the mapping between station and cluster ids.
sts_clust_mapping <- sts_kme %>%
  st_drop_geometry() %>%
  select(stid, clust) %>%
  as.data.table()
# write_csv(sts_clust_mapping,
#           path = sprintf('data/stid_clust_map_k%d.csv', k))

#' Read the trip data (using `data.table` due to high amount of data),
#' aggregate by station ids (to reduce the amount of data),
#' join cluster ids,
#' and calculate trip counts grouped by the cluster ids.

trp <- readRDS('data/trips_2019.rds') %>%
  .[, dep_t := ymd_hms(dep_t) %>% with_tz('Europe/Helsinki')] %>%
  .[, timecls := '15-03'] %>%
  .[hour(dep_t) %between% c(3, 15), timecls := '03-15']
str(trp)
trp_agg <- trp[, .N, by = .(dep_id, arr_id, timecls)]

trp_clu <- merge(trp_agg, sts_clust_mapping, by.x = 'dep_id', by.y = 'stid') %>%
  setnames('clust', 'dep_clust') %>%
  merge(., sts_clust_mapping, by.x = 'arr_id', by.y = 'stid') %>%
  setnames('clust', 'arr_clust') %>%
  .[, .(N = sum(N)), by = .(dep_clust, arr_clust, timecls)]
head(trp_clu)

fwrite(trp_clu, file = sprintf('data/od_clusters_k%d.csv', k))

#' Join dep and arr coordinates
vor_cen_crd <- vor_centroids %>%
  cbind(st_coordinates(.)) %>%
  st_drop_geometry()
head(vor_cen_crd)
trp_clu_crd <- trp_clu %>%
  inner_join(vor_cen_crd, by = c('dep_clust' = 'clust')) %>%
  rename(dep_x = X, dep_y = Y) %>%
  inner_join(vor_cen_crd, by = c('arr_clust' = 'clust')) %>%
  rename(arr_x = X, arr_y = Y)
  