import pandas as pd
import os

ECON_DATA_DIR = 'src/_data/sources/economy'
ENVIRON_DATA_DIR = 'src/_data/sources/environment'
def read_data(filename, sheet_name):
    data = pd.read_excel(filename, sheet_name, na_values='-')
    return data

def get_median_house_prices(data):
    return data.pivot(index=['ONSConstID', 'ConstituencyName', 'RegionName'], columns='DateOfDataset', values='HouseConstMedianPrice')

if __name__ == '__main__':
    data = read_data('raw-data/house-prices.xlsx', 'Constituency data table')
    get_median_house_prices(data).to_csv(os.path.join(ECON_DATA_DIR, 'house_prices.csv'))
    data.pivot(index=['ONSConstID', 'ConstituencyName', 'RegionName'], columns='DateOfDataset', values='ConstRatio').to_csv(os.path.join(ECON_DATA_DIR, 'house_price_wage_ratio.csv'))
    data.pivot(index=['ONSConstID', 'ConstituencyName', 'RegionName'], columns='DateOfDataset', values='ConstWage').to_csv(os.path.join(ECON_DATA_DIR, 'wages.csv'))

    unemploy = read_data('raw-data/unemployment.xlsx','Data')
    unemploy.pivot(index=['ONSConstID', 'ConstituencyName', 'RegionName'], columns='DateOfDataset', values='UnempConstRate').to_csv(os.path.join(ECON_DATA_DIR, 'unemployment_rate.csv'))

    spills = pd.read_json('raw-data/spills-by-constituency.json')
    spills.to_csv(os.path.join(ENVIRON_DATA_DIR, 'spills_by_constituency.csv'))