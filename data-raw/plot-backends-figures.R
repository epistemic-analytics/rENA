## data-raw/plot-backends-figures.R — the plot-backend comparison
##
## Runs the same views three ways — rENA with backend = "plotly", rENA with
## backend = "qeviz", and qeviz's own functions — screenshots each view's three
## panels side by side with headless Chrome, and writes the page that shows
## them with their code:
##
##   man/figures/backends-{network,subtraction,points}.png
##       (also used by ?rENA-plot-backends)
##   PLOT-BACKENDS.md   (linked from README.md; a page on the pkgdown site)
##
##   Rscript data-raw/plot-backends-figures.R     (from the package root)
##
## The code on the page is the code below: each view's code is a string that
## is both run and printed. Needs qeviz >= 0.5.0, htmlwidgets, plotly, sys and
## Google Chrome (set CHROME for another binary). Re-run after changing either
## backend's look.

pkgload::load_all(".", quiet = TRUE)
library(qeviz)

chrome <- Sys.getenv("CHROME", "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
out_dir <- file.path("man", "figures")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
work <- tempfile("backends-figures-")
dir.create(work)

setup <- '
library(rENA)
data(RS.data)
codeNames <- c("Data", "Technical.Constraints", "Performance.Parameters",
  "Client.and.Consultant.Requests", "Design.Reasoning", "Collaboration")
accum <- ena.accumulate.data(
  units = RS.data[, c("Condition", "UserName")],
  conversation = RS.data[, c("Condition", "GroupName")],
  codes = RS.data[, codeNames],
  window.size.back = 4
)
set <- ena.make.set(accum)
first  <- set$meta.data$Condition == "FirstGame"
second <- set$meta.data$Condition == "SecondGame"
lw  <- as.matrix(set$line.weights)
pts <- as.matrix(set$points)'

# Per view: a caption, the rENA code (run with backend = "plotly" and
# "qeviz"; `backend` is set before it runs) and the qeviz code.
views <- list(
  network = list(
    title = "A group's network and its mean",
    caption = paste(
      "On qeviz, line width is absolute per weight and each node's size is the",
      "sum of its edge widths, so separate plots of one model are directly comparable."),
    rena = '
p <- ena.plot(set, title = "FirstGame", backend = backend)
p <- ena.plot.network(p, network = colMeans(lw[first, ]))
p <- ena.plot.group(p, pts[first, ], labels = "FirstGame", colors = "red",
                    confidence.interval = "box")',
    qeviz = '
p <- qe_plot(set, title = "FirstGame", group_col = "Condition",
             scale_points = FALSE, range = "network") |>
  qe_axes() |>
  qe_colors(FirstGame = "#FF0000") |>
  qe_edges(group = "FirstGame") |>
  qe_group("FirstGame")'
  ),
  subtraction = list(
    title = "A subtraction with both means",
    caption = paste(
      "Colour and width are on the model-wide scale, so the small differences in a",
      "subtraction draw lighter than a group's network; `multiplier` (rENA) or",
      "`magnify` (qeviz) enlarges them."),
    rena = '
p <- ena.plot(set, title = "FirstGame - SecondGame", backend = backend)
p <- ena.plot.network(p, network = colMeans(lw[first, ]) - colMeans(lw[second, ]),
                      colors = c("red", "blue"))
p <- ena.plot.group(p, pts[first, ], labels = "FirstGame", colors = "red",
                    confidence.interval = "box")
p <- ena.plot.group(p, pts[second, ], labels = "SecondGame", colors = "blue",
                    confidence.interval = "box")',
    qeviz = '
p <- qe_plot(set, title = "FirstGame - SecondGame", group_col = "Condition",
             scale_points = FALSE, range = "network") |>
  qe_axes() |>
  qe_colors(FirstGame = "#FF0000", SecondGame = "#0000FF") |>
  qe_edges(group = "FirstGame", compare = "SecondGame") |>
  qe_group("FirstGame", "SecondGame")'
  ),
  points = list(
    title = "Units and means",
    caption = "Each mean keeps its own confidence interval.",
    rena = '
p <- ena.plot(set, title = "Units and means", scale.to = "points", backend = backend)
p <- ena.plot.points(p, pts[first, ], colors = "red")
p <- ena.plot.points(p, pts[second, ], colors = "blue")
p <- ena.plot.group(p, pts[first, ], labels = "FirstGame", colors = "red",
                    confidence.interval = "box")
p <- ena.plot.group(p, pts[second, ], labels = "SecondGame", colors = "blue",
                    confidence.interval = "box")',
    qeviz = '
p <- qe_plot(set, title = "Units and means", group_col = "Condition",
             scale_points = FALSE, range = "points") |>
  qe_axes() |>
  qe_colors(FirstGame = "#FF0000", SecondGame = "#0000FF") |>
  qe_edges(show = FALSE) |>
  qe_points() |>
  qe_group("FirstGame", "SecondGame")'
  )
)

env <- new.env()
eval(parse(text = sub("library(rENA)\n", "", setup, fixed = TRUE)), env)

PANELS <- c(plotly = 'rENA, backend = "plotly" (default)',
            qeviz  = 'rENA, backend = "qeviz"',
            native = "qeviz directly")
W <- 520; H <- 520   # each panel
GAP <- 16

widget <- function(view, panel) {
  e <- new.env(parent = env)
  if (panel == "native") {
    eval(parse(text = views[[view]]$qeviz), e)
    qeviz::qe_widget(e$p)
  } else {
    e$backend <- panel
    eval(parse(text = views[[view]]$rena), e)
    e$p$plot
  }
}

save_panel <- function(view, panel) {
  w <- widget(view, panel)
  w$width <- W; w$height <- H
  # saveWidget's standalone page pads the widget by 40px; the frame is exact.
  w$sizingPolicy$padding <- 0
  w$sizingPolicy$browser$padding <- 0
  f <- file.path(work, sprintf("%s-%s.html", view, panel))
  suppressWarnings(htmlwidgets::saveWidget(w, f, selfcontained = FALSE, libdir = "lib",
                                           background = "white"))
  basename(f)
}

page <- function(view) {
  cols <- vapply(names(PANELS), function(panel) sprintf(
    '<div class="col"><div>%s</div><iframe src="%s"></iframe></div>',
    htmltools::htmlEscape(PANELS[[panel]]), save_panel(view, panel)), "")
  html <- sprintf('<!doctype html><meta charset="utf-8">
<style>
  body { margin: 0; background: #fff; font: 600 15px/1.2 -apple-system, Helvetica, Arial, sans-serif; color: #333; }
  .row { display: flex; gap: %dpx; padding: 12px %dpx 0; }
  .col { width: %dpx; }
  .col div { padding: 0 0 6px 4px; }
  iframe { width: %dpx; height: %dpx; border: 1px solid #ddd; }
</style>
<div class="row">%s</div>', GAP, GAP, W, W, H, paste(cols, collapse = "\n"))
  f <- file.path(work, sprintf("%s.html", view))
  writeLines(html, f)
  f
}

# Headless Chrome can keep running after it writes the screenshot; wait for
# the PNG to appear and stop growing, then end it.
screenshot <- function(html, png, width, height) {
  unlink(png)
  profile <- file.path(work, "chrome-profile")
  pid <- sys::exec_background(chrome, c(
    "--headless=new", paste0("--user-data-dir=", profile), "--hide-scrollbars",
    sprintf("--window-size=%d,%d", width, height), "--force-device-scale-factor=1",
    "--virtual-time-budget=6000", "--default-background-color=ffffffff",
    paste0("--screenshot=", normalizePath(png, mustWork = FALSE)),
    paste0("file://", normalizePath(html))), std_out = FALSE, std_err = FALSE)
  on.exit(tools::pskill(pid), add = TRUE)
  last <- -1
  for (i in 1:60) {
    Sys.sleep(1)
    size <- if (file.exists(png)) file.size(png) else -1
    if (size > 0 && size == last) return(invisible(png))
    last <- size
  }
  stop("no screenshot from Chrome for ", html)
}

n <- length(PANELS)
for (view in names(views)) {
  png <- file.path(out_dir, sprintf("backends-%s.png", view))
  screenshot(page(view), png, width = n * W + (n + 1) * GAP + 2 * n,
             height = H + 12 + 26 + 4)
  message("wrote ", png, " (", round(file.size(png) / 1024), " KB)")
}

# ── PLOT-BACKENDS.md ──────────────────────────────────────────────────────────

code <- function(x) c("```r", trimws(x, "left"), "```")
FIG_URL <- "https://gitlab.com/epistemic-analytics/qe-packages/rENA/-/raw/main/man/figures"
md <- c(
  "# Plot backends: plotly and qeviz",
  "",
  "rENA draws plots with **plotly** (the default) or **qeviz**, the library",
  "behind webENA's network plots. Existing plotting code works on either: add",
  "`backend = \"qeviz\"` to `ena.plot()`, or set it for the session with",
  "",
  code('options(rENA.plot.backend = "qeviz")'),
  "",
  "qeviz (>= 0.5.0) installs from qe-libs.org:",
  "",
  code('install.packages("qeviz", repos = c("https://cran.qe-libs.org", "https://cran.rstudio.org"))'),
  "",
  "Below, each view is drawn three ways from RS.data: the rENA code with each",
  "backend (only `backend` differs), and the same view written with qeviz's own",
  "functions, which take the ENA set directly. The full list of differences is in",
  "the `?rENA-plot-backends` help page.",
  "",
  "All three use this setup:",
  "",
  code(setup),
  ""
)
for (view in names(views)) {
  v <- views[[view]]
  md <- c(md,
    sprintf("## %s", v$title), "",
    # The link is absolute: pkgdown rewrites image paths but not links.
    sprintf("[![Left to right: %s.](man/figures/backends-%s.png)](%s/backends-%s.png)",
            paste(PANELS, collapse = "; "), view, FIG_URL, view),
    "", "*Click the figure for full size.*", "",
    v$caption, "",
    "**rENA** (`backend` is `\"plotly\"` or `\"qeviz\"`):", "",
    code(v$rena), "",
    "**qeviz directly:**", "",
    code(v$qeviz), "")
}
md <- c(md,
  "---", "",
  "Generated by `data-raw/plot-backends-figures.R`; re-run it after changing",
  "either backend.")
writeLines(md, "PLOT-BACKENDS.md")
message("wrote PLOT-BACKENDS.md")
