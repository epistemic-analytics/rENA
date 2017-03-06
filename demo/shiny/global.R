debug <- F;

print("Global file loaded.")

housesList = list(
  list(house="Stark", color="#4c4c4c", colors=c("#2980b9","#e5901a"), img = T),
  list(house="Lannister", color="#a41d1e", colors=c("#e74c3c","#52aa6f"), img = T),
  list(house="Baratheon", color="#c4c452", img = T),
  list(house="Targaryen", color="#2c2f30", img = T),
  list(house="Martell", color="#f0863a", img = T),
  list(house="Tyrell", color="#7ace94", img = T),
  list(house="Tully", color="#2c2f66", img = T),
  list(house="Arryn", color="#1671F4", img = T),
  list(house="Greyjoy", color="#2c2f66", img = T),
  list(house="Frey", color="#133547", img = T),
  list(house="Bolton", color="#1e1e1e", img = T),
  list(house="Wildlings", color="#232323", img = T),
  list(house="Extra", color="#a6d3eb", img = F)
)

housesListJSON = rjson::toJSON(housesList)

library(data.table);
library(sigma);
library(R6);
library(RcppArmadillo);

Rcpp::sourceCpp('../../src/ena.cpp')
Rcpp::sourceCpp('../../src/ref_window_sum.cpp')
Rcpp::sourceCpp('../../src/svector_to_ut.cpp')
Rcpp::sourceCpp('../../src/ref_window_df.cpp')
Rcpp::sourceCpp('../../src/vector_to_ut.cpp');
source("../../R/accumulate.R");
source('../../R/do_optimization.R');
source('../../R/do_scale.R');
source("../../R/ENAdata.R");
source("../../R/ENAset.R");


#filename = "../../data/GoT-ENA-ego-heads-v3.csv"
filename = "../../data/got-ena-ego-v1.csv"
if(!file.exists(filename)) {
  filename = substring(filename,first=5);
}
if(file.exists(filename)) {
  print("Creating initial gotSet.");
  GoT = read.csv(filename)
  gotData = ENAdata$new(
    GoT,
    unitsBy = c("season", "episode", "character", "house"),
    units = NULL, conversationsBy = c("unique_id"),
    codeNames = gsub("\\.", "_", c('Arya','Jaime','Cersei','Robert.Baratheon','Joffrey','Tommen','Robb','Catelyn','Ned','Tyrion','Bronn','Brienne','Tywin','Bran')),
    unitsSelected = c("Jaime"),
    windowSize = 0,
    exact.match = T
  );
  gotSet = ENAset$new(gotData, sphereNorm = T)
  gotSet$process();
}
