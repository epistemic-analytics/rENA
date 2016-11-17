accumulate.data <- function(dfDT, stanzasBy, unitsBy, units, codeNames, window = 3,append=F) {
  if(!is.data.table(dfDT)) {
    dfDT = as.data.table(dfDT);
  }
  dfDT_codes = copy(dfDT);

  dfDT_codes$ENA_UNIT = apply(dfDT_codes[,unitsBy,with=F], 1, paste, collapse=".");

  codedTriNames = svector_to_ut(codeNames);
  dfDT_codes[, (codedTriNames) := ref_window_df(.SD,windowSize=window), by=stanzasBy, .SDcols=codeNames, with=T];

  dfDT_codes_u = dfDT_codes[ENA_UNIT %in% units, ref_window_sum(.SD), by=unitsBy, .SDcols=(codedTriNames) ];

  colnames(dfDT_codes_u) = c(unitsBy, codedTriNames);

  return(dfDT_codes_u);
}
