#from pipelines.util import *
import json
from shapely.geometry import shape, Point
from shapely.validation import make_valid

lon = -1.063984
lat = 52.11284
point = Point(lon,lat)

with open('src/_data/geojson/constituencies-2022.geojson') as f:
    geo = json.load(f)
for feature in geo['features']:
    feature['geometry']['polygon'] = make_valid(shape(feature['geometry']))
    feature['geometry']['bounds'] = feature['geometry']['polygon'].bounds

for feature in geo['features']:
    if feature['properties']['PCON22NM'] == 'Pudsey':
        print(feature)
        break
for feature in geo['features']:
    b = feature['geometry']['bounds']
    if lon >= b[0] and lon <= b[2] and lat >= b[1] and lat <= b[3]:
        print(point,'is within bounds',b,'for',feature['properties']['PCON22NM'])
        # It has passed the initial bounding-box test
        # so check if it is really within the polygon(s)
        if feature['geometry']['polygon'].contains(point):
            print('\tA full check gives:', feature['properties']['PCON22NM'],feature['properties']['PCON22CD'])
            #print('yes', feature['properties']['PCON22NM'])
            continue
