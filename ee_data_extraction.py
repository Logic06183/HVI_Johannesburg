import ee
import geemap
import geopandas as gpd
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import contextily as ctx
from datetime import datetime, timedelta
import os

# Initialize Earth Engine
ee.Initialize()

# Read the Johannesburg shapefile for boundaries
gdf = gpd.read_file('HVI_with_CVI.geojson')
# Ensure the GeoDataFrame is in Web Mercator projection for basemap
gdf = gdf.to_crs(epsg=3857)

# Convert GeoDataFrame to Earth Engine FeatureCollection
def gdf_to_ee_fc(gdf):
    """Convert GeoDataFrame to Earth Engine FeatureCollection"""
    # Convert to geographic coordinates for Earth Engine
    gdf_geo = gdf.to_crs(epsg=4326)
    features = []
    for idx, row in gdf_geo.iterrows():
        geom = row.geometry
        if geom.type == 'Polygon':
            coords = [[[x, y] for x, y in zip(*geom.exterior.coords.xy)]]
        elif geom.type == 'MultiPolygon':
            coords = [[[x, y] for x, y in zip(*poly.exterior.coords.xy)] 
                     for poly in geom.geoms]
        
        feature = ee.Feature(
            ee.Geometry.Polygon(coords),
            {'id': str(idx)}
        )
        features.append(feature)
    
    return ee.FeatureCollection(features)

# Convert to Earth Engine FeatureCollection
ee_fc = gdf_to_ee_fc(gdf)

def extract_ee_data(image, ee_fc, scale=1000):
    """Extract data from Earth Engine image for each polygon"""
    try:
        # Reduce regions
        data = image.reduceRegions(
            collection=ee_fc,
            reducer=ee.Reducer.mean(),
            scale=scale
        )
        # Convert to dictionary
        return data.getInfo()
    except Exception as e:
        print(f"Error extracting data: {str(e)}")
        return None

def create_map(gdf, data_column, title, cmap, legend_label, output_path):
    """Create and save a map visualization"""
    try:
        fig, ax = plt.subplots(figsize=(15, 15))
        
        # Plot the data
        gdf.plot(column=data_column, 
                cmap=cmap,
                legend=True,
                ax=ax,
                legend_kwds={'label': legend_label})
        
        # Add basemap
        ctx.add_basemap(ax, source=ctx.providers.CartoDB.Positron)
        
        # Customize the plot
        ax.set_title(title, fontsize=16, pad=20)
        ax.axis('off')
        
        # Save the plot
        plt.savefig(output_path, bbox_inches='tight', dpi=300)
        plt.close()
    except Exception as e:
        print(f"Error creating map for {title}: {str(e)}")

def main():
    try:
        # Create output directory
        output_dir = "ee_extracted_maps"
        os.makedirs(output_dir, exist_ok=True)
        
        # 1. ERA5-Land Temperature
        print("Processing ERA5-Land temperature data...")
        era5_land = ee.ImageCollection("ECMWF/ERA5_LAND/HOURLY") \
            .filterDate('2023-01-01', '2023-12-31') \
            .select('temperature_2m') \
            .mean() \
            .subtract(273.15)  # Convert to Celsius
        
        era5_data = extract_ee_data(era5_land, ee_fc)
        if era5_data:
            gdf['ERA5_TEMP'] = pd.DataFrame(era5_data['features'])['properties'].apply(lambda x: x.get('mean'))
            create_map(gdf, 'ERA5_TEMP', 
                      'ERA5-Land Temperature (2023)',
                      'RdYlBu_r',
                      'Temperature (°C)',
                      os.path.join(output_dir, 'era5_temperature.png'))

        # 2. Latest MODIS LST
        print("Processing MODIS LST data...")
        modis_lst = ee.ImageCollection("MODIS/061/MOD11A2") \
            .filterDate('2023-01-01', '2023-12-31') \
            .select('LST_Day_1km') \
            .mean() \
            .multiply(0.02) \
            .subtract(273.15)
        
        lst_data = extract_ee_data(modis_lst, ee_fc)
        if lst_data:
            gdf['MODIS_LST'] = pd.DataFrame(lst_data['features'])['properties'].apply(lambda x: x.get('mean'))
            create_map(gdf, 'MODIS_LST',
                      'MODIS Land Surface Temperature (2023)',
                      'RdYlBu_r',
                      'Temperature (°C)',
                      os.path.join(output_dir, 'modis_lst.png'))

        # 3. Latest MODIS NDVI
        print("Processing MODIS NDVI data...")
        modis_ndvi = ee.ImageCollection("MODIS/061/MOD13Q1") \
            .filterDate('2023-01-01', '2023-12-31') \
            .select('NDVI') \
            .mean() \
            .multiply(0.0001)
        
        ndvi_data = extract_ee_data(modis_ndvi, ee_fc)
        if ndvi_data:
            gdf['MODIS_NDVI'] = pd.DataFrame(ndvi_data['features'])['properties'].apply(lambda x: x.get('mean'))
            create_map(gdf, 'MODIS_NDVI',
                      'MODIS NDVI (2023)',
                      'YlGn',
                      'NDVI',
                      os.path.join(output_dir, 'modis_ndvi.png'))

        # 4. WorldPop Population Density
        print("Processing WorldPop data...")
        worldpop = ee.ImageCollection("WorldPop/GP/100m/pop") \
            .filterDate('2020-01-01', '2020-12-31') \
            .first()
        
        pop_data = extract_ee_data(worldpop, ee_fc)
        if pop_data:
            gdf['POPULATION'] = pd.DataFrame(pop_data['features'])['properties'].apply(lambda x: x.get('mean'))
            create_map(gdf, 'POPULATION',
                      'Population Density (2020)',
                      'YlOrRd',
                      'Population per 100m²',
                      os.path.join(output_dir, 'population.png'))

        # 5. Urban Heat Island
        print("Processing Urban Heat Island data...")
        uhi = ee.ImageCollection("YALE/YCEO/UHI/UHI_all_averaged") \
            .filterBounds(ee_fc.geometry()) \
            .first() \
            .select('UHI')
        
        uhi_data = extract_ee_data(uhi, ee_fc)
        if uhi_data:
            gdf['UHI'] = pd.DataFrame(uhi_data['features'])['properties'].apply(lambda x: x.get('mean'))
            create_map(gdf, 'UHI',
                      'Urban Heat Island Intensity',
                      'RdYlBu_r',
                      'Temperature Difference (°C)',
                      os.path.join(output_dir, 'uhi.png'))

        # Save the updated GeoJSON with new data
        # Convert back to geographic coordinates for saving
        gdf_save = gdf.copy()
        gdf_save = gdf_save.to_crs(epsg=4326)
        gdf_save.to_file(os.path.join(output_dir, 'johannesburg_with_ee_data.geojson'), driver='GeoJSON')
        
        # Create combined visualization
        print("Creating combined visualization...")
        fig, axes = plt.subplots(3, 2, figsize=(20, 30))
        axes = axes.flatten()
        
        # Plot each dataset
        datasets = [
            ('ERA5_TEMP', 'ERA5-Land Temperature', 'RdYlBu_r', 'Temperature (°C)'),
            ('MODIS_LST', 'MODIS LST', 'RdYlBu_r', 'Temperature (°C)'),
            ('MODIS_NDVI', 'MODIS NDVI', 'YlGn', 'NDVI'),
            ('POPULATION', 'Population Density', 'YlOrRd', 'Population per 100m²'),
            ('UHI', 'Urban Heat Island', 'RdYlBu_r', 'Temperature Difference (°C)')
        ]
        
        for idx, (col, title, cmap, label) in enumerate(datasets):
            if col in gdf.columns:
                gdf.plot(column=col,
                        cmap=cmap,
                        legend=True,
                        ax=axes[idx],
                        legend_kwds={'label': label})
                ctx.add_basemap(axes[idx], source=ctx.providers.CartoDB.Positron)
                axes[idx].set_title(title)
                axes[idx].axis('off')
        
        # Remove the last empty subplot
        fig.delaxes(axes[5])
        
        plt.tight_layout()
        plt.savefig(os.path.join(output_dir, 'combined_ee_analysis.png'), 
                    bbox_inches='tight', dpi=300)
        plt.close()

    except Exception as e:
        print(f"Error in main execution: {str(e)}")

if __name__ == "__main__":
    main()
    print("All Earth Engine data has been extracted and visualized!")
