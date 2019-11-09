library(tidyverse)
library(lubridate)
library(httr)
library(xml2)

#' Form a query parameterized by year.
#' Other parts remain static.

fmi_query <- function(x) {
  q <- paste(
    'http://opendata.fmi.fi/wfs?service=WFS',
    'version=2.0.0',
    'request=getFeature',
    'storedquery_id=fmi::observations::weather::daily::simple',
    sprintf('starttime=%d-12-24T00:00:00Z', x),
    sprintf('endtime=%d-12-24T23:59:59Z', x),
    'timestep=1440',
    'crs=EPSG::3067',
    'bbox=19.45,59.71,31.58,70.11,EPSG:4326',
    'parameters=snow',
    sep = '&'
  )
  return(q)
}

# fmi_query(1960)

#' Test:
# res <- GET(url = fmi_query(1980)) %>%
#   content()
#' 
#' #' Extract the values we want from the first member of the XML results,
#' #' in a 4 el chr vector:
#' vec <- res %>%
#'   xml_child(1) %>% # First element; change this to see results from another station
#'   xml_children() %>%
#'   xml_children() %>%
#'   xml_text()
#' 
#' vec
#' 
#' # X Y Z coordinates in EPSG:3067
#' vec[1] %>% str_split_fixed(pattern = ' ', n = 3)
#' 
#' # UTC timestamp
#' vec[2]
#' 
#' # Parameter name
#' vec[3]
#' 
#' # Parameter value (here: snow depth)
#' vec[4]
#' 
#' # Make into a named vector:
#' coords <- vec[1] %>% str_split_fixed(pattern = ' ', n = 3)
#' out_vec <- c(
#'   X = coords[1],
#'   Y = coords[2],
#'   ts = vec[2],
#'   snow = vec[4]
#' )
#' out_vec

parse_member <- function(x) {
  vec <- x %>%
    xml_children() %>%
    xml_children() %>%
    xml_text()
  empty_res <- data.frame(
    X = NA_character_,
    Y = NA_character_,
    ts = NA_character_,
    snow = NA_character_,
    stringsAsFactors = FALSE
  )
  if (length(vec) != 4) {
    return(empty_res)
  }
  coords <- vec[1] %>% str_split_fixed(pattern = ' ', n = 3)
  if (length(coords) < 2) {
    return(empty_res)
  }
  out <- data.frame(
    X = coords[1],
    Y = coords[2],
    ts = vec[2],
    snow = vec[4],
    stringsAsFactors = FALSE
  )
  return(out)
}

# res %>%
#   xml_child(10) %>%
#   parse_member()
# 
# test_df <- res %>%
#   xml_children() %>%
#   map_dfr(parse_member)
# 
# test_df %>%
#   mutate(X = as.numeric(X),
#          Y = as.numeric(Y),
#          ts = ymd_hms(ts),
#          yr = year(ts),
#          snow = as.numeric(snow)) %>%
#   head()

for (y in 1960:2018) {
  tryCatch({
    message(paste(y, '...'))
    res <- GET(url = fmi_query(y)) %>%
      content()
    df <- res %>%
      xml_children() %>%
      map_dfr(parse_member) %>%
      mutate(X = as.numeric(X),
             Y = as.numeric(Y),
             ts = ymd_hms(ts),
             yr = year(ts),
             snow = as.numeric(snow))
    write_csv(df, path = sprintf('data/fmi_snow_%d.csv', y))
  }, error = function(e) {})
  Sys.sleep(1)
}
message('DONE')

#' See [FMI API guidelines](https://en.ilmatieteenlaitos.fi/open-data-manual-wfs-examples-and-guidelines):
#' 
#' - *Download Service has limit of 20000 requests per day*
#' - *Download and View Services have combined limit of 600 requests per 5 minutes*

