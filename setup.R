# =============================================================================
# setup.R
# Project: NYC Last-Mile Logistics Gap Analysis
# Author:  Raúl J. Solá Navarro
# Purpose: One-time script to initialize the project folder structure and
#          install all required R packages. Run this before anything else.
#
# Instructions: Open this file in RStudio and click "Source", or run:
#   source("setup.R")
# =============================================================================


# ── 1. Create folder structure ────────────────────────────────────────────────
# We define all required directories up front so the rest of the scripts
# have consistent, predictable places to read from and write to.
#
# Folder breakdown:
#   data/raw        → reserved for any manually downloaded files (kept empty
#                     in this project since we pull everything via API)
#   data/processed  → cleaned and transformed spatial objects saved as .rds
#                     files after each analysis step
#   output/maps     → final map images exported for the Quarto report
#   output/tables   → any summary tables exported as CSV or similar
#   report          → the Quarto (.qmd) report that documents the full analysis

dirs <- c(
  "data/raw",
  "data/processed",
  "output/maps",
  "output/tables",
  "report"
)

# Loop through each directory path. The `recursive = TRUE` argument tells
# dir.create() to build nested folders in one step (e.g., "data/raw" creates
# "data/" first if it doesn't exist). The existence check prevents errors
# if setup.R is accidentally run more than once.
for (d in dirs) {
  if (!dir.exists(d)) {
    dir.create(d, recursive = TRUE)
    message("Created folder: ", d)
  } else {
    message("Already exists, skipping: ", d)
  }
}


# ── 2. Define required packages ───────────────────────────────────────────────
# Each package is listed with a comment explaining why it's needed.
# This makes it easy for a successor to understand the dependency stack
# without having to trace through every script.

packages <- c(
  "tidycensus",  # Pulls U.S. Census Bureau data (population counts) and
                 # Census tract geometries directly from the Census API.
                 # Eliminates the need to manually download shapefiles.

  "tigris",      # Downloads TIGER/Line geographic boundaries (counties,
                 # states, roads) from the Census Bureau. Used here for
                 # NYC borough (county) boundaries.

  "osmdata",     # Queries the OpenStreetMap (OSM) Overpass API to retrieve
                 # real-world features like warehouses, roads, and land use.
                 # Used here to pull warehouse building locations in NYC.

  "sf",          # The core R package for working with spatial (geographic)
                 # data. Handles reading, transforming, projecting, and
                 # performing operations (buffers, intersections) on vector
                 # data stored as simple features (sf objects).

  "ggplot2",     # The standard R plotting library. Extended by the sf package
                 # via geom_sf() to render spatial layers as publication-quality
                 # maps.

  "dplyr",       # Tidyverse data manipulation: filter(), mutate(), group_by(),
                 # summarise(), etc. Used throughout for cleaning and reshaping
                 # data frames and sf objects.

  "here"         # Builds file paths relative to the project root regardless
                 # of the working directory. Critical for reproducibility —
                 # here("data/processed/file.rds") works on any machine
                 # without hardcoded absolute paths.
)


# ── 3. Install missing packages ───────────────────────────────────────────────
# We only install packages that aren't already present. This avoids
# unnecessary reinstalls when setup.R is re-run after an initial setup.

installed <- rownames(installed.packages())
to_install <- packages[!packages %in% installed]

if (length(to_install) > 0) {
  message("Installing missing packages: ", paste(to_install, collapse = ", "))
  install.packages(to_install)
} else {
  message("All required packages are already installed.")
}


# ── 4. Census API key reminder ────────────────────────────────────────────────
# tidycensus requires a free Census API key to pull data. If you haven't
# already registered for one, do so at:
#   https://api.census.gov/data/key_signup.html
#
# Once you have the key, run this line ONE TIME in the console (not in a
# script) so it gets stored in your .Renviron file permanently:
#   census_api_key("YOUR_KEY_HERE", install = TRUE)
#
# After running that, restart R. You won't need to set it again on this machine.

message("
─────────────────────────────────────────────────────────
Setup complete. Next steps:
  1. Register for a free Census API key at:
     https://api.census.gov/data/key_signup.html
  2. Run in the R console (once only):
     census_api_key('YOUR_KEY_HERE', install = TRUE)
  3. Restart R, then run analysis/01_data_pull.R
─────────────────────────────────────────────────────────
")
