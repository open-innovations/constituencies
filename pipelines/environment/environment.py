from pipelines.util import *
import json
from OSGridConverter import grid2latlong
from shapely.geometry import shape, Point
from shapely.validation import make_valid

def spills():
    # this is what we are trying to reproduce
    data = pd.read_json('raw-data/spills-by-constituency.json').to_csv(os.path.join(ENVIRON_DATA_DIR, 'spills_by_constituency.csv'))
    return data

def df_grid2latlong():
    xl = pd.ExcelFile('raw-data/EDM 2022 Storm Overflow Annual Return - all water and sewerage companies.xlsx')
    names = xl.sheet_names 

    data_sets = []
    for name in names:
        data = pd.read_excel('raw-data/EDM 2022 Storm Overflow Annual Return - all water and sewerage companies.xlsx', sheet_name=name, skiprows=1)
        data_sets.append(data)
    df = pd.concat(data_sets)
    df['Outlet Discharge NGR\n(EA Consents Database)'] = df['Outlet Discharge NGR\n(EA Consents Database)'].str.replace('.*([A-Z]{2}\s?[0-9]{5}\s?[0-9]{5}).*', lambda x: x[1], regex=True)
    column = df['Outlet Discharge NGR\n(EA Consents Database)']
    df['lon'] = pd.Series()
    df['lat'] = pd.Series()
    for i in range(len(column)):
        #print(column.iloc[i])
        try:
            l = grid2latlong(column.iloc[i])
            df['lon'].iloc[i] = l.longitude
            df['lat'].iloc[i] = l.latitude
        except:
            print('No grid ref for', df.iloc[i]['Water Company Name'], df.iloc[i]['Site Name\n(WaSC operational)\n[optional]'])
        #print(i)
    df.columns = df.columns.str.replace('\n',' ')
    return df

def df_latlong2constituency(df, opts={}):
    if not 'key' in opts:
        # default key
        opts['key'] = 'PCON22CD'
    if not 'name' in opts:
        opts['name'] = 'PCON22NM'
    if not 'geojson' in opts:
        opts['geojson'] = 'src/_data/geojson/constituencies-2022.geojson'

    # load the geojson
    with open(opts['geojson']) as f:
        geo = json.load(f)

    # Go through each area and work out the rectangular bounds
    # This will be used as a first pass for points as it is faster
    for feature in geo['features']:
        feature['geometry']['polygon'] = make_valid(shape(feature['geometry']))
        feature['geometry']['bounds'] = feature['geometry']['polygon'].bounds

    df[opts['key']] = ""
    
    df = df.reset_index()

    for i, row in df.iterrows():
        lat = row['lat']
        lon = row['lon']
        ok = True
        try:
            val = float(lat)
        except:
            ok = False
        try:
            val = float(lon)
        except:
            ok = False

        if ok:
            try:
                point = Point(lon,lat)
            except:
                ok = False
                print('Bad point',i,lon,lat)

            if ok:
                # Could try 
                for feature in geo['features']:
                    b = feature['geometry']['bounds']
                    if lon >= b[0] and lon <= b[2] and lat >= b[1] and lat <= b[3]:
                        # It has passed the initial bounding-box test
                        # so check if it is really within the polygon(s)
                        if feature['geometry']['polygon'].contains(point):
                            df.at[i,opts['key']] = feature['properties'][opts['key']]
                            df.at[i,opts['name']] = feature['properties'][opts['name']]
                            #print(point,'is within',feature['properties'][opts['name']])
                            continue
    df.to_csv('raw-data/storm_overflows_latlong.csv')
    df = df.loc[:, ['Total Duration (hrs) all spills prior to processing through 12-24h count method', 'Counted spills using 12-24h count method', 'PCON22CD', 'PCON22NM']]
    # remove non-numeric entries
    df.replace(['#N/a', 'N/a', '-'], '', inplace=True)
    df.to_csv('src/_data/sources/environment/storm_overflows_by_constituency.csv')
    return df

def storm_overflows():
    #convert the OSgrid to latlong coords
    df = df_grid2latlong()
    # convert latlong to a constituency using shapely to check polygons
    df = df_latlong2constituency(df,{'key':'PCON22CD','geojson':'src/_data/geojson/constituencies-2022.geojson'})
    
    # we select only necessary columns, groupby those columns and sum the counts
    # reset_index() ensures we return a dataframe rather than a groupby object 
    
    df['Total Duration (hrs) all spills prior to processing through 12-24h count method'] = pd.to_numeric(df['Total Duration (hrs) all spills prior to processing through 12-24h count method'], errors='coerce')
    total_duration = df.groupby(['PCON22CD', 'PCON22NM'])['Total Duration (hrs) all spills prior to processing through 12-24h count method'].sum().reset_index()
    
    df['Counted spills using 12-24h count method'] = pd.to_numeric(df['Counted spills using 12-24h count method'], errors='coerce')
    total_spills = df.groupby(['PCON22CD', 'PCON22NM'])['Counted spills using 12-24h count method'].sum().reset_index() 

    total_spills.to_csv('src/_data/sources/environment/storm_overflows_spill_count.csv')
    total_duration.round(1).to_csv('src/_data/sources/environment/storm_overflows_total_duration.csv')

    return total_spills

if __name__ == '__main__':
    spills()
    storm_overflows()
     
