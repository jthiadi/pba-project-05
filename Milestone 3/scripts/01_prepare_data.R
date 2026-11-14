# Run from the Milestone 3 folder: Rscript scripts/01_prepare_data.R
# Real Meituan data; no simulated observations and no model estimation.
suppressPackageStartupMessages(library(data.table))
options(timeout = max(600, getOption("timeout")))
dir.create("data/raw", recursive = TRUE, showWarnings = FALSE)
dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)
dir.create("data/figure_data", recursive = TRUE, showWarnings = FALSE)

source_commit <- "1f9b4288cee5a78d1e5da007fc306bbaa662fc6d"
source_file <- "all_waybill_info_meituan_0322.csv"
archive <- file.path("data/raw", paste0(source_file, ".zip"))
raw_file <- file.path("data/raw", source_file)
source_url <- paste0("https://raw.githubusercontent.com/meituan/",
  "Meituan-INFORMS-TSL-Research-Challenge/", source_commit, "/", source_file, ".zip")
if (!file.exists(archive)) download.file(source_url, archive, mode = "wb")
# Detect partial/corrupt downloads, including an interrupted first run.
expected_md5 <- "eb647d2297ae6818ef05fb3ad71ab12f"
if (unname(tools::md5sum(archive)) != expected_md5) {
  stop("Raw ZIP checksum mismatch. Remove data/raw/", basename(archive), " and rerun.")
}
unzip(archive, files = source_file, exdir = "data/raw", overwrite = TRUE)
raw <- fread(raw_file)
needed <- c("dt", "order_id", "waybill_id", "courier_id", "da_id", "poi_id",
  "is_courier_grabbed", "is_prebook", "platform_order_time", "grab_time",
  "arrive_time", "estimate_arrived_time")
stopifnot(all(needed %in% names(raw)))
raw <- raw[, ..needed]
raw_n <- nrow(raw)
exact_duplicates <- sum(duplicated(raw))
raw <- unique(raw)
accepted <- raw[is_courier_grabbed == 1]
# A refused waybill is an assignment attempt, not a new delivered order.
# Never silently select one of several accepted records for an order.
if (anyDuplicated(accepted$order_id)) stop("Repeated accepted order IDs need review.")
valid_interval <- with(accepted, is.finite(grab_time) & grab_time > 0 &
  is.finite(arrive_time) & arrive_time > grab_time & !is.na(courier_id))
intervals <- copy(accepted[valid_interval])

# At acceptance t, count this courier's observed intervals [grab_time, arrive_time).
# All acceptances at t count together; completions at t have already left.
# Use all completed accepted orders, INCLUDING prebooks, before subsetting outcomes.
# Do not split by date: an order can remain active across midnight.
intervals[, workload := findInterval(grab_time, sort(grab_time)) -
  findInterval(grab_time, sort(arrive_time)), by = courier_id]
stopifnot(all(intervals$workload >= 1))
valid_outcome <- with(intervals,
  is.finite(platform_order_time) & platform_order_time > 0 &
  is.finite(estimate_arrived_time) & estimate_arrived_time > 0 &
  platform_order_time <= grab_time & estimate_arrived_time >= platform_order_time)
eligible <- intervals[valid_outcome]
orders <- copy(eligible[is_prebook == 0])
orders[, `:=`(
  delay_min = (arrive_time - estimate_arrived_time) / 60,
  duration_min = (arrive_time - platform_order_time) / 60,
  workload_group = fifelse(workload >= 4, "4+", as.character(workload))) ]
orders[, late := as.integer(delay_min > 0)]
local_acceptance <- as.POSIXct(orders$grab_time, origin = "1970-01-01", tz = "Asia/Shanghai")
orders[, acceptance_hour := as.integer(format(local_acceptance, "%H", tz = "Asia/Shanghai"))]
# Predefined meal windows, based on acceptance in China local time (UTC+8).
# These are operational definitions, not estimated peaks.
orders[, period := fifelse(acceptance_hour %in% c(11:13, 17:19), "Peak", "Off-peak")]
fwrite(orders, "data/processed/orders_milestone3.csv") # ignored, local only

# Figure 1: keep every eligible order; pool tails rather than trim them.
breaks <- c(-Inf, seq(-30, 30, 5), Inf)
orders[, bin_id := as.integer(cut(delay_min, breaks, right = TRUE))]
bins <- data.table(bin_id = seq_len(length(breaks) - 1),
  lower_min = head(breaks, -1), upper_min = tail(breaks, -1))
bins <- merge(bins, orders[, .(n_orders = .N), by = bin_id], by = "bin_id", all.x = TRUE)
bins[is.na(n_orders), n_orders := 0L]
bins[, share := n_orders / nrow(orders)]
fwrite(bins, "data/figure_data/delay_distribution.csv")

# Figure 2: unadjusted proportions, no regression, testing, or fitted trend.
groups <- orders[, .(n_orders = .N, n_late = sum(late), n_couriers = uniqueN(courier_id),
  mean_duration_min = mean(duration_min), median_delay_min = median(delay_min)),
  by = .(period, workload_group)]
groups[, `:=`(n_on_time = n_orders - n_late, late_rate = n_late / n_orders)]
setorder(groups, period, workload_group)
fwrite(groups, "data/figure_data/workload_period_summary.csv")

quality <- data.table(metric = c("raw_waybill_records", "exact_duplicate_records_removed",
  "unique_raw_orders", "raw_assigned_couriers", "rejected_waybill_records",
  "accepted_orders", "invalid_or_missing_delivery_intervals", "valid_delivery_intervals",
  "invalid_outcome_timestamps", "excluded_prebooked_orders", "analysis_orders",
  "analysis_couriers", "analysis_merchants", "late_orders", "on_time_orders",
  "late_rate", "delay_p25_min", "delay_median_min", "delay_p75_min", "delay_p95_min",
  "delay_min_min", "delay_max_min", "late_over_15_min", "mean_duration_min",
  "median_duration_min", "multiorder_share", "first_dt", "last_dt"),
  value = c(raw_n, exact_duplicates, uniqueN(raw$order_id), uniqueN(raw$courier_id),
    raw[is_courier_grabbed == 0, .N], nrow(accepted), sum(!valid_interval), nrow(intervals),
    sum(!valid_outcome), eligible[is_prebook != 0, .N], nrow(orders),
    uniqueN(orders$courier_id), uniqueN(orders$poi_id), sum(orders$late),
    sum(orders$late == 0), mean(orders$late), quantile(orders$delay_min, c(.25,.5,.75,.95)),
    min(orders$delay_min), max(orders$delay_min), sum(orders$delay_min > 15),
    mean(orders$duration_min), median(orders$duration_min), mean(orders$workload >= 2),
    min(orders$dt), max(orders$dt)))
fwrite(quality, "data/figure_data/sample_quality.csv")
metadata <- data.table(field = c("source_commit", "source_url", "archive_md5", "timezone",
  "peak_hours", "sample", "workload_ties"), value = c(source_commit, source_url,
  unname(tools::md5sum(archive)), "Asia/Shanghai (UTC+8)",
  "11:00 <= acceptance < 14:00 or 17:00 <= acceptance < 20:00",
  "Completed, accepted, non-prebooked orders with valid timestamps",
  "Simultaneous acceptances included together; simultaneous completions removed first"))
fwrite(metadata, "data/figure_data/provenance.csv")
stopifnot(sum(bins$n_orders) == nrow(orders), sum(groups$n_orders) == nrow(orders),
  sum(groups$n_late) == sum(orders$late), !anyNA(orders$bin_id),
  all(groups$n_late + groups$n_on_time == groups$n_orders))
print(quality)
print(groups)
