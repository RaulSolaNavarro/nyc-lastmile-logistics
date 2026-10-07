# =============================================================================
# analysis/01_data_pull.R
# Project: NYC Last-Mile Logistics Gap Analysis
# Author:  Raúl J. Solá Navarro
# Purpose: Pull all spatial data from external APIs and save processed
#          objects locally as .rds files for use in downstream scripts.
#
# Data sources:
#   - U.S. Census Bureau (via tidycensus + tigris): tract population,
#     borough boundaries
#   - OpenStreetMap Overpass API (via osmdata): warehouse building locations
#
# Inputs:  None (all data pulled live from APIs)
# Outputs: data/processed/nyc_tracts.rds
#          data/processed/boroughs.rds
#          data/processed/warehouses.rds
#
# Prerequisites:
#   - Run setup.R first
#   - Census API key must be installed via census_api_key("KEY", install=TRUE)
# =============================================================================


# ── Load libraries ────────────────────────────────────────────────────────────
# These must be installed before loading. Run setup.R if any are missing.

library(tidycensus)  # Census API client
library(tigris)      # TIGER/Line boundary downloader
library(httr2)       # HTTP request handling for Socrata API calls
library(jsonlite)
library(sf)          # Spatial data manipulation
library(dplyr)       # Data wrangling
library(here)        # Reproducible file paths relative to project root


# ── Global settings ───────────────────────────────────────────────────────────

# Cache tigris downloads locally so repeated runs don't re-download the same
# boundary files. Cached files are stored in a temp directory managed by tigris.
options(tigris_use_cache = TRUE)
options(download.file.method = "wininet")  # Required on Windows to avoid SSL errors

# EPSG:2263 is the New York State Plane (Long Island) coordinate reference
# system, measured in feet. We use this throughout because:
#   1. It's optimized for accuracy in New York State
#   2. Distance calculations (e.g., 5-mile buffers) work correctly in feet
#   3. It's the standard CRS used by NYC government GIS data
# All layers will be transformed to this CRS before saving.
TARGET_CRS <- 2263

# NYC is spread across 5 counties (boroughs). We define them here so the
# same list can be reused in both the Census tract and borough pulls.
# Note: Census uses county names, not borough names.
#   New York  = Manhattan
#   Kings     = Brooklyn
#   Queens    = Queens
#   Bronx     = The Bronx
#   Richmond  = Staten Island
NYC_COUNTIES <- c("New York", "Kings", "Queens", "Bronx", "Richmond")


# ── Section 1: NYC Census Tracts with Population ──────────────────────────────
# Census tracts are small statistical subdivisions of a county, typically
# containing 1,200–8,000 people. They are the finest geographic unit at which
# population data is publicly available, making them ideal for identifying
# dense but underserved areas.
#
# We use the 2020 Decennial Census (not the ACS) because:
#   - It's a full count, not a sample estimate, so there's no margin of error
#   - Variable P1_001N = total population count for every person enumerated
#   - The 2020 Census is the most recent full count available

message("Pulling NYC census tract population data from Census Bureau API...")

nyc_tracts <- get_decennial(
  geography = "tract",         # Unit of analysis: census tracts
  variables = "P1_001N",       # Variable: total population (2020 Decennial)
  state     = "NY",            # Limit to New York State
  county    = NYC_COUNTIES,    # Limit to the 5 NYC counties defined above
  geometry  = TRUE,            # Return sf object with tract geometries attached
  year      = 2020             # 2020 Decennial Census
) |>
  # Rename the generic "value" column to something descriptive
  rename(population = value) |>

  # Transform to NYC State Plane CRS for accurate distance measurements.
  # The Census API returns data in WGS84 (EPSG:4326, lat/lon degrees),
  # which is not suitable for distance-based spatial operations.
  st_transform(TARGET_CRS)

message("Census tracts pulled: ", nrow(nyc_tracts), " tracts across 5 boroughs.")

# Save as .rds (R's native binary format). Faster to read than shapefiles
# and preserves all R object attributes including the sf class.
saveRDS(nyc_tracts, here("data/processed/nyc_tracts.rds"))
message("Saved: data/processed/nyc_tracts.rds")

# ── Pull median household income by tract (ACS 2020 5-year) ──────────────────
# Variable B19013_001 = median household income in the past 12 months.
# We pull without geometry to keep this lightweight — geometry comes from
# nyc_tracts pulled above.

message("Pulling ACS median household income...")

nyc_income <- get_acs(
  geography = "tract",
  variables = "B19013_001",
  state     = "NY",
  county    = c("New York", "Kings", "Queens", "Bronx", "Richmond"),
  year      = 2020,
  geometry  = FALSE
) |>
  select(GEOID, median_income = estimate)

saveRDS(nyc_income, here("data/processed/nyc_income.rds"))
message("Saved: data/processed/nyc_income.rds (", nrow(nyc_income), " tracts)")

# ── Section 2: NYC Borough Boundaries ─────────────────────────────────────────
# Borough boundaries are used as the base layer for all maps — they give the
# reader geographic orientation (coastline, shape of NYC) and allow us to
# summarize results by borough in the analysis step.
#
# We use the Census Bureau's county boundaries (cb = TRUE for cartographic
# boundaries, which are clipped to the shoreline and look cleaner on maps
# than the full legal boundaries that extend into the water).

message("Pulling NYC borough (county) boundaries from Census TIGER/Line...")

boroughs <- counties(
  state = "NY",   # Limit to New York State
  cb    = TRUE    # Use cartographic boundary (clipped to shoreline)
) |>
  # Filter down to only the 5 NYC counties. The counties() call returns
  # all 62 NY counties, so we drop everything outside NYC.
  filter(NAME %in% NYC_COUNTIES) |>

  # Transform to the same CRS as our tract data so layers align correctly.
  # Mixing CRS across layers is one of the most common sources of errors
  # in GIS work — always confirm all layers share the same CRS before analysis.
  st_transform(TARGET_CRS)

message("Borough boundaries pulled: ", nrow(boroughs), " boroughs.")

saveRDS(boroughs, here("data/processed/boroughs.rds"))
message("Saved: data/processed/boroughs.rds")


# ── Section 3: Warehouse/Industrial Lots from NYC PLUTO ───────────────────────
# PLUTO (Primary Land Use Tax Lot Output) is maintained by NYC Department of
# City Planning and covers every tax lot in the five boroughs.
#
# We filter for land use code "06" (Industrial & Manufacturing), which includes
# warehouses, distribution centers, and freight terminals.
#
# We use the Socrata JSON API (not GeoJSON) because the GeoJSON endpoint
# returns empty geometries for this dataset. Instead we pull latitude/longitude
# as plain columns and build the sf point geometry ourselves.
#
# Limitation to document in the report: land use code "06" captures industrial
# lots broadly — some may be factories or workshops rather than distribution
# facilities. This is the best publicly available proxy without purchasing
# commercial real estate data.

message("Pulling NYC warehouse/industrial lots from NYC PLUTO via Socrata API...")

pluto_url <- paste0(
  "https://data.cityofnewyork.us/resource/64uk-42ks.json",
  "?$where=landuse='06'",
  "&$limit=5000",
  "&$select=bbl,address,borough,landuse,bldgarea,latitude,longitude"
)

pluto_raw <- jsonlite::fromJSON(pluto_url)

warehouses <- pluto_raw |>
  # Remove rows where lat/lon are missing — can't build geometry without them
  filter(!is.na(latitude), !is.na(longitude)) |>
  
  # Convert character columns to numeric (Socrata returns everything as text)
  mutate(
    latitude  = as.numeric(latitude),
    longitude = as.numeric(longitude)
  ) |>
  
  # Build point geometry from coordinate columns.
  # Longitude always comes first in st_as_sf coords argument.
  # CRS 4326 = WGS84 (standard lat/lon), which is what Socrata returns.
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326) |>
  
  # Transform to NY State Plane (feet) to match our other layers
  st_transform(TARGET_CRS)

message("Industrial/warehouse lots pulled: ", nrow(warehouses), " locations.")

saveRDS(warehouses, here("data/processed/warehouses.rds"))
message("Saved: data/processed/warehouses.rds")


# ── Completion summary ────────────────────────────────────────────────────────
message("
─────────────────────────────────────────────────────────
01_data_pull.R complete. Files saved to data/processed/:
  ✓ nyc_tracts.rds     — ", nrow(nyc_tracts), " census tracts with population
  ✓ boroughs.rds       — ", nrow(boroughs), " borough boundaries
  ✓ warehouses.rds     — ", nrow(warehouses), " industrial/warehouse lots

Next step: run analysis/02_spatial_analysis.R
─────────────────────────────────────────────────────────
")