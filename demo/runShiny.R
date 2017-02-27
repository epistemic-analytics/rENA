library(R6);
library(data.table);
library(microbenchmark);
library(shiny);
if("sigma" %in% installed.packages() == F) {
  print("Installing Shiny Sigma")
  #devtools::install_url("https://git.doit.wisc.edu/clmarquart/shiny-sigma/repository/archive.zip");
  #devtools::install_local("~/Workspaces/RStudio2/sigma/")
  devtools::install_local("C:/Users/Vincent/dev/shiny-sigma/");
}
library(sigma);

build = T;

haveGoTSet = ls(pattern="gotSet")
if(!is.logical(haveGoTSet) || haveGoTSet != "gotSet") {
  print("Creating the GoT set.");
  if(build == T) {
    source('./R/buildSet_got.R');
  } else {
    load(file = "./demo/gotSet.RData")
  }
}
runApp("./demo/shiny", port=7705, launch.browser = F)
