# Milestone 3 codebook

This research was supported by data provided by Meituan.

## Source and scope

- Source: [Meituan INFORMS TSL Research Challenge](https://github.com/meituan/Meituan-INFORMS-TSL-Research-Challenge).
- Pinned source revision: `1f9b4288cee5a78d1e5da007fc306bbaa662fc6d`.
- File: `all_waybill_info_meituan_0322.csv.zip` (38,763,754 bytes). SHA-256: `38b51431a12dd7e73deb4fc750b1275067fbc29cfce2c4b4492339738c988ce2`.
- Date partitions (`dt`): October 17-24, 2022. Unix timestamps are seconds; local-time classification uses `Asia/Shanghai` (UTC+8). Some orders, especially prebooks, were created before their partition date; do not assume `dt` equals every event's calendar date.
- Raw unit: one waybill / assignment attempt, not necessarily one order. A refused attempt may be followed by another waybill for the same order.
- 654,343 raw rows; 568,546 unique orders; 85,797 refused attempts. There are no exact duplicate selected records and exactly one accepted record per order in this release.
- 568,546 accepted orders; remove one missing/invalid completion interval, then 22,181 prebooks from the outcomes. Final sample: **546,364 orders**, **4,890 couriers**, **4,938 merchants**, including **80,742 late orders** and **465,622 on-time/early orders**.

The source's [license](https://github.com/meituan/Meituan-INFORMS-TSL-Research-Challenge/blob/main/License.txt) states CC BY-NC 4.0 and restricts third-party dataset redistribution without permission. Downloaded raw and order-level derived files stay local and are ignored by Git. The committed files contain aggregate academic figure summaries without order or courier identifiers. The repository's MIT software license does not replace the source data terms.

## Preparation and workload definition

`scripts/01_prepare_data.R` verifies the source archive's MD5, extracts only the main CSV, checks required columns, removes exact duplicates, and selects accepted waybills. Repeated accepted order IDs cause a stop for manual review rather than an arbitrary selection. Valid delivery intervals have a positive acceptance time and a strictly later arrival. Valid outcomes additionally require positive order and promise times, order creation no later than acceptance, and promise no earlier than creation. No valid extreme observations are trimmed.

For courier c accepting at t, workload is the number of **recorded completed delivery intervals** with `grab_time <= t < arrive_time`. It includes the newly accepted order, all simultaneous acceptances, and valid prebooks. Completions at t leave before acceptances at t. Compute across the full collection window, without splitting at midnight and before excluding prebooks from outcomes. Group as 1, 2, 3, 4+. This measures observed workload at acceptance; an order in group 1 may be batched with subsequent orders. It is not the same as total orders in a wave.

The one accepted order lacking a completion is omitted from workload reconstruction as well as outcomes; tasks absent from the dataset and intervals starting before the observation window can cause undercounting. No tasks are imputed. Final-report sensitivity checks should address this measurement limitation.

## Selected raw / local order-level columns

`data/processed/orders_milestone3.csv` is recreated locally and **not committed**. Its unit is one completed non-prebooked order with valid timestamps. Original numeric IDs are anonymized categorical keys, not quantities.

| Column | Type / unit | Meaning |
|---|---|---|
| `dt` | integer, YYYYMMDD | Source date partition; retained as supplied. |
| `order_id` | integer key | Unique order in the accepted-order sample. |
| `waybill_id` | integer key | Accepted assignment attempt. |
| `courier_id` | integer key | Assigned courier; 0 is a valid ID. |
| `da_id` | integer category | Business area identifier. Areas may overlap geographically. |
| `poi_id` | integer key | Merchant identifier. |
| `is_courier_grabbed` | 0/1 | Accepted waybill indicator; retained sample is 1. |
| `is_prebook` | 0/1 | Scheduled/prebooked order; plotted outcome sample is 0. |
| `platform_order_time` | Unix seconds | Order creation time. |
| `grab_time` | Unix seconds | Courier acceptance time. |
| `arrive_time` | Unix seconds | Recorded completion/delivery time. |
| `estimate_arrived_time` | Unix seconds | Promised delivery time, not courier performance evaluation. |
| `workload` | positive integer, orders | Observed unfinished delivery intervals at acceptance, including the new order. |
| `workload_group` | category | `1`, `2`, `3`, or `4+`. |
| `delay_min` | minutes, signed | `(arrive_time - estimate_arrived_time) / 60`; negative is early. |
| `duration_min` | minutes | `(arrive_time - platform_order_time) / 60`. |
| `late` | 0/1 | 1 iff `arrive_time > estimate_arrived_time`; equality is on time. |
| `acceptance_hour` | integer 0-23 | Hour of acceptance in Asia/Shanghai. |
| `period` | category | `Peak` if 11:00 <= acceptance < 14:00 or 17:00 <= acceptance < 20:00; otherwise `Off-peak`. These windows are specified in code, not fitted to outcome rates. |
| `bin_id` | integer 1-14 | Delay-bin identifier added for Figure 1; see below. |

Source zeros in timestamps indicate absent events, not January 1970. Refused waybills typically have zero acceptance, pickup, and arrival times. Unused raw columns are deliberately not carried into the local subset.

## Committed small figure datasets

All proportions are in 0-1 units; multiply by 100 for percentages. Values are descriptive, with repeated observations from the same couriers. No inferential confidence intervals or tests are included.

### `figure_data/delay_distribution.csv` (14 rows)

| Column | Definition |
|---|---|
| `bin_id` | Ordered bin identifier, 1 through 14. |
| `lower_min`, `upper_min` | Delay bounds in minutes. Every bin is `(lower_min, upper_min]`; `-Inf` / `Inf` denote open tails. First bin is <= -30, last is > 30, interior bins are five minutes wide. Zero belongs to the on-time bin. |
| `n_orders` | Number of eligible orders in the bin; sums to 546,364. |
| `share` | `n_orders / 546364`; shares sum to 1. |

### `figure_data/workload_period_summary.csv` (8 rows)

Unit: one period x workload group. Denominators are orders, not unique couriers.

| Column | Definition |
|---|---|
| `period`, `workload_group` | Categories defined above. |
| `n_orders` | Eligible orders in the cell. |
| `n_late` | Orders with `late == 1`. |
| `n_on_time` | `n_orders - n_late`, including exactly-on-time orders. |
| `late_rate` | `n_late / n_orders`. |
| `n_couriers` | Distinct couriers represented in that cell; not additive across cells. |
| `mean_duration_min` | Arithmetic mean of order creation-to-arrival duration. |
| `median_delay_min` | Median signed arrival-minus-promise delay. |

### `figure_data/sample_quality.csv` (28 rows)

Columns: `metric` (name below), `value` (numeric). Count metrics are integer counts, rates/shares are fractions, and duration/delay metrics are minutes.

| Metric(s) | Meaning |
|---|---|
| `raw_waybill_records`, `exact_duplicate_records_removed` | Loaded raw rows and duplicates removed on the selected fields. |
| `unique_raw_orders`, `raw_assigned_couriers` | Distinct IDs across all assignment attempts, including refused ones. |
| `rejected_waybill_records`, `accepted_orders` | Refused attempts and accepted order records after deduplication. |
| `invalid_or_missing_delivery_intervals`, `valid_delivery_intervals` | Accepted rows failing/passing the positive acceptance and later-completion rule. |
| `invalid_outcome_timestamps` | Valid intervals failing order/promise chronology checks. |
| `excluded_prebooked_orders` | Valid-outcome intervals removed because prebooked. |
| `analysis_orders`, `analysis_couriers`, `analysis_merchants` | Final order count and distinct courier/merchant counts. |
| `late_orders`, `on_time_orders`, `late_rate` | Final counts and late share; equality with promise counts as on time. |
| `delay_p25_min`, `delay_median_min`, `delay_p75_min`, `delay_p95_min` | Signed delay percentiles, R default quantile type 7. |
| `delay_min_min`, `delay_max_min` | Signed delay extremes, retained in the plots' pooled tails. |
| `late_over_15_min` | Count with delay strictly greater than 15 minutes. |
| `mean_duration_min`, `median_duration_min` | Mean and median creation-to-arrival duration. |
| `multiorder_share` | Share with observed acceptance workload >= 2. |
| `first_dt`, `last_dt` | Minimum and maximum source date partition in the final sample. |

### `figure_data/provenance.csv`

Columns: `field`, `value` (text). Records the source revision, immutable download URL, archive MD5, timezone, peak windows, sample definition, and simultaneous-event convention.

## Planned measures, not computed in Milestone 3

Productivity will use completed orders divided by observed active courier-hours, merging overlapping active intervals. [The October 2024 source clarification](https://github.com/meituan/Meituan-INFORMS-TSL-Research-Challenge/blob/main/tsl_meituan_2024_data_report_20241015.pdf) flags incorrect `wave_start_time` indexing: reconstruct starts from the earliest accepted order in each wave. A wave is keyed by `(courier_id, dt, wave_id)`, not `wave_id` alone. Distance, courier/area/time controls, workload-by-peak comparisons, alternative peak windows, and wave-size robustness checks remain future work.
