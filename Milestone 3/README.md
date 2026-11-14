# pba-project-05

## Milestone 3: One More Order

**Research question:** How does multi-order courier workload relate to delivery lateness and courier productivity, and how do these relationships differ between peak and off-peak periods?

- **Submission:** [two-page Milestone 3 PDF](output/pdf/PBA_Milestone3_Group5.pdf).
- [Editable visualization write-up](Report.qmd).
- [Milestone 2 proposal](../Milestone%202/PBA_Milestone2_Group5.qmd).
- [Codebook, sample rules, source terms, and variable definitions](data/CODEBOOK.md).
- [Small figure datasets](data/figure_data/) and [figures](output/figures/).

The figures describe **546,364 completed, non-prebooked deliveries** in the Meituan October 17-24, 2022 date partitions. Figure 1 shows the distribution of arrival relative to the promise; Figure 2 compares unadjusted late rates across acceptance workload and peak/off-peak groups. No model, significance test, or productivity analysis has been run.

## Reproduce from the Milestone 3 folder

The report is authored in `Report.qmd` using Quarto and R. Install Quarto and a LaTeX distribution (for example, `quarto install tinytex`). All writing and figure labels use black Times New Roman; install that font before rendering.

```r
# Install once in R if needed:
install.packages(c("data.table", "ggplot2", "scales"))
```

```sh
# Downloads the pinned official ZIP (~39 MB), checks it, and creates the local
# order-level subset plus small aggregate figure tables. Internet required once.
Rscript scripts/01_prepare_data.R

# Recreates the PNG figures from the small committed CSVs.
# This step works without downloading the raw data.
Rscript scripts/02_plot_figures.R

# Render the QMD; this also regenerates the figures using the R plotting script.
quarto render Report.qmd
```

Run these commands with the current working directory set to the Milestone 3 folder. The download uses a pinned source revision and an MD5 check; the [codebook](data/CODEBOOK.md) also records SHA-256. The preparation script stops if it encounters ambiguous repeated accepted-order IDs. It validates group totals and saves data-quality counts in `data/figure_data/sample_quality.csv`. The plotting run records R versions in `output/sessionInfo.txt`.

`data/raw/` and `data/processed/` remain local and are ignored by Git, keeping large raw and order-level files out of the public repository. The committed `data/figure_data/` tables are the smaller aggregated outputs used by the figures; `data/CODEBOOK.md` documents every field. All eligible observations are retained in Figure 1, with extreme delays pooled into the end bars.

## Data attribution and interpretation

This research was supported by data provided by Meituan.

Source: [Meituan INFORMS TSL Research Challenge](https://github.com/meituan/Meituan-INFORMS-TSL-Research-Challenge). The source data terms state CC BY-NC 4.0 and restrict third-party dataset redistribution without permission. Source data terms apply independently of the software MIT license in this repository.

Peak windows are fixed at 11:00-14:00 and 17:00-20:00 by acceptance time in China (UTC+8). Observed workload counts all valid completed delivery intervals active at acceptance, including prebooks and the new order. Plotted outcomes exclude prebooks. Simultaneous acceptances count together and simultaneous completions leave first. Missing tasks and sample boundaries can understate workload. Differences are descriptive associations and do not establish causal effects or productivity benefits. See the write-up and codebook for the planned final analysis.

## Team

Grace Angeline Sun 114006473; Jennifer Nathania 112006202; Justin Thiadi 112006234; Mario Ananda Salim 112006261; Steven Indrawan 112006211.
