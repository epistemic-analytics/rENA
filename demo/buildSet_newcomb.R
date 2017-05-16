library(R6);
library(data.table);

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

df = read.csv("./inst/extdata/newcombnonbin2r.csv");
codeNames = c('P1r','P2r','P3r','P4r','P5r','P6r','P7r','P8r','P9r','P10r','P11r','P12r','P13r','P14r','P15r','P16r','P17r','P1s','P2s','P3s','P4s','P5s','P6s','P7s','P8s','P9s','P10s','P11s','P12s','P13s','P14s','P15s','P16s','P17s');
codeNames_less = codeNames[1:4];


units_all = trimws(apply(df[,c('week','send')], 1, paste, collapse="."));
units_all_less = units_all[1:4];


enadataNewcomb = ENAdata$new(df, units.by = c("week","send"), conversations.by = c("stanza"), code.names = codeNames, window.size = 1);
enasetNewcomb = ENAset$new(enadataNewcomb)$process()
print("Done.")
