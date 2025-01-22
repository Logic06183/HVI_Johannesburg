import geopandas as gpd
import folium
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np
import contextily as ctx
from matplotlib.patches import Patch
from matplotlib.colors import LinearSegmentedColormap

# Set basic style
plt.rcParams['figure.facecolor'] = 'white'
plt.rcParams['axes.facecolor'] = 'white'
sns.set_style("white")

# Read the GeoJSON file
gdf = gpd.read_file('HVI_with_CVI.geojson')

# Custom color maps
hvi_colors = ['#440154', '#414487', '#2a788e', '#22a884', '#7ad151', '#fde725']
lst_colors = ['#313695', '#74add1', '#fed976', '#feb24c', '#fd8d3c', '#f03b20']
ndvi_colors = ['#ffffe5', '#f7fcb9', '#d9f0a3', '#addd8e', '#41ab5d', '#005a32']
cvi_colors = ['#2166ac', '#67a9cf', '#f7f7f7', '#fddbc7', '#ef8a62', '#b2182b']

# Create custom colormaps
hvi_cmap = LinearSegmentedColormap.from_list('custom_hvi', hvi_colors)
lst_cmap = LinearSegmentedColormap.from_list('custom_lst', lst_colors)
ndvi_cmap = LinearSegmentedColormap.from_list('custom_ndvi', ndvi_colors)
cvi_cmap = LinearSegmentedColormap.from_list('custom_cvi', cvi_colors)

def add_basemap(ax):
    """Add a light basemap to provide geographic context"""
    ax.set_facecolor('#F0F0F0')  # Light gray background
    ctx.add_basemap(ax, source=ctx.providers.CartoDB.Positron, alpha=0.3)

def create_static_maps():
    # Set up the figure with multiple subplots
    fig, axes = plt.subplots(2, 2, figsize=(20, 20))
    fig.patch.set_facecolor('white')
    
    # Add title with styling
    fig.suptitle('Heat Vulnerability Analysis - Johannesburg\nSpatial Distribution of Key Indicators', 
                fontsize=20, fontweight='bold', y=0.95)

    # HVI Map
    gdf.plot(column='HVI_weighted_standardized', cmap=hvi_cmap, legend=True,
             legend_kwds={'label': 'Heat Vulnerability Index',
                         'orientation': 'horizontal',
                         'shrink': 0.8,
                         'aspect': 40,
                         'pad': 0.01},
             ax=axes[0, 0])
    axes[0, 0].set_title('Heat Vulnerability Index', pad=20, fontsize=14, fontweight='bold')
    add_basemap(axes[0, 0])
    axes[0, 0].axis('off')

    # LST Map
    gdf.plot(column='LST', cmap=lst_cmap, legend=True,
             legend_kwds={'label': 'Land Surface Temperature (°C)',
                         'orientation': 'horizontal',
                         'shrink': 0.8,
                         'aspect': 40,
                         'pad': 0.01},
             ax=axes[0, 1])
    axes[0, 1].set_title('Land Surface Temperature', pad=20, fontsize=14, fontweight='bold')
    add_basemap(axes[0, 1])
    axes[0, 1].axis('off')

    # NDVI Map
    gdf.plot(column='NDVI', cmap=ndvi_cmap, legend=True,
             legend_kwds={'label': 'Vegetation Index',
                         'orientation': 'horizontal',
                         'shrink': 0.8,
                         'aspect': 40,
                         'pad': 0.01},
             ax=axes[1, 0])
    axes[1, 0].set_title('Normalized Difference Vegetation Index', pad=20, fontsize=14, fontweight='bold')
    add_basemap(axes[1, 0])
    axes[1, 0].axis('off')

    # CVI Map
    gdf.plot(column='CVI_standardized', cmap=cvi_cmap, legend=True,
             legend_kwds={'label': 'Climate Vulnerability Index',
                         'orientation': 'horizontal',
                         'shrink': 0.8,
                         'aspect': 40,
                         'pad': 0.01},
             ax=axes[1, 1])
    axes[1, 1].set_title('Climate Vulnerability Index', pad=20, fontsize=14, fontweight='bold')
    add_basemap(axes[1, 1])
    axes[1, 1].axis('off')

    # Add explanatory text
    fig.text(0.02, 0.02, 
             'Data sources: Health Vulnerability Index (HVI) combines socio-economic and environmental factors\n' +
             'LST derived from satellite data, NDVI indicates vegetation density, CVI represents climate vulnerability',
             fontsize=10, ha='left')

    # Adjust layout
    plt.tight_layout(rect=[0, 0.03, 1, 0.95])
    
    # Save with high quality
    plt.savefig('johannesburg_vulnerability_maps.png', 
                dpi=300, bbox_inches='tight', 
                facecolor='white', edgecolor='none')
    plt.close()

def create_interactive_map():
    # Convert to WGS84 for folium
    gdf_wgs84 = gdf.to_crs(epsg=4326)

    # Create a folium map centered on Johannesburg
    m = folium.Map(location=[-26.2041, 28.0473], 
                  zoom_start=10,
                  tiles='cartodbpositron')

    # Create choropleth layer with improved styling
    folium.Choropleth(
        geo_data=gdf_wgs84,
        name='Heat Vulnerability Index',
        data=gdf_wgs84,
        columns=['WardID_', 'HVI_weighted_standardized'],
        key_on='feature.properties.WardID_',
        fill_color='YlOrRd',
        fill_opacity=0.7,
        line_opacity=0.2,
        legend_name='Heat Vulnerability Index',
        smooth_factor=0.5,
        highlight=True
    ).add_to(m)

    # Add hover functionality with improved styling
    style_function = lambda x: {
        'fillColor': '#ffffff',
        'color': '#000000',
        'fillOpacity': 0.1,
        'weight': 0.5
    }
    
    highlight_function = lambda x: {
        'fillColor': '#000000',
        'color': '#000000',
        'fillOpacity': 0.5,
        'weight': 1
    }

    # Add tooltips with improved formatting
    tooltip = folium.features.GeoJsonTooltip(
        fields=['WardID_', 
                'HVI_weighted_standardized', 
                'LST', 
                'NDVI', 
                'CVI_standardized'],
        aliases=['Ward ID:', 
                'Heat Vulnerability Index:', 
                'Land Surface Temperature (°C):', 
                'Vegetation Index:', 
                'Climate Vulnerability:'],
        style=('background-color: white; '
               'color: #333333; '
               'font-family: arial; '
               'font-size: 12px; '
               'padding: 10px; '
               'border-radius: 3px; '
               'box-shadow: 3px 3px 10px rgba(0,0,0,0.2);')
    )

    # Add GeoJson layer with tooltips
    folium.GeoJson(
        gdf_wgs84,
        style_function=style_function,
        highlight_function=highlight_function,
        tooltip=tooltip
    ).add_to(m)

    # Add title
    title_html = '''
        <div style="position: fixed; 
                    top: 10px; 
                    left: 50px; 
                    width: 300px; 
                    height: 90px; 
                    z-index:9999; 
                    background-color: white;
                    padding: 10px;
                    border-radius: 5px;
                    box-shadow: 3px 3px 10px rgba(0,0,0,0.2);">
            <h4 style="margin-bottom: 0;">Johannesburg Heat Vulnerability</h4>
            <p style="margin-top: 5px; font-size: 12px;">
                Click on wards to see detailed information.<br>
                Darker colors indicate higher vulnerability.
            </p>
        </div>
    '''
    m.get_root().html.add_child(folium.Element(title_html))

    # Add Layer Control
    folium.LayerControl().add_to(m)

    # Save the map
    m.save('johannesburg_interactive_map.html')

def create_statistical_plots():
    # Set up the figure with improved styling
    fig = plt.figure(figsize=(20, 15))
    fig.patch.set_facecolor('white')
    
    # Create grid for subplots
    gs = fig.add_gridspec(2, 2, hspace=0.3, wspace=0.3)
    
    # Add title
    fig.suptitle('Statistical Analysis of Heat Vulnerability in Johannesburg',
                 fontsize=20, fontweight='bold', y=0.95)

    # Histogram of HVI with KDE
    ax1 = fig.add_subplot(gs[0, 0])
    sns.histplot(data=gdf, x='HVI_weighted_standardized', 
                kde=True, color='#440154', 
                line_kws={'color': '#22a884'}, 
                ax=ax1)
    ax1.set_title('Distribution of Heat Vulnerability Index', 
                  fontsize=14, pad=20)
    ax1.set_xlabel('Heat Vulnerability Index')
    ax1.set_ylabel('Frequency')

    # Enhanced scatterplot of LST vs NDVI
    ax2 = fig.add_subplot(gs[0, 1])
    scatter = ax2.scatter(gdf['LST'], gdf['NDVI'], 
                         c=gdf['HVI_weighted_standardized'],
                         cmap='viridis', alpha=0.6)
    plt.colorbar(scatter, ax=ax2, label='Heat Vulnerability Index')
    ax2.set_title('Relationship: LST vs NDVI\nColored by HVI', 
                  fontsize=14, pad=20)
    ax2.set_xlabel('Land Surface Temperature (°C)')
    ax2.set_ylabel('Vegetation Index')

    # Enhanced boxplot
    ax3 = fig.add_subplot(gs[1, 0])
    if 'LISA_Type' in gdf.columns:
        sns.boxplot(data=gdf, x='LISA_Type', y='HVI_weighted_standardized',
                   palette='RdYlBu_r', ax=ax3)
        ax3.set_title('HVI Distribution by LISA Type',
                      fontsize=14, pad=20)
        ax3.set_xticklabels(ax3.get_xticklabels(), rotation=45)
        ax3.set_xlabel('LISA Classification')
        ax3.set_ylabel('Heat Vulnerability Index')

    # Enhanced correlation heatmap
    ax4 = fig.add_subplot(gs[1, 1])
    vars_to_correlate = ['HVI_weighted_standardized', 'LST', 'NDVI', 'CVI_standardized']
    corr_matrix = gdf[vars_to_correlate].corr()
    
    # Create correlation heatmap with improved styling
    sns.heatmap(corr_matrix, 
                annot=True, 
                cmap='RdBu_r',
                center=0,
                vmin=-1, vmax=1,
                square=True,
                fmt='.2f',
                cbar_kws={'label': 'Correlation Coefficient'},
                ax=ax4)
    ax4.set_title('Correlation Matrix of Key Variables',
                  fontsize=14, pad=20)
    
    # Rotate x-axis labels for better readability
    ax4.set_xticklabels(ax4.get_xticklabels(), rotation=45, ha='right')
    ax4.set_yticklabels(ax4.get_yticklabels(), rotation=0)

    # Add explanatory text
    fig.text(0.02, 0.02,
             'Notes:\n' +
             '• LISA Types indicate spatial clustering patterns\n' +
             '• Correlation values range from -1 (negative) to 1 (positive)\n' +
             '• LST and NDVI are key environmental indicators',
             fontsize=10, ha='left')

    # Save with high quality
    plt.savefig('johannesburg_statistical_analysis.png',
                dpi=300, bbox_inches='tight',
                facecolor='white', edgecolor='none')
    plt.close()

if __name__ == "__main__":
    print("Creating enhanced static maps...")
    create_static_maps()
    
    print("Creating enhanced interactive map...")
    create_interactive_map()
    
    print("Creating enhanced statistical plots...")
    create_statistical_plots()
    
    print("All enhanced visualizations have been created!")
