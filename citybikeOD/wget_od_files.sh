#!/usr/bin/env bash
months=(04 05 06 07 08 09 10)
for m in "${months[@]}";
do
  wget dev.hsl.fi/citybikes/od-trips-2019/2019-$m.csv;
done;
