library(R6);
library(data.table);
library(microbenchmark);
library(plotly);

source('R/rENA.R');

Rcpp::sourceCpp('src/ena.cpp');
Rcpp::sourceCpp('src/svector_to_ut.cpp');
Rcpp::sourceCpp('src/ref_window_df.cpp');
Rcpp::sourceCpp('src/ref_window_sum.cpp');
Rcpp::sourceCpp('src/merge_columns_c.cpp');

source('R/accumulate.data.R');
source('R/do_optimization.R');
source('R/full_opt_soln.R');
source('R/ENAdata.R');
source('R/ENAset.R');

load("~/old-df.RData")

#codeNames = c("E.data","S.data","E.design","S.design","S.professional","E.client","V.client","E.consultant","V.consultant","S.collaboration","I.engineer","I.intern","K.actuator","K.rom","K.materials","K.power");
codeNames = c("E.data","S.data","E.design","S.design","S.professional","E.client","V.client","E.consultant","V.consultant","S.collaboration","I.engineer","I.intern","K.actuator","K.rom","K.materials","K.power");
codeNames_less = codeNames[1:4];

units_all_names = c("akash v","alexander b","amelia n","arden f","brandon l","cameron k","connor f","devin c","jimmy i","jordan l","joseph l","margaret n","peter p","robert z","steven z","tiffany x","abigail z","brandon f","brent p","cameron i","christina b","cormick u","daniel t","derek v","jackson p","keegan q","kiana k","luke u","madeline g","nathan d","nicholas l","nicholas n","ruzhen e","shane t","caitlyn y","justin y","samuel o","fletcher l","amirah u","carl b","christian x","kevin g","casey f","luis t","mitchell h","amalia x");
units_less_names = units_all_names[1:4];

runIt <- function() {
  enadata = ENAdata$new(
    df, #"./inst/extdata/rs.data.sorted.csv",
    unitsBy = c("UserName","Condition"),
    conversationsBy = c("ActivityNumber", "GroupName"),
    codeNames = codeNames, #_less,
    windowSize = 1
  );
  enaset = ENAset$new(enadata, optim.method=do_optimization_2, inPar=F)$process();
}

done = microbenchmark(runIt(), times=1)
print(done)

#source('~/Workspaces/RStudio2/rENA/demo/plotTests.R')
