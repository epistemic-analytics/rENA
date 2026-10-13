## data-raw/plot-backends-figures.R — the figures in ?rENA-plot-backends
##
## Draws the same rENA plotting code with backend = "plotly" and "qeviz" and
## screenshots each pair side by side with headless Chrome:
##
##   man/figures/backends-network.png       one group's network and mean
##   man/figures/backends-subtraction.png   FirstGame − SecondGame, both means
##   man/figures/backends-points.png        all units by condition, both means
##
##   Rscript data-raw/plot-backends-figures.R     (from the package root)
##
## Needs qeviz >= 0.5.0, htmlwidgets, plotly and Google Chrome (set CHROME to
## use another binary). Re-run after changing either backend's look.

pkgload::load_all(".", quiet = TRUE)

chrome <- Sys.getenv("CHROME", "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
out_dir <- file.path("man", "figures")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
work <- tempfile("backends-figures-")
dir.create(work)

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
first <- set$meta.data$Condition == "FirstGame"
second <- set$meta.data$Condition == "SecondGame"
lw <- as.matrix(set$line.weights)
pts <- as.matrix(set$points)

# Each view is ordinary rENA code; only `backend` differs between the panels.
views <- list(
  network = function(backend) {
    p <- ena.plot(set, title = "FirstGame", backend = backend)
    p <- ena.plot.network(p, network = colMeans(lw[first, ]))
    ena.plot.group(p, pts[first, ], labels = "FirstGame", colors = "red",
                   confidence.interval = "box")
  },
  subtraction = function(backend) {
    p <- ena.plot(set, title = "FirstGame - SecondGame", backend = backend)
    p <- ena.plot.network(p, network = colMeans(lw[first, ]) - colMeans(lw[second, ]),
                          colors = c("red", "blue"))
    p <- ena.plot.group(p, pts[first, ], labels = "FirstGame", colors = "red",
                        confidence.interval = "box")
    ena.plot.group(p, pts[second, ], labels = "SecondGame", colors = "blue",
                   confidence.interval = "box")
  },
  points = function(backend) {
    p <- ena.plot(set, title = "Units and means", scale.to = "points", backend = backend)
    p <- ena.plot.points(p, pts[first, ], colors = "red")
    p <- ena.plot.points(p, pts[second, ], colors = "blue")
    p <- ena.plot.group(p, pts[first, ], labels = "FirstGame", colors = "red",
                        confidence.interval = "box")
    ena.plot.group(p, pts[second, ], labels = "SecondGame", colors = "blue",
                   confidence.interval = "box")
  }
)

W <- 520; H <- 520   # each panel

save_panel <- function(view, backend) {
  w <- views[[view]](backend)$plot
  w$width <- W; w$height <- H
  # saveWidget's standalone page pads the widget by 40px; the frame is exact.
  w$sizingPolicy$padding <- 0
  w$sizingPolicy$browser$padding <- 0
  f <- file.path(work, sprintf("%s-%s.html", view, backend))
  suppressWarnings(htmlwidgets::saveWidget(w, f, selfcontained = FALSE, libdir = "lib",
                                           background = "white"))
  basename(f)
}

page <- function(view) {
  left <- save_panel(view, "plotly")
  right <- save_panel(view, "qeviz")
  html <- sprintf('<!doctype html><meta charset="utf-8">
<style>
  body { margin: 0; background: #fff; font: 600 15px/1.2 -apple-system, Helvetica, Arial, sans-serif; color: #333; }
  .row { display: flex; gap: 16px; padding: 12px 16px 0; }
  .col { width: %dpx; }
  .col div { padding: 0 0 6px 4px; }
  iframe { width: %dpx; height: %dpx; border: 1px solid #ddd; }
</style>
<div class="row">
  <div class="col"><div>backend = "plotly" (default)</div><iframe src="%s"></iframe></div>
  <div class="col"><div>backend = "qeviz"</div><iframe src="%s"></iframe></div>
</div>', W, W, H, left, right)
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

for (view in names(views)) {
  png <- file.path(out_dir, sprintf("backends-%s.png", view))
  screenshot(page(view), png, width = 2 * W + 3 * 16 + 4, height = H + 12 + 26 + 4)
  message("wrote ", png, " (", round(file.size(png) / 1024), " KB)")
}
