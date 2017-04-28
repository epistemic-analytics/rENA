
library(R6);
library(data.table);
library(microbenchmark);

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
source('R/rENA.R');


#source('code/functions/ENAMaker/cpp/02/R/buildSet2.R')
csvPath = 'inst/extdata/bigdata/dataset_for_ENA_Include_STRATG_3_TRAJECT.csv'
csv = fread(csvPath) #, stringsAsFactors = F, strip.white = T)
#csv$STUDENT_ID_WEEK = apply(csv[,c('STUDENT_ID', 'WEEK')],1, paste,collapse=" & ")
#csv$rowid = csv$row.id
#write.csv(x = csv, file = csvPath, row.names=F)
codeNames = names(csv)[14:31]

# profName = "fullprof3.out";
# Rprof(filename=profName);

  enadata = ENAdata$new(
    csv[1:500,],
    unitsBy = c('STUDENT_ID_WEEK'),
    #units = units,
    conversationsBy = c('rowid'),
    codeNames = codeNames,
    windowSize = 1
  )
#, times=1)

#microbenchmark(
 #r_cor = ENAset$new(enadata, optim.method=do_optimization)$process(),
 #c_cor  =
  enaset = ENAset$new(enadata, optim.method=do_optimization, inPar=F)$process()
 #times = 10
#)

#Rprof(NULL)

