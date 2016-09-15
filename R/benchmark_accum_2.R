library("data.table");
library(RcppRoll);
library(microbenchmark);
Rcpp::sourceCpp('src/svector_to_ut.cpp')
#Rcpp::sourceCpp('src/dfvector_to_ut.cpp')
#Rcpp::sourceCpp('src/vector_to_ut.cpp')
Rcpp::sourceCpp('src/ref_window_df.cpp')
source('~/Workspaces/RStudio2/rENA/R/old.accumulation.R');
#source('~/Workspaces/RStudio2/rENA/R/roll.sum.pad.R');
#source('~/Workspaces/RStudio2/rENA/R/lagpad.R');
source('~/Workspaces/RStudio2/rENA/R/accumulate.R');

df2= read.csv("./data/SENS.Proposal.dataset.2.csv");

codeNames = c("Homework..course.organization","Critical.thinking","Diseases","Climate.change","Food..obesity","Population","Energy","Communities..social.groups","Global.challenges..public.initiative","Humanity..issues.and.challenges","Water","Learning..in.general...student.interests..course.related.");
#codeNames = codeNames[1:4];

unitsBy = c("student_id");
unitsListTable = data.frame(df2[, unitsBy]);
colnames(unitsListTable) = unitsBy;
unitsList = unitsListTable; #data.frame(dfDT[, paste(collapse = " & ", UserName), by = unitsBy]);

conversationsBy = c("forum_id", "thread_id");
conversations = df2[, conversationsBy]
conversationsList = unique(conversations)

sList = paste(conversationsList$ActivityNumber, conversationsList$GroupName, sep = " & ");
gList = data.frame(as.data.table(df2)[, paste(collapse = " & ", student_id), by = unitsBy])$V1;
#gList = gList[1:4];
uList = gList

windowSize = 1;
print(microbenchmark(
oldRes = old.accumulation(window = windowSize, codes = df2[,codeNames],group = unitsList,units = unitsList,stanzas = conversations,sList = sList,gList = gList,uList = uList, binary = T)
,
newRes = accumulate(df2, conversationsBy, unitsBy, codeNames, window=windowSize)
,
times = 100))
