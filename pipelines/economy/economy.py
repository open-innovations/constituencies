from pipelines.util import *

def covid_grants():
    ohlg = read_data('raw-data/covid-grants-april-2022.xlsx', 'OHLG')
    ohlg.replace('-', '', inplace=True)
    ohlg.round(0).to_csv(os.path.join(ECON_DATA_DIR, 'covid_grants_ohlg.csv'))

    arg = read_data('raw-data/covid-grants-april-2022.xlsx','ARG')
    arg.round(0).to_csv(os.path.join(ECON_DATA_DIR, 'covid_grants_arg.csv'))
    return

def data_pivot(data, values):
    # pivot the house price data into wide format
    return data.pivot(index=['ONSConstID', 'ConstituencyName', 'RegionName'], columns='DateOfDataset', values=values)

def wages(path):
    data = pd.read_csv(path)
    data = data.pivot(index='GEOGRAPHY_CODE', columns='DATE', values='OBS_VALUE')
    data.index.rename('geography_code', inplace=True)
    for i, row in data.iterrows():
        prev_value = np.nan
        for j, value in row.items():
            if pd.isna(value):
                data.at[i, j] = prev_value
                value = prev_value
            prev_value = value
    return data.to_csv(os.path.join(ECON_DATA_DIR, 'wages.csv'))

def house_prices(data, values):
    data = data_pivot(data, values).round(0)
    data.replace('-', '', inplace=True)
    data.to_csv(os.path.join(ECON_DATA_DIR, 'house_prices.csv'))
    return

def house_price_wage_ratio(data, values):
    data.replace('-', '', inplace=True)
    data = data_pivot(data, values)
    data = data.apply(pd.to_numeric, errors='ignore')
    data = data.round(4)
    data.to_csv(os.path.join(ECON_DATA_DIR, 'house_price_wage_ratio.csv'))
    return

def unemployment(data, values):
    data = data_pivot(data, values)
    # Drop all months that aren't December
    data.drop(data.filter(regex='20[0-9]{2}-(0[0-9]|10|11)').columns, axis=1, inplace=True)
    data = data.apply(pd.to_numeric, errors='ignore')
    data = data.round(4)
    #print(data['UnempConstRate'])
    data.to_csv(os.path.join(ECON_DATA_DIR, 'unemployment_rate.csv'))
    return

if __name__ == '__main__':
    covid_grants()
    
    #get a metrics from house price data and write to csvs.
    house_price_data = read_data('raw-data/house-prices.xlsx', 'Constituency data table')
    wages('raw-data/median-wages.csv')
    house_prices(house_price_data, 'HouseConstMedianPrice')
    house_price_wage_ratio(house_price_data, 'ConstRatio')

    unem_data = read_data('raw-data/unemployment.xlsx', 'Data')
    unemployment(unem_data, 'UnempConstRate')

