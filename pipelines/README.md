# Pipelines

## Economy

### ATMs

`perl pipelines/economy/atms.pl`


## Health

### Health conditions

Take the HoC data from https://commonslibrary.parliament.uk/constituency-data-how-healthy-is-your-area/#constituency

`perl pipelines/groupSum.pl src/themes/health/health-conditions/_data/health_conditions_constituency.csv -group "condition" -sum "prevalence%" -precision=0.001 -id "pcon_code" -keep "pcon_code,pcon_name,prevalence%" -o src/themes/health/health-conditions/_data/release/health_conditions.csv`


## Society

### Benches

`perl pipelines/totalByConstituency.pl https://www.openbenches.org/api/benches.tsv -latitude=latitude -longitude=longitude -o src/themes/society/benches/_data/release/open-benches.csv -t "%Y-%m" -updatedate src/themes/society/benches/_data/openbenches.json -updatedate src/themes/society/benches/index.vto`

### Country of birth

Get data from https://data.parliament.uk/resources/constituencystatistics/PowerBIData/ConstituencyDashboards/Census2122/country_of_birth_census.xlsx. Extract the constituency groups sheet as a CSV and save in `raw-data/society/country-of-birth/country_of_birth_census.csv`.

`perl pipelines/groupSum.pl raw-data/society/country-of-birth/country_of_birth_census.csv -group "groups" -sum "con_pc,rn_pc,uk_pc" -precision=0.001,0.001,0.001 -id "ONSConstID" -keep "ONSConstID,ConstituencyName,RegNationID,RegNationName,NatComparator,con_pc,rn_pc,uk_pc" -o src/themes/society/country-of-birth/_data/release/country_of_birth.csv`

### Gambling premises

Check if the CSV from the Gambling Commission is the whole file. Otherwise get the XLSX version and convert it.

`perl pipelines/totalByConstituency.pl https://www.gamblingcommission.gov.uk/downloads/premises-licence-register.csv -postcode=Postcode -o src/themes/society/gambling-premises/_data/release/premises.csv -c "Premises Activity" -updatedate src/themes/society/gambling-premises/index.vto -updatedate src/themes/society/gambling-premises/_data/map_1.json -t Total`

### Foodbanks

`perl pipelines/society/foodbanks.pl`

### Post Offices

`perl pipelines/totalByConstituency.pl raw-data/society/post-offices/postofficebranches-details.csv -latitude=Latitude -longitude=Longitude -o src/themes/society/post-offices/_data/release/postoffices.csv -t "%Y-%m" -updatedate src/themes/society/post-offices/index.vto -updatedate src/themes/society/post-offices/_data/map_1.json`

### RMFI

`perl pipelines/society/RMFI.pl`