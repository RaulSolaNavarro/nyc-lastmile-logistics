# Is $10,000 Enough? Industrial Land Proximity, Income Gradients, and the Cost of Living Next to a Facility

A geospatial analysis of NYC industrial land proximity that connects to a live
policy debate: when a large industrial facility is proposed near a residential
area, how much should affected residents actually be compensated?

**Live report:** https://raulsolanavarro.github.io/nyc-lastmile-logistics/report/

---

## The Policy Question

In late 2025, NorthPoint Development offered 4,500 households in Hazle Township,
Pennsylvania $10,000 each -- in cash -- to support approval of a 1,300-acre data
center in their community. Locals pushed back. The township median household
income is around $60,000. Residents called it a bribe.

That offer sits at the center of a live national debate. By Q2 2026, community
resistance had blocked or delayed $68 billion in U.S. data center projects. The
Brookings Institution framed it as a question of who bears the costs of AI
infrastructure. The core empirical question -- what does living near industrial
land actually cost residents? -- has not been answered with enough specificity
to evaluate whether $10,000 is reasonable, low, or absurd.

This project provides one empirical anchor, using NYC as a test case.

---

## Key Findings

**Income gradient:** Median household income rises monotonically with distance
from industrial land across NYC's 2,327 census tracts:

| Distance Band | Median Income | Residents |
|---|---|---|
| 0--0.25 mi | $63,708 | 4.2M |
| 0.25--0.5 mi | $66,704 | 2.9M |
| 0.5--1 mi | $84,558 | 1.4M |
| >1 mi | $90,379 | 296K |

The $18,000 jump between the within-0.5-mile and beyond-0.5-mile bands is
statistically significant (Wilcoxon rank-sum, p < 0.001, across 2,206 tracts
with income data).

**Spatial gaps:** 31 census tracts containing 61,426 residents (0.7% of NYC's
population) fall entirely outside a 1-mile radius of any industrial lot. Queens
has the largest gap population (32,622 residents across 13 tracts).

**The compensation benchmark:** If proximity to industrial land is associated
with roughly $18,000--$27,000 in annual income difference, and Netherlands
research suggests a 15% property value discount within 250 meters of industrial
sites, a one-time $10,000 payment is a fraction of the implied cost. The right
number depends on distance, property values, and the facility's operating life
-- not on what a developer can negotiate down to.

---

## How This Project Started and How It Changed

This began as a logistics gap analysis: which NYC neighborhoods lack proximity
to warehouse and industrial land, and how many people live there? The spatial
analysis answered that question, but when income data was added, the logistics
framing became secondary.

The income gradient finding -- continuous, monotonic, and robust -- connects
directly to debates about where industrial facilities get sited and what
communities should expect in return. The analysis was reframed accordingly.

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
│   └── tables/                   # Borough summary CSV
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
| Industrial tax lots | NYC PLUTO via NYC Open Data | Current | Socrata JSON API |
| Median household income by tract | U.S. Census Bureau (ACS 5-year) | 2020 | `tidycensus` |

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

1. **Data acquisition** -- Census tract population and geometry via
   `tidycensus`, borough boundaries via `tigris`, industrial lot locations
   via the NYC PLUTO Socrata API, median household income via ACS 5-year.

2. **Projection** -- All layers transformed to EPSG:2263 (NY State Plane,
   feet) for accurate distance measurement.

3. **Buffer analysis** -- Each industrial lot centroid buffered by 5,280 feet
   (1 mile), dissolved into a single merged coverage polygon via `st_union()`.

4. **Gap identification** -- Census tracts tested for intersection with the
   coverage polygon via `st_intersects()`. Non-intersecting tracts classified
   as gaps.

5. **Distance-band income analysis** -- Straight-line distance from each tract
   centroid to nearest industrial lot computed via `st_distance()`. Tracts
   grouped into four distance bands; median household income compared across
   bands. Wilcoxon rank-sum test used to confirm the income gradient.

---

## Tools

- **R** -- data wrangling, spatial analysis, map production
- **QGIS 3.44 LTR** -- spatial data exploration, layer styling, and cartographic
  map export
- **Quarto** -- report authoring and GitHub Pages deployment
- **tidycensus / tigris** -- Census data access
- **sf** -- spatial data manipulation
- **ggplot2** -- map and chart rendering

---

## References

- Brinkman & Rosenthal (2011). *The Impact of Industrial Sites on Residential Property Values.* Regional Studies. https://papers.tinbergen.nl/09035.pdf
- Data Center Watch / Parameter.io (2026). *Community Resistance Stalls $68 Billion Worth of AI Data Center Developments.* https://parameter.io/community-resistance-stalls-68-billion-worth-of-ai-data-center-developments/
- Wheeler, T. (2026). *Data Center Backlash Signals a Fight Over AI Power.* Brookings Institution. https://www.brookings.edu/articles/data-center-backlash-signals-a-fight-over-ai-power/
- Tom's Hardware (2026). *Data center developer offers $10,000 checks to 4,500 households.* https://www.tomshardware.com/tech-industry/data-centers/data-center-developer-offers-usd10-000-checks-to-4-500-households-if-the-1-300-acre-facility-is-approved-locals-push-back-over-noise-and-bribe-concerns

---

## Author

**Raul Sola Navarro**
MS Business Analytics, Baruch College -- Zicklin School of Business
[github.com/RaulSolaNavarro](https://github.com/RaulSolaNavarro)

---

## AI Usage Disclosure

This project was developed with assistance from Claude (Anthropic) as a
collaborative coding and methodology tool. Claude helped structure the R
scripts, debug API connectivity issues during data acquisition, and draft
report prose. All analytical decisions were made and reviewed by the author.
All code was tested and executed locally prior to publication.
