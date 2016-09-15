accumulate <- function(dfDT, stanzasBy, unitsBy, codeNames, window = 3,append=F) {
  if(!is.data.table(dfDT)) {
    dfDT = as.data.table(dfDT);
  }
  dfDT_codes = copy(dfDT);

  codedTriNames = svector_to_ut(codeNames);
  dfDT_codes[, (codedTriNames) := ref_window_df(.SD,windowSize=window), by=stanzasBy, .SDcols=codeNames, with=T];
  #dfDT_codes_u = dfDT_codes[, { triNames=.SD[, (codedTriNames), with=F]; lapply(triNames, sum) }, by=unitsBy ];
  dfDT_codes_u = dfDT_codes[UserName %in% gList, ref_window_sum(.SD), by=unitsBy, .SDcols=(codedTriNames) ];

  return(dfDT_codes_u); #_u);
}
