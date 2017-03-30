library(R6);
library(data.table);
library(microbenchmark);



source('R/ENAdata.R');
source('R/ENAset.R');
source('R/accumulate.data.R');
Rcpp::sourceCpp('src/svector_to_ut.cpp');
Rcpp::sourceCpp('src/ref_window_df.cpp');
Rcpp::sourceCpp('src/ref_window_sum.cpp');
Rcpp::sourceCpp('src/vector_to_ut.cpp');

Rcpp::sourceCpp('src/ena.cpp');
source('R/do_optimization.R');
source('R/full_opt_soln.R');

#load("~/old-df.RData")
#load('./data/581a266034064f4f6c8d4e87.rdata');
#load('./data/58178a2f34064f4f6c8d4e66.rdata');
#GoTSet = `all_starks&lann`;

#jaimeSet = eg_jaime_ep_season;
codeNames = c('Arya','Jaime','Cersei','Robert.Baratheon','Joffrey','Tommen','Robb','Catelyn','Ned','Hodor','Tyrion','Bronn','Brienne','Margaery','Olenna','Tywin','The.Hound','Oberyn','Littlefinger','Varys','Theon','Ramsay','Sansa','Jon.Snow','Ygritte','Myrcella','Sam','Bran','Rickon');
codeNames_less = codeNames[1:4];

codeNames_Jaime = c('Arya','Jaime','Cersei','Robert.Baratheon','Joffrey','Tommen','Robb','Catelyn','Ned','Tyrion','Bronn','Brienne','Tywin','Bran'); #,'Sansa');
codeNames_Jaime2 = c('Arya','Jaime','Cersei','Robert.Baratheon','Joffrey','Tommen','Robb','Catelyn','Ned','Tyrion','Bronn','Brienne','Tywin','Bran','Sansa');


GoT = read.csv("./data/GoT-ENA-ego-heads-v3.csv")

sNorm = sphere_norm_c;

unitsBy=unitsBy = c("season", "episode", "character", "house")
unitsSelected=c("Jaime","Ned")

units = unique(data.table(GoT)[ character %in% unitsSelected ,{apply(.SD,1,function(x){paste(trimws(x),collapse=".")})},with=T,.SDcols=unitsBy]);

runIt1 <- function() {
  gotData = ENAdata$new(GoT, unitsBy = unitsBy, units = units, conversationsBy = c("unique_id"), codeNames = codeNames_Jaime, unitsSelected = unitsSelected, windowSize = 1);
  gotSet = ENAset$new(gotData, sphere.norm = sNorm, binary = T, optim.method = do_optimization)$process()
}

runIt2 <- function() {
  gotData2 = ENAdata$new(GoT[1:1111,], unitsBy = unitsBy, units = units, conversationsBy = c("unique_id"), codeNames = codeNames_Jaime, unitsSelected = unitsSelected, windowSize = 1);
  gotSet2 = ENAset$new(gotData2, sphere.norm = sNorm, binary = T, optim.method = do_optimization_2)$process()
}


done = microbenchmark(runIt1(),runIt2(), times=10)
print(done)

