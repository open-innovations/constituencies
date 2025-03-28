import os
import sys
import re
import pandas as pd
sys.path.append("./")
from pipelines.util import *
import json
from OSGridConverter import grid2latlong
from shapely.geometry import shape, Point
from shapely.validation import make_valid
import datetime


def df_create(opts={}):
    file = opts['base']+opts['data']['xls'];

    print('Read ',file)
    xl = pd.ExcelFile(file)
    names = xl.sheet_names 

    data_sets = []
    for name in names:
        data = pd.read_excel(file, sheet_name=name, keep_default_na=True, na_values='', skiprows=opts['data']['skiprows'])
        data_sets.append(data)
    df = pd.concat(data_sets,ignore_index=True)
    return df
    
def df_grid2latlong(df,gridref):

    if(gridref):
        
        df[gridref] = df[gridref].str.replace('.*([A-Z]{2}\s?[0-9]{5}\s?[0-9]{5}).*', lambda x: x[1], regex=True)

        df["lon"] = np.nan
        df["lat"] = np.nan

        for i in range(len(df)):
            try:
                l = grid2latlong(df[gridref][i])
                df.at[i,'lon'] = l.longitude
                df.at[i,'lat'] = l.latitude
            except:
                print("Bad gridref on row ",i,df[gridref][i])

    df.columns = df.columns.str.replace('\n',' ')
    return df

def df_latlong2constituency(df, opts={}):

    print("latlong2constituency")

    basedir = getBaseDir()

    if not 'year' in opts:
        opts['year'] = 'XXXX'
    if not 'key' in opts:
        opts['key'] = 'PCON24CD'
    if not 'name' in opts:
        opts['name'] = 'PCON24NM'
    if not 'geojson' in opts:
        opts['geojson'] = basedir+'../../src/_data/geojson/constituencies-2024.geojson'
    if not 'countedspills' in opts:
        opts['countedspills'] = 'Counted spills using 12-24h count method'
    if not 'totalduration' in opts:
        opts['totalduration'] = 'Total Duration (hrs) all spills prior to processing through 12-24h count method'

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

    # Save a temporary copy of the augemented file
    print("Basedir: ", basedir)
    try:
        df.to_csv(basedir+'../../raw-data/storm_overflows_latlong-'+opts['year']+'.csv')
    except:
        print("Can't save file "+basedir+'../../raw-data/storm_overflows_latlong-'+opts['year']+'.csv')

    # Limit the columns
    df = df.loc[:, [opts['totalduration'], opts['countedspills'], 'PCON24CD', 'PCON24NM']]
    # remove non-numeric entries
    df.replace(['#N/a', 'N/a', '-'], '', inplace=True)
    #df.to_csv('../../src/_data/sources/environment/storm_overflows_by_constituency.csv')

    return df

def getBaseDir():
    basedir = os.path.dirname(__file__);
    if(basedir):
        basedir += '/';
    return basedir

def save_tidy_csv(df, directory, filename, with_index=True):
    # First add the header
    ncol = len(df.columns)
    new_record = pd.DataFrame([[*['---'] * ncol]], columns=df.columns)
    final = pd.concat([new_record, df], ignore_index=True)

    # Get the output as CSV
    csv = final.to_csv(index=with_index)

    # Because we added an index column we will now tidy
    csv = re.sub(r'\n0,---,---', '\n---,---,---', csv)

    text_file = open(os.path.join(directory, filename), "w")
    text_file.write(csv)
    text_file.close()

def to_decimal_hours(dt):
    if isinstance(dt, str):
        if dt is None:
            return 0
        if "-" not in dt:
            dt = "1899-12-31 "+dt
        dt = datetime.datetime.strptime(dt, "%Y-%m-%d %H:%M:%S")
    if isinstance(dt,datetime.time):
        dt = datetime.datetime.combine(datetime.date(1899, 12, 31), dt)
    duration = dt - datetime.datetime(1899, 12, 31, 0, 0, 0);
    return (duration.total_seconds() / 3600)

def storm_overflows():

    basedir = getBaseDir()
    years = {
        #"2021": {
        #    "xls":"../../raw-data/EDM_2021_Storm_Overflow_Annual_Return/EDM 2021 Storm Overflow Annual Return - all water and sewerage companies.xlsx"
        #},
        "2022": {
            "xls":"../../raw-data/EDM_2022_Storm_Overflow_Annual_Return/EDM 2022 Storm Overflow Annual Return - all water and sewerage companies.xlsx",
            "gridref": "Outlet Discharge NGR\n(EA Consents Database)",
            "name": "Site Name\n(EA Consents Database)",
            "totalduration": "Total Duration (hrs) all spills prior to processing through 12-24h count method",
            "countedspills": "Counted spills using 12-24h count method",
            "skiprows": 1
        },
        "2023":{
            "xls":"../../raw-data/EDM_2023_Storm_Overflow_Annual_Return/EDM 2023 Storm Overflow Annual Return - all water and sewerage companies.xlsx",
            "gridref": "Outlet Discharge NGR\n(EA Consents Database)",
            "name": "Site Name\n(EA Consents Database)",
            "totalduration": "Total Duration (hrs) all spills prior to processing through 12-24h count method",
            "countedspills": "Counted spills using 12-24h count method",
            "skiprows": 1
        },
        "2024":{
            "xls":"../../raw-data/EDM_2024_Storm_Overflow_Annual_Return/EDM 2024 Storm Overflow Annual Return - all water and sewerage companies.xlsx",
            "gridref": "Outlet Discharge NGR\n(EA Consents Database)",
            "name": "Site Name\n(WaSC operational)\n[optional]",
            "totalduration": "Total Duration (hh:mm:ss) all spills prior to processing through 12-24h count method",
            "countedspills": "Counted spills using 12-24h count method",
            "skiprows": 1
        }
    }

    header_total_duration = 'Total Duration (hrs) all spills prior to processing through 12-24h count method'
    header_counted_spills = 'Counted spills using 12-24h count method'
    data_sets = []
    for y in years:
        print("Processing year "+y)

        df = df_create({'base':basedir,'data':years[y]});

        #convert the OSgrid to latlong coords
        df = df_grid2latlong(df,years[y]['gridref'])

        # Move columns to standard name
        df[header_total_duration] =  df[years[y]['totalduration']]
        df[header_counted_spills] =  df[years[y]['countedspills']]

        # Need to convert 2024's not-actually-hh::mm:ss date format into decimal hours
        if(years[y]['totalduration'] == 'Total Duration (hh:mm:ss) all spills prior to processing through 12-24h count method'):
            # Fix empty values
            df[header_total_duration].fillna("00:00:00", inplace = True)
            for index, row in df.iterrows():
                df.at[index,header_total_duration] = to_decimal_hours(df.at[index,header_total_duration])

        # convert latlong to a constituency using shapely to check polygons
        df = df_latlong2constituency(df,{'year':y,'key':'PCON24CD','geojson':basedir+'../../src/_data/geojson/constituencies-2024.geojson','totalduration':header_total_duration,'countedspills':header_counted_spills})

        df[header_total_duration] = pd.to_numeric(df[header_total_duration], errors='coerce')
        total_duration = df.groupby(['PCON24CD', 'PCON24NM'])[header_total_duration].sum().reset_index()
        df[header_counted_spills] = pd.to_numeric(df[header_counted_spills], errors='coerce')
        total_spills = df.groupby(['PCON24CD', 'PCON24NM'])[header_counted_spills].sum().reset_index()

        merged_df = total_spills.merge(total_duration, how='inner')
        
        # Round columns
        merged_df[header_total_duration] = merged_df[header_total_duration].round(2)
        merged_df[header_counted_spills] = merged_df[header_counted_spills].round(0).astype(int)

        # Add a column with the year
        merged_df["Year"] = y

        # Add it to our data_sets array
        data_sets.append(merged_df)

    # Join all the data_sets
    full = pd.concat(data_sets,ignore_index=True)

    pivotted = full.pivot_table(index=['PCON24CD'], columns=['Year'], values=[header_counted_spills,header_total_duration])
    
    # Add a column at the start which is a duplicate of the index (so we can not print the index column)
    pivotted.insert(0,'PCON24CD',pivotted.index)

    # Add the Names back
    pivotted.insert(1,'PCON24NM',pivotted.PCON24CD.map(full.set_index('PCON24CD')['PCON24NM'].to_dict()),True)

    pivotted.pipe(save_tidy_csv, basedir, '../../src/themes/environment/storm-overflows/_data/storm_overflows.csv')
    print(pivotted);
    
    return pivotted


if __name__ == '__main__':
    storm_overflows()

