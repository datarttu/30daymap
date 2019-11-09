library(data.table)
library(magrittr)

files_in <- list.files(path = 'data',
                       pattern = '^fmi_snow_[0-9]{4}.csv',
                       full.names = TRUE)
lapply(files_in, fread) %>%
  rbindlist() %>%
  fwrite(file = 'data/fmi_snow_all_years.csv')
