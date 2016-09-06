library("data.table");
library(RcppRoll);
Rcpp::sourceCpp('src/svector_to_ut.cpp')
Rcpp::sourceCpp('src/dfvector_to_ut.cpp')
Rcpp::sourceCpp('src/vector_to_ut.cpp')
source('~/Workspaces/RStudio2/rENA/R/old.accumulation.R');
source('~/Workspaces/RStudio2/rENA/R/roll.sum.pad.R');
source('~/Workspaces/RStudio2/rENA/R/lagpad.R');
source('~/Workspaces/RStudio2/rENA/R/accumulate.R');

df = read.csv("./data/rs.data.sorted.csv");
#df = df[order(as.POSIXlt(df$Timestamp, format = "%m/%d/%Y %H:%M")), ]

#codeNames = c("E.data","S.data","E.design","S.design","S.professional","E.client","V.client","E.consultant", "V.consultant", "S.collaboration", "I.engineer",   "I.intern","K.actuator",   "K.rom", "K.materials",  "K.power","K.sensor", "K.design.specs","K.attribute",  "K.data","K.design","Tradeoffs","Performance.Parameters","Constraints.and.Requests","Collaboration","Data");
codeNames = c("E.data","S.data","E.design","S.design"); #,"S.professional","E.client","V.client","E.consultant","V.consultant","S.collaboration","I.engineer","I.intern","K.actuator","K.rom","K.materials","K.power");

unitsBy = c("UserName");
#unitsListTable = data.frame(unique(df[, unitsBy]));
unitsListTable = data.frame(df[, unitsBy]);
colnames(unitsListTable) = unitsBy;
unitsList = unitsListTable; #data.frame(dfDT[, paste(collapse = " & ", UserName), by = unitsBy]);

conversationsBy = c("ActivityNumber", "GroupName");
conversations = df[, conversationsBy]
conversationsList = unique(conversations)

sList = paste(conversationsList$ActivityNumber, conversationsList$GroupName, sep = " & ");
gList = c("akash v", "alexander b", "amelia n", "tiffany x"); #paste(unitsList$UserName, sep = " & ");
uList = gList;

benchRes = microbenchmark(
  #old.accumulation(window = 1,codes = df[,codeNames],group = unitsList,units = unitsList,stanzas = conversations,sList = sList,gList = gList,uList = uList, binary = T),
  accumulate(df, c(), codeNames, window=1)
)


