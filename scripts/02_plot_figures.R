# Run from the repository root. Requires only the committed small summary tables.
suppressPackageStartupMessages({library(data.table); library(ggplot2)})
dir.create("output/figures", recursive = TRUE, showWarnings = FALSE)
teal <- "#167D8D"
orange <- "#D17828"
ink <- "#182F43"
theme_set(theme_minimal(base_size = 12, base_family = "sans") + theme(
  plot.title = element_text(face = "bold", color = ink, size = 16),
  plot.subtitle = element_text(color = "#42576A", size = 11, margin = margin(b = 14)),
  plot.title.position = "plot", plot.caption.position = "plot",
  plot.caption = element_text(hjust = 0, size = 9, color = "#42576A", margin = margin(t = 12)),
  panel.grid.minor = element_blank(), panel.grid.major.x = element_blank(),
  axis.title = element_text(size = 11), axis.text = element_text(color = ink),
  plot.margin = margin(12, 18, 12, 12), legend.position = "top",
  legend.title = element_blank()))
q <- fread("data/figure_data/sample_quality.csv")
metric <- function(name) q$value[q$metric == name]
bins <- fread("data/figure_data/delay_distribution.csv")
bins[, `:=`(xmin = pmax(-35, lower_min), xmax = pmin(35, upper_min),
  timing = fifelse(upper_min <= 0, "On time or early", "Late"))]
p1 <- ggplot(bins) + geom_rect(aes(xmin = xmin, xmax = xmax, ymin = 0, ymax = share,
  fill = timing), color = "white", linewidth = .4) +
  geom_vline(xintercept = 0, linewidth = .6, linetype = "dashed", color = ink) +
  scale_fill_manual(values = c("On time or early" = teal, "Late" = orange),
    breaks = c("On time or early", "Late")) +
  scale_x_continuous(breaks = c(-32.5, -20, -10, 0, 10, 20, 32.5),
    labels = c("<= -30", "-20", "-10", "0", "10", "20", "> 30"), expand = c(.01,0)) +
  scale_y_continuous(labels = scales::label_percent(accuracy = 1),
    expand = expansion(mult = c(0,.08))) +
  labs(title = "Most deliveries arrive early, but a late tail remains",
    subtitle = sprintf("%s completed on-demand orders | %.1f%% arrive after the promise",
      format(metric("analysis_orders"), big.mark = ",", scientific = FALSE), 100*metric("late_rate")),
    x = "Actual arrival minus promised arrival (minutes)", y = "Share of orders",
    caption = paste("Five-minute bins; first and last bars pool all values <= -30 and > 30 minutes.",
      "Negative = early; zero = on time; positive = late. All eligible orders are included.", sep = "\n"))
groups <- fread("data/figure_data/workload_period_summary.csv")
groups[, workload_group := factor(workload_group, levels = c("1", "2", "3", "4+"))]
groups[, period := factor(period, levels = c("Off-peak", "Peak"))]
groups[, label := sprintf("%.1f%%\nn = %s", 100*late_rate, format(n_orders, big.mark = ",", trim = TRUE))]
p2 <- ggplot(groups, aes(workload_group, late_rate, color = period, shape = period)) +
  geom_point(size = 3.5) +
  geom_text(aes(label = label), vjust = -.7, lineheight = 1.05, size = 3.6, show.legend = FALSE) +
  facet_wrap(~period, nrow = 1) +
  scale_color_manual(values = c("Off-peak" = teal, "Peak" = orange)) +
  scale_shape_manual(values = c("Off-peak" = 16, "Peak" = 17)) +
  scale_y_continuous(labels = scales::label_percent(accuracy = 1),
    limits = c(0, max(groups$late_rate) + .065), breaks = scales::breaks_width(.05),
    expand = expansion(mult = c(.01,0))) +
  scale_x_discrete(expand = expansion(add = .55)) +
  labs(title = "Late-delivery rates vary with workload and time of day",
    subtitle = "Unadjusted order-level proportions | labels show rate and order count",
    x = "Accepted but unfinished orders at acceptance (including the new order)",
    y = "Late-delivery rate",
    caption = paste("Peak: 11:00-14:00 and 17:00-20:00, classified by acceptance time in China (UTC+8).",
      "Workload includes valid prebooked deliveries; plotted outcomes exclude prebooked orders.",
      "Observed completed-order workload; these descriptive comparisons do not establish causality.", sep = "\n")) +
  theme(legend.position = "none", strip.text = element_text(face = "bold", size = 12),
    panel.spacing.x = grid::unit(18, "pt"))
for (ext in c("png", "pdf")) {
  ggsave(paste0("output/figures/figure1_delay_distribution.", ext), p1,
    width = 9, height = 4.7, dpi = 320, bg = "white")
  ggsave(paste0("output/figures/figure2_workload_lateness.", ext), p2,
    width = 9, height = 5.1, dpi = 320, bg = "white")
}
writeLines(trimws(capture.output(sessionInfo()), which = "right"), "output/sessionInfo.txt")
cat("Saved both figures as PNG and vector PDF.\n")
