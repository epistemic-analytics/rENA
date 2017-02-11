#load data set
load("demo/gotSet.RData");

#install shiny-sigma
#devtools::install_url("https://git.doit.wisc.edu/clmarquart/shiny-sigma/repository/archive.zip");
devtools::install_local("C:/Users/Vincent/dev/shiny-sigma/");
library(sigma);

#reference library shiny
library(shiny);

#source other files
Rcpp::sourceCpp('src/svector_to_ut.cpp');
source('C:/Users/Vincent/dev/rena/R/accumulate.R');

#run the app
runApp("./demo/shiny", port=7705, launch.browser = F);

