library(tidyverse)
library(readr)
library(sf)

#' # Plot snow / non-snow areas for each year
#' 
#' Read the data:
#' 
#' - Finland area as polygons from [Natural Earth Data](https://naturalearthdata.com).
#' We simplify this a bit to get rid of vertices too accurate.
#' - Extent of the above dataset, made with QGIS
#' - Yearly 24.12. snow depth observations, see previous scripts

# Cm limit above which an area is considered fully "snowy":
k <- 20

fin <- st_read(dsn = 'data/ne_10m_finland.shp') %>%
  st_simplify(dTolerance = 7000)
fin_bbox <- st_read(dsn = 'data/extent_ne_10m_finland.shp')
df <- read_csv('data/fmi_snow_all_years.csv') %>%
  # Snow depth values > 10 are considered "fully" snowy,
  # lower values will get colors towards black.
  mutate(snowy = if_else(snow >= k, k,
                         if_else(snow < 0, 0, snow)))

#' Construct Voronoi polygons from the observation points per year.
#' This requires some wrangling,
#' since `sf_voronoi` requires the input as MULTIPOINT
#' and not as separate rows;
#' in this process the attributes are lost,
#' so the result has to be converted back to separate points
#' and attributes joined to the result polygons from the points.
#' Note that the point locations vary between years
#' since weather stations have been taken in and out of use.
#' 
#' We do the polygonization with a function that takes the records
#' of a single year as argument.
df_pt <- df %>%
  st_as_sf(coords = c('X', 'Y'), crs = 3067)

vor_per_year <- function(x) {
  x %>%
    st_union() %>%
    st_voronoi(envelope = fin_bbox %>% st_geometry()) %>%
    st_collection_extract(type = 'POLYGON') %>%
    st_sf() %>%
    st_join(x) %>%
    st_intersection(fin %>% st_geometry())
}

snow_pol <- df_pt %>%
  group_by(yr) %>%
  group_split() %>%
  map(vor_per_year)

snow_pol_df <- do.call(rbind, snow_pol)

#' Test case:
ggplot(snow_pol_df %>% filter(yr == 1980)) +
  geom_sf(aes(fill = snowy), color = NA) +
  scale_fill_gradient(low = 'black', high = 'white',
                      breaks = c(0, k),
                      labels = c('0', sprintf('> %d', k))) +
  guides(fill = guide_colorbar(title = 'Snow\ndepth\n(cm)',
                               ticks = FALSE)) +
  labs(title = 'Snow depth on Christmas Eve',
       subtitle = 'Voronoi Polygons of FMI weather stations') +
  theme_void() +
  theme(text = element_text(color = 'white'),
        plot.background = element_rect(fill = 'black'),
        plot.subtitle = element_text(margin = margin(0, 0, 10, 0)))

#' Actual plotting
p <- ggplot(snow_pol_df) +
  geom_sf(aes(fill = snowy), color = NA)  +
  scale_fill_gradient(low = 'black', high = 'white',
                      breaks = c(0, k),
                      labels = c('0', sprintf('> %d', k))) +
  guides(fill = guide_colorbar(title = 'Snow\ndepth\n(cm)',
                               ticks = FALSE)) +
  facet_wrap(facets = vars(yr), ncol = 10) +
  labs(title = 'Snow depths in Finland on December 24',
       subtitle = 'Voronoi polygons of FMI weather stations',
       caption = '© Arttu Kosonen 2019\nData © Finnish Meteorological Institute & Natural Earth Data') +
  theme_void() +
  theme(text = element_text(color = 'white', family = 'mono'),
        plot.background = element_rect(fill = 'black'),
        panel.background = element_rect(fill = 'black'),
        strip.background = element_rect(fill = 'black'),
        strip.text = element_text(size = 7),
        legend.title = element_text(size = 7),
        legend.text = element_text(size = 7),
        legend.box.margin = margin(0, 0, 0, 10),
        plot.subtitle = element_text(size = 7,
                                     margin = margin(5, 0, 10, 0)),
        plot.caption = element_text(size = 7),
        plot.margin = margin(10, 10, 10, 10)
        )

ggsave(filename = sprintf('png/snow_multiples_%d_cm.png', k), plot = p,
       width = 6, height = 7, units = 'in')


