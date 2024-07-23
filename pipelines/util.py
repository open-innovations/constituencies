import os
import pandas as pd
import numpy as np
#from shapely import 


# Setting up the directories.
DATA_DIR = 'src/_data/sources/'
ECON_DATA_DIR = 'src/themes/economy/_data/'
ENVIRON_DATA_DIR = os.path.join(DATA_DIR, 'environment')
ENERGY_DATA_DIR = os.path.join(DATA_DIR, 'energy')
HEALTH_DATA_DIR = os.path.join(DATA_DIR, 'health')
SOCIETY_DATA_DIR = os.path.join(DATA_DIR, 'society')
TRANSPORT_DATA_DIR = os.path.join(DATA_DIR, 'transport')

def read_data(filename, sheet_name, na_values=None, engine=None, skiprows=None):
    data = pd.read_excel(filename, sheet_name, na_values=na_values, engine=engine, skiprows=skiprows)
    return data