"""Build the two-page submission and its editable Markdown from real summary tables.

Run from the repo root: python scripts/03_build_report.py
Requires reportlab; all data preparation and plotting are in R.
"""
import csv
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.platypus import (
    Image, PageBreak, Paragraph, SimpleDocTemplate, Spacer,
)

ROOT = Path(__file__).resolve().parents[1]


def read_csv(name):
    with (ROOT / "data" / "figure_data" / name).open(encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


quality = {row["metric"]: float(row["value"]) for row in read_csv("sample_quality.csv")}
groups = {(row["period"], row["workload_group"]): row
          for row in read_csv("workload_period_summary.csv")}


def count(key):
    return f"{quality[key]:,.0f}"


def rate(period, group):
    return 100 * float(groups[period, group]["late_rate"])


def workload_share(period, group):
    total = sum(int(row["n_orders"]) for (p, _), row in groups.items() if p == period)
    return 100 * int(groups[period, group]["n_orders"]) / total


question = (
    "How does multi-order courier workload relate to delivery lateness and courier "
    "productivity, and how do these relationships differ between peak and off-peak periods?"
)
sample = (
    f"We use Meituan delivery records dated October 17-24, 2022. From "
    f"{count('raw_waybill_records')} waybill records, we retain one accepted record per "
    f"order, remove {count('invalid_or_missing_delivery_intervals')} order without a valid "
    f"completion time, and exclude {count('excluded_prebooked_orders')} prebooked orders "
    f"from the plotted outcomes. The resulting sample contains {count('analysis_orders')} "
    f"completed on-demand orders from {count('analysis_couriers')} couriers. Both figures "
    "are descriptive; no model or main analysis has been run."
)
figure1_shows = (
    f"Figure 1 plots actual arrival minus promised arrival. Most orders arrive early: "
    f"the median is {-quality['delay_median_min']:.1f} minutes before the promise, and "
    f"the middle half arrive between {-quality['delay_p25_min']:.1f} and "
    f"{-quality['delay_p75_min']:.1f} minutes early. Nevertheless, "
    f"{count('late_orders')} orders ({100*quality['late_rate']:.1f}%) are late. "
    f"At the 95th percentile, delivery is {quality['delay_p95_min']:.1f} minutes late; "
    f"{count('late_over_15_min')} orders "
    f"({100*quality['late_over_15_min']/quality['analysis_orders']:.2f}%) are more than "
    "15 minutes late. The pooled end bars retain extreme observations."
)
figure1_matters = (
    "A typical early delivery can coexist with a meaningful late-delivery problem, "
    "so averages alone would hide the service risk motivating our question. In the "
    "final analysis, we plan to examine both the probability of lateness and delivery "
    "duration, with sensitivity checks for extreme timestamps. This figure establishes "
    "the outcome distribution; it does not show which factors explain the late tail."
)
figure2_shows = (
    f"Figure 2 shows higher late-delivery rates at higher acceptance workloads in both "
    f"periods. Off-peak, the rate rises from {rate('Off-peak','1'):.1f}% with one "
    f"unfinished order to {rate('Off-peak','4+'):.1f}% with four or more "
    f"(a {rate('Off-peak','4+')-rate('Off-peak','1'):.1f} percentage-point gap). "
    f"During peak periods, it rises from {rate('Peak','1'):.1f}% to "
    f"{rate('Peak','4+'):.1f}%. Peak rates are higher at workloads one and two, "
    "but the periods converge at three and four or more orders. The four-or-more "
    f"group contains {int(groups['Peak','4+']['n_orders']):,} peak orders "
    f"({workload_share('Peak','4+'):.1f}% of peak orders), versus "
    f"{int(groups['Off-peak','4+']['n_orders']):,} off-peak orders "
    f"({workload_share('Off-peak','4+'):.1f}% of off-peak orders), showing a different workload mix."
)
figure2_matters = (
    "The workload gradient motivates comparing workload groups, while the changing "
    "peak/off-peak gap motivates a workload-by-peak interaction. These are unadjusted "
    "associations: courier selection, delivery distance, location, restaurant waits, "
    "and promised time allowances may differ across groups. Workload is reconstructed "
    "from recorded completed deliveries, so missing tasks and the observation-window "
    "boundary may understate it. The figures cannot establish that batching causes "
    "lateness or that it improves productivity."
)
next_steps = (
    "We plan to compare lateness and duration across workload groups while accounting "
    "for distance, area, time, and courier differences. We will then examine completed "
    "orders per active courier-hour, merging overlapping wave intervals and "
    "reconstructing wave starts from the earliest acceptance, as the source's "
    "supplementary document flags errors in wave_start_time. Finally, we will compare "
    "acceptance workload with total orders per wave and check alternative peak windows. "
    "This will assess whether the proposed productivity-timeliness trade-off is present."
)

source_url = "https://github.com/meituan/Meituan-INFORMS-TSL-Research-Challenge"
clarification_url = source_url + "/blob/main/tsl_meituan_2024_data_report_20241015.pdf"
source_note = (
    f'<b>Source:</b> <link href="{source_url}" color="#167D8D">Meituan INFORMS TSL '
    'Research Challenge dataset and data dictionary</link>; '
    f'<link href="{clarification_url}" color="#167D8D">supplementary clarification '
    '(October 2024), section 2.2</link>. '
    "This research was supported by data provided by Meituan."
)

styles = getSampleStyleSheet()
ink = colors.HexColor("#182F43")
teal = colors.HexColor("#167D8D")
styles.add(ParagraphStyle(name="ReportTitle", fontName="Helvetica-Bold", fontSize=24,
                          leading=28, textColor=ink, spaceAfter=5))
styles.add(ParagraphStyle(name="Kicker", fontName="Helvetica-Bold", fontSize=9,
                          leading=13, textColor=teal, spaceAfter=9))
styles.add(ParagraphStyle(name="Team", fontName="Helvetica", fontSize=8,
                          leading=11, textColor=ink, spaceAfter=11))
styles.add(ParagraphStyle(name="Section", fontName="Helvetica-Bold", fontSize=13,
                          leading=17, textColor=ink, spaceBefore=9, spaceAfter=6))
styles.add(ParagraphStyle(name="Text", fontName="Helvetica", fontSize=10,
                          leading=14, textColor=ink, spaceAfter=8, alignment=TA_LEFT))
styles.add(ParagraphStyle(name="SmallNote", fontName="Helvetica", fontSize=8,
                          leading=11, textColor=colors.HexColor("#42576A"), spaceAfter=6))
styles.add(ParagraphStyle(name="Caption", fontName="Helvetica-Bold", fontSize=9,
                          leading=12, textColor=ink, spaceAfter=7))

out = ROOT / "output" / "pdf"
out.mkdir(parents=True, exist_ok=True)
pdf_path = out / "PBA_Milestone3_Group5.pdf"
doc = SimpleDocTemplate(str(pdf_path), pagesize=A4, rightMargin=43, leftMargin=43,
                        topMargin=36, bottomMargin=36,
                        title="One More Order - Milestone 3", author="PBA Group 5")
width = A4[0] - 86


def p(text, style="Text"):
    return Paragraph(text, styles[style])


def chart(name, original_height):
    return Image(str(ROOT / "output" / "figures" / name),
                 width=width, height=width * original_height / 9)


story = [
    p("MILESTONE 3  /  GROUP 5  /  FIRST LOOK AT THE DATA", "Kicker"),
    p("One More Order", "ReportTitle"),
    p("Courier workload, delivery timeliness, and the proposed productivity trade-off", "Text"),
    p("Grace Angeline Sun 114006473 | Jennifer Nathania 112006202 | Justin Thiadi 112006234<br/>"
      "Mario Ananda Salim 112006261 | Steven Indrawan 112006211", "Team"),
    p("<b>Research question.</b> " + question),
    p(sample),
    p("1. Delivery timing relative to the promise", "Section"),
    chart("figure1_delay_distribution.png", 4.7),
    p("Figure 1. Distribution of delivery timing in the on-demand sample.", "Caption"),
    p("<b>What stands out.</b> " + figure1_shows),
    p("<b>Why it matters.</b> " + figure1_matters),
    PageBreak(),
    p("2. Workload and late-delivery rates", "Section"),
    chart("figure2_workload_lateness.png", 5.1),
    p("Figure 2. Late-delivery rates by observed acceptance workload and period.", "Caption"),
    p("<b>Definition.</b> Workload counts the courier's accepted but unfinished orders at "
      "acceptance, including the new order and valid prebooked deliveries. Simultaneous "
      "acceptances count together; completions at that second are removed first. "
      "A workload of one does not guarantee the order remains unbatched later.", "SmallNote"),
    p("<b>What stands out.</b> " + figure2_shows),
    p("<b>Why it matters.</b> " + figure2_matters),
    p("Planned analysis", "Section"),
    p(next_steps),
    Spacer(1, 3),
    p(source_note, "SmallNote"),
]


def footer(canvas, document):
    canvas.saveState()
    canvas.setStrokeColor(colors.HexColor("#D9E2E8"))
    canvas.line(43, 28, A4[0] - 43, 28)
    canvas.setFillColor(colors.HexColor("#42576A"))
    canvas.setFont("Helvetica", 8)
    canvas.drawString(43, 16, "Programming for Business Analytics | Group 5")
    canvas.drawRightString(A4[0] - 43, 16, str(document.page))
    canvas.restoreState()


doc.build(story, onFirstPage=footer, onLaterPages=footer)

markdown = f"""# One More Order - Milestone 3

Group 5: Grace Angeline Sun; Jennifer Nathania; Justin Thiadi; Mario Ananda Salim; Steven Indrawan.

**Research question.** {question}

{sample}

## 1. Delivery timing relative to the promise

![Figure 1](../output/figures/figure1_delay_distribution.png)

**What stands out.** {figure1_shows}

**Why it matters.** {figure1_matters}

## 2. Workload and late-delivery rates

![Figure 2](../output/figures/figure2_workload_lateness.png)

Workload counts accepted but unfinished orders at acceptance, including the new order and valid prebooks. Simultaneous acceptances count together; completions at that second are removed first. One order at acceptance does not guarantee it remains unbatched later. Peak = 11:00-14:00 or 17:00-20:00 at acceptance, Asia/Shanghai; all other hours are off-peak.

**What stands out.** {figure2_shows}

**Why it matters.** {figure2_matters}

## Planned analysis

{next_steps}

Source: [Meituan data and dictionary]({source_url}); [supplementary clarification]({clarification_url}), section 2.2.

This research was supported by data provided by Meituan.
"""
(ROOT / "reports" / "PBA_Milestone3_Group5.md").write_text(markdown, encoding="utf-8")
print(pdf_path)
