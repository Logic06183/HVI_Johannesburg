import ee
import geemap
import geopandas as gpd
import matplotlib.pyplot as plt
import contextily as ctx
import os
import pandas as pd
import numpy as np
import rasterio
from rasterio.mask import mask

# Initialize Earth Engine
ee.Initialize()

def geometry_to_ee(geom):
    """Convert Shapely geometry to Earth Engine geometry"""
    if geom.geom_type == 'Polygon':
        coords = [[[x, y] for x, y in zip(*geom.exterior.coords.xy)]]
        return ee.Geometry.Polygon(coords)
    elif geom.geom_type == 'MultiPolygon':
        coords = []
        for poly in geom.geoms:
            coords.extend([[[x, y] for x, y in zip(*poly.exterior.coords.xy)]])
        return ee.Geometry.MultiPolygon(coords)
    else:
        raise ValueError(f"Unsupported geometry type: {geom.geom_type}")

def create_map(gdf, column, title, cmap, label, output_path):
    """Create and save a map visualization"""
    fig, ax = plt.subplots(figsize=(15, 15))
    gdf.plot(column=column, 
            cmap=cmap,
            legend=True,
            ax=ax,
            legend_kwds={'label': label})
    ctx.add_basemap(ax, source=ctx.providers.CartoDB.Positron)
    ax.set_title(title, fontsize=16)
    ax.axis('off')
    plt.savefig(output_path, bbox_inches='tight', dpi=300)
    plt.close()

def extract_raster_values(gdf, raster_path):
    """Extract mean values from a raster for each polygon in the GeoDataFrame"""
    with rasterio.open(raster_path) as src:
        means = []
        for geom in gdf.geometry:
            try:
                # Get pixel values within the geometry
                out_image, out_transform = mask(src, [geom.__geo_interface__], crop=True)
                # Calculate mean, excluding no data values
                data = out_image[0]
                if data.size > 0:
                    mean_val = np.mean(data[data > 0])  # Exclude zeros/no data
                else:
                    mean_val = np.nan
                means.append(mean_val)
            except Exception as e:
                print(f"Error extracting raster values: {str(e)}")
                means.append(np.nan)
        return means

def main():
    try:
        # Read the GeoJSON file
        print("Reading GeoJSON file...")
        gdf = gpd.read_file('HVI_with_CVI.geojson')
        gdf = gdf.to_crs(epsg=3857)  # Convert to Web Mercator for plotting
        
        # Create a feature collection from the GeoJSON
        print("Converting to Earth Engine features...")
        features = []
        gdf_geo = gdf.to_crs(epsg=4326)  # Convert to WGS84 for Earth Engine
        for idx, row in gdf_geo.iterrows():
            try:
                ee_geom = geometry_to_ee(row.geometry)
                feature = ee.Feature(ee_geom, {'id': str(idx)})
                features.append(feature)
            except Exception as e:
                print(f"Error converting geometry at index {idx}: {str(e)}")
        
        ee_fc = ee.FeatureCollection(features)
        
        # Create output directory
        output_dir = "ee_maps"
        os.makedirs(output_dir, exist_ok=True)

        # 1. MODIS LST
        print("Getting MODIS LST data...")
        modis = ee.ImageCollection("MODIS/061/MOD11A2") \
            .filterDate('2023-01-01', '2023-12-31') \
            .select('LST_Day_1km') \
            .mean() \
            .multiply(0.02) \
            .subtract(273.15)
        
        lst_data = modis.reduceRegions(
            collection=ee_fc,
            reducer=ee.Reducer.mean(),
            scale=1000
        ).getInfo()
        
        if lst_data:
            gdf['LST'] = pd.DataFrame(lst_data['features'])['properties'].apply(lambda x: x.get('mean'))
            create_map(gdf, 'LST', 'Land Surface Temperature (2023)',
                      'RdYlBu_r', 'Temperature (°C)',
                      os.path.join(output_dir, 'lst_map.png'))

        # 2. WorldPop from local TIF
        print("Processing WorldPop data...")
        worldpop_path = os.path.abspath(os.path.join('World_Pop', 'zaf_ppp_2020_UNadj_constrained.tif'))
        print(f"Looking for WorldPop TIF at: {worldpop_path}")
        if os.path.exists(worldpop_path):
            gdf['POPULATION'] = extract_raster_values(gdf_geo, worldpop_path)
            create_map(gdf, 'POPULATION', 'Population Density (2020)',
                      'YlOrRd', 'Population per 100m²',
                      os.path.join(output_dir, 'population_map.png'))
        else:
            print(f"WorldPop TIF file not found at: {worldpop_path}")

        # 3. MODIS NDVI
        print("Getting MODIS NDVI data...")
        ndvi = ee.ImageCollection("MODIS/061/MOD13Q1") \
            .filterDate('2023-01-01', '2023-12-31') \
            .select('NDVI') \
            .mean() \
            .multiply(0.0001)
        
        ndvi_data = ndvi.reduceRegions(
            collection=ee_fc,
            reducer=ee.Reducer.mean(),
            scale=250
        ).getInfo()
        
        if ndvi_data:
            gdf['NDVI'] = pd.DataFrame(ndvi_data['features'])['properties'].apply(lambda x: x.get('mean'))
            create_map(gdf, 'NDVI', 'Vegetation Index (2023)',
                      'YlGn', 'NDVI',
                      os.path.join(output_dir, 'ndvi_map.png'))

        # 4. Landsat Surface Temperature
        print("Getting Landsat temperature data...")
        landsat = ee.ImageCollection("LANDSAT/LC08/C02/T1_L2") \
            .filterDate('2023-01-01', '2023-12-31') \
            .filterBounds(ee_fc.geometry()) \
            .select('ST_B10') \
            .mean() \
            .multiply(0.00341802) \
            .add(149.0) \
            .subtract(273.15)
        
        landsat_data = landsat.reduceRegions(
            collection=ee_fc,
            reducer=ee.Reducer.mean(),
            scale=30
        ).getInfo()
        
        if landsat_data:
            gdf['LANDSAT_TEMP'] = pd.DataFrame(landsat_data['features'])['properties'].apply(lambda x: x.get('mean'))
            create_map(gdf, 'LANDSAT_TEMP', 'Landsat Surface Temperature (2023)',
                      'RdYlBu_r', 'Temperature (°C)',
                      os.path.join(output_dir, 'landsat_temp_map.png'))

        # Create combined visualization
        if all(col in gdf.columns for col in ['LST', 'NDVI', 'LANDSAT_TEMP', 'POPULATION']):
            print("Creating combined visualization...")
            fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(20, 20))
            
            # Plot each dataset
            gdf.plot(column='LST', cmap='RdYlBu_r', legend=True,
                    ax=ax1, legend_kwds={'label': 'Temperature (°C)'})
            ctx.add_basemap(ax1, source=ctx.providers.CartoDB.Positron)
            ax1.set_title('MODIS LST')
            ax1.axis('off')
            
            gdf.plot(column='LANDSAT_TEMP', cmap='RdYlBu_r', legend=True,
                    ax=ax2, legend_kwds={'label': 'Temperature (°C)'})
            ctx.add_basemap(ax2, source=ctx.providers.CartoDB.Positron)
            ax2.set_title('Landsat Temperature')
            ax2.axis('off')
            
            gdf.plot(column='NDVI', cmap='YlGn', legend=True,
                    ax=ax3, legend_kwds={'label': 'NDVI'})
            ctx.add_basemap(ax3, source=ctx.providers.CartoDB.Positron)
            ax3.set_title('Vegetation Index')
            ax3.axis('off')
            
            gdf.plot(column='POPULATION', cmap='YlOrRd', legend=True,
                    ax=ax4, legend_kwds={'label': 'Population per 100m²'})
            ctx.add_basemap(ax4, source=ctx.providers.CartoDB.Positron)
            ax4.set_title('Population Density')
            ax4.axis('off')
            
            plt.tight_layout()
            plt.savefig(os.path.join(output_dir, 'combined_analysis.png'),
                       bbox_inches='tight', dpi=300)
            plt.close()

        # Save the updated GeoJSON
        print("Saving updated GeoJSON...")
        gdf_save = gdf.copy()
        gdf_save = gdf_save.to_crs(epsg=4326)
        gdf_save.to_file(os.path.join(output_dir, 'johannesburg_ee_data.geojson'),
                         driver='GeoJSON')
        
        print("Analysis complete! Check the 'ee_maps' directory for results.")
        
    except Exception as e:
        print(f"Error in main execution: {str(e)}")

if __name__ == "__main__":
    main()
