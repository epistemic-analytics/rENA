suppressMessages(library(rENA, quietly = T, verbose = F))
context("Test accumulating data");

test_that("Simple data.frame to accumulate", {
  fake.codes.len = 10;
  fake.codes <- function(x) sample(0:1,fake.codes.len, replace=T)

  code.names = paste("Codes",LETTERS[1:fake.codes.len],sep="-");

  df = data.frame(
    Name=c("J","Z"),
    Day=c(1,1,1,1,1,1,2,2,2,2,2,2),
    c1=c(1,1,1,1,1,0,0,1,1,0,0,1),
    c2=c(1,1,1,0,0,1,0,1,0,1,0,0),
    c3=c(0,0,1,0,1,0,1,0,0,0,1,0),
    c4=c(1,1,1,0,0,1,0,1,0,1,0,0)
  );

  df.accum = ena.accumulate.data(df, units.by = c("Name"), conversations.by = c("Day"), code.names = c("c1","c2","c3"));
  df.accum.weighted = ena.accumulate.data(df, units.by = c("Name"), conversations.by = c("Day"), code.names = c("c1","c2","c3"), binary = F);

  expect_true(all(
    as.matrix(df.accum$data.units.summed[, attr(df.accum$data.units.summed,"adjacency.codes"), with=F])
      ==
    matrix(c(2,2,2,0,1,0), nrow=length(unique(df.accum$get("units"))))
  ));
})

test_that("Accumulate weighted data.", {
  testdata = runif(24, 0, 1)
  testmat = matrix(testdata, 4, dimnames=list(NULL,LETTERS[1:6]))
  testmeta = data.frame(tr=1:4, unit=rep(1, 4))
  testdf = cbind(testmeta, testmat)

  x = ena.accumulate.data(testdf,
                          units.by='unit',
                          conversations.by='tr',
                          units='1',
                          code.names=LETTERS[1:6],
                          window.size=4,
                          binary=F)


  testthat::expect_true(all(apply(x$data.units.summed.meta[,.SD,.SDcols=colnames(x$data.units.summed.meta)[grep("^adj",colnames(x$data.units.summed.meta))]], 2, is.double)))
})

test_that("Simple forwarded metadata", {
  fake.codes.len = 10;
  fake.codes <- function(x) sample(0:1,fake.codes.len, replace=T)

  code.names = paste("Codes",LETTERS[1:fake.codes.len],sep="-");

  df = data.frame(
    Name=c("J","Z"),
    Day=c(1,1,1,1,1,1,2,2,2,2,2,2),
    c1=c(1,1,1,1,1,0,0,1,1,0,0,1),
    c2=c(1,1,1,0,0,1,0,1,0,1,0,0),
    c3=c(0,0,1,0,1,0,1,0,0,0,1,0),
    m1=c(1,2),
    m2=c(1,2,3,4)
  );

  df.accum = ena.accumulate.data(df, units.by = c("Name"), conversations.by = c("Day"), code.names = c("c1","c2","c3"));

  expect_true("m1" %in% colnames(df.accum$data.units.summed.meta));
});
test_that("Test trajectories", {
  fake.codes.len = 10;
  fake.codes <- function(x) sample(0:1,fake.codes.len, replace=T)

  code.names = paste("Codes",LETTERS[1:fake.codes.len],sep="-");

  df = data.frame(
    Name=c("J","Z"),
    Day=c(1,1,1,1,1,1,2,2,2,2,2,2),
    Activity=c(1,1,1,1,2,2,2,2,3,3,3,3),
    c1=c(1,1,1,1,1,0,0,1,1,0,0,1),
    c2=c(1,1,1,0,0,1,0,0,0,0,0,1),
    c3=c(0,0,1,0,1,0,1,0,0,0,1,0)
  );

  df.accum = ena.accumulate.data(
    df, units.by = c("Name"), conversations.by = c("Day"), code.names = c("c1","c2","c3")
    ,trajectory.by = c("Activity"), trajectory.type = "accumulated"
  );
  df.non.accum = ena.accumulate.data(
    df, units.by = c("Name"), conversations.by = c("Day"), code.names = c("c1","c2","c3")
    ,trajectory.by = c("Activity"), trajectory.type = "non-accumulated"
  );

  # Test for expected accumulated value
    expect_equal(df.accum$data.units.summed[Name == "J" & Activity == 3, adjacency.code.1],df.accum$data.units.accumulated[Name == "J", sum(adjacency.code.1)]);

  # Test for a value of 1 in the first accumulation of the trajectory of code 1
  expect_true(sum(df.accum$data.units.accumulated[Name == "Z" & Activity == 1, adjacency.code.1]) == 1);
  # Test for a value of 0 in the second accumulation of the trajectory of code 1
    expect_true(all(df.accum$data.units.accumulated[Name == "Z" & Activity == 2, adjacency.code.1] == 0));
  # Test that the first summed trajectory is 1
    expect_equal(df.accum$data.units.summed[Name == "Z" & Activity == 1, adjacency.code.1], 1);
  # Test that the second summed trajectory is 1, even thought it had a zero accumulation for it's conversations
    expect_equal(df.accum$data.units.summed[Name == "Z" & Activity == 2, adjacency.code.1], 1);

  # Test that non-accumulation is properly leaving second trajectory group 0 (different than the previous test)
    expect_identical(c(1,0,1), df.non.accum$data.units.summed[Name == "Z", adjacency.code.1]);
})
