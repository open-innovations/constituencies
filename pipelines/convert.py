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

def latlong2constituency(df):
    # load the geojson
    with open('src/_data/geojson/constituencies-2022.geojson') as f:
        js = json.load(f)

    # load the data to convert
    latitudes, longitudes = df['latitude'], df['longitude']
    
    #create the points 
    Points = []
    for long, lat in zip(longitudes,latitudes):
        point = Point(long, lat)
        Points.append(point)

    #iterate through polygons to find which one contains point.
    for point in Points:
        for feature in js['features']:
            polygon = shape(feature['geometry'])
            #print(feature['properties']['PCON22NM'])
            try:
                if polygon.contains(point):
                    df[df.loc[Points.index(point)],'PCON22CD'] = feature['properties']['PCON22CD']
                    break
            except:
                print('bad geometry for', feature['properties']['PCON22NM'])
                #break
    return df

if __name__ == '__main__':
    data = dataframe_grid2latlong()
    df = latlong2constituency(data)
    print(df['PCON22CD'])
