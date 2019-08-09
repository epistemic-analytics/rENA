suppressMessages(library(rENA, quietly = T, verbose = F))
context("Test making sets");

test_that("Simple data.frame to accumulate and make set", {
  codenames <- c("Data", "Technical.Constraints", "Performance.Parameters",
    "Client.and.Consultant.Requests", "Design.Reasoning", "Collaboration");

  data(RS.data)
  df.file <- RS.data
  accum <- ena.accumulate.data.file(
    RS.data, units.by = c("UserName", "Condition"),
    conversations.by = c("ActivityNumber", "GroupName"),
    codes = codenames
  );
  set <- ena.make.set(accum)

  testthat::expect_equal(
    label = "Used 6 codes",
    object = length(set$rotation$codes),
    expected = 6
  );
  testthat::expect_equal(
    label = "48 units with all dimensions",
    object = dim(as.matrix(set$points)),
    expected = c(48,choose(length(codenames),2))
  );
  testthat::expect_equal(
    label = "Has all 48 units",
    object = length(set$model$unit.labels),
    expected = 48
  );
})

test_that("Test custom rotation.set", {
  codenames <- c("Data", "Technical.Constraints", "Performance.Parameters",
    "Client.and.Consultant.Requests", "Design.Reasoning", "Collaboration");

  data(RS.data)
  df.file <- RS.data

  conversations.by <- c("Condition", "ActivityNumber", "GroupName")
  df_accum_grps <- ena.accumulate.data.file(
    df.file, units.by = c("GroupName", "Condition"),
    conversations.by = conversations.by, codes = codenames);
  df_accum_usrs <- ena.accumulate.data.file(
    df.file, units.by = c("UserName", "Condition"),
    conversations.by = conversations.by, codes = codenames);

  df_set_grps <- ena.make.set(df_accum_grps)
  df_set_usrs <- ena.make.set(df_accum_usrs)
  df_set_grps_usrs = ena.make.set(
    df_accum_grps, rotation.set = df_set_usrs$rotation)

  expect_true(all(
    df_set_grps_usrs$rotation.matrix == df_set_usrs$rotation.matrix
  ))
  expect_false(all(
    df_set_grps_usrs$rotation.matrix == df_set_grps$rotation.matrix
  ))

  expect_equal(df_set_usrs$rotation$nodes, df_set_grps_usrs$rotation$nodes)

  expect_equal(df_set_grps$line.weights, df_set_grps_usrs$line.weights)
})

test_that("Test rotate by mean", {
  codenames <- c("Data", "Technical.Constraints", "Performance.Parameters",
    "Client.and.Consultant.Requests", "Design.Reasoning", "Collaboration");

  data(RS.data)
  df.file <- RS.data

  conversations.by <- c("Condition", "ActivityNumber", "GroupName")
  df_accum_usrs <- ena.accumulate.data.file(
    df.file, units.by = c("UserName", "Condition"),
    conversations.by = conversations.by, codes = codenames);

  set.svd <- ena.make.set(df_accum_usrs)
  set.mr <- ena.make.set(df_accum_usrs,
    rotation.by = ena.rotate.by.mean,
    rotation.params = list(
      df_accum_usrs$meta.data$Condition == "FirstGame",
      df_accum_usrs$meta.data$Condition == "SecondGame"
    ) 
  );

  expect_equal(ncol(set.svd$rotation.matrix), ncol(set.mr$rotation.matrix))

  expect_equal(
    colnames(set.svd$rotation.matrix),
    colnames(as.matrix(set.svd$points))
  )
  expect_equal(
    colnames(set.mr$rotation.matrix), colnames(as.matrix(set.mr$points))
  )
  expect_equal("MR1", colnames(set.mr$rotation.matrix)[1])
  expect_equal("SVD1", colnames(set.svd$rotation.matrix)[1])
})