
library(R6);
library(data.table);
library(microbenchmark);

#Rcpp::sourceCpp('code/functions/ENAMaker/cpp/02/src/ena.cpp');
#Rcpp::sourceCpp('code/functions/ENAMaker/cpp/02/src/svector_to_ut.cpp');
#Rcpp::sourceCpp('code/functions/ENAMaker/cpp/02/src/ref_window_df.cpp');
#Rcpp::sourceCpp('code/functions/ENAMaker/cpp/02/src/ref_window_sum.cpp');

# load("~/old-df.RData")

#source('code/functions/ENAMaker/cpp/02/R/accumulate.R');
#source('code/functions/ENAMaker/cpp/02/R/do_optimization.R');
#source('code/functions/ENAMaker/cpp/02/R/full_opt_soln.R');
#source('code/functions/ENAMaker/cpp/02/R/ENAdata.R');
#source('code/functions/ENAMaker/cpp/02/R/ENAset.R');


makeENA = function(csvPath, unitsBy, units, conversationsBy, codeNames, windowSize = 1, setName = 'x') {
  print("Start reading file in.")

	enadata = ENAdata$new(
	  #df,
	  csvPath,
	  unitsBy = unitsBy,
	  units = units,
	  conversationsBy = conversationsBy,
	  codeNames = codeNames,
	  windowSize = windowSize
	);
  print("Reading file complete.");

	runIt <- function() {
	  enaset = ENAset$new(enadata, sphereNorm = F)
	  enaset$process();
	  assign(x=setName, value=enaset, envir=.GlobalEnv)
	  #save(substitute(deparse(setName)), file = paste0(setName, '.rdata'))
	}

	#done = microbenchmark(
	  runIt()
	  #, times=1)
	#cat(done[[2]]/1e9, file = "model_perf", sep = "\n", append=T)
	#print(done)

	#source('~/Workspaces/RStudio2/rENA/demo/plotTests.R')
}

#source('code/functions/ENAMaker/cpp/02/R/buildSet2.R')
csvPath = 'data/bigdata/dataset_for_ENA_Include_STRATG_3_TRAJECT.csv'
#csv2 = read.csv(csvPath)
csv = fread(csvPath) #, stringsAsFactors = F, strip.white = T)
#csv$STUDENT_ID_WEEK = apply(csv[,c('STUDENT_ID', 'WEEK')],1, paste,collapse=" & ")
#write.csv(x = csv, file = 'data/dataset_for_ENA_Include_STRATG_3_TRAJECT.csv', row.names=F)

codeNames = names(csv)[14:31]

profName = "fullprof2.out";
Rprof(filename=profName);

  makeENA(csv,
  	unitsBy = 'STUDENT_ID_WEEK',
  	setName = 'A_STUDENT_ID.WEEK',
  	units = unique(csv$STUDENT_ID_WEEK)[1],
  	conversationsBy = c('STUDENT_ID_WEEK', 'row.id'),
  	codeNames = codeNames,
  	windowSize = 0)

Rprof(NULL)

