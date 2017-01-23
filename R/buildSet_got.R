library(R6);
library(data.table);
library(microbenchmark);
library(shiny);
#devtools::install_local("~/Workspaces/RStudio2/sigma/"); library(sigma);

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

load('./data/581a266034064f4f6c8d4e87.rdata');
load('./data/58178a2f34064f4f6c8d4e66.rdata');

GoTSet = `all_starks&lann`;
jaimeSet = eg_jaime_ep_season;

codeNames = c('Arya','Jaime','Cersei','Robert.Baratheon','Joffrey','Tommen','Robb','Catelyn','Ned','Hodor','Tyrion','Bronn','Brienne','Margaery','Olenna','Tywin','The.Hound','Oberyn','Littlefinger','Varys','Theon','Ramsay','Sansa','Jon.Snow','Ygritte','Myrcella','Sam','Bran','Rickon');
codeNames_less = codeNames[1:4];

codeNames_Jaime = c('Arya','Jaime','Cersei','Robert.Baratheon','Joffrey','Tommen','Robb','Catelyn','Ned','Tyrion','Bronn','Brienne','Tywin','Bran');

unitNames_Jaime = c('1.1.Jaime','3.1.Jaime','5.1.Jaime','7.1.Jaime','10.1.Jaime','7.2.Jaime','8.2.Jaime','10.2.Jaime','2.3.Jaime','3.3.Jaime','4.3.Jaime','5.3.Jaime','6.3.Jaime','7.3.Jaime','10.3.Jaime','1.4.Jaime','2.4.Jaime','4.4.Jaime','7.4.Jaime','8.4.Jaime','10.4.Jaime','1.5.Jaime','2.5.Jaime','4.5.Jaime','6.5.Jaime','7.5.Jaime','9.5.Jaime','10.5.Jaime','1.6.Jaime','2.6.Jaime','3.6.Jaime','4.6.Jaime','6.6.Jaime','7.6.Jaime','8.6.Jaime','10.6.Jaime');

GoT = read.csv("./data/GoT-ENA-ego-heads-v3.csv")

gotData = ENAdata$new(GoT, unitsBy = c("episode", "season", "character"), units = NULL, conversationsBy = c("unique_id"), codeNames = codeNames_Jaime, unitsSelected = c("Jaime"), windowSize = 1, exact.match = T );

#runIt <- function() {
gotSet = ENAset$new(gotData, sphereNorm = T)
gotSet$process();
gotSet$plot();
#}
#done = microbenchmark(runIt(), times=100)
#print(done)

#source('~/Workspaces/RStudio2/rENA/demo/plotTests.R')

print("Done.")
