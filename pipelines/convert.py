import pandas as pd
import os
import json
from OSGridConverter import grid2latlong
from shapely.geometry import shape, Point

def dataframe_grid2latlong():
    xl = pd.ExcelFile('raw-data/EDM 2022 Storm Overflow Annual Return - all water and sewerage companies.xlsx')
    names = xl.sheet_names 

    data_sets = []
    for name in names:
        data = pd.read_excel('raw-data/EDM 2022 Storm Overflow Annual Return - all water and sewerage companies.xlsx', sheet_name=name, skiprows=1)
        data_sets.append(data)
    df = pd.concat(data_sets)
    df['Outlet Discharge NGR\n(EA Consents Database)'] = df['Outlet Discharge NGR\n(EA Consents Database)'].str.replace('.*([A-Z]{2}\s?[0-9]{5}\s?[0-9]{5}).*', lambda x: x[1], regex=True)
    column = df['Outlet Discharge NGR\n(EA Consents Database)']
    df['longitude'] = pd.Series()
    df['latitude'] = pd.Series()
    for i in range(len(column)):
        #print(column.iloc[i])
        try:
            l = grid2latlong(column.iloc[i])
            df['longitude'].iloc[i] = l.longitude
            df['latitude'].iloc[i] = l.latitude
        except:
            print('No grid ref for', df.iloc[i]['Water Company Name'], df.iloc[i]['Site Name\n(WaSC operational)\n[optional]'])
        #print(i)
    df.columns = df.columns.str.replace('\n',' ')
    #df.to_csv('src/_data/sources/environment/storm_overflows.csv')
    return df

def latlong2constituency(df, opts={}):

    if not 'key' in opts:
        opts['key'] = 'PCON21CD'
    if not 'geojson' in opts:
        opts['geojson'] = 'src/_data/geojson/constituencies-2022.geojson'

    # load the geojson
    with open(opts['geojson']) as f:
        geo = json.load(f)

    # Go through each area and work out the rectangular bounds
    # This will be used as a first pass for points as it is faster
    for feature in geo['features']:
        feature['geometry']['polygon'] = shape(feature['geometry']);
        feature['geometry']['bounds'] = feature['geometry']['polygon'].bounds;

    df[opts['key']] = ""

    for i, row in df.iterrows():
        lat = row['lat']
        lon = row['lon']
        point = Point(lon,lat)
        for feature in geo['features']:
            b = feature['geometry']['bounds']
            if lon >= b[0] and lon <= b[2] and lat >= b[1] and lat <= b[3]:
                # It has passed the initial bounding-box test
                # so check if it is really within the polygon(s)
                if feature['geometry']['polygon'].contains(point):
                    df.at[i,opts['key']] = feature['properties'][opts['key']];

    return df

if __name__ == '__main__':
    #data = dataframe_grid2latlong()
    d = {'lat': [53.9948, 53.8382,53.7969,53.7419], 'lon': [-1.5401, -1.6399, -1.5341,-2.0131]}
    df = pd.DataFrame(data=d)
    df = latlong2constituency(df,{'key':'PCON22CD','geojson':'src/_data/geojson/constituencies-2022.geojson'})
    print(df)
