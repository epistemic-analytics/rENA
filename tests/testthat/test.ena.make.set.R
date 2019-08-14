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
  df_accum_grps <- rENA:::ena.accumulate.data.file(
    df.file, units.by = c("GroupName", "Condition"),
    conversations.by = conversations.by, codes = codenames);
  df_accum_usrs <- ena.accumulate.data.file(
    df.file, units.by = c("UserName", "Condition"),
    conversations.by = conversations.by, codes = codenames);

  df_set_grps <- ena.make.set(df_accum_grps)
  df_set_usrs <- ena.make.set(df_accum_usrs)
  df_set_grps_usrs <- ena.make.set(
    df_accum_grps, rotation.set = df_set_usrs$rotation)

  expect_true(all(
    df_set_grps_usrs$rotation.matrix == df_set_usrs$rotation.matrix
  ))
  expect_false(all(
    df_set_grps_usrs$rotation.matrix == df_set_grps$rotation.matrix
  ))
  expect_equal(df_set_usrs$rotation$nodes, df_set_grps_usrs$rotation$nodes)
  expect_equal(df_set_grps$line.weights, df_set_grps_usrs$line.weights)

  testthat::expect_error(
    df_set_bogus <- ena.make.set(df_accum_grps, rotation.set = list()),
    regexp = "rotation.set is not an instance"
  )
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

test_that("Test rotation with table for weights", {
  codenames <- c("Data", "Technical.Constraints", "Performance.Parameters",
    "Client.and.Consultant.Requests", "Design.Reasoning", "Collaboration");

  data(RS.data)
  df.file <- RS.data

  conversations.by <- c("Condition", "ActivityNumber", "GroupName")
  df_accum_usrs <- rENA:::ena.accumulate.data.file(
    df.file, units.by = c("UserName", "Condition"),
    conversations.by = conversations.by, codes = codenames);

  testthat::expect_error(set.mr <- ena.make.set(df_accum_usrs,
    rotation.by = ena.rotate.by.mean,
    rotation.params = list()
  ))

  rotate.grps <- list(
    df_accum_usrs$meta.data$Condition == "FirstGame",
    df_accum_usrs$meta.data$Condition == "SecondGame"
  )
  set.svd <- ena.make.set(df_accum_usrs)
  set.svd$line.weights <- remove.meta.data(set.svd$line.weights)

  testthat::expect_message(
    rENA:::orthogonal_svd(
      set.svd$line.weights,
      matrix(0, nrow = ncol(set.svd$line.weights), ncol = 2)
    ),
    regexp = "converting data to matrix"
  )
})

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

})

test_that("Test bad position method", {
  codenames <- c("Data", "Technical.Constraints", "Performance.Parameters",
    "Client.and.Consultant.Requests", "Design.Reasoning", "Collaboration");

  data(RS.data)
  df.file <- RS.data

  conversations.by <- c("Condition", "ActivityNumber", "GroupName")
  acc <- rENA:::ena.accumulate.data.file(
    df.file, units.by = c("UserName", "Condition"),
    conversations.by = conversations.by, codes = codenames);

  bad_positions <- function(enaset, groups) {
    return(list(bad = 1))
  }
  testthat::expect_error(
    ena.make.set(acc, node.position.method = bad_positions),
    regexp = "position method didn't return back the expected objects"
  )

  custom_rotation <- structure(list(),class = "ena.rotation.matrix")
  testthat::expect_error(
    ena.make.set(acc, rotation.by = NULL, rotation.set = custom_rotation),
    regexp = "no rotation matrix"
  )

  custom_rotation$rotation.matrix <- matrix(1,
    ncol = ncol(acc$rotation$adjacency.key),
    nrow = ncol(acc$rotation$adjacency.key)
  )
  testthat::expect_error(
    ena.make.set(acc, rotation.by = NULL, rotation.set = custom_rotation),
    regexp = "Unable to determine the node positions"
  )

  testthat::expect_error(
    ena.make.set(acc, rotation.by = NULL, rotation.set = NULL),
    regexp = "Unable to find or create a rotation set"
  )
})
