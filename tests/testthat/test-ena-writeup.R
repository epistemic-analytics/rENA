context("ENA writeup")

test_that("ena.writeup streams the methods text without touching the working directory", {
  skip_if_not_installed("rmarkdown")
  skip_if_not_installed("knitr")
  skip_if_not(rmarkdown::pandoc_available(), "pandoc not available")
  data(RS.data)
  codeNames <- c("Data", "Technical.Constraints", "Performance.Parameters",
                 "Client.and.Consultant.Requests", "Design.Reasoning", "Collaboration")
  set <- ena.make.set(ena.accumulate.data(
    units = RS.data[, c("Condition", "UserName")],
    conversation = RS.data[, c("Condition", "GroupName")],
    codes = RS.data[, codeNames], window.size.back = 4
  ))

  wd <- tempfile("wd")
  dir.create(wd)
  old <- setwd(wd)
  on.exit(setwd(old), add = TRUE)

  text <- ena.writeup(set, type = "stream")
  expect_match(text, "Epistemic Network Analysis", fixed = TRUE)
  expect_length(list.files(wd, all.files = TRUE, no.. = TRUE), 0)
})
