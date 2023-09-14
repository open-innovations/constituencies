import json
import numpy as np
from pipelines.util import *

def merge_charging_stats():
    charging_device_stats = read_data("raw-data/electric-vehicle-charging-statistics-july-2023.ods",
                                      sheet_name='1a',
                                      engine='odf',
                                      skiprows=2)
    charging_device_stats = charging_device_stats[charging_device_stats['Local Authority / Region Code'].str.match('^(E06|E07|E08|E09|S12|W06|N09)([0-9]{6})')]
    charging_device_stats = charging_device_stats[charging_device_stats.columns[charging_device_stats.columns.str.contains('Total Charging Devices|Local Authority / Region Code')]]

    charging_grant_stats_workplace = read_data('raw-data/electric-vehicle-charging-device-grant-scheme-statistics.ods',
                                               sheet_name='3',
                                               engine='odf',
                                               skiprows=2)
    
    charging_grant_stats_home = read_data('raw-data/electric-vehicle-charging-device-grant-scheme-statistics.ods',
                                               sheet_name='10',
                                               engine='odf',
                                               skiprows=2)
    
    charging_grant_stats_workplace = charging_grant_stats_workplace[charging_grant_stats_workplace['ONS LA Code'].str.match('^(E06|E07|E08|E09|S12|W06|N09)([0-9]{6})')]
    charging_grant_stats_home = charging_grant_stats_home[charging_grant_stats_home['ONS LA Code'].str.match('^(E06|E07|E08|E09|S12|W06|N09)([0-9]{6})')]
    
    charging_device_stats = charging_device_stats.loc[:, ['Local Authority / Region Code', 'Apr-23 (Total Charging Devices)']].rename(columns={'Local Authority / Region Code': 'LA22CD', 'Apr-23 (Total Charging Devices)': 'public-2023-04'})
    charging_grant_stats_workplace = charging_grant_stats_workplace.loc[:, ['ONS LA Code', 'Sockets Installed']].rename(columns={'ONS LA Code': 'LA22CD', 'Sockets Installed': 'workplace-2023-04'})
    charging_grant_stats_home = charging_grant_stats_home.loc[:,['ONS LA Code', '2022']].rename(columns={'ONS LA Code': 'LA22CD', '2022': 'home-2022'})

    merged_df = charging_grant_stats_workplace.merge(charging_grant_stats_home.merge(charging_device_stats, on='LA22CD'), on='LA22CD')
    merged_df.replace('x', 'NaN', inplace=True)
    merged_df['public-2023-04'] = merged_df['public-2023-04'].astype(float)
    merged_df['total'] = merged_df[['workplace-2023-04', 'home-2022', 'public-2023-04']].sum(axis=1)

    return merged_df

def local_authority_to_constituency(data, floor=True):
    # load the lookup table
    with open('lookups/lookup-LAD22CD-PCON22CD.json') as f:
        lookup = json.load(f)

    # create an empty dataframe to put the data into
    df = pd.DataFrame(columns=['PCON22CD', 'workplace-2023-04', 'home-2022', 'public-2023-04', 'total'])
    df.set_index('PCON22CD', inplace=True)

    # iterate through each column of the LA_Code dataframe
    for la, c in lookup.items():
        # get a key and value pair for each constituency and its overlap
        for constituency_code, overlap in c.items():
            # if constituency doesnt exist, loop over columns and set all to 0.
            if constituency_code not in df.index.to_list():
                for cname in df.columns.to_list():
                    df.loc[constituency_code, cname] = 0.0
            for col in df.columns.to_list():
                try:
                    # calculate the share of charging devices in each constituency
                    share = data.loc[data.LA22CD==la, col].values[0]*overlap
                    df.loc[constituency_code, col] += share
                except:
                    print('failed')
        
    if floor==True:
        df = df.apply(np.floor)

    return df                    
    
if __name__ == '__main__':
    
    merged_df = merge_charging_stats()
    data = local_authority_to_constituency(merged_df)
    data.to_csv(os.path.join(TRANSPORT_DATA_DIR, 'ev_charging_points.csv'))
    
    