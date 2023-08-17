from pipelines.util import *

def covid_grants():
    ohlg = read_data('raw-data/covid-grants-april-2022.xlsx', 'OHLG')
    ohlg.to_csv(os.path.join(ECON_DATA_DIR, 'covid_grants_ohlg.csv'))

    arg = read_data('raw-data/covid-grants-april-2022.xlsx','ARG')
    arg.to_csv(os.path.join(ECON_DATA_DIR, 'covid_grants_arg.csv'))
    return

def data_pivot(data, values):
    # pivot the house price data into wide format
    return data.pivot(index=['ONSConstID', 'ConstituencyName', 'RegionName'], columns='DateOfDataset', values=values)

def wages(data, values):
    data_pivot(data, values).to_csv(os.path.join(ECON_DATA_DIR, 'wages.csv'))
    return

def house_prices(data, values):
    data_pivot(data, values).to_csv(os.path.join(ECON_DATA_DIR, 'house_prices.csv'))
    return

def house_price_wage_ratio(data, values):
    data_pivot(data, values).to_csv(os.path.join(ECON_DATA_DIR, 'house_price_wage_ratio.csv'))
    return

def unemployment(data, values):
    data_pivot(data, values).to_csv(os.path.join(ECON_DATA_DIR, 'unemployment_rate.csv'))
    return

if __name__ == '__main__':
    covid_grants()
    
    #get a metrics from house price data and write to csvs.
    house_price_data = read_data('raw-data/house-prices.xlsx', 'Constituency data table')
    wages(house_price_data, 'ConstWage')
    house_prices(house_price_data, 'HouseConstMedianPrice')
    house_price_wage_ratio(house_price_data, 'ConstRatio')

    unem_data = read_data('raw-data/unemployment.xlsx', 'Data')
    unemployment(unem_data, 'UnempConstRate')

