# =============================================================================
# analysis/02_spatial_analysis.R
# Project: NYC Last-Mile Logistics Gap Analysis
# Author:  Raúl J. Solá Navarro
# Purpose: Perform the core spatial analysis to identify which NYC census
#          tracts are underserved by warehouse infrastructure.
#
# Methodology:
#   1. Buffer each warehouse by 5 miles to approximate its service area
#   2. Merge overlapping buffers into a single coverage polygon
#   3. Classify each census tract as "served" or "underserved" based on
#      whether it intersects the coverage polygon
#   4. Calculate population density per tract for map styling
#   5. Summarize results by borough for the report
#
# The 5-mile service radius is a standard last-mile logistics assumption.
# In dense urban environments like NYC, 5 miles represents a reasonable
# same-day delivery reach from a warehouse. This threshold can be adjusted
# in the BUFFER_DIST_FT constant below.
#
# Inputs:  data/processed/nyc_tracts.rds
#          data/processed/boroughs.rds
#          data/processed/warehouses.rds
# Outputs: data/processed/nyc_tracts_analyzed.rds
#          data/processed/underserved_tracts.rds
#          data/processed/warehouse_buffer.rds
#          data/processed/borough_summary.rds
#          output/tables/borough_summary.csv
# =============================================================================


# ── Load libraries ────────────────────────────────────────────────────────────

library(sf)      # Spatial operations: buffer, intersect, area calculation
library(dplyr)   # Data manipulation: mutate, filter, group_by, summarise
library(here)    # Reproducible file paths


# ── Constants ─────────────────────────────────────────────────────────────────
# Defining key parameters as named constants at the top of the script makes
# it easy for a successor to adjust the analysis without hunting through code.

# Buffer distance in feet. Our CRS (EPSG:2263) uses feet as its unit.
# 5 miles × 5,280 feet/mile = 26,400 feet.
# To change the service radius, update this single value.
BUFFER_DIST_FT <- 5280  # 1 mile in feet


# ── Load processed data ───────────────────────────────────────────────────────
# All three inputs were created by 01_data_pull.R and share the same CRS
# (EPSG:2263). Confirm this if you ever add new data layers — mismatched
# CRS is the most common source of silent errors in spatial analysis.

message("Loading processed spatial data...")

nyc_tracts <- readRDS(here("data/processed/nyc_tracts.rds"))
boroughs   <- readRDS(here("data/processed/boroughs.rds"))
warehouses <- readRDS(here("data/processed/warehouses.rds"))

message("Loaded:  ", nrow(nyc_tracts), " tracts | ",
        nrow(boroughs), " boroughs | ",
        nrow(warehouses), " warehouses")


# ── Section 1: Buffer Warehouse Locations ─────────────────────────────────────
# st_buffer() draws a circle of radius BUFFER_DIST_FT around each warehouse
# centroid, creating a polygon that represents the area that warehouse could
# theoretically serve within a last-mile delivery window.
#
# st_union() then dissolves all individual buffer circles into a single
# merged polygon. This is important because:
#   1. Overlapping individual buffers would double-count served areas
#   2. A single polygon is faster for the intersection test in Section 2
#   3. The union represents the total contiguous coverage footprint

message("Buffering warehouse locations by ", BUFFER_DIST_FT / 5280, " miles...")

warehouse_buffer <- warehouses |>
  st_buffer(dist = BUFFER_DIST_FT) |>  # Draw service radius circle
  st_union()                            # Merge all circles into one polygon

message("Warehouse buffer created.")


# ── Section 2: Classify Tracts as Served or Underserved ──────────────────────
# st_intersects() tests whether each census tract overlaps with the merged
# warehouse buffer polygon. It returns a sparse matrix by default; setting
# sparse = FALSE returns a logical matrix that's easier to work with.
#
# We extract column 1 ([, 1]) because we're comparing many tracts against
# one buffer polygon, so the result is a single-column logical vector:
#   TRUE  = tract intersects the buffer = within 5 miles of a warehouse
#   FALSE = tract does not intersect  = potential logistics gap

message("Classifying census tracts as served or underserved...")

# The intersection test: does each tract touch the warehouse coverage area?
served_logical <- st_intersects(nyc_tracts, warehouse_buffer, sparse = FALSE)[, 1]

# Add the served flag and population density to the tracts data.
# Population density = people per square mile, calculated from:
#   - st_area() returns area in square feet (our CRS unit)
#   - Divide by 5280^2 to convert sq ft → sq miles
#   - Then divide population by area in sq miles
nyc_tracts <- nyc_tracts |>
  mutate(
    # Logical flag: TRUE if tract is within 5 miles of any warehouse
    served = served_logical,

    # Population per square mile. as.numeric() strips the unit class that
    # st_area() attaches, which would otherwise cause downstream type errors.
    pop_density = population / (as.numeric(st_area(geometry)) / 5280^2)
  )

# Create a separate layer of only the underserved tracts for easier mapping
# and for potential further analysis (e.g., which neighborhoods are most
# at risk, what is the total underserved population, etc.)
underserved <- nyc_tracts |>
  filter(!served)  # Keep only tracts where served == FALSE

message("Tracts classified:")
message("  Served:      ", sum(nyc_tracts$served), " tracts")
message("  Underserved: ", sum(!nyc_tracts$served), " tracts")
message("  Underserved population: ",
        scales::comma(sum(underserved$population, na.rm = TRUE)))


# ── Section 3: Borough-Level Summary ─────────────────────────────────────────
# Aggregate the tract-level results up to the borough level for the executive
# summary table in the report. This gives stakeholders a high-level view of
# which boroughs have the worst logistics coverage gaps.
#
# st_drop_geometry() removes the spatial column before grouping. This is
# best practice when you don't need geometry for a calculation — it's faster
# and avoids potential issues with geometry aggregation.

message("Summarizing results by borough...")

# Note: The GEOID column in nyc_tracts follows Census format: the first 5
# digits are the state+county FIPS code, which we can use to identify the
# borough each tract belongs to.
#   36005 = Bronx
#   36047 = Kings (Brooklyn)
#   36061 = New York (Manhattan)
#   36081 = Queens
#   36085 = Richmond (Staten Island)

borough_fips <- c(
  "36005" = "Bronx",
  "36047" = "Brooklyn",
  "36061" = "Manhattan",
  "36081" = "Queens",
  "36085" = "Staten Island"
)

borough_summary <- nyc_tracts |>
  st_drop_geometry() |>

  # Extract the 5-digit county FIPS from the tract GEOID (first 5 characters)
  mutate(borough = borough_fips[substr(GEOID, 1, 5)]) |>

  group_by(borough, served) |>
  summarise(
    tracts     = n(),
    population = sum(population, na.rm = TRUE),
    .groups    = "drop"
  ) |>

  # Add a human-readable coverage status label
  mutate(coverage = ifelse(served, "Served", "Underserved"))

print(borough_summary)


# ── Section 4: Save all outputs ───────────────────────────────────────────────
# Save spatial objects as .rds for use in 03_maps.R.
# Save the summary table as both .rds and .csv so it can be embedded in
# the Quarto report directly or opened in Excel for review.

message("Saving analysis outputs...")

saveRDS(nyc_tracts,       here("data/processed/nyc_tracts_analyzed.rds"))
saveRDS(underserved,      here("data/processed/underserved_tracts.rds"))
saveRDS(warehouse_buffer, here("data/processed/warehouse_buffer.rds"))
saveRDS(borough_summary,  here("data/processed/borough_summary.rds"))

# CSV export for easy review outside of R
write.csv(borough_summary,
          here("output/tables/borough_summary.csv"),
          row.names = FALSE)

message("
─────────────────────────────────────────────────────────
02_spatial_analysis.R complete. Files saved:
  ✓ data/processed/nyc_tracts_analyzed.rds
  ✓ data/processed/underserved_tracts.rds
  ✓ data/processed/warehouse_buffer.rds
  ✓ data/processed/borough_summary.rds
  ✓ output/tables/borough_summary.csv

Next step: run analysis/03_maps.R
─────────────────────────────────────────────────────────
")
