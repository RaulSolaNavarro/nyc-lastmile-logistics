# NYC Last-Mile Logistics Gap Analysis

A geospatial analysis identifying which NYC neighborhoods lack adequate
warehouse coverage, and how many residents live in those gaps.

**Live report:** https://raulsolanavarro.github.io/nyc-lastmile-logistics/report/

---

## Overview

Last-mile delivery is the most expensive segment of any urban supply chain.
This project combines 2020 Census population data with NYC's PLUTO property
database to map industrial and warehouse facilities across the five boroughs,
then applies a 1-mile service radius to identify underserved census tracts.

**Key finding:** 31 census tracts containing 61,426 residents (0.7% of NYC's population) 
fall outside a 1-mile radius of any industrial or warehouse facility. Manhattan 
accounts for the largest share, with 111,489  residents far from classified industrial 
land concentrated above 96th Street and in Washington Heights.

---

## Repository Structure

```
nyc-lastmile-logistics/
├── setup.R                       # Install packages and create folder structure
├── analysis/
│   ├── 01_data_pull.R            # Pull all data from public APIs
│   ├── 02_spatial_analysis.R     # Buffer analysis and gap identification
│   └── 03_maps.R                 # Export final map PNGs
├── data/
│   ├── raw/                      # Reserved for manual downloads (unused)
│   └── processed/                # Spatial objects saved as .rds files
├── output/
│   ├── maps/                     # Exported map PNGs (300 DPI)
│   └/tables/                    # Borough summary CSV
├── report/
│   └── index.qmd                 # Quarto report source
├── docs/                         # Rendered GitHub Pages site
└── _quarto.yml                   # Quarto project configuration
```

---

## Data Sources

| Dataset | Source | Year | Method |
|---|---|---|---|
| Census tract boundaries + population | U.S. Census Bureau | 2020 | `tidycensus` |
| Borough boundaries | U.S. Census Bureau (TIGER/Line) | 2024 | `tigris` |
| Industrial/warehouse tax lots | NYC PLUTO via NYC Open Data | Current | Socrata JSON API |

All data is pulled programmatically at runtime. No manual downloads required.

---

## Reproducing the Analysis

**Prerequisites**

- R 4.x
- A free Census API key from [api.census.gov/data/key_signup.html](https://api.census.gov/data/key_signup.html)

**Steps**

```r
# 1. Install packages and create folder structure
source("setup.R")

# 2. Register your Census API key (run once in the console)
tidycensus::census_api_key("YOUR_KEY_HERE", install = TRUE)

# 3. Restart R, then pull all data
source("analysis/01_data_pull.R")

# 4. Run the spatial analysis
source("analysis/02_spatial_analysis.R")

# 5. Export maps
source("analysis/03_maps.R")

# 6. Render the report
quarto::quarto_render("report/index.qmd")
```

---

## Methodology

1. **Data acquisition** — Census tract population and geometry via
   `tidycensus`, borough boundaries via `tigris`, industrial lot locations
   via the NYC PLUTO Socrata API.

2. **Projection** — All layers transformed to EPSG:2263 (NY State Plane,
   feet) for accurate distance measurement.

3. **Buffer analysis** — Each industrial lot centroid buffered by 5,280 feet
   (1 mile), then dissolved into a single merged coverage polygon via
   `st_union()`.

4. **Gap identification** — Census tracts tested for intersection with the
   coverage polygon via `st_intersects()`. Non-intersecting tracts classified
   as underserved.

---

## Tools

- **R** — data wrangling, spatial analysis, map production
- **QGIS 3.44 LTR** — spatial data exploration, layer styling, and cartographic
  map export. The QGIS project file (`qgis/nyc_lastmile.qgz`) loads all four
  analysis layers (borough boundaries, census tracts, warehouse buffer, warehouse
  points) styled to match the R analysis. A map export is available at
  `output/maps/qgis_map_export.png`.
- **Quarto** — report authoring and GitHub Pages deployment
- **tidycensus / tigris** — Census data access
- **sf** — spatial data manipulation
- **ggplot2** — map and chart rendering

---

## Author

**Raul Sola Navarro**  
MS Business Analytics, Baruch College — Zicklin School of Business  
[github.com/RaulSolaNavarro](https://github.com/RaulSolaNavarro)

---

## AI Usage Disclosure

This project was developed with assistance from Claude (Anthropic) as a
collaborative coding and methodology tool. Claude helped structure the R
scripts, debug API connectivity issues during data acquisition, and draft
report prose. All analytical decisions were made and reviewed by the author.
All code was tested and executed locally prior to publication.
