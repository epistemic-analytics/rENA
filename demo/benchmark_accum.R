loadLibraries <- function() {
  library("data.table");
  library(RcppRoll);
  library(microbenchmark);
  Rcpp::sourceCpp('src/svector_to_ut.cpp')
  #Rcpp::sourceCpp('src/dfvector_to_ut.cpp')
  #Rcpp::sourceCpp('src/vector_to_ut.cpp')
  Rcpp::sourceCpp('src/ref_window_df.cpp')
  Rcpp::sourceCpp('src/ref_window_sum.cpp')
  source('~/Workspaces/RStudio2/rENA/R/old.accumulation.R');
  #source('~/Workspaces/RStudio2/rENA/R/roll.sum.pad.R');
  #source('~/Workspaces/RStudio2/rENA/R/lagpad.R');
  source('~/Workspaces/RStudio2/rENA/R/accumulate.R');
}


loadFile <- function(f, codeNames, unitsBy, conversationsBy, windowSize = 1) {
  #df = read.csv(f);
  #df = df[order(as.POSIXlt(df$Timestamp, format = "%m/%d/%Y %H:%M")), ]
  browser()
  #unitsListTable = data.frame(unique(df[, unitsBy]));
  unitsListTable = data.frame(df[, unitsBy]);
  colnames(unitsListTable) = unitsBy;
  unitsList = unitsListTable; #data.frame(dfDT[, paste(collapse = " & ", UserName), by = unitsBy]);

  conversations = df[, conversationsBy]
  conversationsList = unique(conversations)

  #sList = paste(conversationsList$ActivityNumber, conversationsList$GroupName, sep = " & ");
  sList = trimws(unique(apply(df[, colnames(conversationsList)], 1, paste , collapse = " & ")));

  #gList = c("akash v", "alexander b", "amelia n", "tiffany x"); #paste(unitsList$UserName, sep = " & ");
  #dfDT = as.data.table(df);
  #gList = data.frame(as.data.table(df)[, paste(collapse = " & ", UserName), by = unitsBy])$V1;
  gList = apply(as.matrix(unique(df[, colnames(unitsList)], ncol=length(colnames(unitsList)))), 1, paste , collapse = " & ");

  #gList = gList[1:4];
  #uList = gList

  windowSize = 1;

  newRes = accumulate.data(df, conversationsBy, unitsBy, codeNames, window=windowSize)

  return(newRes);
}

f = "./data/rs.data.sorted.csv";

unitsBy = c("UserName");
stanzasBy = c("ActivityNumber","GroupName");

unitsBy_all = c("akash v","alexander b","amelia n","arden f","brandon l","cameron k","connor f","devin c","jimmy i","jordan l","joseph l","margaret n","peter p","robert z","steven z","tiffany x","abigail z","brandon f","brent p","cameron i","christina b","cormick u","daniel t","derek v","jackson p","keegan q","kiana k","luke u","madeline g","nathan d","nicholas l","nicholas n","ruzhen e","shane t","caitlyn y","justin y","samuel o","fletcher l","amirah u","carl b","christian x","kevin g","casey f","luis t","mitchell h","amalia x");
stanzasBy = c("1 & Electric","1 & PAM","1 & Hydraulic","1 & Series Elastic","1 & Pneumatic","2 & Hydraulic","2 & Series Elastic","2 & Electric","2 & PAM","3 & Hydraulic","3 & Electric","3 & PAM","2 & Pneumatic","3 & Series Elastic","4 & Series Elastic","4 & PAM","4 & Electric","4 & Pneumatic","4 & Hydraulic","5 & Series Elastic","5 & Hydraulic","5 & Electric","5 & PAM","5 & Pneumatic","3 & Pneumatic","6 & Series Elastic","6 & PAM","6 & Pneumatic","7 & Series Elastic","7 & Hydraulic","7 & Electric","7 & PAM","7 & Pneumatic","8 & Series Elastic","8 & PAM","8 & Hydraulic","8 & Pneumatic","6 & Hydraulic","8 & Electric","9 & Series Elastic","9 & Hydraulic","9 & Electric","9 & PAM","9 & Pneumatic","6 & Electric","10 & PAM","10 & Pneumatic","10 & Series Elastic","10 & Electric","11 & Series Elastic","11 & Hydraulic","11 & Electric","11 & PAM","11 & Pneumatic","12 & 4","12 & 5","12 & 1","12 & 2","12 & 3","10 & Hydraulic","13 & 5","13 & 1","13 & 2","13 & 4","14 & 5","14 & 1","14 & 2","14 & 3","14 & 4","15 & 1","15 & 5","15 & 3","16 & 5","16 & 2","16 & 1","13 & 3","15 & 4","16 & 3","16 & 4","17 & 3","17 & 5","17 & 4","17 & 1","17 & 2","18 & 1","18 & 4","18 & 2");
codeNames = c("E.data","S.data","E.design","S.design","S.professional","E.client","V.client","E.consultant","V.consultant","S.collaboration","I.engineer","I.intern","K.actuator","K.rom","K.materials","K.power");
#print(microbenchmark(
#oldRes = old.accumulation(window = windowSize, codes = df[,codeNames],group = unitsList,units = unitsList,stanzas = conversations,sList = sList,gList = gList,uList = uList, binary = T)
#,
#newRes = accumulate.data(df, conversationsBy, unitsBy, codeNames, window=windowSize)
#,
#times = 100))


newRes = loadFile(f, codeNames[1:4], unitsBy[1:4], stanzasBy, windowSize = 1)
#system.time(runENA_c(newRes, dims = 2, optimMethod = "C"))
