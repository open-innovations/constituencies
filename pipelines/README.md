# Pipelines

## Benches

`perl pipelines/totalByConstituency.pl https://www.openbenches.org/api/benches.tsv -latitude=latitude -longitude=longitude -o src/themes/society/benches/_data/release/open-benches.csv -t "%Y-%m" -updatedate src/themes/society/benches/_data/openbenches.json -updatedate src/themes/society/benches/index.vto`

## Gambling premises

`perl pipelines/totalByConstituency.pl https://www.gamblingcommission.gov.uk/downloads/premises-licence-register.csv -postcode=Postcode -o src/themes/society/gambling-premises/_data/release/premises.csv -c "Premises Activity"`

## Foodbanks

`perl pipelines/society/foodbanks.pl`

