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
  df = read.csv(f);
  #df = df[order(as.POSIXlt(df$Timestamp, format = "%m/%d/%Y %H:%M")), ]

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

#codeNames = c("E.data","S.data","E.design","S.design");
codeNames = c("E.data","S.data","E.design","S.design","S.professional","E.client","V.client","E.consultant","V.consultant","S.collaboration","I.engineer","I.intern","K.actuator","K.rom","K.materials","K.power");

unitsBy = c("UserName");

conversationsBy = c("ActivityNumber", "GroupName");

#print(microbenchmark(
#oldRes = old.accumulation(window = windowSize, codes = df[,codeNames],group = unitsList,units = unitsList,stanzas = conversations,sList = sList,gList = gList,uList = uList, binary = T)
#,
#newRes = accumulate.data(df, conversationsBy, unitsBy, codeNames, window=windowSize)
#,
#times = 100))


newRes = loadFile(f, codeNames, unitsBy, conversationsBy, windowSize = 1)
#system.time(runENA_c(newRes, dims = 2, optimMethod = "C"))
