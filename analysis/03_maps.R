# =============================================================================
# analysis/03_maps.R
# Project: NYC Last-Mile Logistics Gap Analysis
# Author:  Raúl J. Solá Navarro
# Purpose: Produce and export all final maps for the Quarto report.
#          Each map is saved as a high-resolution PNG to output/maps/.
#
# Maps produced:
#   Map 1 — Population density choropleth by census tract
#   Map 2 — Last-mile logistics gap analysis (served vs. underserved tracts)
#
# Design rationale:
#   - theme_void() removes axes, gridlines, and background — appropriate for
#     thematic maps where geographic context (shape, coastline) carries the
#     story rather than coordinate values
#   - viridis "magma" palette for Map 1: perceptually uniform, colorblind-safe,
#     prints well in grayscale
#   - Red/green for Map 2: conventional served/unserved coding familiar to
#     logistics and operations audiences
#   - 300 DPI export ensures crisp rendering in the HTML report
#
# Inputs:  data/processed/nyc_tracts_analyzed.rds
#          data/processed/warehouse_buffer.rds
#          data/processed/warehouses.rds
# Outputs: output/maps/map1_population_density.png
#          output/maps/map2_logistics_gaps.png
# =============================================================================


# ── Load libraries ────────────────────────────────────────────────────────────

library(sf)      # Required for geom_sf() to render spatial layers in ggplot2
library(ggplot2) # Core plotting engine
library(dplyr)   # Data manipulation (used for label prep)
library(scales)  # Formatting helpers: comma(), percent(), etc.
library(here)    # Reproducible file paths


# ── Load analysis outputs ─────────────────────────────────────────────────────

message("Loading analysis outputs for mapping...")

nyc_tracts       <- readRDS(here("data/processed/nyc_tracts_analyzed.rds"))
warehouse_buffer <- readRDS(here("data/processed/warehouse_buffer.rds"))
warehouses       <- readRDS(here("data/processed/warehouses.rds"))

message("Data loaded. Building maps...")


# ── Map 1: Population Density Choropleth ──────────────────────────────────────
# A choropleth map shades geographic areas by a numeric variable. Here we
# shade each census tract by population density (people per square mile).
#
# This map answers the first analytical question: WHERE are people concentrated
# in NYC? It sets the stage for Map 2, which shows whether those dense areas
# have adequate warehouse coverage.

map1 <- ggplot(nyc_tracts) +

  # geom_sf() renders sf objects as map layers. aes(fill = pop_density) maps
  # the population density variable to the fill color of each tract polygon.
  # color = NA removes the tract borders, which would be too cluttered at
  # the census tract level (NYC has ~2,300 tracts).
  geom_sf(aes(fill = pop_density), color = NA) +

  # scale_fill_viridis_c() applies a continuous (gradient) viridis color scale.
  # option = "magma" uses a dark purple → orange → yellow ramp that reads
  # intuitively as "low → high" and remains accessible to colorblind readers.
  # labels = scales::comma formats legend values with thousand separators.
  scale_fill_viridis_c(
    option = "magma",
    name   = "Population\nper sq mi",
    labels = comma,
    # Compress the upper tail so extreme outliers (very dense Manhattan tracts)
    # don't wash out variation in the rest of the city.
    # Adjust these limits if the map looks flat or oversaturated.
    limits = c(0, quantile(nyc_tracts$pop_density, 0.98, na.rm = TRUE)),
    oob    = scales::squish  # Values above the limit get the max color
  ) +

  labs(
    title    = "NYC Population Density by Census Tract",
    subtitle = "2020 U.S. Decennial Census — persons per square mile",
    caption  = "Source: U.S. Census Bureau via tidycensus | CRS: EPSG:2263 (NY State Plane)"
  ) +

  # theme_void() is the standard choice for thematic maps. It removes:
  #   - Axis tick marks and labels (lat/lon values add no value here)
  #   - Panel background and grid lines (distracting on a map)
  #   - Keeping only the legend and title elements
  theme_void() +
  theme(
    plot.title    = element_text(size = 14, face = "bold", hjust = 0.5),
    plot.subtitle = element_text(size = 10, hjust = 0.5, color = "gray40"),
    plot.caption  = element_text(size = 7, hjust = 1, color = "gray50"),
    legend.position = "right"
  )

# Export at 300 DPI. Width/height in inches × DPI = pixel dimensions.
# 10 × 8 inches at 300 DPI = 3000 × 2400 pixels — sharp at any report size.
ggsave(
  filename = here("output/maps/map1_population_density.png"),
  plot     = map1,
  width    = 10,
  height   = 8,
  dpi      = 300,
  bg       = "white"  # Explicit white background (ggplot default is transparent)
)
message("Saved: output/maps/map1_population_density.png")


# ── Map 2: Last-Mile Logistics Gap Analysis ───────────────────────────────────
# This is the primary analytical map. It layers three pieces of information:
#
#   Layer 1 (bottom): Census tracts colored red/green by served status.
#                     Red = no warehouse within 5 miles = logistics gap.
#                     Green = within 5 miles of at least one warehouse.
#
#   Layer 2 (middle): The merged warehouse buffer polygon, shown as a
#                     semi-transparent blue overlay. This lets the reader
#                     see exactly where the 5-mile service radius reaches.
#
#   Layer 3 (top):    Individual warehouse centroid points in blue.
#                     Anchors the buffer visually to its source locations.
#
# Layers are drawn bottom to top in ggplot2 — each geom_sf() call adds
# a layer on top of the previous one.

map2 <- ggplot() +

  # Layer 1: Census tracts — the analytical result layer
  # fill is mapped to the logical "served" column (TRUE/FALSE).
  # alpha = 0.8 lets a small amount of the tract borders show through
  # when tracts are adjacent, helping the reader parse the geography.
  geom_sf(
    data  = nyc_tracts,
    aes(fill = served),
    color = NA,
    alpha = 0.85
  ) +

  # Layer 2: Warehouse service radius buffer
  # The merged buffer polygon shows the total area within 5 miles of any
  # warehouse. Semi-transparent (alpha = 0.15) so the tract colors show through.
  # The border (color = "steelblue") traces the exact edge of coverage.
  geom_sf(
    data      = warehouse_buffer,
    fill      = "steelblue",
    alpha     = 0.15,
    color     = NA,
    linewidth = 0.4
  ) +

  # Layer 3: Individual warehouse locations
  # Small points mark each warehouse centroid so the reader can see the
  # source locations that generated the buffer. Size and alpha are tuned
  # to be visible without overwhelming the underlying tract layer.
  geom_sf(
    data  = warehouses,
    color = "steelblue",
    size  = 1.0,
    alpha = 0.8
  ) +

  # Manual color scale for the served/underserved binary fill.
  # Color choices follow convention: green = OK, red = problem.
  # Hex values are muted versions to avoid eye strain on a large map.
  scale_fill_manual(
    values = c(
      "TRUE"  = "#7fbf7b",  # Muted green: served tracts
      "FALSE" = "#d6604d"   # Muted red: underserved tracts (logistics gaps)
    ),
    labels = c(
      "TRUE"  = "Served (within 1 mi of warehouse)",
      "FALSE" = "Underserved — Logistics Gap"
    ),
    name = "Coverage Status"
  ) +

  labs(
    title    = "NYC Last-Mile Logistics Gap Analysis",
    subtitle = "Census tracts outside a 1-mile warehouse service radius",
    caption  = paste(
      "Sources: OpenStreetMap via osmdata (warehouses) |",
      "U.S. Census Bureau via tidycensus (tracts) |",
      "1-mile service radius assumption | CRS: EPSG:2263"
    )
  ) +

  theme_void() +
  theme(
    plot.title    = element_text(size = 14, face = "bold", hjust = 0.5),
    plot.subtitle = element_text(size = 10, hjust = 0.5, color = "gray40"),
    plot.caption  = element_text(size = 7, hjust = 1, color = "gray50"),
    legend.position = "right",
    # Stack the two legend keys vertically for readability
    legend.direction = "vertical"
  )

ggsave(
  filename = here("output/maps/map2_logistics_gaps.png"),
  plot     = map2,
  width    = 10,
  height   = 8,
  dpi      = 300,
  bg       = "white"
)
message("Saved: output/maps/map2_logistics_gaps.png")


# ── Completion ────────────────────────────────────────────────────────────────
message("
─────────────────────────────────────────────────────────
03_maps.R complete. Maps exported to output/maps/:
  ✓ map1_population_density.png
  ✓ map2_logistics_gaps.png

Next step: open report/index.qmd and render the report.
─────────────────────────────────────────────────────────
")
