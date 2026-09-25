context("model() passes rotate_params to the rotation function")

codes <- c("Data", "Technical.Constraints", "Performance.Parameters",
           "Client.and.Consultant.Requests", "Design.Reasoning", "Collaboration")
horizon <- c("Condition", "GroupName")

rotation_of <- function(set) unname(as.matrix(set$rotation.matrix))

test_that("a means rotation's two group vectors are passed through (used to error)", {
  data(RS.data)
  acc <- accumulate(RS.data, c("Condition", "UserName"), codes, horizon, default_window = 4)
  groups <- list(acc$meta.data$Condition == "FirstGame", acc$meta.data$Condition == "SecondGame")

  via_model <- model(acc, rotate_fun = ena.rotate.by.mean, rotate_params = groups)
  direct <- acc |> sphere_norm() |> center() |> rotate(wh = ena.rotate.by.mean, params = groups) |>
    project() |> optimize()
  expect_equal(rotation_of(via_model), rotation_of(direct))

  nested <- model(acc, rotate_fun = ena.rotate.by.mean, rotate_params = list(params = groups))
  expect_equal(rotation_of(nested), rotation_of(via_model))
})

test_that("a single generalized-rotation parameter is used, not silently ignored", {
  data(RS.data)
  acc <- accumulate(RS.data, c("Condition", "GameHalf", "UserName"), codes, horizon, default_window = 4)

  by_gamehalf <- model(acc, rotate_params = list(x_var = "GameHalf"))
  nested      <- model(acc, rotate_params = list(params = list(x_var = "GameHalf")))
  default     <- model(acc)   # first unit column: Condition

  expect_equal(rotation_of(by_gamehalf), rotation_of(nested))
  expect_false(isTRUE(all.equal(rotation_of(by_gamehalf), rotation_of(default))))
})

test_that("empty rotate_params keeps rotate()'s default", {
  data(RS.data)
  acc <- accumulate(RS.data, c("Condition", "UserName"), codes, horizon, default_window = 4)
  explicit <- model(acc, rotate_params = list(x_var = "Condition"))
  expect_equal(rotation_of(model(acc)), rotation_of(explicit))
})
