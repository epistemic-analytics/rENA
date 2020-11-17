#!/bin/bash

export Rbin="$1"

cd /
rm rENA_0.2.0.2.tar.gz

cd rENA/
rm src/*.o
rm src/*.so
rm src/RcppExports*
rm R/RcppExports*
$Rbin -e 'Rcpp::compileAttributes()'
$Rbin -e " devtools::document(roclets = c('rd', 'collate', 'namespace', 'vignette'))"

cd /
$Rbin CMD build rENA/ --no-build-vignettes
$Rbin CMD INSTALL rENA_0.2.0.2.tar.gz

cd rENA/tests/
rm *.Rout
rm *.Rout.fail
$Rbin -e 'tools:::.runPackageTestsR()'

cd /
cat rENA/tests/testthat.Rout | grep -B4 'ena.cpp'
cat rENA/tests/testthat.Rout.fail | grep -B4 'ena.cpp'

# cd rENA/demo/backup/
# Rbin -f test-simple-san-check.R
