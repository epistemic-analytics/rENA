testData = enadata;
#testData = gotData;
stanzasBy = testData$get("conversationsBy")
unitsBy = testData$get("unitsBy")
dfDT_codes = as.data.table(copy(testData$get('file')));
dfDT_codes$ENA_UNIT = trimws(apply(dfDT_codes[,unitsBy,with=F], 1, paste, collapse="."));
codeNames = testData$get("codeNames");
codedTriNames = svector_to_ut(codeNames);

retDF <- function() {
  dfDT_codes1 = copy(dfDT_codes);
  arma=dfDT_codes1[, (codedTriNames):=ref_window_df(.SD,windowSize=2), by=stanzasBy, .SDcols=codeNames, with=T]
}
retMat <- function() {
  dfDT_codes2 = copy(dfDT_codes);
  #rcpp=dfDT_codes2[, (codedTriNames):=ref_window_df2(.SD,windowSize=2), by=stanzasBy, .SDcols=codeNames, with=T]
  #dfDT_codes2$rowID = 1:nrow(dfDT_codes2)
  dfDT_codes2[,ENA_CONVERSATION:=.GRP, by=stanzasBy, with=T]
  res=ref_window_from_conv(data.matrix(dfDT_codes2[, c(codeNames, "ENA_CONVERSATION"), with=F]), unique(dfDT_codes2$ENA_CONVERSATION))
  #res=data.table(res)
  #res=merge(dfDT_codes, res, by.x = "rowID", by.y = "V7")
  #res = cbind(dfDT_codes2, res)
  #res[[length(res)+1]] = 1:nrow(res);
  #cbind(dfDT_codes2, res);
}

done=microbenchmark(
#done = profvis::profvis({
  arma = retDF()
  ,
  rcpp = retMat()
#})
 ,times = 1000)
print(done)
