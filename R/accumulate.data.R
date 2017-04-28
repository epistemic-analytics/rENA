##
#' @title Accumulate Data
#' @description Accumulate Data
#' @import data.table
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
    #dfDT_codes$ENA_UNIT = dfDT_codes[,{apply(.SD,1,function(x){paste(trimws(x),collapse=".")})},with=T,.SDcols=unitsBy];
    dfDT_codes$ENA_UNIT = merge_columns_c(dfDT_codes, cols=unitsBy, sep=".");

  ##
  # String vector of codesnames representing the names of the co-occurrences
  ##
    vL = length(codeNames);
    adjacency.length = ( (vL * (vL + 1)) / 2) - vL ;
    codedTriNames = paste("adjacency.code",rep(1:adjacency.length), sep="-");

  ##
  # Accumulated windows appended to the end of each row
  #
  # FIXME: Don't append on the results to the initial data.table, keep a separate
  #        to lookup the results for the co-occurred values later on.
  ##
    if(window == 1) {
      dfDT.co.occurrences = dfDT_codes[,{ ocs=data.table::as.data.table(rows_to_co_occurrences(.SD[,.SD,.SDcols=codeNames, with=T])); data.table::data.table(.SD,ocs) }, .SDcols=c(codeNames, stanzasBy), with=T]
    } else {
      #browser();
      dfDT.co.occurrences = dfDT_codes[, ref_window_df(.SD,windowSize=window), by=stanzasBy, .SDcols=codeNames, with=T];
    }

    colnames(dfDT.co.occurrences)[grep("V\\d+",colnames(dfDT.co.occurrences))] = codedTriNames;
    dfDT.co.occurrences$ENA_UNIT = dfDT_codes$ENA_UNIT #[,{apply(.SD,1,function(x){paste(trimws(x),collapse=".")})},with=T,.SDcols=unitsBy];
    #dfDT_codes[, (codedTriNames) := ref_window_df(.SD,windowSize=window), by=stanzasBy, .SDcols=codeNames, with=T];

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
  # Keep original columns used for units
  ###
    dfDT.co.occurrences[, (unitsBy) := dfDT_codes[,.SD,.SDcols=unitsBy]];

  ###
  # Sum each unit found in dfDT.co.occurrences
  ###
  #dfDT.summed.units = dfDT_codes[ENA_UNIT %in% units, ref_window_sum(.SD), by=unitsBy, .SDcols=(codedTriNames) ];
    dfDT.summed.units = dfDT.co.occurrences[ENA_UNIT %in% units, ref_window_sum(.SD), by=unitsBy, .SDcols=(codedTriNames) ];
    dfDT.summed.units$ENA_UNIT = dfDT.summed.units[,{apply(.SD,1,function(x){paste(trimws(x),collapse=".")})},with=T,.SDcols=unitsBy];

  ###
  # Name the rows an columns accordingly
  ###
    colnames(dfDT.summed.units)[grep("V\\d+",colnames(dfDT.summed.units))] = codedTriNames;
    rownames(dfDT.summed.units) = dfDT.summed.units$ENA_UNIT;

  ###
  # Set attributes containing matrix representations of the data used for
  # columns and rows
  ###
    codedRow1 = codeNames[triIndices(length(codeNames), 0)[,1]+1];
    codedRow2 = codeNames[triIndices(length(codeNames), 1)[,1]+1];
    attr(dfDT.summed.units, "adjacency.matrix") = rbind(codedRow1, codedRow2);
    attr(dfDT.summed.units, UNIT_NAMES) = dfDT.summed.units[,  .SD ,with=T,.SDcols=unitsBy]

  return(list(
    "units.co.occurred" = dfDT.co.occurrences,
    "units.summed" = dfDT.summed.units
  ));
}
