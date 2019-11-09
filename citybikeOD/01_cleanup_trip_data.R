library(magrittr)
library(data.table)
# Also using lubridate::ymd_hms()

#' Read all csv files of the year 2019.
#' Only keep the timestamp and station id columns,
#' others are not needed in this case.
#' Rename the columns with shorter names.
#' Convert timestamp columns into correct type.
#' Save the dataset in serialized format.
csv_in <- list.files('data', pattern = '^2019.*.csv', full.names = TRUE)
csv_in
dt <- lapply(csv_in, fread,
             select = c('Departure', 'Return', 'Departure station id', 'Return station id')) %>%
  rbindlist() %>%
  .[, .(dep_t = Departure, arr_t = Return,
        dep_id = `Departure station id`, arr_id = `Return station id`)]
n_orig <- nrow(dt)
dt[, dep_t := lubridate::ymd_hms(dep_t) %>% with_tz('Europe/Helsinki')]
dt[, arr_t := lubridate::ymd_hms(arr_t) %>% with_tz('Europe/Helsinki')]

#' Leave out records that do not have dep id, arr id, dep timestamp or arr timestamp.
dt <- dt[!(is.na(dep_t) | is.na(arr_t) | is.na(dep_id) | is.na(arr_id)), ]
sprintf('%d orig. rows,\n%d after filtering NA values',
        n_orig, nrow(dt)) %>%
  message()

saveRDS(dt, file = 'data/trips_2019.rds')
