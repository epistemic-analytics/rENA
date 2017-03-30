##
#' @title Accumulate Data
#' @description Accumulate rows of data
# @export
##
accumulate.data <- function(
  dfDT,
  stanzasBy, unitsBy, units,
  codeNames, stanzas = NULL,
  unitsSelected = NULL, window = 3,
  append=F,binary=T,
  units.exclude = c()
) {
  ### We need data
    if(is.null(dfDT) || nrow(dfDT) < 1) return(-1);

  ###
  # We need a data.table, it's worth it.
  ###
    if(!data.table::is.data.table(dfDT)) {
      dfDT = data.table::as.data.table(dfDT);
    }

  ###
  # Make a copy of the data for safe usage
  ###
    dfDT_codes = data.table::copy(dfDT);

  ###
  # Create a column representing the ENA_UNIT as defined
  # by the the `unitsBy` parameter
  ###
    dfDT_codes$ENA_UNIT = dfDT_codes[,{apply(.SD,1,function(x){paste(trimws(x),collapse=".")})},with=T,.SDcols=unitsBy];

  ##
  # String vector of codesnames representing the names of the co-occurrences
  ##
    vL = length(codeNames);
    adjacency.length = ( (vL * (vL + 1)) / 2) - vL ;
    codedTriNames = paste("adjacency.code",rep(1:adjacency.length), sep="-");

  ##
  # Accumulated windows appended to the end of each row
  ##
    dfDT_codes[, (codedTriNames) := ref_window_df(.SD,windowSize=window), by=stanzasBy, .SDcols=codeNames, with=T];

  ##
  # If units aren't supplied, use all available
  ##
    if(is.null(units)) {
      units = dfDT_codes$ENA_UNIT;
    }

    if(!is.null(units.exclude) && length(units.exclude)>0){
      units = units[which(!units %in% units.exclude)];
    }

  ###
  # Sum each unit.
  ###
    dfDT_summed_units = dfDT_codes[ENA_UNIT %in% units, ref_window_sum(.SD), by=unitsBy, .SDcols=(codedTriNames) ];
    dfDT_summed_units$ENA_UNIT = dfDT_summed_units[,{apply(.SD,1,function(x){paste(trimws(x),collapse=".")})},with=T,.SDcols=unitsBy];

  ###
  # Name the rows an columns accordingly
  ###
    colnames(dfDT_summed_units)[grep("V",colnames(dfDT_summed_units))] = codedTriNames;
    rownames(dfDT_summed_units) = dfDT_summed_units$ENA_UNIT;

  ###
  # Set attributes containing matrix representations of the data used for
  # columns and rows
  ###
    codedRow1 = codeNames[triIndices(length(codeNames), 0)[,1]+1];
    codedRow2 = codeNames[triIndices(length(codeNames), 1)[,1]+1];
    attr(dfDT_summed_units, "adjacency.matrix") = rbind(codedRow1, codedRow2);
    attr(dfDT_summed_units, UNIT_NAMES) = dfDT_summed_units[,  .SD ,with=T,.SDcols=unitsBy]

  return(dfDT_summed_units);
}
