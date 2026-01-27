# Pipelines

## Economy

### ATMs

`perl pipelines/economy/atms.pl`

## Society

### Benches

`perl pipelines/totalByConstituency.pl https://www.openbenches.org/api/benches.tsv -latitude=latitude -longitude=longitude -o src/themes/society/benches/_data/release/open-benches.csv -t "%Y-%m" -updatedate src/themes/society/benches/_data/openbenches.json -updatedate src/themes/society/benches/index.vto`

### Gambling premises

`perl pipelines/totalByConstituency.pl https://www.gamblingcommission.gov.uk/downloads/premises-licence-register.csv -postcode=Postcode -o src/themes/society/gambling-premises/_data/release/premises.csv -c "Premises Activity"`

### Foodbanks

`perl pipelines/society/foodbanks.pl`

### Post Offices

`perl pipelines/totalByConstituency.pl raw-data/society/post-offices/postofficebranches-details.csv -latitude=Latitude -longitude=Longitude -o src/themes/society/post-offices/_data/release/postoffices.csv -t "%Y-%m" -updatedate src/themes/society/post-offices/index.vto -updatedate src/themes/society/post-offices/_data/map_1.json`

### RMFI

`perl pipelines/society/RMFI.pl`