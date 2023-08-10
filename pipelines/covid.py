import pandas as pd
import os

ECON_DATA_DIR = 'src/_data/sources/economy'

def read_data(filename, sheet_name):
    data = pd.read_excel(filename, sheet_name, na_values='-')
    return data

if __name__ == '__main__':
    ohlg = read_data('raw-data/covid-grants-april-2022.xlsx', 'OHLG')
    ohlg.to_csv(os.path.join(ECON_DATA_DIR, 'covid_grants_ohlg.csv'))

    arg = read_data('raw-data/covid-grants-april-2022.xlsx','ARG')
    arg.to_csv(os.path.join(ECON_DATA_DIR, 'covid_grants_arg.csv'))