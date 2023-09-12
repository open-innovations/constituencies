from pipelines.util import *

if __name__ == '__main__':
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
    
    charging_device_stats = charging_device_stats.loc[:, ['Local Authority / Region Code', 'Apr-23 (Total Charging Devices)']].rename(columns={'Local Authority / Region Code': 'LA23CD', 'Apr-23 (Total Charging Devices)': 'public-2023-04'})
    charging_grant_stats_workplace = charging_grant_stats_workplace.loc[:, ['ONS LA Code', 'Sockets Installed']].rename(columns={'ONS LA Code': 'LA23CD', 'Sockets Installed': 'workplace-2023-04'})
    charging_grant_stats_home = charging_grant_stats_home.loc[:,['ONS LA Code', '2022']].rename(columns={'ONS LA Code': 'LA23CD', '2022': 'home-2022'})

    merged_df = charging_grant_stats_workplace.merge(charging_grant_stats_home.merge(charging_device_stats, on='LA23CD'), on='LA23CD')
    merged_df.replace('x', 'NaN', inplace=True)
    merged_df['public-2023-04'] = merged_df['public-2023-04'].astype(float)
    merged_df['total'] = merged_df[['workplace-2023-04', 'home-2022', 'public-2023-04']].sum(axis=1)


    lookup = pd.read_csv('lookups/lookup-PCON22CD-LAD23CD.csv')
    merged_df = merged_df.merge(lookup, on='LA23CD')
    merged_df.set_index('LA23CD', inplace=True)
    merged_df.to_csv(os.path.join(TRANSPORT_DATA_DIR, 'ev_charging_points.csv'))
    
    