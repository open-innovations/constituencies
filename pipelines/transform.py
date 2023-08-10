import pandas as pd
import os

ECON_DATA_DIR = 'src/_data/sources/economy'

def read_data(filename, sheet_name):
    data = pd.read_excel(filename, sheet_name, na_values='-')
    return data

def get_median_house_prices(data):
    data = data.pivot(index=['ONSConstID', 'ConstituencyName', 'RegionName'], columns='DateOfDataset', values='HouseConstMedianPrice')
    return data

if __name__ == '__main__':
    data = read_data('raw-data/house-prices.xlsx', 'Constituency data table')
    data = get_median_house_prices(data)
    data.to_csv(os.path.join(ECON_DATA_DIR, 'house_prices.csv'))