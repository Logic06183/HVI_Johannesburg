import ee
import geemap
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from datetime import datetime, timedelta
import os

def initialize_earth_engine():
    """Initialize Earth Engine with proper authentication"""
    try:
        # Try to initialize Earth Engine
        ee.Initialize()
        print("Earth Engine initialized successfully!")
    except Exception as e:
        print("Authentication required. Please follow these steps:")
        print("1. Go to https://code.earthengine.google.com/")
        print("2. Sign in with your Google account")
        print("3. Run 'earthengine authenticate' in your terminal")
        raise Exception("Earth Engine authentication required") from e

# Initialize Earth Engine
initialize_earth_engine()

# Define Johannesburg region
jhb_coords = [
    [27.85, -26.55],  # SW
    [28.15, -26.55],  # SE
    [28.15, -26.25],  # NE
    [27.85, -26.25],  # NW
    [27.85, -26.55]   # SW (close polygon)
]
johannesburg = ee.Geometry.Polygon([jhb_coords])

def create_output_dir():
    """Create output directory if it doesn't exist"""
    output_dir = os.path.join(os.path.dirname(__file__), 'earth_engine_outputs')
    os.makedirs(output_dir, exist_ok=True)
    return output_dir

def visualize_lst_modis():
    """Visualize MODIS Land Surface Temperature for Johannesburg"""
    try:
        print("Fetching MODIS LST data...")
        # Get MODIS LST data
        modis_lst = ee.ImageCollection("MODIS/006/MOD11A2") \
            .filterBounds(johannesburg) \
            .filterDate('2023-01-01', '2023-12-31')

        # Convert to Celsius and get mean
        lst_mean = modis_lst.select('LST_Day_1km') \
            .mean() \
            .multiply(0.02) \
            .subtract(273.15)

        # Create the map
        Map = geemap.Map(center=[-26.4, 28.0], zoom=10)
        
        # Add LST layer
        vis_params = {
            'min': 20,
            'max': 40,
            'palette': ['blue', 'yellow', 'red']
        }
        Map.addLayer(lst_mean, vis_params, 'Land Surface Temperature')
        
        # Add a colorbar
        Map.add_colorbar(vis_params, label='Land Surface Temperature (°C)')
        
        # Save the map
        output_dir = create_output_dir()
        output_file = os.path.join(output_dir, 'johannesburg_lst_modis.html')
        Map.save(output_file)
        print(f"LST map saved to {output_file}")
        
    except Exception as e:
        print(f"Error creating LST visualization: {str(e)}")

def visualize_urban_heat_island():
    """Visualize Urban Heat Island effect using YCEO dataset"""
    try:
        print("Fetching Urban Heat Island data...")
        # Get YCEO UHI data
        uhi = ee.ImageCollection("YALE/YCEO/UHI/UHI_all_averaged") \
            .filterBounds(johannesburg) \
            .first()

        # Create the map
        Map = geemap.Map(center=[-26.4, 28.0], zoom=10)
        
        # Add UHI layer
        vis_params = {
            'min': 0,
            'max': 5,
            'palette': ['blue', 'yellow', 'red']
        }
        Map.addLayer(uhi.select('UHI'), vis_params, 'Urban Heat Island')
        
        # Add a colorbar
        Map.add_colorbar(vis_params, label='Urban Heat Island Intensity (°C)')
        
        # Save the map
        output_dir = create_output_dir()
        output_file = os.path.join(output_dir, 'johannesburg_uhi.html')
        Map.save(output_file)
        print(f"UHI map saved to {output_file}")
        
    except Exception as e:
        print(f"Error creating UHI visualization: {str(e)}")

def visualize_population_density():
    """Visualize WorldPop population density"""
    try:
        print("Fetching WorldPop data...")
        # Get WorldPop data
        worldpop = ee.ImageCollection("WorldPop/GP/100m/pop") \
            .filterBounds(johannesburg) \
            .filterDate('2020-01-01', '2020-12-31') \
            .first()

        # Create the map
        Map = geemap.Map(center=[-26.4, 28.0], zoom=10)
        
        # Add population density layer
        vis_params = {
            'min': 0,
            'max': 1000,
            'palette': ['white', 'yellow', 'orange', 'red']
        }
        Map.addLayer(worldpop, vis_params, 'Population Density')
        
        # Add a colorbar
        Map.add_colorbar(vis_params, label='Population per 100m²')
        
        # Save the map
        output_dir = create_output_dir()
        output_file = os.path.join(output_dir, 'johannesburg_population.html')
        Map.save(output_file)
        print(f"Population density map saved to {output_file}")
        
    except Exception as e:
        print(f"Error creating population density visualization: {str(e)}")

def visualize_ndvi():
    """Visualize MODIS NDVI"""
    try:
        print("Fetching MODIS NDVI data...")
        # Get MODIS NDVI data
        modis_ndvi = ee.ImageCollection("MODIS/006/MOD13Q1") \
            .filterBounds(johannesburg) \
            .filterDate('2023-01-01', '2023-12-31')

        # Calculate mean NDVI
        ndvi_mean = modis_ndvi.select('NDVI').mean().multiply(0.0001)

        # Create the map
        Map = geemap.Map(center=[-26.4, 28.0], zoom=10)
        
        # Add NDVI layer
        vis_params = {
            'min': 0,
            'max': 1,
            'palette': ['brown', 'yellow', 'green']
        }
        Map.addLayer(ndvi_mean, vis_params, 'NDVI')
        
        # Add a colorbar
        Map.add_colorbar(vis_params, label='Normalized Difference Vegetation Index')
        
        # Save the map
        output_dir = create_output_dir()
        output_file = os.path.join(output_dir, 'johannesburg_ndvi.html')
        Map.save(output_file)
        print(f"NDVI map saved to {output_file}")
        
    except Exception as e:
        print(f"Error creating NDVI visualization: {str(e)}")

if __name__ == "__main__":
    try:
        # Create output directory
        output_dir = create_output_dir()
        print(f"Output directory created at: {output_dir}")
        
        print("\nCreating LST visualization...")
        visualize_lst_modis()
        
        print("\nCreating UHI visualization...")
        visualize_urban_heat_island()
        
        print("\nCreating population density visualization...")
        visualize_population_density()
        
        print("\nCreating NDVI visualization...")
        visualize_ndvi()
        
        print("\nAll visualizations have been created!")
        print(f"You can find all output files in: {output_dir}")
        
    except Exception as e:
        print(f"\nError during visualization process: {str(e)}")
        print("Please make sure you have authenticated with Earth Engine")
