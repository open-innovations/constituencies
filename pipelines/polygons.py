import json
import pandas as pd
from shapely.geometry import shape, Point

def latlong2constituency():

    # load the geojson
    with open('src/_data/geojson/constituencies-2022.geojson') as f:
        js = json.load(f)

    # load the data to convert
    df = pd.read_csv('src/_data/sources/environment/storm_overflows.csv')
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
    df = latlong2constituency()
    print(df['PCON22CD'])