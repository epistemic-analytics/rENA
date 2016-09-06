accumulate <- function(dfDT, by, codeNames, window = 3,append=F) {
  if(!is.data.table(dfDT)) {
    dfDT = as.data.table(dfDT);
  }

  codeNameSums = paste0(codeNames,"_","sum");
  codeNameRefSums = paste0(codeNames,"_","sum_ref");
  codedTriNames = svector_to_ut(codeNames);
  if(append == T) {
    codedTriNames = c(codedTriNames, codeNameRefSums);
  }
  #print(codedTriNames)
  #summedDfDT = dfDT[, (codeNameSums) := roll.sum.pad(.SD,window), by=.(GroupName, ActivityNumber), .SDcols = codeNames];
  #summedDfDT[, (codedTriNames) := dfvector_to_ut(.SD, codedTriNames), .SDcols = codeNameSums, by = 1:nrow(summedDfDT)];
  #summedDfDT_users = summedDfDT[UserName %in% uList, lapply(.SD, sum, na.rm=T), by =.(UserName), .SDcols = codeNameSums]

  #dfDT_codes=dfDT[, by = conversationsBy, .SDcols = codeNames, with = T]

  ##dfDT_windows=dfDT_codes[, {ref_window_df2(.SD,windowSize=window,append=TRUE)}, by=conversationsBy, .SDcols=codeNames, with=T]
  ##dfDT_windows=dfDT_codes[, {ref_window_df2(.SD,windowSize=window,append=TRUE)}, by=conversationsBy, .SDcols=codeNames, with=T]

  dfDT_codes = copy(dfDT);
  dfDT_codes[, (codedTriNames) := ref_window_df2(.SD,windowSize=window,append=append), by=conversationsBy, .SDcols=codeNames, with=T];
  dfDT_codes_u = dfDT_codes[UserName %in% gList, { triNames=.SD[, (codedTriNames), with=F]; lapply(triNames, sum) }, by=unitsBy ];

  #colnames(dfDT_windows) = c(colnames(dfDT_windows)[1:length(conversationsBy)], codedTriNames, codeNames[1:length(codeNames)])

  return(dfDT_codes_u);
}
