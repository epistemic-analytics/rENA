context("test-trajectory-smoothing")

test_that("ena.plot.trajectory supports polynomial smoothing and raw points", {
  data(RS.data)
  codeNames = c('Data','Technical.Constraints','Performance.Parameters',
    'Client.and.Consultant.Requests','Design.Reasoning','Collaboration')

  accum = ena.accumulate.data(
    units = RS.data[,c("UserName","Condition")],
    conversation = RS.data[,c("GroupName","ActivityNumber")],
    codes = RS.data[,codeNames],
    window.size.back = 4,
    model = "A"
  )
  set = ena.make.set(accum)

  plot = ena.plot(set)
  points = as.matrix(set$points)[1:20, 1:2]
  by_unit = set$trajectories$ENA_UNIT[1:20]

  # Test standard trajectory
  p1 = ena.plot.trajectory(
    plot,
    points = points,
    by = by_unit,
    smooth = "none"
  )
  expect_true(!is.null(p1$plot))

  # Test polynomial trajectory smoothing
  p2 = ena.plot.trajectory(
    plot,
    points = points,
    by = by_unit,
    smooth = "poly",
    poly.max.degree = 2L,
    show.points = TRUE,
    show.curve = TRUE
  )
  expect_true(!is.null(p2$plot))
})

test_that("ena.plot.movie creates an animated Plotly trajectory object", {
  data(RS.data)
  codeNames = c('Data','Technical.Constraints','Performance.Parameters',
    'Client.and.Consultant.Requests','Design.Reasoning','Collaboration')

  accum = ena.accumulate.data(
    units = RS.data[,c("UserName","Condition")],
    conversation = RS.data[,c("GroupName","ActivityNumber")],
    codes = RS.data[,codeNames],
    window.size.back = 4,
    model = "A"
  )
  set = ena.make.set(accum)

  plot = ena.plot(set)
  points = as.matrix(set$points)[1:30, 1:2]
  by_unit = set$trajectories$ENA_UNIT[1:30]
  times = seq_len(30)

  mov = ena.plot.movie(
    plot,
    points = points,
    by = by_unit,
    time = times,
    frame_ms = 100
  )
  expect_true(!is.null(mov))
  expect_true(inherits(mov, "plotly"))
})
