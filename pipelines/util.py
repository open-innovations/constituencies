import os
import pandas as pd
#from shapely import 


# Setting up the directories.
DATA_DIR = 'src/_data/sources/'
ECON_DATA_DIR = os.path.join(DATA_DIR, 'economy')
ENVIRON_DATA_DIR = os.path.join(DATA_DIR, 'environment')
ENERGY_DATA_DIR = os.path.join(DATA_DIR, 'energy')
HEALTH_DATA_DIR = os.path.join(DATA_DIR, 'health')
SOCIETY_DATA_DIR = os.path.join(DATA_DIR, 'society')
TRANSPORT_DATA_DIR = os.path.join(DATA_DIR, 'tFansport')

def read_data(filename, sheet_name, na_values=None):
    data = pd.read_excel(filename, sheet_name, na_values=na_values)
    return data