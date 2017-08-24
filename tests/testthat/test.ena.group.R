suppressMessages(library(rENA, quietly = T, verbose = F))
context("Test creating groups");

df <- system.file("extdata", "rs.data.csv", package="rENA")
codeNames = c("E.data","S.data","E.design","S.design","S.professional","E.client","V.client","E.consultant","V.consultant","S.collaboration","I.engineer","I.intern","K.actuator","K.rom","K.materials","K.power");
accum = ena.accumulate.data.file(df, units.by = c("UserName","Condition"), conversations.by = c("ActivityNumber","GroupName"), codes = codeNames);
set = ena.make.set(accum, position.method = lws.positions.es)


test_that("Mean set points and edges (default)", {
  means = ena.group(set, by=accum$metadata$Condition)
  testthat::expect_equal(
    label="Group result row count same has unique values of by",
    object=nrow(means$points),
    expected=length(unique(accum$metadata$Condition))
  );
})
test_that("Mean arbitrary point matrix", {
  means = ena.group(set$points.rotated, by =accum$metadata$Condition);
  testthat::expect_equal(
    label="Group result row count same has unique values of by",
    object=nrow(means),
    expected=length(unique(accum$metadata$Condition))
  );
});
test_that("Use custom method", {
  custom <- function(x) {
    return(99)
  };
  means=ena.group(set$points.rotated, by =accum$metadata$Condition, method = custom)
  testthat::expect_true(all(means==99))
  # testthat::expect_equal(
  #   label = "48 units by 2 dimensions",
  #   object = dim(df.set.lws.es$points.rotated),
  #   expected = c(48,2)
  # );
  # testthat::expect_equal(
  #   label = "48 units",
  #   object = length(df.set.lws.es$enadata$unit.names),
  #   expected = 48
  # );
})
