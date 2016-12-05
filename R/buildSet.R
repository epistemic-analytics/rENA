library(R6);
library(data.table);
library(microbenchmark);

Rcpp::sourceCpp('src/ena.cpp');
Rcpp::sourceCpp('src/svector_to_ut.cpp');
Rcpp::sourceCpp('src/ref_window_df.cpp');
Rcpp::sourceCpp('src/ref_window_sum.cpp');

load("~/old-df.RData")

source('R/accumulate.R');
source('R/do_optimization.R');
source('R/do_scale.R');
source('R/ENAdata.R');
source('R/ENAset.R');

codeNames_less = c("E.data","S.data","E.design","S.design");
#codeNames = c("E.data","S.data","E.design","S.design","S.professional","E.client","V.client","E.consultant","V.consultant","S.collaboration","I.engineer","I.intern","K.actuator","K.rom","K.materials","K.power");
codeNames = c("E.data","S.data","E.design","S.design","S.professional","E.client","V.client","E.consultant","V.consultant","S.collaboration","I.engineer","I.intern","K.actuator","K.rom","K.materials","K.power");


units_all_names = c("akash v","alexander b","amelia n","arden f","brandon l","cameron k","connor f","devin c","jimmy i","jordan l","joseph l","margaret n","peter p","robert z","steven z","tiffany x","abigail z","brandon f","brent p","cameron i","christina b","cormick u","daniel t","derek v","jackson p","keegan q","kiana k","luke u","madeline g","nathan d","nicholas l","nicholas n","ruzhen e","shane t","caitlyn y","justin y","samuel o","fletcher l","amirah u","carl b","christian x","kevin g","casey f","luis t","mitchell h","amalia x");
units_less_names = units_all_names[1:4];

enadata = ENAdata$new(
  df, #"./data/rs.data.sorted.csv",
  unitsBy = c("UserName"), #,"Condition"),
  units = units_all_names,
  conversationsBy = c("ActivityNumber", "GroupName"),
  codeNames = codeNames,
  windowSize = 1
);

runIt <- function() {
  enaset = ENAset$new(enadata, sphereNorm = F)
  enaset$process();
}

done = microbenchmark(runIt(), times=1)
print(done)

#source('~/Workspaces/RStudio2/rENA/demo/plotTests.R')
