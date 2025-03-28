# Pre-requisites

Have `DVC`, `pipenv` installed and be able to run Jupyter Notebooks.

## Updating data

From the root of the project, run `pipenv sync` to install all packcages.

From root of this project, run `dvc update pipelines/transport/stops/data/stops.csv.dvc` to update the `stops.csv` file from NaPTAN. Ths file is not checked into Git.

## Running the pipeline

Open `pipeline.ipynb` and click "Run all". Select the kernel named `constituencies-<some_letters_and_numbers>`. The output file is saved to `src/themes/transport/transport-stops/_data/release/all.csv`.
