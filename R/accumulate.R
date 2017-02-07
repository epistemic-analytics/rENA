accumulate.data <- function(
  dfDT,
  stanzasBy, unitsBy, units,
  codeNames, stanzas = NULL,
  unitsSelected = NULL, window = 3,
  append=F,binary=T,
  exact.match = T
) {
  if(!is.data.table(dfDT)) {
    dfDT = as.data.table(dfDT);
  }
  dfDT_codes = copy(dfDT);
  dfDT_codes$ENA_UNIT = trimws(apply(dfDT_codes[,unitsBy,with=F], 1, paste, collapse="."));
  codedTriNames = svector_to_ut(codeNames);
  #browser()
  dfDT_codes[, (codedTriNames) := ref_window_df(.SD,windowSize=window), by=stanzasBy, .SDcols=codeNames, with=T];
  #dfDT_codes[, (codedTriNames) := ifelse(nrow(.SD)==1,(as.data.frame(t(vector_to_ut(as.matrix(.SD))))),(ref_window_df(.SD,windowSize=window))), by=stanzasBy, .SDcols=codeNames, with=T];

  if(is.null(units)) {
    #return();
    units = trimws(apply(unique(dfDT[character %in% unitsSelected, unitsBy, with = F]), 1, paste, collapse="."));
  }

  if(exact.match == T) {
    dfDT_codes_u = dfDT_codes[ENA_UNIT %in% units, ref_window_sum(.SD), by=ENA_UNIT, .SDcols=(codedTriNames) ];
  } else {
    dfDT_codes_u = dfDT_codes[ENA_UNIT %like% units, ref_window_sum(.SD), by=ENA_UNIT, .SDcols=(codedTriNames) ];
  }
  #dfDT_codes_u = dfDT_codes_u[rowSums(dfDT_codes_u[,c(2:ncol(dfDT_codes_u)), with=F]) > 0]
  colnames(dfDT_codes_u) = c("ENA_UNIT", codedTriNames);
  rownames(dfDT_codes_u) = units;

  attr(dfDT_codes_u,"filters") <- unique(dfDT[character %in% unitsSelected, unitsBy, with = F]);

  #browser()
  return(dfDT_codes_u);
}
