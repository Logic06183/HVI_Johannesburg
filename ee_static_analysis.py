import geopandas as gpd
import matplotlib.pyplot as plt
import contextily as ctx
import ee
import numpy as np
from matplotlib.colors import LinearSegmentedColormap
import os

# Initialize Earth Engine
try:
    ee.Initialize()
except Exception as e:
    print("Earth Engine initialization failed:", str(e))
    print("Continuing with local data only...")

# Read the Johannesburg shapefile
gdf = gpd.read_file('HVI_with_CVI.geojson')

def create_base_map(gdf, title):
    """Create a base map with consistent styling"""
    fig, ax = plt.subplots(figsize=(15, 15))
    gdf.to_crs(epsg=3857).plot(ax=ax, alpha=0.6)
    ctx.add_basemap(ax, source=ctx.providers.CartoDB.Positron)
    ax.set_title(title, fontsize=16, pad=20)
    ax.axis('off')
    return fig, ax

def get_ee_data(collection_name, start_date, end_date, band_name, scale_factor=1.0):
    """Get data from Earth Engine and convert to DataFrame"""
    try:
        # Get the collection
        collection = ee.ImageCollection(collection_name) \
            .filterDate(start_date, end_date) \
            .filterBounds(ee.Geometry.Rectangle([27.85, -26.55, 28.15, -26.25]))
        
        # Get the mean image
        mean_image = collection.select(band_name).mean()
        
        # Scale the values
        if scale_factor != 1.0:
            mean_image = mean_image.multiply(scale_factor)
        
        return mean_image
        
    except Exception as e:
        print(f"Error getting Earth Engine data: {str(e)}")
        return None

def create_visualizations():
    """Create all visualizations"""
    output_dir = "static_maps"
    os.makedirs(output_dir, exist_ok=True)
    
    # 1. LST Visualization
    print("Creating LST visualization...")
    try:
        lst_data = get_ee_data(
            "MODIS/006/MOD11A2",
            '2023-01-01',
            '2023-12-31',
            'LST_Day_1km',
            0.02
        )
        if lst_data is not None:
            # Create visualization
            fig, ax = create_base_map(gdf, 'Land Surface Temperature (2023)')
            gdf.plot(
                column='LST',
                cmap='RdYlBu_r',
                legend=True,
                ax=ax,
                legend_kwds={'label': 'Temperature (°C)'}
            )
            plt.savefig(os.path.join(output_dir, 'lst_map.png'), 
                       bbox_inches='tight', dpi=300)
            plt.close()
    except Exception as e:
        print(f"Error creating LST visualization: {str(e)}")

    # 2. NDVI Visualization
    print("Creating NDVI visualization...")
    try:
        ndvi_data = get_ee_data(
            "MODIS/006/MOD13Q1",
            '2023-01-01',
            '2023-12-31',
            'NDVI',
            0.0001
        )
        if ndvi_data is not None:
            fig, ax = create_base_map(gdf, 'Normalized Difference Vegetation Index (2023)')
            gdf.plot(
                column='NDVI',
                cmap='YlGn',
                legend=True,
                ax=ax,
                legend_kwds={'label': 'NDVI'}
            )
            plt.savefig(os.path.join(output_dir, 'ndvi_map.png'), 
                       bbox_inches='tight', dpi=300)
            plt.close()
    except Exception as e:
        print(f"Error creating NDVI visualization: {str(e)}")

    # 3. HVI Visualization
    print("Creating HVI visualization...")
    try:
        fig, ax = create_base_map(gdf, 'Health Vulnerability Index')
        gdf.plot(
            column='HVI',
            cmap='YlOrRd',
            legend=True,
            ax=ax,
            legend_kwds={'label': 'HVI Score'}
        )
        plt.savefig(os.path.join(output_dir, 'hvi_map.png'), 
                   bbox_inches='tight', dpi=300)
        plt.close()
    except Exception as e:
        print(f"Error creating HVI visualization: {str(e)}")

    # 4. CVI Visualization
    print("Creating CVI visualization...")
    try:
        fig, ax = create_base_map(gdf, 'Climate Vulnerability Index')
        gdf.plot(
            column='CVI',
            cmap='RdYlBu_r',
            legend=True,
            ax=ax,
            legend_kwds={'label': 'CVI Score'}
        )
        plt.savefig(os.path.join(output_dir, 'cvi_map.png'), 
                   bbox_inches='tight', dpi=300)
        plt.close()
    except Exception as e:
        print(f"Error creating CVI visualization: {str(e)}")

    # 5. Combined Visualization
    print("Creating combined visualization...")
    try:
        fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(20, 20))
        
        # HVI
        gdf.plot(
            column='HVI',
            cmap='YlOrRd',
            legend=True,
            ax=ax1,
            legend_kwds={'label': 'HVI Score'}
        )
        ctx.add_basemap(ax1, source=ctx.providers.CartoDB.Positron)
        ax1.set_title('Health Vulnerability Index')
        ax1.axis('off')
        
        # CVI
        gdf.plot(
            column='CVI',
            cmap='RdYlBu_r',
            legend=True,
            ax=ax2,
            legend_kwds={'label': 'CVI Score'}
        )
        ctx.add_basemap(ax2, source=ctx.providers.CartoDB.Positron)
        ax2.set_title('Climate Vulnerability Index')
        ax2.axis('off')
        
        # LST
        gdf.plot(
            column='LST',
            cmap='RdYlBu_r',
            legend=True,
            ax=ax3,
            legend_kwds={'label': 'Temperature (°C)'}
        )
        ctx.add_basemap(ax3, source=ctx.providers.CartoDB.Positron)
        ax3.set_title('Land Surface Temperature')
        ax3.axis('off')
        
        # NDVI
        gdf.plot(
            column='NDVI',
            cmap='YlGn',
            legend=True,
            ax=ax4,
            legend_kwds={'label': 'NDVI'}
        )
        ctx.add_basemap(ax4, source=ctx.providers.CartoDB.Positron)
        ax4.set_title('Normalized Difference Vegetation Index')
        ax4.axis('off')
        
        plt.tight_layout()
        plt.savefig(os.path.join(output_dir, 'combined_vulnerability_maps.png'), 
                   bbox_inches='tight', dpi=300)
        plt.close()
    except Exception as e:
        print(f"Error creating combined visualization: {str(e)}")

if __name__ == "__main__":
    create_visualizations()
    print("All visualizations have been created in the 'static_maps' directory!")
