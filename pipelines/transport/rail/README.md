# Performance at stations

## Find constituency for each station

Data is available to download as XLSX from https://dataportal.orr.gov.uk/statistics/performance/performance-at-stations

A CSV of UK stations can be obtained from https://www.doogal.co.uk/UkStations

Westminster Parliamentary Constituencies can be downloaded as Geopackage from https://geoportal.statistics.gov.uk/datasets/e489d4e5fe9f4f9caa6af161da5442af_0/explore

In QGIS run Vector->Data Management Tools->Join Attributes By Location and set options.

The resulting output is missing PCON details for Stranraer,STR and Ryde Pier Head,RYP because they are on piers so these needed to be set manually.
